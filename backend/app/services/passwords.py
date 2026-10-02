"""Password hashing (bcrypt). Passwords are never stored or logged in plain text."""

import bcrypt

MIN_LENGTH = 8
MAX_BYTES = 72  # bcrypt ignores anything past 72 bytes; reject instead of silently truncating


class WeakPassword(ValueError):
    pass


def validate_password(password: str) -> None:
    if len(password) < MIN_LENGTH:
        raise WeakPassword(f"Password must be at least {MIN_LENGTH} characters")
    if len(password.encode("utf-8")) > MAX_BYTES:
        raise WeakPassword("Password is too long (max 72 bytes)")


def hash_password(password: str) -> str:
    validate_password(password)
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode("ascii")


def verify_password(password: str, password_hash: str) -> bool:
    """Constant-time check. False for anything malformed, never raises."""
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("ascii"))
    except (ValueError, TypeError):
        return False
