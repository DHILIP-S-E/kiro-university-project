import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

from datetime import datetime, timedelta, timezone

import pytest
from hypothesis import given, strategies as st
from jose import jwt

from app.services.tokens import (
    ACCESS_TTL, ALGORITHM, ISSUER, TokenError,
    create_access_token, create_refresh_token, verify_token,
)

SECRET = "s" * 40
NOW = datetime(2026, 10, 2, 12, 0, tzinfo=timezone.utc)


def test_access_token_round_trips():
    assert verify_token(create_access_token("u1", SECRET), "access", SECRET) == "u1"


def test_refresh_token_cannot_be_used_as_access_or_vice_versa():
    refresh = create_refresh_token("u1", SECRET)
    access = create_access_token("u1", SECRET)
    with pytest.raises(TokenError):
        verify_token(refresh, "access", SECRET)
    with pytest.raises(TokenError):
        verify_token(access, "refresh", SECRET)


def test_expired_token_rejected():
    token = create_access_token("u1", SECRET, now=NOW)
    assert verify_token(token, "access", SECRET, now=NOW + ACCESS_TTL - timedelta(seconds=1)) == "u1"
    with pytest.raises(TokenError):
        verify_token(token, "access", SECRET, now=NOW + ACCESS_TTL + timedelta(seconds=1))


def test_wrong_secret_rejected():
    with pytest.raises(TokenError):
        verify_token(create_access_token("u1", SECRET), "access", "x" * 40)


def test_short_secret_refused_everywhere():
    with pytest.raises(TokenError):
        create_access_token("u1", "short")
    with pytest.raises(TokenError):
        verify_token("anything", "access", "short")


def test_unsigned_alg_none_token_rejected():
    forged = jwt.encode({"sub": "admin", "typ": "access", "iss": ISSUER, "exp": 9999999999}, "", algorithm="HS256")
    # craft an alg=none token by hand
    import base64, json
    b = lambda d: base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b"=").decode()
    none_token = f"{b({'alg': 'none', 'typ': 'JWT'})}.{b({'sub': 'admin', 'typ': 'access', 'iss': ISSUER, 'exp': 9999999999})}."
    with pytest.raises(TokenError):
        verify_token(none_token, "access", SECRET)
    with pytest.raises(TokenError):
        verify_token(forged, "access", SECRET)


def test_wrong_issuer_rejected():
    token = jwt.encode({"sub": "u", "typ": "access", "iss": "someone-else", "exp": 9999999999}, SECRET, algorithm=ALGORITHM)
    with pytest.raises(TokenError):
        verify_token(token, "access", SECRET)


@given(st.text(max_size=200))
def test_garbage_never_crashes_only_raises_token_error(junk):
    with pytest.raises(TokenError):
        verify_token(junk, "access", SECRET)
