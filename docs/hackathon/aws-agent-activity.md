# Proof: a coding agent working in the AWS account

This project was built and deployed by a coding agent (Claude Code, running in a terminal on the
developer's machine) that is connected to the developer's AWS account through the AWS CLI. The agent
created, configured and updated the AWS resources behind the live application. This page is the audit
trail from **AWS CloudTrail**, AWS's own record of API calls made in the account.

> **Live application:** https://main.d1kc2e2qvfes41.amplifyapp.com (web) and
> https://wrducpxx4p.ap-south-1.awsapprunner.com (API), region `ap-south-1`.

## What CloudTrail shows

Every row below is a *change* (not a read) made on **2 October 2026** by the IAM user `test`
(the account's CLI identity the agent operates through).

| Service | Event | Count |
|---|---|---|
| amplify | `CreateApp` | 1 |
| amplify | `CreateBranch` | 1 |
| amplify | `CreateDeployment` | 4 |
| amplify | `StartDeployment` | 4 |
| apprunner | `CreateAutoScalingConfiguration` | 1 |
| apprunner | `CreateService` | 1 |
| apprunner | `StartDeployment` | 1 |
| apprunner | `UpdateService` | 1 |
| ecr | `CreateRepository` | 1 |
| ecr | `PutImage` | 2 |
| ecr | `PutLifecyclePolicy` | 1 |
| iam | `AttachRolePolicy` | 2 |
| iam | `CreateRole` | 2 |
| iam | `CreateServiceLinkedRole` | 1 |
| iam | `PutRolePolicy` | 1 |
| ssm | `PutParameter` | 4 |

Plus 14 container-image upload calls (`ecr` layer uploads) for the backend image.
Client reported by CloudTrail on these calls: `aws-cli/1.44.55`, `ecr.amazonaws.com`, `apprunner.amazonaws.com`.

## Chronological record (IST and UTC)

| Time (IST) | Time (UTC) | Service | Event | Region | Result |
|---|---|---|---|---|---|
| 02 Oct 21:13:08 | 15:43:08 | ecr | `CreateRepository` | ap-south-1 | success |
| 02 Oct 21:13:10 | 15:43:10 | ecr | `PutLifecyclePolicy` | ap-south-1 | success |
| 02 Oct 21:15:29 | 15:45:29 | ecr | `PutImage` | ap-south-1 | success |
| 02 Oct 21:15:36 | 15:45:36 | iam | `AttachRolePolicy` | us-east-1 | NoSuchEntityException |
| 02 Oct 21:16:13 | 15:46:13 | iam | `CreateRole` | us-east-1 | success |
| 02 Oct 21:16:15 | 15:46:15 | iam | `AttachRolePolicy` | us-east-1 | success |
| 02 Oct 21:16:21 | 15:46:21 | iam | `CreateRole` | us-east-1 | success |
| 02 Oct 21:16:23 | 15:46:23 | iam | `PutRolePolicy` | us-east-1 | success |
| 02 Oct 21:16:35 | 15:46:35 | ssm | `PutParameter` | ap-south-1 | success |
| 02 Oct 21:16:37 | 15:46:37 | ssm | `PutParameter` | ap-south-1 | success |
| 02 Oct 21:16:56 | 15:46:56 | ssm | `PutParameter` | ap-south-1 | success |
| 02 Oct 21:16:57 | 15:46:57 | ssm | `PutParameter` | ap-south-1 | success |
| 02 Oct 21:18:23 | 15:48:23 | apprunner | `CreateAutoScalingConfiguration` | ap-south-1 | success |
| 02 Oct 21:18:26 | 15:48:26 | apprunner | `CreateService` | ap-south-1 | success |
| 02 Oct 21:18:26 | 15:48:26 | iam | `CreateServiceLinkedRole` | us-east-1 | success |
| 02 Oct 21:30:02 | 16:00:02 | amplify | `CreateApp` | ap-south-1 | success |
| 02 Oct 21:30:04 | 16:00:04 | amplify | `CreateBranch` | ap-south-1 | success |
| 02 Oct 21:31:30 | 16:01:30 | amplify | `CreateDeployment` | ap-south-1 | success |
| 02 Oct 21:31:33 | 16:01:33 | amplify | `StartDeployment` | ap-south-1 | success |
| 02 Oct 21:32:01 | 16:02:01 | apprunner | `UpdateService` | ap-south-1 | success |
| 02 Oct 21:40:15 | 16:10:15 | amplify | `CreateDeployment` | ap-south-1 | success |
| 02 Oct 21:40:17 | 16:10:17 | amplify | `StartDeployment` | ap-south-1 | success |
| 02 Oct 21:40:46 | 16:10:46 | ecr | `PutImage` | ap-south-1 | success |
| 02 Oct 21:40:50 | 16:10:50 | apprunner | `StartDeployment` | ap-south-1 | success |
| 02 Oct 21:46:07 | 16:16:07 | amplify | `CreateDeployment` | ap-south-1 | success |
| 02 Oct 21:46:10 | 16:16:10 | amplify | `StartDeployment` | ap-south-1 | success |
| 02 Oct 21:46:56 | 16:16:56 | amplify | `CreateDeployment` | ap-south-1 | success |
| 02 Oct 21:46:59 | 16:16:59 | amplify | `StartDeployment` | ap-south-1 | success |

## How the agent was used

- **Built and tested the application:** backend (FastAPI), Flutter app, React web dashboard, with automated tests.
- **Created the cloud resources:** ECR repository, IAM roles with least-privilege policies, encrypted
  secrets in Systems Manager Parameter Store, an App Runner service, an Amplify Hosting app.
- **Deployed and verified:** built the container image, pushed it to ECR, rolled the App Runner service,
  uploaded the web build to Amplify, then tested the live URLs (including a real-browser end-to-end test).
- **Used Amazon Bedrock** (Amazon Nova models) to check the AI features against the live service.

The deploy steps are reproducible: see [`infra/deploy/`](../../infra/deploy/README.md).

## How to verify this yourself

In the AWS console open **CloudTrail → Event history**, set the region to `ap-south-1`
(IAM events appear under `us-east-1`), and filter **User name = `test`**, or look up the event names above.

## Limits of this evidence

CloudTrail records *which account identity* made each call, not *which tool* typed the command; the calls
above were issued by the coding agent through the AWS CLI. The full agent session transcript is the
complementary record.

