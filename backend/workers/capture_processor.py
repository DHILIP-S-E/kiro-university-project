"""
Lambda: SQS -> capture processing (S3 upload -> EventBridge -> SQS -> here).

Two kinds of messages arrive on the queue:

1. A new capture object under users/...  -> start extraction.
   * notes/links: summarise the stored text directly.
   * photos/documents: start a Bedrock Data Automation job (async).
   * voice: start an Amazon Transcribe job (async).
2. A result object under processed/...   -> finish the capture.
   Transcribe and BDA write their output there; we read the text, summarise
   with Bedrock Claude, and store the AI result (spec R3.4-R3.7).

Partial batch failures are reported so SQS retries only failed messages and,
after maxReceiveCount, moves them to the DLQ.
"""

import json
import logging
import os
import re

import boto3
import psycopg2

from app.db_url import sync_database_url

logger = logging.getLogger()
logger.setLevel(logging.INFO)

_KEY_RE = re.compile(
    r"users/(?P<user>[^/]+)/(?:events/(?P<event>[^/]+)/|misc/)(?P<type>[^/]+)/(?P<id>[^./]+)\."
)
_TRANSCRIBE_RESULT_RE = re.compile(
    r"^users/[^/]+/(?:events/[^/]+/|misc/)[^/]+/[^/]+\.json$"
)
PROCESSED_PREFIX = "processed/"


class AsyncJobStarted(Exception):
    """An async extraction job was started; a later result message finishes the capture."""


def parse_s3_key(key: str) -> dict | None:
    """users/{user}/events/{event}/{type}/{id}.ext -> parts; None if not a capture key."""
    match = _KEY_RE.match(key)
    return match.groupdict() if match else None


def parse_result_key(key: str) -> dict | None:
    """processed/<original capture key>[/...]/result.json -> the capture's parts.

    Only real result files count: Transcribe's `<key>.json` and BDA's
    `.../standard_output/<n>/result.json`. BDA's job_metadata.json is ignored."""
    if not key.startswith(PROCESSED_PREFIX):
        return None
    inner = key[len(PROCESSED_PREFIX):]
    is_bda = inner.endswith("/result.json") and "/standard_output/" in inner
    is_transcribe = bool(_TRANSCRIBE_RESULT_RE.match(inner))
    if not (is_bda or is_transcribe):
        return None
    match = _KEY_RE.search(inner)
    return match.groupdict() if match else None


def s3_keys(body: dict) -> list[str]:
    """Object keys from an S3 notification, direct or delivered via EventBridge."""
    if "Records" in body:
        return [r["s3"]["object"]["key"] for r in body["Records"]]
    key = body.get("detail", {}).get("object", {}).get("key")
    return [key] if key else []


def text_from_result(result: dict) -> str:
    """Readable text out of a Transcribe or Bedrock Data Automation result document."""
    def obj(value) -> dict:
        return value if isinstance(value, dict) else {}

    def text(value) -> str:
        return value if isinstance(value, str) else ""

    parts: list[str] = []
    transcripts = obj(result.get("results")).get("transcripts")
    if isinstance(transcripts, list):
        parts.append(" ".join(text(obj(t).get("transcript")) for t in transcripts))
    doc = obj(result.get("document"))
    parts.append(text(obj(doc.get("representation")).get("markdown")))
    parts.append(text(doc.get("summary")))
    image = obj(result.get("image"))
    parts.append(text(image.get("summary")))
    lines = image.get("text_lines")
    if isinstance(lines, list):
        parts.extend(text(obj(line).get("text")) for line in lines)
    parts.append(text(obj(result.get("audio")).get("summary")))
    return "\n".join(p for p in parts if p.strip())


def _guardrail_kwargs() -> dict:
    gid, version = os.environ.get("GUARDRAIL_ID"), os.environ.get("GUARDRAIL_VERSION")
    if not (gid and version):
        return {}
    return {"guardrailIdentifier": gid, "guardrailVersion": version}


def summarise(text: str) -> dict:
    prompt = (
        "Summarise this captured content. Return ONLY JSON: "
        '{"summary": str, "topics": [str], "key_points": [str], "actions": [str]}\n\n'
        + text[:8000]
    )
    resp = boto3.client("bedrock-runtime").invoke_model(
        modelId=os.environ["BEDROCK_MODEL_HAIKU"],
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 800,
            "temperature": 0.1,
            "messages": [{"role": "user", "content": prompt}],
        }),
        **_guardrail_kwargs(),
    )
    raw = json.loads(resp["body"].read())["content"][0]["text"]
    match = re.search(r"\{.*\}", raw, re.DOTALL)
    return json.loads(match.group()) if match else {"summary": raw[:500]}


