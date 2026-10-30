#!/usr/bin/env bash
# =================================================================================================
# EWB Cloud Labs - AWS VPC Peering Teardown Script (AWS CLI)
# Student: Aman Kumar | Project: EWB-VPC-Peering
# Description: Safely deletes all lab resources in the correct dependency order (Workbook Page 14)
# =================================================================================================

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-ap-south-1}"
TAG_PROJECT="EWB-VPC-Peering"

echo "==================================================================="
echo "Starting Clean Up of EWB VPC Peering Lab in ${REGION}"
echo "==================================================================="

# 1. Terminate EC2 Instances
echo "[1/5] Terminating EC2 instances with Project=${TAG_PROJECT}..."
INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "${REGION}" \
  --filters "Name=tag:Project,Values=${TAG_PROJECT}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

if [ -n "${INSTANCE_IDS}" ] && [ "${INSTANCE_IDS}" != "None" ]; then
  aws ec2 terminate-instances --region "${REGION}" --instance-ids ${INSTANCE_IDS} > /dev/null
  echo "  -> Waiting for instances to terminate..."
  aws ec2 wait instance-terminated --region "${REGION}" --instance-ids ${INSTANCE_IDS}
  echo "  -> Instances terminated."
else
  echo "  -> No active lab instances found."
fi

# 2. Delete VPC Peering Connection
echo "[2/5] Deleting VPC Peering connection..."
PCX_IDS=$(aws ec2 describe-vpc-peering-connections \
  --region "${REGION}" \
  --filters "Name=tag:Project,Values=${TAG_PROJECT}" "Name=status-code,Values=active,pending-acceptance" \
  --query "VpcPeeringConnections[].VpcPeeringConnectionId" \
  --output text)

if [ -n "${PCX_IDS}" ] && [ "${PCX_IDS}" != "None" ]; then
  for PCX in ${PCX_IDS}; do
    aws ec2 delete-vpc-peering-connection --region "${REGION}" --vpc-peering-connection-id "${PCX}" > /dev/null
    echo "  -> Deleted peering connection ${PCX}"
  done
fi

# 3. Delete Security Groups
echo "[3/5] Deleting Security Groups..."
SG_IDS=$(aws ec2 describe-security-groups \
  --region "${REGION}" \
  --filters "Name=tag:Project,Values=${TAG_PROJECT}" \
  --query "SecurityGroups[].GroupId" \
  --output text)

if [ -n "${SG_IDS}" ] && [ "${SG_IDS}" != "None" ]; then
  for SG in ${SG_IDS}; do
    # Try deleting group; ignore if already deleted
    aws ec2 delete-security-group --region "${REGION}" --group-id "${SG}" 2>/dev/null || true
  done
  echo "  -> Security groups deleted."
fi

# 4. Detach and Delete Internet Gateway
echo "[4/5] Detaching and deleting Internet Gateway..."
IGW_IDS=$(aws ec2 describe-internet-gateways \
  --region "${REGION}" \
  --filters "Name=tag:Project,Values=${TAG_PROJECT}" \
  --query "InternetGateways[].InternetGatewayId" \
  --output text)

if [ -n "${IGW_IDS}" ] && [ "${IGW_IDS}" != "None" ]; then
  for IGW in ${IGW_IDS}; do
    VPC_ATTACHED=$(aws ec2 describe-internet-gateways --region "${REGION}" --internet-gateway-ids "${IGW}" --query "InternetGateways[0].Attachments[0].VpcId" --output text 2>/dev/null || true)
    if [ -n "${VPC_ATTACHED}" ] && [ "${VPC_ATTACHED}" != "None" ]; then
      aws ec2 detach-internet-gateway --region "${REGION}" --internet-gateway-id "${IGW}" --vpc-id "${VPC_ATTACHED}" > /dev/null
    fi
    aws ec2 delete-internet-gateway --region "${REGION}" --internet-gateway-id "${IGW}" > /dev/null
    echo "  -> Deleted IGW ${IGW}"
  done
fi

# 5. Delete Subnets, Custom Route Tables and VPCs
echo "[5/5] Deleting subnets, route tables and VPCs..."

# Subnets
SUBNET_IDS=$(aws ec2 describe-subnets \
  --region "${REGION}" \
  --filters "Name=tag:Project,Values=${TAG_PROJECT}" \
  --query "Subnets[].SubnetId" \
  --output text)

if [ -n "${SUBNET_IDS}" ] && [ "${SUBNET_IDS}" != "None" ]; then
  for SUB in ${SUBNET_IDS}; do
    aws ec2 delete-subnet --region "${REGION}" --subnet-id "${SUB}" > /dev/null
    echo "  -> Deleted subnet ${SUB}"
  done
fi

# Custom Route Tables
RT_IDS=$(aws ec2 describe-route-tables \
  --region "${REGION}" \
  --filters "Name=tag:Project,Values=${TAG_PROJECT}" \
  --query "RouteTables[?Associations[0].Main!=`true`].RouteTableId" \
  --output text)

if [ -n "${RT_IDS}" ] && [ "${RT_IDS}" != "None" ]; then
  for RT in ${RT_IDS}; do
    aws ec2 delete-route-table --region "${REGION}" --route-table-id "${RT}" > /dev/null 2>&1 || true
    echo "  -> Deleted custom route table ${RT}"
  done
fi

# VPCs
VPC_IDS=$(aws ec2 describe-vpcs \
  --region "${REGION}" \
  --filters "Name=tag:Project,Values=${TAG_PROJECT}" \
  --query "Vpcs[].VpcId" \
  --output text)

if [ -n "${VPC_IDS}" ] && [ "${VPC_IDS}" != "None" ]; then
  for VPC in ${VPC_IDS}; do
    aws ec2 delete-vpc --region "${REGION}" --vpc-id "${VPC}" > /dev/null
    echo "  -> Deleted VPC ${VPC}"
  done
fi

echo "==================================================================="
echo "Clean Up Complete! All EWB-VPC-Peering resources removed."
echo "==================================================================="
