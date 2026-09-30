"""
S3 service — pre-signed URL generation for private bucket access.
Flutter uploads directly to S3 using the pre-signed PUT URL.
Flutter downloads using the pre-signed GET URL.
No media ever passes through the FastAPI server.
"""

import boto3
from botocore.exceptions import ClientError
from app.config import settings

_s3_client = None


def _get_client():
    global _s3_client
    if _s3_client is None:
        kwargs = {"region_name": settings.aws_region}
        if settings.aws_access_key_id:
            kwargs["aws_access_key_id"] = settings.aws_access_key_id
            kwargs["aws_secret_access_key"] = settings.aws_secret_access_key
        _s3_client = boto3.client("s3", **kwargs)
    return _s3_client


def generate_upload_url(
    s3_key: str,
    content_type: str,
    expires_in: int = 3600,
) -> str:
    """Return a pre-signed PUT URL for direct client upload."""
    client = _get_client()
    return client.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": settings.s3_bucket,
            "Key": s3_key,
            "ContentType": content_type,
        },
        ExpiresIn=expires_in,
    )


def generate_download_url(s3_key: str, expires_in: int = 3600) -> str:
    """Return a pre-signed GET URL for private object access."""
    client = _get_client()
    return client.generate_presigned_url(
        "get_object",
        Params={"Bucket": settings.s3_bucket, "Key": s3_key},
        ExpiresIn=expires_in,
    )


def delete_object(s3_key: str) -> None:
    """Delete a single S3 object. Silently succeeds if key does not exist."""
    client = _get_client()
    try:
        client.delete_object(Bucket=settings.s3_bucket, Key=s3_key)
    except ClientError:
        pass
