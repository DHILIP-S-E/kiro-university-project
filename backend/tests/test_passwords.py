import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

import pytest

from app.services.passwords import WeakPassword, hash_password, verify_password


def test_hash_verifies_and_is_not_plaintext():
    h = hash_password("correct horse")
    assert "correct horse" not in h and h.startswith("$2")
    assert verify_password("correct horse", h)


def test_wrong_password_rejected():
    assert not verify_password("wrong password", hash_password("correct horse"))


def test_same_password_hashes_differently():
    assert hash_password("correct horse") != hash_password("correct horse")


@pytest.mark.parametrize("bad", ["", "short", "1234567"])
def test_short_passwords_refused(bad):
    with pytest.raises(WeakPassword):
        hash_password(bad)


def test_over_72_bytes_refused_not_truncated():
    with pytest.raises(WeakPassword):
        hash_password("a" * 73)


@pytest.mark.parametrize("junk", ["", "not-a-hash", "$2b$12$short"])
def test_malformed_hash_is_false_not_an_error(junk):
    assert verify_password("anything", junk) is False
