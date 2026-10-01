"""FastAPI backend on Lambda behind API Gateway + WAF (spec R5.2, R5.6).

The backend verifies the Cognito JWT itself (app/auth.py); API Gateway adds
throttling and the WAF web ACL in front.
"""

from aws_cdk import CfnOutput, Duration, Stack, aws_apigateway as apigw, aws_cognito as cognito
from aws_cdk import aws_ec2 as ec2, aws_iam as iam, aws_lambda as lambda_
from aws_cdk import aws_rds as rds, aws_s3 as s3, aws_secretsmanager as secretsmanager
from aws_cdk import aws_sns as sns, aws_sqs as sqs, aws_wafv2 as wafv2, triggers
from constructs import Construct

from stacks.common import BEDROCK_MODEL_HAIKU, BEDROCK_MODEL_SONNET, EMBEDDING_MODEL, backend_function


class ApiStack(Stack):
    def __init__(
        self,
        scope: Construct,
        id: str,
        *,
        vpc: ec2.IVpc,
        lambda_sg: ec2.ISecurityGroup,
        cluster: rds.IDatabaseCluster,
        db_secret: secretsmanager.ISecret,
        bucket: s3.IBucket,
        user_pool: cognito.IUserPool,
        app_client: cognito.IUserPoolClient,
        web_acl: wafv2.CfnWebACL,
        capture_queue: sqs.IQueue,
        push_topic: sns.ITopic,
        scheduler_group_name: str,
        scheduler_group_arn: str,
        dispatcher_arn: str,
        scheduler_role_arn: str,
        knowledge_base_id: str,
        knowledge_base_arn: str,
        data_source_id: str,
        **kwargs,
    ) -> None:
        super().__init__(scope, id, **kwargs)

        platform_app_arn = self.node.try_get_context("sns_platform_app_arn") or ""

        env = {
            "DB_SECRET_ARN": db_secret.secret_arn,
            "S3_BUCKET": bucket.bucket_name,
            "COGNITO_USER_POOL_ID": user_pool.user_pool_id,
            "COGNITO_REGION": self.region,
            "COGNITO_APP_CLIENT_ID": app_client.user_pool_client_id,
            "SCHEDULER_TARGET_ARN": dispatcher_arn,
            "SCHEDULER_ROLE_ARN": scheduler_role_arn,
            "SCHEDULER_GROUP": scheduler_group_name,
            "NOTIFICATION_TOPIC_ARN": push_topic.topic_arn,
            "CAPTURE_QUEUE_URL": capture_queue.queue_url,
            "KNOWLEDGE_BASE_ID": knowledge_base_id,
            "KNOWLEDGE_BASE_DATA_SOURCE_ID": data_source_id,
            "SNS_PLATFORM_APP_ARN": platform_app_arn,
            "BEDROCK_MODEL_HAIKU": BEDROCK_MODEL_HAIKU,
            "BEDROCK_MODEL_SONNET": BEDROCK_MODEL_SONNET,
        }

        # ── API function ─────────────────────────────────────────────────────
        self.api_fn = backend_function(
            self,
            "ApiFunction",
            cmd="app.lambda_handler.handler",
            vpc=vpc,
            security_group=lambda_sg,
            memory_size=1024,
            timeout=Duration.seconds(29),  # API Gateway's hard limit
            environment=env,
        )

        db_secret.grant_read(self.api_fn)
        bucket.grant_read_write(self.api_fn)
        capture_queue.grant_send_messages(self.api_fn)
        self.api_fn.add_to_role_policy(iam.PolicyStatement(
            actions=["bedrock:InvokeModel"],
            resources=[
                f"arn:aws:bedrock:{self.region}::foundation-model/{m}"
                for m in (BEDROCK_MODEL_HAIKU, BEDROCK_MODEL_SONNET, EMBEDDING_MODEL)
            ],
        ))
        self.api_fn.add_to_role_policy(iam.PolicyStatement(
            actions=["bedrock:Retrieve"], resources=[knowledge_base_arn]
        ))
        self.api_fn.add_to_role_policy(iam.PolicyStatement(
            actions=["bedrock:StartIngestionJob"], resources=[knowledge_base_arn]
        ))
        # Cloud reminder schedules: create/delete in our group, hand the role to Scheduler.
        self.api_fn.add_to_role_policy(iam.PolicyStatement(
            actions=["scheduler:CreateSchedule", "scheduler:DeleteSchedule", "scheduler:GetSchedule"],
            resources=[scheduler_group_arn],
        ))
        self.api_fn.add_to_role_policy(iam.PolicyStatement(
            actions=["iam:PassRole"],
            resources=[scheduler_role_arn],
            conditions={"StringEquals": {"iam:PassedToService": "scheduler.amazonaws.com"}},
        ))
        # Device registration: platform endpoint + per-user subscription.
        self.api_fn.add_to_role_policy(iam.PolicyStatement(
            actions=["sns:Subscribe"], resources=[push_topic.topic_arn]
        ))
        if platform_app_arn:
            self.api_fn.add_to_role_policy(iam.PolicyStatement(
                actions=["sns:CreatePlatformEndpoint"], resources=[platform_app_arn]
            ))

        # ── API Gateway ──────────────────────────────────────────────────────
        self.api = apigw.LambdaRestApi(
            self,
            "Api",
            rest_api_name="personal-memory-os",
            handler=self.api_fn,
            proxy=True,
            endpoint_types=[apigw.EndpointType.REGIONAL],
            deploy_options=apigw.StageOptions(
                stage_name="v1",
                throttling_rate_limit=50,
                throttling_burst_limit=100,
                metrics_enabled=True,
                tracing_enabled=True,
            ),
        )
        wafv2.CfnWebACLAssociation(
            self,
            "WafAssociation",
            resource_arn=self.api.deployment_stage.stage_arn,
            web_acl_arn=web_acl.attr_arn,
        )

        # ── Database migrations on every deploy ──────────────────────────────
        migrate_fn = backend_function(
            self,
            "MigrateFunction",
            cmd="workers.migrate.handler",
            vpc=vpc,
            security_group=lambda_sg,
            timeout=Duration.minutes(5),
            environment={"DB_SECRET_ARN": db_secret.secret_arn},
        )
        db_secret.grant_read(migrate_fn)
        trigger = triggers.Trigger(
            self,
            "RunMigrations",
            handler=migrate_fn,
            timeout=Duration.minutes(5),
            invocation_type=triggers.InvocationType.REQUEST_RESPONSE,
            execute_on_handler_change=True,
        )
        trigger.node.add_dependency(cluster)

        CfnOutput(self, "ApiUrl", value=self.api.url, description="Set as BACKEND_URL in the app")
