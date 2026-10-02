import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

import pytest
from hypothesis import given, strategies as st

from app.services.conditions import should_fire
from app.services.reminder_parser import VALID_TYPES, normalize_reminder


@pytest.mark.parametrize("status", ["completed", "cancelled"])
def test_done_dependency_suppresses(status):
    assert should_fire(status) is False


@pytest.mark.parametrize("status", ["active", "snoozed", "missed", "overdue"])
def test_open_dependency_fires(status):
    assert should_fire(status) is True


def test_missing_dependency_still_fires():
    assert should_fire(None) is True


@given(st.text(max_size=20))
def test_only_done_statuses_suppress(status):
    assert should_fire(status) == (status not in {"completed", "cancelled"})


def test_conditional_is_a_valid_parsed_type():
    assert "conditional" in VALID_TYPES
    assert normalize_reminder({"title": "t", "type": "Conditional"})["type"] == "conditional"
