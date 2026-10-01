"""
Database URL resolution.

Locally: DATABASE_URL from .env. On AWS: DB_SECRET_ARN points at the Aurora
credentials secret in Secrets Manager (spec R5.5 — no secrets in env vars or
source). The password is fetched at cold start and never written to config.
"""

import json
from urllib.parse import quote_plus

import boto3


def urls_from_secret(secret: dict) -> tuple[str, str]:
    """(async_url, sync_url) from an RDS-style secret {username,password,host,port,dbname}."""
    user = quote_plus(secret["username"])
    password = quote_plus(secret["password"])
    host, port = secret["host"], secret.get("port", 5432)
    db = secret.get("dbname", "postgres")
    base = f"{user}:{password}@{host}:{port}/{db}"
    return f"postgresql+asyncpg://{base}?ssl=require", f"postgresql://{base}?sslmode=require"


def _from_arn(secret_arn: str, region: str) -> tuple[str, str]:
    client = boto3.client("secretsmanager", region_name=region)
    secret = json.loads(client.get_secret_value(SecretId=secret_arn)["SecretString"])
    return urls_from_secret(secret)


def to_sync(url: str) -> str:
    """Convert a SQLAlchemy asyncpg URL into a psycopg2 one."""
    return url.replace("postgresql+asyncpg://", "postgresql://", 1)


def resolve_urls(database_url: str, db_secret_arn: str, region: str) -> tuple[str, str]:
    """(async_url, sync_url). An explicit DATABASE_URL wins (local dev)."""
    if database_url:
        return database_url, to_sync(database_url)
    if db_secret_arn:
        return _from_arn(db_secret_arn, region)
    raise RuntimeError("Set DATABASE_URL or DB_SECRET_ARN")


def sync_database_url() -> str:
    """psycopg2 URL for the Lambda workers (which do not use the async engine)."""
    from app.config import settings

    return resolve_urls(settings.database_url, settings.db_secret_arn, settings.aws_region)[1]
