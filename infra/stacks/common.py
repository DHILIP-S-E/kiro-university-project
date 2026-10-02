"""Helpers shared by the stacks."""

import os

from aws_cdk import Duration, aws_ec2 as ec2, aws_ecr_assets as ecr_assets
from aws_cdk import aws_lambda as lambda_
from constructs import Construct

BACKEND_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "backend")

# Amazon Nova through the apac cross-region inference profile (works in Mumbai
# with no model-access form). The model is a setting: swap the id, keep the rest.
BEDROCK_MODEL_FAST = "apac.amazon.nova-lite-v1:0"    # parsing, extraction, capture summaries
BEDROCK_MODEL_STRONG = "apac.amazon.nova-pro-v1:0"   # event summaries, memory Q&A
EMBEDDING_MODEL = "amazon.titan-embed-text-v2:0"


def invoke_model_arns(region: str, account: str, *profile_ids: str) -> list[str]:
    """IAM resources needed to call models through inference profiles: the profile
    itself plus the underlying foundation model in whichever region it routes to.
    (Exactly these models; never a wildcard over all of Bedrock.)"""
    arns: list[str] = []
    for profile_id in profile_ids:
        base_model = profile_id.split(".", 1)[1] if "." in profile_id.split(":")[0] else profile_id
        arns.append(f"arn:aws:bedrock:{region}:{account}:inference-profile/{profile_id}")
        arns.append(f"arn:aws:bedrock:*::foundation-model/{base_model}")
    return arns


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
