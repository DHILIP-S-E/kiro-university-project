import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

from datetime import datetime

from hypothesis import given, strategies as st

from app.services.action_items import MAX_ACTIONS, MAX_TITLE, normalize_actions


def test_keeps_title_and_due_date():
    out = normalize_actions([{"title": "Submit the prototype", "due_at": "2026-10-20"}])
    assert out == [{"title": "Submit the prototype", "due_at": "2026-10-20"}]


def test_plain_strings_become_undated_actions():
    assert normalize_actions(["Read the docs"]) == [{"title": "Read the docs", "due_at": None}]


def test_bad_dates_are_dropped_not_guessed():
    assert normalize_actions([{"title": "x", "due_at": "next friday"}])[0]["due_at"] is None


def test_duplicates_and_blank_titles_removed():
    out = normalize_actions(["Ship it", "ship it", "  ", {"title": ""}, {"nope": 1}, 5, None])
    assert [a["title"] for a in out] == ["Ship it"]


def test_not_a_list_gives_nothing():
    assert normalize_actions(None) == [] and normalize_actions("x") == [] and normalize_actions({}) == []


json_values = st.recursive(
    st.none() | st.booleans() | st.integers() | st.text(max_size=20),
    lambda c: st.lists(c, max_size=4) | st.dictionaries(st.text(max_size=6), c, max_size=4),
    max_leaves=12,
)


@given(json_values)
def test_output_is_always_well_formed(raw):
    out = normalize_actions(raw)
    assert len(out) <= MAX_ACTIONS
    titles = [a["title"].lower() for a in out]
    assert len(set(titles)) == len(titles)
    for a in out:
        assert a["title"] and len(a["title"]) <= MAX_TITLE
        if a["due_at"] is not None:
            datetime.fromisoformat(a["due_at"].replace("Z", "+00:00"))


@given(json_values)
def test_idempotent(raw):
    once = normalize_actions(raw)
    assert normalize_actions(once) == once
