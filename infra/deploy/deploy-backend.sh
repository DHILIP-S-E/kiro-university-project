#!/usr/bin/env bash
# Build the backend image, push it to ECR, and roll App Runner onto it.
# Usage: infra/deploy/deploy-backend.sh      (needs Docker running and AWS credentials)
set -euo pipefail
cd "$(dirname "$0")"; . ./config.sh
cd ../../backend

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
docker build -f Dockerfile.server -t "$IMAGE" .
docker push "$IMAGE"

ARN=$(aws apprunner list-services --region "$AWS_REGION" \
      --query "ServiceSummaryList[?ServiceName=='$APPRUNNER_SERVICE'].ServiceArn" --output text)
aws apprunner start-deployment --service-arn "$ARN" --region "$AWS_REGION" >/dev/null
echo "Deploying... (about 4 minutes). Watch: aws apprunner describe-service --service-arn $ARN --query Service.Status"
