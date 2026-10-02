"""Conditional reminders: "if I haven't submitted it by Friday, remind me".

A conditional reminder points at the reminder it checks (depends_on_id). At fire
time it is skipped when that reminder is already completed. Deterministic — no
LLM decides at delivery time.
"""

# Dependency states under which the check reminder must NOT fire.
SATISFIED_STATUSES = frozenset({"completed", "cancelled"})


def should_fire(dependency_status: str | None) -> bool:
    """True if the conditional reminder should go out.

    dependency_status is the checked reminder's status, or None if it no longer
    exists. A missing dependency fires: never silently lose a reminder."""
    return dependency_status not in SATISFIED_STATUSES
