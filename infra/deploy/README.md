# Deployment (lean, about $5–8 a month)

What is live, in `ap-south-1` (Mumbai):

| Piece | Service | Address |
|---|---|---|
| Backend API | AWS App Runner (`pmos-backend`, 0.25 vCPU / 0.5 GB, 1–2 instances) | https://wrducpxx4p.ap-south-1.awsapprunner.com |
| Web app | AWS Amplify Hosting (`pmos-web`, branch `main`) | https://main.d1kc2e2qvfes41.amplifyapp.com |
| Database | Neon PostgreSQL (free tier) | secret in SSM |
| Media files | S3 `personal-memory-os-captures-<account>` | private |
| AI | Amazon Bedrock: Nova Lite (fast), Nova Pro (strong), Titan embeddings | via the service role |
| Secrets | SSM Parameter Store `SecureString` under `/pmos/` (free) | `DATABASE_URL`, `JWT_SECRET` |

No Lambda, NAT gateway, WAF, Aurora or OpenSearch. (`infra/stacks` holds the larger
CDK design for when those are wanted; it is not what is deployed.)

## Redeploy

```bash
infra/deploy/deploy-backend.sh   # build image, push to ECR, roll App Runner (needs Docker running)
infra/deploy/deploy-web.sh       # build the web app, upload to Amplify
```

Backend start-up applies pending database migrations (`alembic upgrade head`) before serving.

## Security model

- The service runs as `pmos-apprunner-instance`, which may call **only** the named Nova/Titan
  models, read/write the captures bucket, and read `/pmos/*` parameters. There are no access keys.
- `pmos-apprunner-ecr-access` lets App Runner pull the image.
- Browsers may call the API only from the web app's address (`CORS_ORIGINS`). The phone app is
  unaffected (CORS is a browser rule).
- Login tokens are signed with `JWT_SECRET`. Rotating it signs everyone out:
  `aws ssm put-parameter --name /pmos/JWT_SECRET --type SecureString --overwrite --value <new>`
  then `deploy-backend.sh`.
- Changing the database password: update `/pmos/DATABASE_URL` the same way.

## Cost (estimate, list prices)

| | Per month |
|---|---|
| App Runner (always-on small instance + request time) | $4–7 |
| Amplify Hosting (free tier first 12 months) | $0–1 |
| ECR image storage (last 3 images kept) | < $0.1 |
| S3, SSM parameters | < $1 |
| Bedrock Nova (light use) | $1–3 |
| **Total** | **about $6–10** |

Set a budget alert in the AWS console (Billing → Budgets) at $10.

## Tear down

```bash
aws apprunner delete-service --region ap-south-1 --service-arn <arn>
aws amplify delete-app --region ap-south-1 --app-id <id>
aws ecr delete-repository --region ap-south-1 --repository-name pmos-backend --force
aws ssm delete-parameters --region ap-south-1 --names /pmos/DATABASE_URL /pmos/JWT_SECRET
```
