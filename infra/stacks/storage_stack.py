"""Private S3 bucket for captured media (spec R3.3, R5.3, R5.4)."""

from aws_cdk import CfnOutput, Duration, RemovalPolicy, Stack, aws_kms as kms, aws_s3 as s3
from constructs import Construct


class StorageStack(Stack):
    def __init__(self, scope: Construct, id: str, *, data_key: kms.IKey, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        self.bucket = s3.Bucket(
            self,
            "CapturesBucket",
            encryption=s3.BucketEncryption.KMS,
            encryption_key=data_key,
            bucket_key_enabled=True,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            enforce_ssl=True,
            versioned=True,
            # Object-created events go to EventBridge -> SQS (spec R3.4).
            event_bridge_enabled=True,
            removal_policy=RemovalPolicy.RETAIN,
            lifecycle_rules=[
                s3.LifecycleRule(
                    noncurrent_version_expiration=Duration.days(30),
                    abort_incomplete_multipart_upload_after=Duration.days(7),
                ),
                # Async extraction output is derived data; the source object is kept.
                s3.LifecycleRule(prefix="processed/", expiration=Duration.days(90)),
            ],
        )

        CfnOutput(self, "CapturesBucketName", value=self.bucket.bucket_name)
