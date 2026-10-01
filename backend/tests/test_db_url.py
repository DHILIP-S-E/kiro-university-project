import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

import pytest

from app.db_url import resolve_urls, to_sync, urls_from_secret


def test_secret_password_is_url_encoded():
    a, s = urls_from_secret(
        {"username": "pg", "password": "p@ss/w:rd%!", "host": "h.rds.amazonaws.com", "port": 5432, "dbname": "memos"}
    )
    assert a == "postgresql+asyncpg://pg:p%40ss%2Fw%3Ard%25%21@h.rds.amazonaws.com:5432/memos?ssl=require"
    assert s.startswith("postgresql://pg:p%40ss%2Fw%3Ard%25%21@h.rds.amazonaws.com:5432/memos?sslmode=require")


def test_explicit_database_url_wins():
    a, s = resolve_urls("postgresql+asyncpg://u:p@h/d", "arn:ignored", "us-east-1")
    assert a.startswith("postgresql+asyncpg://") and s == "postgresql://u:p@h/d"


def test_requires_some_configuration():
    with pytest.raises(RuntimeError):
        resolve_urls("", "", "us-east-1")


def test_to_sync():
    assert to_sync("postgresql+asyncpg://a@b/c") == "postgresql://a@b/c"
