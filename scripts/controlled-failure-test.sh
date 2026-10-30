#!/usr/bin/env bash

set -Eeuo pipefail

REGION="${AWS_DEFAULT_REGION:-ap-south-1}"
TAG_PROJECT="EWB-VPC-Peering"
SG_APP_B_ID="$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=group-name,Values=ewb-sg-app-b" "Name=tag:Project,Values=$TAG_PROJECT" --query 'SecurityGroups[0].GroupId' --output text)"

if [[ -z "$SG_APP_B_ID" || "$SG_APP_B_ID" == "None" ]]; then
  echo "Could not find the project App-B security group." >&2
  exit 1
fi

restore_rule() {
  aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_APP_B_ID" --protocol icmp --port 8-0 --cidr 10.10.2.10/32 >/dev/null 2>&1 || true
}

trap restore_rule EXIT INT TERM
aws ec2 revoke-security-group-ingress --region "$REGION" --group-id "$SG_APP_B_ID" --protocol icmp --port 8-0 --cidr 10.10.2.10/32

if ssh -o BatchMode=yes -o ConnectTimeout=10 ewb-app-a "ping -c 4 -W 2 10.20.1.10"; then
  echo "ICMP unexpectedly succeeded while its inbound rule was removed." >&2
  exit 1
fi

ssh -o BatchMode=yes -o ConnectTimeout=10 ewb-app-b "hostname"
restore_rule
trap - EXIT INT TERM
ssh -o BatchMode=yes -o ConnectTimeout=10 ewb-app-a "ping -c 4 -W 2 10.20.1.10"
