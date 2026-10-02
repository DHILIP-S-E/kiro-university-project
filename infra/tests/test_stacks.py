"""Synthesis + security-invariant tests for the CDK app. No AWS access needed."""

import os
import sys

os.environ.setdefault("JSII_SILENCE_WARNING_UNTESTED_NODE_VERSION", "1")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import aws_cdk as cdk
import pytest
from aws_cdk.assertions import Match, Template

from app import build


@pytest.fixture(scope="module")
def app():
    app = cdk.App()
    build(app)
    return app


@pytest.fixture(scope="module")
def templates(app):
    stacks = [c for c in app.node.children if isinstance(c, cdk.Stack)]
    return {s.stack_name.split("-", 2)[2]: Template.from_stack(s) for s in stacks}


def test_all_eleven_stacks_synthesize(templates):
    assert set(templates) == {
        "Security", "Auth", "Storage", "Database", "Notifications", "Ai",
        "Search", "Queues", "Scheduler", "Api", "Monitoring",
    }


def test_media_bucket_is_private_encrypted_and_tls_only(templates):
    t = templates["Storage"]
    t.has_resource_properties("AWS::S3::Bucket", {
        "PublicAccessBlockConfiguration": {
            "BlockPublicAcls": True, "BlockPublicPolicy": True,
            "IgnorePublicAcls": True, "RestrictPublicBuckets": True,
        },
        "BucketEncryption": {"ServerSideEncryptionConfiguration": [Match.object_like({
            "ServerSideEncryptionByDefault": {"SSEAlgorithm": "aws:kms", "KMSMasterKeyID": Match.any_value()}
        })]},
        "VersioningConfiguration": {"Status": "Enabled"},
    })
    # EventBridge delivery is enabled through CDK's bucket-notifications resource.
    t.has_resource_properties("Custom::S3BucketNotifications", {
        "NotificationConfiguration": Match.object_like({"EventBridgeConfiguration": {}}),
    })
    t.has_resource_properties("AWS::S3::BucketPolicy", {"PolicyDocument": {"Statement": Match.array_with([
        Match.object_like({"Effect": "Deny", "Condition": {"Bool": {"aws:SecureTransport": "false"}}})
    ])}})


def test_kms_key_rotates_and_is_retained(templates):
    t = templates["Security"]
    t.has_resource("AWS::KMS::Key", {
        "Properties": {"EnableKeyRotation": True}, "DeletionPolicy": "Retain",
    })


def test_waf_has_managed_rules_and_rate_limit(templates):
    t = templates["Security"]
    t.has_resource_properties("AWS::WAFv2::WebACL", {"Scope": "REGIONAL", "Rules": Match.array_with([
        Match.object_like({"Name": "AWSManagedRulesCommonRuleSet"}),
        Match.object_like({"Name": "RateLimitPerIp"}),
    ])})
    t.resource_count_is("AWS::CloudTrail::Trail", 1)


def test_waf_is_associated_with_the_api_stage(templates):
    templates["Api"].resource_count_is("AWS::WAFv2::WebACLAssociation", 1)


def test_cognito_public_client_has_no_secret_and_revocation(templates):
    t = templates["Auth"]
    t.has_resource_properties("AWS::Cognito::UserPoolClient", {
        "GenerateSecret": False, "EnableTokenRevocation": True,
        "ExplicitAuthFlows": Match.array_with(["ALLOW_USER_PASSWORD_AUTH"]),
    })


def test_aurora_encrypted_serverless_v2_with_deletion_protection(templates):
    t = templates["Database"]
    t.has_resource_properties("AWS::RDS::DBCluster", {
        "StorageEncrypted": True, "DeletionProtection": True, "Engine": "aurora-postgresql",
        "ServerlessV2ScalingConfiguration": Match.object_like({"MinCapacity": 0.5}),
    })
    t.has_resource_properties("AWS::RDS::DBInstance", {"DBInstanceClass": "db.serverless"})


def test_only_backend_lambdas_can_reach_the_database(templates):
    t = templates["Database"]
    ingress = [
        r for r in t.find_resources("AWS::EC2::SecurityGroupIngress").values()
        if r["Properties"].get("FromPort") == 5432
    ]
    assert ingress and all("SourceSecurityGroupId" in r["Properties"] for r in ingress)


def test_capture_queue_has_dlq_and_safe_visibility_timeout(templates):
    t = templates["Queues"]
    t.has_resource_properties("AWS::SQS::Queue", {
        "RedrivePolicy": {"maxReceiveCount": 5, "deadLetterTargetArn": Match.any_value()},
        "VisibilityTimeout": 360,
    })
    t.has_resource_properties("AWS::Events::Rule", {"EventPattern": Match.object_like({
        "source": ["aws.s3"], "detail-type": ["Object Created"],
        "detail": Match.object_like({"object": {"key": [{"prefix": "users/"}, {"prefix": "processed/"}]}}),
    })})


def test_processor_retries_only_failed_messages(templates):
    templates["Queues"].has_resource_properties("AWS::Lambda::EventSourceMapping", {
        "FunctionResponseTypes": ["ReportBatchItemFailures"],
    })


def test_scheduler_group_and_invoke_role(templates):
    t = templates["Scheduler"]
    t.has_resource_properties("AWS::Scheduler::ScheduleGroup", {"Name": "personal-memory-os"})
    t.has_resource_properties("AWS::IAM::Role", {"AssumeRolePolicyDocument": {"Statement": [Match.object_like({
        "Principal": {"Service": "scheduler.amazonaws.com"},
        "Condition": {"StringEquals": {"aws:SourceAccount": Match.any_value()}},
    })]}})


