"""
Action items extracted from captures ("I need to submit the prototype by October 20").

The model's output is untrusted: normalise it to [{"title", "due_at"}] where
due_at is an ISO-8601 date/datetime or None. Pure — property-tested.
"""

from datetime import datetime
from typing import Any

MAX_TITLE = 200
MAX_ACTIONS = 10


def _valid_iso(value: Any) -> str | None:
    if not isinstance(value, str) or not value.strip():
        return None
    text = value.strip()
    try:
        datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None
    return text


def normalize_actions(raw: Any) -> list[dict]:
    """Accepts ["text", ...] or [{"title", "due_at"}, ...]; drops anything else.
    Titles are trimmed and bounded, duplicates removed, order preserved."""
    if not isinstance(raw, list):
        return []
    out: list[dict] = []
    seen: set[str] = set()
    for item in raw:
        if isinstance(item, str):
            title, due = item, None
        elif isinstance(item, dict):
            title, due = item.get("title"), item.get("due_at")
        else:
            continue
        if not isinstance(title, str):
            continue
        title = title.strip()[:MAX_TITLE].strip()
        key = title.lower()
        if not title or key in seen:
            continue
        seen.add(key)
        out.append({"title": title, "due_at": _valid_iso(due)})
        if len(out) == MAX_ACTIONS:
            break
    return out
