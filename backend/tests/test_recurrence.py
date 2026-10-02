import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

import re
from datetime import datetime, timezone

import pytest
from hypothesis import given, strategies as st

from app.config import settings
from app.services import scheduling
from app.services.recurrence import parse_rrule, to_schedule_expression

START = datetime(2026, 10, 5, 9, 30, tzinfo=timezone.utc)  # a Monday


@pytest.mark.parametrize("rule,expected", [
    ("FREQ=DAILY", "cron(30 9 * * ? *)"),
    ("RRULE:FREQ=WEEKLY;BYDAY=MO,WE", "cron(30 9 ? * MON,WED *)"),
    ("FREQ=WEEKLY", "cron(30 9 ? * MON *)"),            # defaults to start's weekday
    ("FREQ=MONTHLY", "cron(30 9 5 * ? *)"),
    ("FREQ=MONTHLY;BYMONTHDAY=15", "cron(30 9 15 * ? *)"),
    ("FREQ=YEARLY", "cron(30 9 5 10 ? *)"),
    ("FREQ=DAILY;INTERVAL=3", "rate(3 days)"),
])
def test_supported_rules(rule, expected):
    assert to_schedule_expression(rule, START) == expected


@pytest.mark.parametrize("rule", [
    "", "junk", "FREQ", "BYDAY=MO", "FREQ=HOURLY", "FREQ=WEEKLY;INTERVAL=2",
    "FREQ=DAILY;COUNT=3", "FREQ=WEEKLY;UNTIL=20261231T000000Z", "FREQ=WEEKLY;BYDAY=XX",
    "FREQ=MONTHLY;BYMONTHDAY=40", "FREQ=DAILY;INTERVAL=0", "FREQ=DAILY;INTERVAL=x",
])
def test_unsupported_rules_return_none(rule):
    assert to_schedule_expression(rule, START) is None


def test_parse_rrule_strips_prefix_and_uppercases():
    assert parse_rrule("rrule:freq=daily") == {"FREQ": "DAILY"}


CRON = re.compile(r"^cron\(\d{1,2} \d{1,2} [\d*?,A-Z]+ [\d*]+ [\d*?,A-Z]+ \*\)$|^cron\(\d{1,2} \d{1,2} \S+ \S+ \S+ \*\)$|^rate\(\d+ days\)$")


@given(
    st.sampled_from(["DAILY", "WEEKLY", "MONTHLY", "YEARLY"]),
    st.datetimes(min_value=datetime(2026, 1, 1), max_value=datetime(2035, 1, 1)),
)
def test_expression_uses_the_start_time_of_day(freq, start):
    expr = to_schedule_expression(f"FREQ={freq}", start)
    assert expr is not None and CRON.match(expr)
    assert f"cron({start.minute} {start.hour} " in expr


@given(st.text(max_size=40), st.datetimes(min_value=datetime(2026, 1, 1), max_value=datetime(2035, 1, 1)))
def test_never_crashes_on_garbage(rule, start):
    to_schedule_expression(rule, start)


class FakeScheduler:
    class exceptions:
        class ResourceNotFoundException(Exception):
            pass

    def __init__(self):
        self.created, self.deleted = [], []

    def create_schedule(self, **kw):
        self.created.append(kw)

    def delete_schedule(self, **kw):
        self.deleted.append(kw["Name"])


@pytest.fixture
def fake(monkeypatch):
    f = FakeScheduler()
    monkeypatch.setattr(scheduling, "_scheduler", lambda: f)
    monkeypatch.setattr(settings, "scheduler_target_arn", "arn:target")
    monkeypatch.setattr(settings, "scheduler_role_arn", "arn:role")
    return f


FUTURE = datetime(2030, 1, 7, 9, 30, tzinfo=timezone.utc)


def test_recurring_reminder_gets_one_recurring_schedule(fake):
    names = scheduling.schedule_reminder(
        "r1", "u1", "Standup", "medium", FUTURE, ["-1h", "-1d"],
        recurrence_rule="FREQ=WEEKLY;BYDAY=MO", timezone_name="Asia/Kolkata",
    )
    assert names == ["rem-r1-rec"] and len(fake.created) == 1
    c = fake.created[0]
    assert c["ScheduleExpression"] == "cron(30 9 ? * MON *)"
    assert c["ScheduleExpressionTimezone"] == "Asia/Kolkata"
    assert "ActionAfterCompletion" not in c, "recurring schedules must not self-delete"


def test_unsupported_rule_falls_back_to_one_time_schedules(fake):
    names = scheduling.schedule_reminder(
        "r1", "u1", "t", "high", FUTURE, ["-1h"], recurrence_rule="FREQ=DAILY;COUNT=3"
    )
    assert len(names) == 2 and all(c["ScheduleExpression"].startswith("at(") for c in fake.created)


def test_cancel_removes_the_recurring_schedule(fake):
    scheduling.cancel_reminder("r1", FUTURE, [])
    assert "rem-r1-rec" in fake.deleted
