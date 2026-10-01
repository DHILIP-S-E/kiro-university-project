import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

import pytest
from fastapi.testclient import TestClient

from app.auth import validate_claims
from app.config import settings

ISS = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_abc"


def test_access_token_accepted():
    claims = {"iss": ISS, "token_use": "access", "client_id": "app1", "sub": "u1"}
    assert validate_claims(claims, ISS, "app1") == "u1"


def test_id_token_accepted():
    claims = {"iss": ISS, "token_use": "id", "aud": "app1", "sub": "u1"}
    assert validate_claims(claims, ISS, "app1") == "u1"


@pytest.mark.parametrize("claims", [
    {"iss": "https://evil", "token_use": "access", "client_id": "app1", "sub": "u"},
    {"iss": ISS, "token_use": "access", "client_id": "other-app", "sub": "u"},
    {"iss": ISS, "token_use": "refresh", "client_id": "app1", "sub": "u"},
    {"iss": ISS, "token_use": "access", "client_id": "app1"},
    {"iss": ISS, "token_use": "access", "client_id": "app1", "sub": ""},
    {},
])
def test_bad_claims_rejected(claims):
    assert validate_claims(claims, ISS, "app1") is None


def test_unconfigured_cognito_fails_closed(monkeypatch):
    from app.main import app

    monkeypatch.setattr(settings, "cognito_user_pool_id", "")
    monkeypatch.setattr(settings, "allow_insecure_dev_auth", False)
    r = TestClient(app).get("/health/me", headers={"Authorization": "Bearer forged.token.value"})
    assert r.status_code == 503


def test_missing_token_rejected():
    from app.main import app

    assert TestClient(app).get("/health/me").status_code in (401, 403)


def test_dev_mode_is_explicit_opt_in(monkeypatch):
    from app.main import app

    monkeypatch.setattr(settings, "cognito_user_pool_id", "")
    monkeypatch.setattr(settings, "allow_insecure_dev_auth", True)
    r = TestClient(app).get("/health/me", headers={"Authorization": "Bearer not-a-jwt"})
    assert r.status_code == 200 and r.json()["user_id"] == "dev_user"
