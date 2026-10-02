import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

from datetime import datetime, timedelta, timezone

from hypothesis import given, strategies as st

from app.services.reminder_parser import detect_ambiguities, normalize_reminder

NOW = datetime(2026, 10, 1, 12, 0, tzinfo=timezone.utc)


def codes(parsed, text="x"):
    return {a["code"] for a in detect_ambiguities(parsed, text, NOW)}


def parsed(**kw):
    return normalize_reminder({"title": "t", **kw})


def test_missing_date_needs_review_unless_recurring():
    assert codes(parsed()) == {"no_date"}
    assert codes(parsed(type="recurring")) == set()


def test_past_date_flagged():
    assert "in_past" in codes(parsed(scheduled_at="2026-09-01T10:00:00+00:00"))


def test_missing_timezone_flagged():
    assert "no_timezone" in codes(parsed(scheduled_at="2026-10-10T10:00:00"))


def test_midnight_without_time_in_text_is_assumed_time():
    p = parsed(scheduled_at="2026-10-10T00:00:00+00:00")
    assert "time_assumed" in codes(p, "remind me on October 10")
    assert "time_assumed" not in codes(p, "remind me at 12 am on October 10")
    assert "time_assumed" not in codes(p, "remind me at midnight")


def test_clear_future_reminder_has_no_ambiguity():
    p = parsed(scheduled_at="2026-10-10T09:30:00+05:30")
    assert codes(p, "remind me Oct 10 at 9:30") == set()


@given(st.datetimes(min_value=datetime(2026, 10, 2), max_value=datetime(2035, 1, 1), timezones=st.just(timezone.utc)).filter(lambda d: d.hour or d.minute))
def test_future_aware_datetimes_with_a_time_are_never_ambiguous(dt):
    assert codes(parsed(scheduled_at=dt.isoformat()), "at 9:00") == set()


@given(st.text(max_size=60), st.one_of(st.none(), st.text(max_size=30)))
def test_never_crashes_on_garbage(text, scheduled):
    assert isinstance(detect_ambiguities(parsed(scheduled_at=scheduled), text, NOW), list)
