#!/usr/bin/env bash
set -euo pipefail
cd ~/Desktop/cloud-security-splunk/splunk
source .env
eval "$(aws configure export-credentials --profile secproj --format env)"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 sync s3://secproj-cloudtrail-${ACCOUNT_ID}/AWSLogs/ logs/ --region eu-west-3 --quiet
mkdir -p logs_flat
find logs -name '*.json.gz' ! -path '*Digest*' -exec zcat {} + | jq -c '.Records[]' > logs_flat/cloudtrail.json
wc -l logs_flat/cloudtrail.json
docker exec -u splunk splunk /opt/splunk/bin/splunk stop
docker exec -u splunk splunk /opt/splunk/bin/splunk clean eventdata -index main -f
docker exec -u splunk splunk /opt/splunk/bin/splunk start
docker cp logs_flat/cloudtrail.json splunk:/tmp/cloudtrail_flat.json
docker exec -u root splunk chown splunk:splunk /tmp/cloudtrail_flat.json
docker exec -u splunk splunk /opt/splunk/bin/splunk add oneshot /tmp/cloudtrail_flat.json -sourcetype aws:cloudtrail -index main -auth "admin:$SPLUNK_PASSWORD"
