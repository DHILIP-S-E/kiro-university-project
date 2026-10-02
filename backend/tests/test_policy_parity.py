"""The app previews the reminder plan on-device; the backend builds the same plan.
These tests fail if the two copies of the policy drift apart."""

import os
import re
from pathlib import Path

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

from app.services import event_policy

DART = Path(__file__).resolve().parents[2] / "lib" / "core" / "utils" / "reminder_plan.dart"


def _ints(text: str) -> list[int]:
    return [int(n) for n in re.findall(r"\d+", text)]


def test_event_offsets_match_the_app():
    source = DART.read_text(encoding="utf-8")
    block = source[source.index("_eventOffsets"):source.index("};")]
    dart = {m.group(1): _ints(m.group(2)) for m in re.finditer(r"EventType\.(\w+):\s*\[([\d,\s]+)\]", block)}
    assert dart, "could not parse the Dart policy"
    assert dart == event_policy._EVENT_OFFSETS


def test_default_and_deadline_offsets_match_the_app():
    source = DART.read_text(encoding="utf-8")
    default = _ints(re.search(r"_defaultOffsets\s*=\s*\[([\d,\s]+)\]", source).group(1))
    deadline = _ints(re.search(r"_deadlineOffsets\s*=\s*\[([\d,\s]+)\]", source).group(1))
    assert default == event_policy._DEFAULT_OFFSETS
    assert deadline == event_policy._DEADLINE_OFFSETS
