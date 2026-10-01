"""KMS data key, WAF web ACL for the API, and CloudTrail audit logging (spec R5.4, R5.6)."""

from aws_cdk import (
    Duration,
    RemovalPolicy,
    Stack,
    aws_cloudtrail as cloudtrail,
    aws_kms as kms,
    aws_s3 as s3,
    aws_wafv2 as wafv2,
)
from constructs import Construct


def _managed_rule(name: str, priority: int) -> wafv2.CfnWebACL.RuleProperty:
    return wafv2.CfnWebACL.RuleProperty(
        name=name,
        priority=priority,
        override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
        statement=wafv2.CfnWebACL.StatementProperty(
            managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                vendor_name="AWS", name=name
            )
        ),
        visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
            cloud_watch_metrics_enabled=True, metric_name=name, sampled_requests_enabled=True
        ),
    )


class SecurityStack(Stack):
    def __init__(self, scope: Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # One customer-managed key for S3 media and CloudTrail. Rotated yearly.
        self.data_key = kms.Key(
            self,
            "DataKey",
            alias="alias/personal-memory-os-data",
            description="Encrypts captured media and audit logs",
            enable_key_rotation=True,
            removal_policy=RemovalPolicy.RETAIN,
        )

        # Regional web ACL, associated with the REST API stage in ApiStack.
        self.web_acl = wafv2.CfnWebACL(
            self,
            "ApiWebAcl",
            scope="REGIONAL",
            default_action=wafv2.CfnWebACL.DefaultActionProperty(allow={}),
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                cloud_watch_metrics_enabled=True,
                metric_name="personal-memory-os-api",
                sampled_requests_enabled=True,
            ),
            rules=[
                _managed_rule("AWSManagedRulesCommonRuleSet", 1),
                _managed_rule("AWSManagedRulesKnownBadInputsRuleSet", 2),
                wafv2.CfnWebACL.RuleProperty(
                    name="RateLimitPerIp",
                    priority=3,
                    action=wafv2.CfnWebACL.RuleActionProperty(block={}),
                    statement=wafv2.CfnWebACL.StatementProperty(
                        rate_based_statement=wafv2.CfnWebACL.RateBasedStatementProperty(
                            limit=1000, aggregate_key_type="IP"
                        )
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="RateLimitPerIp",
                        sampled_requests_enabled=True,
                    ),
                ),
            ],
        )

        # API audit trail: every management event, KMS-encrypted, retained 1 year.
        trail_bucket = s3.Bucket(
            self,
            "AuditBucket",
            encryption=s3.BucketEncryption.KMS,
            encryption_key=self.data_key,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            enforce_ssl=True,
            removal_policy=RemovalPolicy.RETAIN,
            lifecycle_rules=[s3.LifecycleRule(expiration=Duration.days(365))],
        )
        cloudtrail.Trail(
            self,
            "AuditTrail",
            bucket=trail_bucket,
            encryption_key=self.data_key,
            enable_file_validation=True,
            is_multi_region_trail=True,
        )
