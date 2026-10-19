#!/usr/bin/env bash
set -euo pipefail
R=eu-west-3
echo "[1] Disable CloudTrail logging (DET-04)"
aws cloudtrail stop-logging --name secproj-trail --region $R
sleep 2
aws cloudtrail start-logging --name secproj-trail --region $R
echo "[2] Create IAM user + access key (DET-03)"
aws iam create-user --user-name sim-attacker >/dev/null
aws iam create-access-key --user-name sim-attacker >/dev/null
echo "[3] Open a security group to the world (DET-01)"
SG=$(aws ec2 create-security-group --group-name sim-open-sg --description sim --region $R --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 3389 --cidr 0.0.0.0/0 --region $R >/dev/null
echo "Done. Wait 15 min, then run scripts/refresh_logs.sh"
echo "SG=$SG"
