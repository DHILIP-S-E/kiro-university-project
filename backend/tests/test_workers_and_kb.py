import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

import json

from hypothesis import given, strategies as st

from app.routers.devices import filter_policy
from app.services.knowledge_base import (
    doc_ids_from_results, doc_key, metadata_for, render_memory_markdown, retrieval_filter,
)
from workers.capture_processor import parse_result_key, text_from_result

DOC = {
    "id": "d1", "user_id": "u1", "event_id": "e1", "event_title": "AWS Hackathon",
    "overview": "Built an agent.", "key_topics": ["Bedrock Agents"], "key_takeaways": ["Use tools"],
    "things_learned": [], "important_people": [], "resources": [], "decisions": [],
    "action_items": [{"title": "Finish prototype", "due_at": None}, "Read docs"],
}


def test_markdown_contains_content_and_skips_empty_sections():
    md = render_memory_markdown(DOC)
    assert md.startswith("# AWS Hackathon")
    assert "Bedrock Agents" in md and "Finish prototype" in md and "Read docs" in md
    assert "## People" not in md


def test_metadata_scopes_document_to_its_owner():
    meta = metadata_for(DOC)["metadataAttributes"]
    assert meta["user_id"] == "u1" and meta["doc_id"] == "d1"
    assert doc_key("u1", "d1") == "knowledge/u1/d1.md"


@given(st.text(min_size=1, max_size=40))
def test_retrieval_always_filters_by_user(user_id):
    assert retrieval_filter(user_id) == {"equals": {"key": "user_id", "value": user_id}}


def test_doc_ids_ranked_unique_and_tolerant():
    results = [
        {"metadata": {"doc_id": "a"}}, {"metadata": {"doc_id": "b"}},
        {"metadata": {"doc_id": "a"}}, {"metadata": {}}, {},
    ]
    assert doc_ids_from_results(results) == ["a", "b"]


def test_device_filter_policy_targets_only_that_user():
    assert json.loads(filter_policy("u1")) == {"user_id": ["u1"]}


KEY = "users/u1/events/e1/voice/c9.m4a"


def test_parse_result_key_transcribe_and_bda():
    assert parse_result_key(f"processed/{KEY}.json")["id"] == "c9"
    bda = f"processed/{KEY}/abc-123/0/standard_output/0/result.json"
    assert parse_result_key(bda)["type"] == "voice"


def test_parse_result_key_ignores_metadata_and_originals():
    assert parse_result_key(f"processed/{KEY}/abc-123/job_metadata.json") is None
    assert parse_result_key(KEY) is None
    assert parse_result_key("processed/random.json") is None


def test_text_from_transcribe_result():
    assert text_from_result({"results": {"transcripts": [{"transcript": "hello world"}]}}) == "hello world"


def test_text_from_bda_image_and_document():
    image = {"image": {"summary": "A slide about RAG", "text_lines": [{"text": "RAG"}, {"text": "Agents"}]}}
    text = text_from_result(image)
    assert "A slide about RAG" in text and "Agents" in text
    doc = {"document": {"representation": {"markdown": "# Notes"}, "summary": "Short"}}
    assert "# Notes" in text_from_result(doc)


@given(st.dictionaries(st.text(max_size=8), st.one_of(st.none(), st.integers(), st.text(max_size=8)), max_size=5))
def test_text_from_unknown_result_never_crashes(result):
    assert isinstance(text_from_result(result), str)
