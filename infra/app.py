#!/usr/bin/env python3
"""Personal Memory OS — AWS CDK app.

Stack order follows data flow; every dependency points one way:

  security -> storage ─┐
  auth                 ├─> search (Knowledge Base) ─┐
  database ────────────┤                            │
  ai (BDA) ──> queues (S3 -> EventBridge -> SQS) ───┤
  notifications ──> scheduler (EventBridge Scheduler)┼─> api ──> monitoring
"""

import aws_cdk as cdk

from stacks.ai_stack import AiStack
from stacks.api_stack import ApiStack
from stacks.auth_stack import AuthStack
from stacks.database_stack import DatabaseStack
from stacks.monitoring_stack import MonitoringStack
from stacks.notifications_stack import NotificationsStack
from stacks.queues_stack import QueuesStack
from stacks.scheduler_stack import SchedulerStack
from stacks.search_stack import SearchStack
from stacks.security_stack import SecurityStack
from stacks.storage_stack import StorageStack


def build(app: cdk.App) -> None:
    env_name = app.node.try_get_context("env_name") or "dev"
    env = cdk.Environment(account=None, region=None)  # resolved from the CLI profile
    prefix = f"Pmos-{env_name}"

    security = SecurityStack(app, f"{prefix}-Security", env=env)
    auth = AuthStack(app, f"{prefix}-Auth", env=env)
    storage = StorageStack(app, f"{prefix}-Storage", data_key=security.data_key, env=env)
    database = DatabaseStack(app, f"{prefix}-Database", env=env)
    notifications = NotificationsStack(app, f"{prefix}-Notifications", env=env)
    ai = AiStack(app, f"{prefix}-Ai", env=env)

    search = SearchStack(
        app, f"{prefix}-Search", bucket=storage.bucket, data_key=security.data_key, env=env
    )
    queues = QueuesStack(
        app,
        f"{prefix}-Queues",
        bucket=storage.bucket,
        vpc=database.vpc,
        lambda_sg=database.lambda_sg,
        db_secret=database.secret,
        bda_project_arn=ai.bda_project.attr_project_arn,
        bda_profile_arn=ai.profile_arn,
        guardrail_id=ai.guardrail_id,
        guardrail_arn=ai.guardrail_arn,
        guardrail_version=ai.guardrail_version_number,
        env=env,
    )
    scheduler = SchedulerStack(
        app,
        f"{prefix}-Scheduler",
        vpc=database.vpc,
        lambda_sg=database.lambda_sg,
        db_secret=database.secret,
        topic=notifications.topic,
        env=env,
    )
    api = ApiStack(
        app,
        f"{prefix}-Api",
        vpc=database.vpc,
        lambda_sg=database.lambda_sg,
        cluster=database.cluster,
        db_secret=database.secret,
        bucket=storage.bucket,
        user_pool=auth.user_pool,
        app_client=auth.app_client,
        web_acl=security.web_acl,
        capture_queue=queues.queue,
        push_topic=notifications.topic,
        scheduler_group_name=scheduler.group_name,
        scheduler_group_arn=scheduler.group_arn,
        dispatcher_arn=scheduler.dispatcher.function_arn,
        scheduler_role_arn=scheduler.scheduler_role.role_arn,
        knowledge_base_id=search.knowledge_base_id,
        knowledge_base_arn=search.knowledge_base_arn,
        data_source_id=search.data_source_id,
        guardrail_id=ai.guardrail_id,
        guardrail_arn=ai.guardrail_arn,
        guardrail_version=ai.guardrail_version_number,
        env=env,
    )
    MonitoringStack(
        app,
        f"{prefix}-Monitoring",
        api_fn=api.api_fn,
        processor=queues.processor,
        dispatcher=scheduler.dispatcher,
        dlq=queues.dlq,
        cluster=database.cluster,
        env=env,
    )


if __name__ == "__main__":
    app = cdk.App()
    build(app)
    app.synth()
