"""
RFC 5545 RRULE -> EventBridge Scheduler expression (spec R1.3).

Supports the rules the app produces: DAILY, WEEKLY (BYDAY), MONTHLY
(BYMONTHDAY) and YEARLY, with INTERVAL for DAILY/WEEKLY-less cases that
EventBridge can express as rate(). Anything else returns None and the reminder
falls back to one-time schedules plus the device's local repeat.
"""

from datetime import datetime

_DAYS = {"MO": "MON", "TU": "TUE", "WE": "WED", "TH": "THU", "FR": "FRI", "SA": "SAT", "SU": "SUN"}
_WEEKDAY_INDEX = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]


def parse_rrule(rule: str) -> dict[str, str] | None:
    """'RRULE:FREQ=WEEKLY;BYDAY=MO' -> {'FREQ': 'WEEKLY', 'BYDAY': 'MO'}; None if malformed."""
    body = rule.strip()
    if body.upper().startswith("RRULE:"):
        body = body[6:]
    parts: dict[str, str] = {}
    for item in body.split(";"):
        if "=" not in item:
            return None
        key, value = item.split("=", 1)
        parts[key.strip().upper()] = value.strip().upper()
    return parts if "FREQ" in parts else None


def to_schedule_expression(rule: str, start: datetime) -> str | None:
    """EventBridge Scheduler expression for the rule, using start's local time of day.
    None when the rule cannot be expressed exactly."""
    parts = parse_rrule(rule)
    if not parts:
        return None
    freq = parts["FREQ"]
    try:
        interval = int(parts.get("INTERVAL", "1"))
    except ValueError:
        return None
    if interval < 1 or "COUNT" in parts or "UNTIL" in parts:
        return None  # bounded rules need an end date the Scheduler cannot derive here
    minute, hour = start.minute, start.hour

    if freq == "DAILY":
        if interval == 1:
            return f"cron({minute} {hour} * * ? *)"
        return f"rate({interval} days)"  # fires relative to the schedule start time
    if interval != 1:
        return None
    if freq == "WEEKLY":
        days = parts.get("BYDAY") or _WEEKDAY_INDEX[start.weekday()]
        names = [_DAYS.get(d) for d in days.split(",")]
        if None in names:
            return None
        return f"cron({minute} {hour} ? * {','.join(names)} *)"
    if freq == "MONTHLY":
        day = parts.get("BYMONTHDAY", str(start.day))
        if not day.isdigit() or not 1 <= int(day) <= 31:
            return None
        return f"cron({minute} {hour} {int(day)} * ? *)"
    if freq == "YEARLY":
        return f"cron({minute} {hour} {start.day} {start.month} ? *)"
    return None
