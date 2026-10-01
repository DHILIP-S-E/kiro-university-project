"""
Bedrock Knowledge Bases integration (spec R4.2, R4.3).

Memory documents live in PostgreSQL (source of truth). For semantic search each
one is also written to S3 as markdown + a metadata sidecar, then a KB ingestion
job embeds it into OpenSearch Serverless. Retrieval is always filtered by
user_id so one user can never see another's memories.

When KNOWLEDGE_BASE_ID is unset every function is a no-op, and the caller falls
back to keyword search over PostgreSQL.
"""

import json
import logging

import boto3

from app.config import settings

logger = logging.getLogger(__name__)

KNOWLEDGE_PREFIX = "knowledge/"


def enabled() -> bool:
    return bool(settings.knowledge_base_id)


def doc_key(user_id: str, doc_id: str) -> str:
    return f"{KNOWLEDGE_PREFIX}{user_id}/{doc_id}.md"


def _bullets(items) -> str:
    return "\n".join(f"- {i if isinstance(i, str) else i.get('title', i)}" for i in items)


def render_memory_markdown(doc: dict) -> str:
    """Markdown for one memory document (a MemoryDocument.to_dict())."""
    sections = [f"# {doc.get('event_title') or 'Event'}", ""]
    if doc.get("overview"):
        sections += [doc["overview"], ""]
    for title, field in (
        ("Key topics", "key_topics"),
        ("Key takeaways", "key_takeaways"),
        ("Things learned", "things_learned"),
        ("People", "important_people"),
        ("Resources", "resources"),
        ("Decisions", "decisions"),
        ("Action items", "action_items"),
    ):
        if doc.get(field):
            sections += [f"## {title}", _bullets(doc[field]), ""]
    return "\n".join(sections).strip() + "\n"


def metadata_for(doc: dict) -> dict:
    """Sidecar metadata used to filter retrieval and cite sources."""
    return {
        "metadataAttributes": {
            "user_id": doc["user_id"],
            "doc_id": doc["id"],
            "event_id": doc.get("event_id") or "",
            "event_title": doc.get("event_title") or "",
        }
    }


def retrieval_filter(user_id: str) -> dict:
    return {"equals": {"key": "user_id", "value": user_id}}


def sync_document(doc: dict) -> None:
    """Write the document to S3 and start a KB ingestion job. Never raises:
    the memory document is already saved; indexing can be retried."""
    if not enabled():
        return
    try:
        key = doc_key(doc["user_id"], doc["id"])
        s3 = boto3.client("s3", region_name=settings.aws_region)
        s3.put_object(
            Bucket=settings.s3_bucket, Key=key,
            Body=render_memory_markdown(doc).encode("utf-8"),
            ContentType="text/markdown",
        )
        s3.put_object(
            Bucket=settings.s3_bucket, Key=key + ".metadata.json",
            Body=json.dumps(metadata_for(doc)).encode("utf-8"),
            ContentType="application/json",
        )
        boto3.client("bedrock-agent", region_name=settings.aws_region).start_ingestion_job(
            knowledgeBaseId=settings.knowledge_base_id,
            dataSourceId=settings.knowledge_base_data_source_id,
        )
    except Exception:
        logger.exception("Knowledge base sync failed for memory document %s", doc.get("id"))


def remove_user_documents(user_id: str) -> None:
    """Delete a user's indexed documents (account deletion, R5.7)."""
    if not enabled():
        return
    try:
        s3 = boto3.client("s3", region_name=settings.aws_region)
        paginator = s3.get_paginator("list_objects_v2")
        for page in paginator.paginate(
            Bucket=settings.s3_bucket, Prefix=f"{KNOWLEDGE_PREFIX}{user_id}/"
        ):
            objs = [{"Key": o["Key"]} for o in page.get("Contents", [])]
            if objs:
                s3.delete_objects(Bucket=settings.s3_bucket, Delete={"Objects": objs})
        boto3.client("bedrock-agent", region_name=settings.aws_region).start_ingestion_job(
            knowledgeBaseId=settings.knowledge_base_id,
            dataSourceId=settings.knowledge_base_data_source_id,
        )
    except Exception:
        logger.exception("Knowledge base cleanup failed for user %s", user_id)


def retrieve_doc_ids(question: str, user_id: str, limit: int = 5) -> list[str]:
    """Semantic search: ids of the user's memory documents most relevant to the
    question, best first. Empty when the KB is disabled or errors."""
    if not enabled():
        return []
    try:
        resp = boto3.client("bedrock-agent-runtime", region_name=settings.aws_region).retrieve(
            knowledgeBaseId=settings.knowledge_base_id,
            retrievalQuery={"text": question},
            retrievalConfiguration={
                "vectorSearchConfiguration": {
                    "numberOfResults": limit,
                    "filter": retrieval_filter(user_id),
                }
            },
        )
    except Exception:
        logger.exception("Knowledge base retrieve failed")
        return []
    return doc_ids_from_results(resp.get("retrievalResults", []))


def doc_ids_from_results(results: list[dict]) -> list[str]:
    """Unique doc_ids in rank order from a KB retrieve response."""
    seen: list[str] = []
    for r in results:
        doc_id = (r.get("metadata") or {}).get("doc_id")
        if doc_id and doc_id not in seen:
            seen.append(doc_id)
    return seen