def _start_extraction(capture_type: str, bucket: str, key: str) -> None:
    project_arn = os.environ.get("BDA_PROJECT_ARN")
    if capture_type in ("photo", "document") and project_arn:
        boto3.client("bedrock-data-automation-runtime").invoke_data_automation_async(
            inputConfiguration={"s3Uri": f"s3://{bucket}/{key}"},
            outputConfiguration={"s3Uri": f"s3://{bucket}/{PROCESSED_PREFIX}{key}/"},
            dataAutomationConfiguration={"dataAutomationProjectArn": project_arn, "stage": "LIVE"},
            dataAutomationProfileArn=os.environ["BDA_PROFILE_ARN"],
        )
        raise AsyncJobStarted(key)
    if capture_type == "voice":
        boto3.client("transcribe").start_transcription_job(
            TranscriptionJobName=f"capture-{os.path.basename(key).split('.')[0]}",
            IdentifyLanguage=True,
            Media={"MediaFileUri": f"s3://{bucket}/{key}"},
            OutputBucketName=bucket,
            OutputKey=f"{PROCESSED_PREFIX}{key}.json",
        )
        raise AsyncJobStarted(key)


def _stored_text(conn, capture_id: str) -> str:
    with conn.cursor() as cur:
        cur.execute("SELECT content FROM captures WHERE id=%s", (capture_id,))
        row = cur.fetchone()
    return row[0] if row and row[0] else ""


def _set_status(conn, capture_id: str, status: str) -> None:
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE captures SET processing_status=%s, updated_at=now() WHERE id=%s",
            (status, capture_id),
        )
    conn.commit()


def _store_result(conn, capture_id: str, text: str, transcript: bool) -> None:
    result = summarise(text) if text.strip() else {"summary": ""}
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE captures SET processing_status='processed', ai_summary=%s, ai_topics=%s, "
            "ai_key_points=%s, ai_actions=%s, "
            "transcription=COALESCE(%s, transcription), updated_at=now() WHERE id=%s",
            (
                result.get("summary", ""),
                json.dumps(result.get("topics", [])),
                json.dumps(result.get("key_points", [])),
                json.dumps(result.get("actions", [])),
                text if transcript else None,
                capture_id,
            ),
        )
    conn.commit()


def _process_text_capture(conn, capture_id: str) -> None:
    """Notes and links: no S3 object, the text lives in the captures table."""
    with conn.cursor() as cur:
        cur.execute("SELECT capture_type, content FROM captures WHERE id=%s", (capture_id,))
        row = cur.fetchone()
    if not row:
        logger.warning("Capture %s not found", capture_id)
        return
    capture_type, content = row
    _set_status(conn, capture_id, "processing")
    if capture_type == "link":
        # Fetching and reading arbitrary pages is out of scope; keep the link itself.
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE captures SET processing_status='processed', ai_summary=%s, "
                "updated_at=now() WHERE id=%s",
                (f"Saved link: {content}", capture_id),
            )
        conn.commit()
        return
    _store_result(conn, capture_id, content or "", transcript=False)


def _process_new(conn, bucket: str, key: str) -> None:
    parts = parse_s3_key(key)
    if not parts:
        logger.info("Ignoring non-capture key %s", key)
        return
    capture_id = parts["id"]
    _set_status(conn, capture_id, "processing")
    text = _stored_text(conn, capture_id)
    if not text:
        _start_extraction(parts["type"], bucket, key)  # raises AsyncJobStarted
    _store_result(conn, capture_id, text, transcript=False)


def _process_result(conn, bucket: str, key: str, parts: dict) -> None:
    body = boto3.client("s3").get_object(Bucket=bucket, Key=key)["Body"].read()
    text = text_from_result(json.loads(body))
    _store_result(conn, parts["id"], text, transcript=parts["type"] == "voice")


def process_key(conn, bucket: str, key: str) -> None:
    result_parts = parse_result_key(key)
    if result_parts:
        _process_result(conn, bucket, key, result_parts)
    elif key.startswith(PROCESSED_PREFIX):
        logger.info("Ignoring auxiliary output %s", key)
    else:
        _process_new(conn, bucket, key)


def _failed_capture_id(key: str) -> str | None:
    parts = parse_result_key(key) or parse_s3_key(key)
    return parts["id"] if parts else None


def handler(event, _context):
    bucket = os.environ["CAPTURE_BUCKET"]
    conn = psycopg2.connect(sync_database_url())
    failures = []
    try:
        for record in event["Records"]:
            try:
                body = json.loads(record["body"])
                if "capture_id" in body:
                    try:
                        _process_text_capture(conn, body["capture_id"])
                    except Exception:
                        logger.exception("Text capture failed: %s", body["capture_id"])
                        conn.rollback()
                        _set_status(conn, body["capture_id"], "failed")
                        raise
                    continue
                for key in s3_keys(body):
                    try:
                        process_key(conn, bucket, key)
                    except AsyncJobStarted:
                        pass
                    except Exception:
                        logger.exception("Processing failed for %s", key)
                        conn.rollback()
                        capture_id = _failed_capture_id(key)
                        if capture_id:
                            _set_status(conn, capture_id, "failed")
                        raise
            except Exception:
                failures.append({"itemIdentifier": record["messageId"]})
    finally:
        conn.close()
    return {"batchItemFailures": failures}
