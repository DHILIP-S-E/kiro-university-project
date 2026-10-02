import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

import pytest
from hypothesis import given, strategies as st

from app.services.converse import build_request, extract_text


def test_request_shape():
    r = build_request("apac.amazon.nova-lite-v1:0", "hello", max_tokens=300)
    assert r["modelId"] == "apac.amazon.nova-lite-v1:0"
    assert r["messages"] == [{"role": "user", "content": [{"text": "hello"}]}]
    assert r["inferenceConfig"] == {"maxTokens": 300, "temperature": 0.1}
    assert "guardrailConfig" not in r


def test_guardrail_needs_both_id_and_version():
    assert "guardrailConfig" not in build_request("m", "p", guardrail_id="g")
    assert "guardrailConfig" not in build_request("m", "p", guardrail_version="1")
    r = build_request("m", "p", guardrail_id="g1", guardrail_version="2")
    assert r["guardrailConfig"] == {"guardrailIdentifier": "g1", "guardrailVersion": "2"}


def resp(*blocks, stop="end_turn"):
    return {"output": {"message": {"role": "assistant", "content": list(blocks)}}, "stopReason": stop}


def test_extracts_text_block():
    assert extract_text(resp({"text": '  {"a": 1}  '})) == '{"a": 1}'


def test_ignores_reasoning_blocks_and_joins_text():
    out = extract_text(resp({"reasoningContent": {"reasoningText": {"text": "thinking..."}}}, {"text": "part1 "}, {"text": "part2"}))
    assert out == "part1 part2"


@pytest.mark.parametrize("bad", [
    {}, {"output": {}}, {"output": {"message": {}}}, None,
    resp(), resp({"text": "   "}), resp({"reasoningContent": {}}, stop="max_tokens"),
])
def test_no_text_raises_value_error(bad):
    with pytest.raises(ValueError):
        extract_text(bad)


def test_error_mentions_the_stop_reason():
    with pytest.raises(ValueError, match="guardrail_intervened"):
        extract_text(resp(stop="guardrail_intervened"))


@given(st.dictionaries(st.text(max_size=6), st.one_of(st.none(), st.integers(), st.text(max_size=8)), max_size=4))
def test_garbage_only_ever_raises_value_error(junk):
    try:
        extract_text(junk)
    except ValueError:
        pass
