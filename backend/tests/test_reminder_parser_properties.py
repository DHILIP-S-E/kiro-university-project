"""
Property-based tests for reminder parsing (spec R1.2, R1.4).

Whatever an LLM returns — garbage, wrong types, missing keys — normalize_reminder
must yield a valid reminder, and be idempotent.
"""

import os
from datetime import datetime, timezone

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

from hypothesis import given, settings, strategies as st

from app.services.reminder_parser import (
    MAX_TITLE_LENGTH,
    VALID_PRIORITIES,
    VALID_TYPES,
    normalize_offsets,
    normalize_reminder,
    offset_to_minutes,
)

json_scalars = st.one_of(
    st.none(), st.booleans(), st.integers(), st.floats(allow_nan=False), st.text()
)
json_values = st.recursive(
    json_scalars,
    lambda children: st.one_of(
        st.lists(children, max_size=5),
        st.dictionaries(st.text(max_size=10), children, max_size=5),
    ),
    max_leaves=15,
)
llm_output = st.one_of(
    json_values,
    st.fixed_dictionaries(
        {},
        optional={
            "title": json_values,
            "type": json_values,
            "priority": json_values,
            "scheduled_at": json_values,
            "offsets": json_values,
        },
    ),
)
valid_offsets = st.builds(
    lambda n, u: f"-{n}{u}", st.integers(1, 999), st.sampled_from("mhdw")
)


@given(llm_output, st.text(max_size=200))
def test_output_is_always_well_formed(raw, fallback):
    r = normalize_reminder(raw, fallback)
    assert set(r) == {"title", "type", "scheduled_at", "priority", "offsets"}
    assert isinstance(r["title"], str) and r["title"].strip()
    assert len(r["title"]) <= MAX_TITLE_LENGTH
    assert r["type"] in VALID_TYPES
    assert r["priority"] in VALID_PRIORITIES
    if r["scheduled_at"] is not None:
        datetime.fromisoformat(r["scheduled_at"].replace("Z", "+00:00"))
    assert all(offset_to_minutes(o) for o in r["offsets"])


@given(llm_output, st.text(max_size=200))
def test_normalisation_is_idempotent(raw, fallback):
    once = normalize_reminder(raw, fallback)
    assert normalize_reminder(once, fallback) == once


@given(st.lists(st.one_of(valid_offsets, st.text(max_size=8), st.integers())))
def test_offsets_sorted_furthest_first_and_unique(raw):
    result = normalize_offsets(raw)
    minutes = [offset_to_minutes(o) for o in result]
    assert minutes == sorted(set(minutes), reverse=True)


@given(st.lists(valid_offsets, min_size=1))
def test_valid_offsets_are_never_dropped(raw):
    kept = {offset_to_minutes(o) for o in normalize_offsets(raw)}
    assert kept == {offset_to_minutes(o) for o in raw}


@given(
    st.datetimes(
        min_value=datetime(2000, 1, 1), max_value=datetime(2100, 1, 1), timezones=st.just(timezone.utc)
    )
)
def test_valid_iso_datetime_is_preserved(dt):
    iso = dt.isoformat()
    assert normalize_reminder({"title": "x", "scheduled_at": iso})["scheduled_at"] == iso


@given(st.text(min_size=1, max_size=2000).filter(lambda s: s.strip()))
def test_valid_title_kept_and_bounded(title):
    r = normalize_reminder({"title": title})
    assert r["title"] == title.strip()[:MAX_TITLE_LENGTH].strip() or r["title"] == "Reminder"


@settings(max_examples=50)
@given(st.text(max_size=300))
def test_extract_json_free_text_never_crashes_normaliser(text):
    assert normalize_reminder({"title": text})["title"]
