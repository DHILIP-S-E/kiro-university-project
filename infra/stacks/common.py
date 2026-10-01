"""Helpers shared by the stacks."""

import os

from aws_cdk import Duration, aws_ec2 as ec2, aws_ecr_assets as ecr_assets
from aws_cdk import aws_lambda as lambda_
from constructs import Construct

BACKEND_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "backend")

BEDROCK_MODEL_HAIKU = "anthropic.claude-3-haiku-20240307-v1:0"
BEDROCK_MODEL_SONNET = "anthropic.claude-3-sonnet-20240229-v1:0"
EMBEDDING_MODEL = "amazon.titan-embed-text-v2:0"


def backend_function(
    scope: Construct,
    id: str,
    *,
    cmd: str,
    vpc: ec2.IVpc,
    security_group: ec2.ISecurityGroup,
    environment: dict[str, str] | None = None,
    memory_size: int = 512,
    timeout: Duration = Duration.seconds(30),
    reserved_concurrency: int | None = None,
) -> lambda_.DockerImageFunction:
    """A Lambda running the shared backend image with a different entrypoint.

    All functions use the same Docker asset (one build), and run in the private
    subnets so they can reach Aurora; egress to AWS APIs goes through the NAT.
    """
    return lambda_.DockerImageFunction(
        scope,
        id,
        code=lambda_.DockerImageCode.from_image_asset(
            BACKEND_DIR,
            cmd=[cmd],
            platform=ecr_assets.Platform.LINUX_AMD64,
        ),
        vpc=vpc,
        vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS),
        security_groups=[security_group],
        memory_size=memory_size,
        timeout=timeout,
        environment=environment or {},
        reserved_concurrent_executions=reserved_concurrency,
        tracing=lambda_.Tracing.ACTIVE,
    )
