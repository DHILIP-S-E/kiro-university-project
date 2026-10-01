"""EventBridge Scheduler group + notification dispatcher (spec R1.5, R7.1, R7.4).

Cloud layer of the two-layer alarm: the API registers one-time schedules in this
group; at fire time the scheduler invokes the dispatcher, which publishes to SNS
and records the delivery. The LLM never schedules — it only parses.
"""

from aws_cdk import CfnOutput, Duration, Stack, aws_ec2 as ec2, aws_iam as iam
from aws_cdk import aws_scheduler as scheduler
from aws_cdk import aws_secretsmanager as secretsmanager
from aws_cdk import aws_sns as sns
from constructs import Construct

from stacks.common import backend_function

GROUP_NAME = "personal-memory-os"


class SchedulerStack(Stack):
    def __init__(
        self,
        scope: Construct,
        id: str,
        *,
        vpc: ec2.IVpc,
        lambda_sg: ec2.ISecurityGroup,
        db_secret: secretsmanager.ISecret,
        topic: sns.ITopic,
        **kwargs,
    ) -> None:
        super().__init__(scope, id, **kwargs)

        self.group = scheduler.CfnScheduleGroup(self, "Group", name=GROUP_NAME)

        self.dispatcher = backend_function(
            self,
            "NotificationDispatcher",
            cmd="workers.notification_dispatcher.handler",
            vpc=vpc,
            security_group=lambda_sg,
            timeout=Duration.seconds(30),
            environment={
                "DB_SECRET_ARN": db_secret.secret_arn,
                "NOTIFICATION_TOPIC_ARN": topic.topic_arn,
            },
        )
        db_secret.grant_read(self.dispatcher)
        topic.grant_publish(self.dispatcher)

        # Role the Scheduler service assumes to invoke the dispatcher.
        self.scheduler_role = iam.Role(
            self,
            "SchedulerRole",
            assumed_by=iam.ServicePrincipal(
                "scheduler.amazonaws.com",
                conditions={"StringEquals": {"aws:SourceAccount": self.account}},
            ),
        )
        self.dispatcher.grant_invoke(self.scheduler_role)

        self.group_name = GROUP_NAME
        self.group_arn = f"arn:aws:scheduler:{self.region}:{self.account}:schedule/{GROUP_NAME}/*"

        CfnOutput(self, "DispatcherArn", value=self.dispatcher.function_arn)
