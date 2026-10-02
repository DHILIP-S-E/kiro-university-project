import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

import pytest

from app.config import settings
from app.services import bedrock_service


class FakeRuntime:
    def __init__(self, text='{"title": "Submit", "type": "deadline", "scheduled_at": null, "priority": "high", "offsets": []}'):
        self.calls = []
        self.text = text

    def converse(self, **kwargs):
        self.calls.append(kwargs)
        return {"output": {"message": {"content": [{"text": self.text}]}}, "stopReason": "end_turn"}


@pytest.fixture
def fake(monkeypatch):
    f = FakeRuntime()
    monkeypatch.setattr(bedrock_service, "_get_client", lambda: f)
    return f


def test_no_guardrail_when_unconfigured(fake, monkeypatch):
    monkeypatch.setattr(settings, "guardrail_id", "")
    monkeypatch.setattr(settings, "guardrail_version", "")
    bedrock_service.parse_reminder("remind me to submit")
    assert "guardrailConfig" not in fake.calls[0]


def test_guardrail_applied_to_every_call_when_configured(fake, monkeypatch):
    monkeypatch.setattr(settings, "guardrail_id", "abc123")
    monkeypatch.setattr(settings, "guardrail_version", "1")
    bedrock_service.parse_reminder("remind me to submit")
    assert fake.calls[0]["guardrailConfig"] == {"guardrailIdentifier": "abc123", "guardrailVersion": "1"}


def test_fast_model_for_parsing_and_strong_model_for_summaries(fake, monkeypatch):
    monkeypatch.setattr(settings, "bedrock_model_fast", "fast-model")
    monkeypatch.setattr(settings, "bedrock_model_strong", "strong-model")
    bedrock_service.parse_reminder("remind me to submit")
    fake.text = '{"overview": "o"}'
    bedrock_service.summarize_event("Hackathon", "2026-10-04", "some captured notes")
    assert [c["modelId"] for c in fake.calls] == ["fast-model", "strong-model"]


def test_no_claude_model_is_configured_by_default():
    assert "anthropic" not in settings.bedrock_model_fast.lower()
    assert "anthropic" not in settings.bedrock_model_strong.lower()


def test_fenced_json_replies_are_understood(fake):
    fake.text = '```json\n{"title": "Submit prototype", "type": "deadline", "scheduled_at": "2030-10-20T17:00:00+05:30", "priority": "high", "offsets": ["-1d"]}\n```'
    out = bedrock_service.parse_reminder("submit prototype by Oct 20 5pm")
    assert out["title"] == "Submit prototype" and out["type"] == "deadline" and out["offsets"] == ["-1d"]


def test_worker_uses_the_same_request_builder():
    from app.services.converse import build_request

    r = build_request("m", "p", guardrail_id="g", guardrail_version="2")
    assert r["guardrailConfig"]["guardrailVersion"] == "2"
