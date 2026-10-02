#!/usr/bin/env bash
# Build the web app against the live backend and upload it to Amplify Hosting.
# Usage: infra/deploy/deploy-web.sh
set -euo pipefail
cd "$(dirname "$0")"; . ./config.sh

APP=$(aws amplify list-apps --region "$AWS_REGION" --query "apps[?name=='$AMPLIFY_APP_NAME'].appId" --output text)
API_HOST=$(aws apprunner list-services --region "$AWS_REGION" \
  --query "ServiceSummaryList[?ServiceName=='$APPRUNNER_SERVICE'].ServiceUrl" --output text)

cd ../../web
VITE_BACKEND_URL="https://$API_HOST" npm run build

# Python makes the path so it is valid for Python and curl on Windows and Linux alike.
ZIP=$(python -c "import tempfile; print(tempfile.mkdtemp().replace(chr(92), '/') + '/web.zip')")
(cd dist && python -c "
import zipfile, os, sys
with zipfile.ZipFile(sys.argv[1], 'w', zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk('.'):
        for f in files:
            p = os.path.join(root, f); z.write(p, os.path.relpath(p, '.').replace(os.sep, '/'))
" "$ZIP")

OUT=$(aws amplify create-deployment --app-id "$APP" --branch-name main --region "$AWS_REGION" --output json)
JOB=$(echo "$OUT" | python -c "import sys,json; print(json.load(sys.stdin)['jobId'])")
URL=$(echo "$OUT" | python -c "import sys,json; print(json.load(sys.stdin)['zipUploadUrl'])")
curl -sf -T "$ZIP" "$URL" >/dev/null
aws amplify start-deployment --app-id "$APP" --branch-name main --job-id "$JOB" --region "$AWS_REGION" >/dev/null
# Wait for Amplify to finish publishing before claiming success.
for _ in $(seq 1 40); do
  STATUS=$(aws amplify get-job --app-id "$APP" --branch-name main --job-id "$JOB" --region "$AWS_REGION" --query job.summary.status --output text)
  case "$STATUS" in
    SUCCEED) break ;;
    FAILED|CANCELLED) echo "Deployment $STATUS" >&2; exit 1 ;;
  esac
  sleep 3
done
echo "Deployed: https://main.$APP.amplifyapp.com"
