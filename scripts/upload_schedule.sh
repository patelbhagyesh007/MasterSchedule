#!/usr/bin/env bash
# Upload schedule_data.json to GitHub via the REST API.
# Usage:
#   export GITHUB_TOKEN=ghp_xxx
#   OWNER=patelbhagyesh007 REPO=MasterSchedule BRANCH=main ./scripts/upload_schedule.sh

set -euo pipefail

OWNER=${OWNER:-patelbhagyesh007}
REPO=${REPO:-MasterSchedule}
BRANCH=${BRANCH:-main}
TOKEN=${GITHUB_TOKEN:-}

if [ -z "$TOKEN" ]; then
  echo "Error: set GITHUB_TOKEN environment variable first."
  exit 1
fi

if [ ! -f schedule_data.json ]; then
  echo "Error: schedule_data.json not found in current directory. Run from project root."
  exit 1
fi

echo "Reading schedule_data.json..."
CONTENT=$(python3 - <<PY
import base64,sys
with open('schedule_data.json','rb') as f:
    print(base64.b64encode(f.read()).decode())
PY
)

API_URL="https://api.github.com/repos/$OWNER/$REPO/contents/schedule_data.json"

echo "Checking for existing file to obtain sha (if any)..."
RESPONSE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "$API_URL?ref=$BRANCH")
SHA=$(python3 - <<PY
import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get('sha',''))
except Exception:
    print('')
PY
<<<"$RESPONSE")

PAYLOAD=$(python3 - <<PY
import json,sys
data={
  'message': 'CLI upload schedule_data.json',
  'content': 'PLACEHOLDER',
  'branch': '%s'
}
print(json.dumps(data))
PY

PAYLOAD=$(printf '%s' "$PAYLOAD" | sed "s|PLACEHOLDER|$CONTENT|")

if [ -n "$SHA" ]; then
  # include sha for update
  PAYLOAD=$(python3 - <<PY
import json,sys
payload=json.load(sys.stdin)
payload['sha'] = '%s'
print(json.dumps(payload))
PY
<<<"$PAYLOAD")
fi

echo "Uploading to $OWNER/$REPO (branch: $BRANCH) ..."
HTTP=$(curl -s -o /dev/stderr -w "%{http_code}" -X PUT -H "Authorization: token $TOKEN" -H "Content-Type: application/json" -d "$PAYLOAD" "$API_URL")

if [ "$HTTP" = "201" ] || [ "$HTTP" = "200" ]; then
  echo "Upload successful (HTTP $HTTP)."
else
  echo "Upload failed (HTTP $HTTP). Check output above for details."
  exit 1
fi
