# Shared settings for the deploy scripts. Source of truth for what is deployed.
export MSYS_NO_PATHCONV=1            # stop Git Bash rewriting /pmos/... paths on Windows
export AWS_REGION=ap-south-1
export ACCOUNT_ID=${ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}
export ECR_REPO=pmos-backend
export APPRUNNER_SERVICE=pmos-backend
export AMPLIFY_APP_NAME=pmos-web
export IMAGE="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:latest"
