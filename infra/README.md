# Infrastructure

**What is deployed today is the lean setup in [`deploy/`](deploy/README.md)** (App Runner + Amplify +
Neon, about $6-10 a month). The rest of this file describes the larger AWS CDK design in
`stacks/` (Lambda, Aurora, OpenSearch, WAF, ...), kept for when that scale is wanted. It costs
roughly $25-500 a month depending on options and is not deployed.

## CDK design (AWS CDK, Python)

Eleven stacks, deployed in dependency order by `app.py`:

| Stack | What it creates |
|---|---|
| Security | KMS data key (rotating), WAF web ACL, CloudTrail |
| Auth | Cognito user pool + public mobile client |
| Storage | Private KMS-encrypted captures bucket, EventBridge notifications on |
| Database | VPC, Aurora Serverless v2 PostgreSQL, backend security group |
| Notifications | SNS push topic |
| Ai | Bedrock Data Automation project, Bedrock Guardrail |
| Search | OpenSearch Serverless vector store, Bedrock Knowledge Base |
| Queues | S3 -> EventBridge -> SQS -> capture processor Lambda (+ DLQ) |
| Scheduler | EventBridge Scheduler group, notification dispatcher Lambda |
| Api | API Gateway + WAF, FastAPI Lambda, migrations on deploy |
| Monitoring | CloudWatch alarms and dashboard |

## Deploy

```bash
cd infra
pip install -r requirements.txt
cdk bootstrap            # once per account/region
cdk deploy --all         # needs Docker (the backend image is built locally)
```

Optional context: `-c alarm_email=you@example.com`, `-c sns_platform_app_arn=<arn>`,
`-c bda_profile_prefix=us|eu|apac`.

## Test (no AWS access needed)

```bash
pip install -r requirements-dev.txt
python -m pytest
```
