"""
Self-issued JWTs for the app's own email/password login.

Two kinds, told apart by the `typ` claim so one can never stand in for the other:
  access  - short-lived, sent on every API call
  refresh - long-lived, only accepted by /auth/refresh
Signed HS256 with JWT_SECRET (from the environment / a secrets store, never source).
"""

from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt

ALGORITHM = "HS256"
ISSUER = "personal-memory-os"
ACCESS_TTL = timedelta(hours=1)
REFRESH_TTL = timedelta(days=30)
MIN_SECRET_LENGTH = 32


class TokenError(Exception):
    pass


def _require_secret(secret: str) -> str:
    if len(secret) < MIN_SECRET_LENGTH:
        raise TokenError("JWT_SECRET must be at least 32 characters")
    return secret


def _issue(user_id: str, typ: str, ttl: timedelta, secret: str, now: datetime | None) -> str:
    now = now or datetime.now(timezone.utc)
    claims = {
        "sub": user_id,
        "typ": typ,
        "iss": ISSUER,
        "iat": int(now.timestamp()),
        "exp": int((now + ttl).timestamp()),
    }
    return jwt.encode(claims, _require_secret(secret), algorithm=ALGORITHM)


def create_access_token(user_id: str, secret: str, now: datetime | None = None) -> str:
    return _issue(user_id, "access", ACCESS_TTL, secret, now)


def create_refresh_token(user_id: str, secret: str, now: datetime | None = None) -> str:
    return _issue(user_id, "refresh", REFRESH_TTL, secret, now)


def verify_token(token: str, expected_typ: str, secret: str, now: datetime | None = None) -> str:
    """Return the user id, or raise TokenError. Checks signature, expiry, issuer and type."""
    try:
        claims = jwt.decode(
            token,
            _require_secret(secret),
            algorithms=[ALGORITHM],  # never trust the token's own `alg` header
            issuer=ISSUER,
            options={"verify_exp": now is None},
        )
    except JWTError as exc:
        raise TokenError("Invalid or expired token") from exc
    if now is not None and claims.get("exp", 0) <= int(now.timestamp()):
        raise TokenError("Invalid or expired token")
    if claims.get("typ") != expected_typ:
        raise TokenError("Wrong token type")
    sub = claims.get("sub")
    if not isinstance(sub, str) or not sub:
        raise TokenError("Invalid token")
    return sub
