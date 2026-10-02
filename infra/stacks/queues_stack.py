"""S3 upload -> EventBridge -> SQS -> capture processor (spec R3.4-R3.7)."""

from aws_cdk import (
    CfnOutput,
    Duration,
    Stack,
    aws_ec2 as ec2,
    aws_events as events,
    aws_events_targets as targets,
    aws_iam as iam,
    aws_lambda_event_sources as event_sources,
    aws_s3 as s3,
    aws_secretsmanager as secretsmanager,
    aws_sqs as sqs,
)
from constructs import Construct

from stacks.common import BEDROCK_MODEL_FAST, backend_function, invoke_model_arns


class QueuesStack(Stack):
    def __init__(
        self,
        scope: Construct,
        id: str,
        *,
        bucket: s3.IBucket,
        vpc: ec2.IVpc,
        lambda_sg: ec2.ISecurityGroup,
        db_secret: secretsmanager.ISecret,
        bda_project_arn: str,
        bda_profile_arn: str,
        guardrail_id: str,
        guardrail_arn: str,
        guardrail_version: str,
        **kwargs,
    ) -> None:
        super().__init__(scope, id, **kwargs)

        self.dlq = sqs.Queue(
            self,
            "CaptureDlq",
            retention_period=Duration.days(14),
            encryption=sqs.QueueEncryption.SQS_MANAGED,
            enforce_ssl=True,
        )
        # Visibility timeout must exceed the processor's timeout (AWS guidance: 6x).
        self.queue = sqs.Queue(
            self,
            "CaptureQueue",
            visibility_timeout=Duration.minutes(6),
            encryption=sqs.QueueEncryption.SQS_MANAGED,
            enforce_ssl=True,
            dead_letter_queue=sqs.DeadLetterQueue(max_receive_count=5, queue=self.dlq),
        )

        # New capture uploads (users/...) and async extraction results (processed/...).
        events.Rule(
            self,
            "CaptureObjectCreated",
            description="S3 object created under users/ or processed/",
            event_pattern=events.EventPattern(
                source=["aws.s3"],
                detail_type=["Object Created"],
                detail={
                    "bucket": {"name": [bucket.bucket_name]},
                    "object": {"key": [{"prefix": "users/"}, {"prefix": "processed/"}]},
                },
            ),
            targets=[targets.SqsQueue(self.queue)],
        )

        self.processor = backend_function(
            self,
            "CaptureProcessor",
            cmd="workers.capture_processor.handler",
            vpc=vpc,
            security_group=lambda_sg,
            memory_size=1024,
            timeout=Duration.minutes(1),
            environment={
                "DB_SECRET_ARN": db_secret.secret_arn,
                "CAPTURE_BUCKET": bucket.bucket_name,
                "BEDROCK_MODEL_FAST": BEDROCK_MODEL_FAST,
                "BDA_PROJECT_ARN": bda_project_arn,
                "BDA_PROFILE_ARN": bda_profile_arn,
                "GUARDRAIL_ID": guardrail_id,
                "GUARDRAIL_VERSION": guardrail_version,
            },
        )
        self.processor.add_event_source(
            event_sources.SqsEventSource(
                self.queue,
                batch_size=5,
                report_batch_item_failures=True,  # retry only the failed messages
                max_concurrency=5,
            )
        )

        db_secret.grant_read(self.processor)
        bucket.grant_read_write(self.processor)
        self.processor.add_to_role_policy(
            iam.PolicyStatement(
                actions=["bedrock:InvokeModel"],
                resources=invoke_model_arns(self.region, self.account, BEDROCK_MODEL_FAST),
            )
        )
        self.processor.add_to_role_policy(
            iam.PolicyStatement(actions=["bedrock:ApplyGuardrail"], resources=[guardrail_arn])
        )
        self.processor.add_to_role_policy(
            iam.PolicyStatement(
                actions=["bedrock:InvokeDataAutomationAsync", "bedrock:GetDataAutomationStatus"],
                resources=[bda_project_arn, bda_profile_arn, f"arn:aws:bedrock:{self.region}:{self.account}:data-automation-invocation/*"],
            )
        )
        self.processor.add_to_role_policy(
            iam.PolicyStatement(
                actions=["transcribe:StartTranscriptionJob", "transcribe:GetTranscriptionJob"],
                resources=["*"],  # Transcribe job ARNs are not known ahead of time
            )
        )

        CfnOutput(self, "CaptureQueueUrl", value=self.queue.queue_url)
