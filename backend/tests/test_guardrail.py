import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

from app.config import settings
from app.services.bedrock_service import guardrail_kwargs
from workers.capture_processor import _guardrail_kwargs


def test_no_guardrail_when_unconfigured(monkeypatch):
    monkeypatch.setattr(settings, "guardrail_id", "")
    monkeypatch.setattr(settings, "guardrail_version", "")
    assert guardrail_kwargs() == {}


def test_needs_both_id_and_version(monkeypatch):
    monkeypatch.setattr(settings, "guardrail_id", "abc")
    monkeypatch.setattr(settings, "guardrail_version", "")
    assert guardrail_kwargs() == {}


def test_guardrail_passed_to_invoke(monkeypatch):
    monkeypatch.setattr(settings, "guardrail_id", "abc123")
    monkeypatch.setattr(settings, "guardrail_version", "1")
    assert guardrail_kwargs() == {"guardrailIdentifier": "abc123", "guardrailVersion": "1"}


def test_worker_reads_guardrail_from_env(monkeypatch):
    monkeypatch.delenv("GUARDRAIL_ID", raising=False)
    assert _guardrail_kwargs() == {}
    monkeypatch.setenv("GUARDRAIL_ID", "g")
    monkeypatch.setenv("GUARDRAIL_VERSION", "2")
    assert _guardrail_kwargs() == {"guardrailIdentifier": "g", "guardrailVersion": "2"}
