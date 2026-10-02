"""Run every migration on a fresh database and check it matches the models.

Catches: a migration that fails on a new database (e.g. creating a table twice),
and models that use columns no migration creates."""

import os
import subprocess
import sys
from pathlib import Path

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

import pytest
from sqlalchemy import create_engine, inspect

BACKEND = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def migrated_db(tmp_path_factory):
    db = tmp_path_factory.mktemp("mig") / "fresh.db"
    env = {**os.environ, "DATABASE_URL": f"sqlite+aiosqlite:///{db.as_posix()}", "PYTHONIOENCODING": "utf-8"}
    result = subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "head"],
        cwd=BACKEND, env=env, capture_output=True, text=True, timeout=120,
    )
    assert result.returncode == 0, result.stderr[-1500:]
    return create_engine(f"sqlite:///{db.as_posix()}")


def test_all_migrations_apply_to_a_fresh_database(migrated_db):
    assert "alembic_version" in inspect(migrated_db).get_table_names()


def test_every_model_table_and_column_exists_after_migrating(migrated_db):
    import app.models  # noqa: F401
    from app.database import Base

    insp = inspect(migrated_db)
    existing = set(insp.get_table_names())
    problems = []
    for name, table in Base.metadata.tables.items():
        if name not in existing:
            problems.append(f"missing table {name}")
            continue
        have = {c["name"] for c in insp.get_columns(name)}
        problems += [f"{name}.{c.name}" for c in table.columns if c.name not in have]
    assert not problems, problems


def test_users_email_is_unique_in_the_migrated_schema(migrated_db):
    indexes = inspect(migrated_db).get_indexes("users")
    assert any(i["unique"] and i["column_names"] == ["email"] for i in indexes)


def test_migrations_can_be_downgraded_one_step(migrated_db, tmp_path):
    db = tmp_path / "down.db"
    env = {**os.environ, "DATABASE_URL": f"sqlite+aiosqlite:///{db.as_posix()}", "PYTHONIOENCODING": "utf-8"}
    for args in (["upgrade", "head"], ["downgrade", "-1"], ["upgrade", "head"]):
        r = subprocess.run([sys.executable, "-m", "alembic", *args], cwd=BACKEND, env=env,
                           capture_output=True, text=True, timeout=120)
        assert r.returncode == 0, (args, r.stderr[-800:])