def test_knowledge_base_waits_for_the_vector_index(templates):
    t = templates["Search"]
    t.has_resource_properties("AWS::OpenSearchServerless::Collection", {"Type": "VECTORSEARCH"})
    kb = list(t.find_resources("AWS::Bedrock::KnowledgeBase").values())[0]
    assert any("VectorIndex" in d for d in kb["DependsOn"]), "KB must depend on the index custom resource"
    t.has_resource_properties("AWS::Bedrock::DataSource", {
        "DataSourceConfiguration": Match.object_like({"S3Configuration": Match.object_like({
            "InclusionPrefixes": ["knowledge/"]})}),
    })


def test_api_runs_migrations_and_respects_api_gateway_timeout(templates):
    t = templates["Api"]
    t.has_resource_properties("AWS::Lambda::Function", {"Timeout": 29, "PackageType": "Image"})
    t.resource_count_is("Custom::Trigger", 1)


def test_no_secrets_in_lambda_environment(templates):
    forbidden = ("PASSWORD", "SECRET_ACCESS_KEY", "ACCESS_KEY_ID", "DATABASE_URL", "TOKEN")
    for name, t in templates.items():
        for fn in t.find_resources("AWS::Lambda::Function").values():
            env = fn["Properties"].get("Environment", {}).get("Variables", {})
            for key in env:
                assert not any(f in key for f in forbidden) or key == "DB_SECRET_ARN", (name, key)


def test_no_wildcard_actions_in_iam_policies(templates):
    for name, t in templates.items():
        for pol in t.find_resources("AWS::IAM::Policy").values():
            for st in pol["Properties"]["PolicyDocument"]["Statement"]:
                actions = st["Action"] if isinstance(st["Action"], list) else [st["Action"]]
                assert "*" not in actions, (name, st)


def test_bedrock_permissions_are_scoped_to_named_models(templates):
    t = templates["Api"]
    invoke = [
        st for pol in t.find_resources("AWS::IAM::Policy").values()
        for st in pol["Properties"]["PolicyDocument"]["Statement"]
        if "bedrock:InvokeModel" in (st["Action"] if isinstance(st["Action"], list) else [st["Action"]])
    ]
    assert invoke
    for st in invoke:
        assert st["Resource"] != "*"


def test_reminder_failures_alarm_on_first_error(templates):
    t = templates["Monitoring"]
    t.has_resource_properties("AWS::CloudWatch::Alarm", {
        "AlarmDescription": "Reminder push delivery failed", "Threshold": 1,
    })
    t.has_resource_properties("AWS::CloudWatch::Alarm", {
        "AlarmDescription": "Captures landed in the dead-letter queue",
    })
    t.resource_count_is("AWS::CloudWatch::Dashboard", 1)


def test_guardrail_blocks_prompt_attacks_and_masks_credentials(templates):
    t = templates["Ai"]
    t.has_resource_properties("AWS::Bedrock::Guardrail", {
        "ContentPolicyConfig": {"FiltersConfig": Match.array_with([
            Match.object_like({"Type": "PROMPT_ATTACK", "InputStrength": "HIGH"}),
        ])},
        "SensitiveInformationPolicyConfig": {"PiiEntitiesConfig": Match.array_with([
            Match.object_like({"Type": "AWS_SECRET_KEY", "Action": "ANONYMIZE"}),
        ])},
    })
    t.resource_count_is("AWS::Bedrock::GuardrailVersion", 1)


def test_callers_get_the_guardrail_and_permission(templates):
    for name in ("Api", "Queues"):
        t = templates[name]
        envs = [f["Properties"]["Environment"]["Variables"] for f in t.find_resources("AWS::Lambda::Function").values()
                if "Environment" in f["Properties"]]
        assert any("GUARDRAIL_ID" in e and "GUARDRAIL_VERSION" in e for e in envs), name
        t.has_resource_properties("AWS::IAM::Policy", {"PolicyDocument": {"Statement": Match.array_with([
            Match.object_like({"Action": "bedrock:ApplyGuardrail"}),
        ])}})


def test_no_claude_or_anthropic_model_anywhere(templates):
    import json
    for name, t in templates.items():
        blob = json.dumps(t.to_json()).lower()
        assert "anthropic" not in blob and "claude" not in blob, name


def test_bedrock_calls_are_allowed_only_on_the_named_inference_profiles(templates):
    import json

    resources = set()
    for pol in templates["Api"].find_resources("AWS::IAM::Policy").values():
        for st in pol["Properties"]["PolicyDocument"]["Statement"]:
            actions = st["Action"] if isinstance(st["Action"], list) else [st["Action"]]
            if "bedrock:InvokeModel" in actions:
                res = st["Resource"] if isinstance(st["Resource"], list) else [st["Resource"]]
                resources.update(json.dumps(r) for r in res)
    joined = " ".join(resources)
    assert "inference-profile/apac.amazon.nova-lite-v1:0" in joined
    assert "inference-profile/apac.amazon.nova-pro-v1:0" in joined
    assert "foundation-model/amazon.nova-lite-v1:0" in joined
    assert '"*"' not in resources, "never a wildcard over all of Bedrock"
