"""
Amazon Bedrock service — all LLM calls happen here.
Flutter never calls Bedrock directly. All AI goes through FastAPI -> this module.
"""

import json
import os
import re
from datetime import datetime
from pathlib import Path

import boto3
from app.config import settings

_bedrock_client = None


def _get_client():
    global _bedrock_client
    if _bedrock_client is None:
        kwargs = {"region_name": settings.aws_region}
        if settings.aws_access_key_id:
            kwargs["aws_access_key_id"] = settings.aws_access_key_id
            kwargs["aws_secret_access_key"] = settings.aws_secret_access_key
        _bedrock_client = boto3.client("bedrock-runtime", **kwargs)
    return _bedrock_client


def _load_prompt(name: str) -> str:
    path = Path(__file__).parent.parent / "prompts" / f"{name}.txt"
    return path.read_text(encoding="utf-8")


def _invoke_claude(model_id: str, prompt: str, max_tokens: int = 1024) -> str:
    """Invoke a Bedrock Claude model and return the text response."""
    client = _get_client()
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": max_tokens,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1,
    })
    response = client.invoke_model(
        modelId=model_id,
        body=body,
        contentType="application/json",
        accept="application/json",
    )
    result = json.loads(response["body"].read())
    return result["content"][0]["text"]


def _extract_json(raw: str) -> dict:
    """Extract the first JSON object from a raw LLM response."""
    match = re.search(r"\{.*\}", raw, re.DOTALL)
    if not match:
        raise ValueError(f"No JSON object found in response: {raw[:200]}")
    return json.loads(match.group())


def parse_reminder(text: str, timezone: str = "UTC") -> dict:
    """
    Parse natural language into a structured reminder dict.
    Uses Claude 3 Haiku for speed and cost efficiency.
    Returns: {title, type, scheduled_at, priority, offsets}
    """
    template = _load_prompt("parse_reminder")
    prompt = template.format(
        current_datetime=datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S UTC"),
        timezone=timezone,
        input=text,
    )
    raw = _invoke_claude(settings.bedrock_model_haiku, prompt, max_tokens=512)
    result = _extract_json(raw)
    # Validate and sanitise required fields
    result.setdefault("title", text[:100])
    result.setdefault("type", "time")
    result.setdefault("priority", "medium")
    result.setdefault("offsets", [])
    result.setdefault("scheduled_at", None)
    return result


def extract_event(text: str) -> dict:
    """
    Extract event metadata from pasted text / URL / email.
    Uses Claude 3 Haiku.
    Returns: {title, event_type, start_at, end_at, location, event_url, ...}
    """
    template = _load_prompt("extract_event")
    prompt = template.format(
        current_date=datetime.utcnow().date().isoformat(),
        text=text,
    )
    raw = _invoke_claude(settings.bedrock_model_haiku, prompt, max_tokens=512)
    result = _extract_json(raw)
    result.setdefault("title", "Event")
    result.setdefault("event_type", "custom")
    result.setdefault("is_virtual", False)
    return result
