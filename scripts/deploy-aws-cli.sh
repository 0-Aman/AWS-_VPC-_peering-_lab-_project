#!/usr/bin/env bash
# =================================================================================================
# EWB Cloud Labs - AWS VPC Peering Deployment Script (AWS CLI)
# Student: Aman Kumar | Project: EWB-VPC-Peering
# Description: Automates network creation, security groups, EC2 launch, peering, and routing.
# =================================================================================================

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-ap-south-1}"
AZ="${REGION}a"
KEY_NAME="ewb-lab"
TAG_PROJECT="EWB-VPC-Peering"
TAG_STUDENT="Aman Kumar"

echo "==================================================================="
echo "Starting AWS VPC Peering Lab Deployment in ${REGION} (${AZ})"
echo "==================================================================="

# -------------------------------------------------------------------------------------------------
# 1. Fetch Latest Amazon Linux 2023 AMI
# -------------------------------------------------------------------------------------------------
echo "[1/7] Resolving Amazon Linux 2023 AMI..."
AMI_ID=$(aws ec2 describe-images \
  --region "${REGION}" \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" \
  --query "reverse(sort_by(Images, &CreationDate))[0].ImageId" \
  --output text)
echo "  -> Found AMI: ${AMI_ID}"

# -------------------------------------------------------------------------------------------------
# 2. Build VPC A & Subnets
# -------------------------------------------------------------------------------------------------
echo "[2/7] Creating VPC A (10.10.0.0/16)..."
VPC_A_ID=$(aws ec2 create-vpc \
  --region "${REGION}" \
  --cidr-block 10.10.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=ewb-vpc-a},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "Vpc.VpcId" --output text)

aws ec2 modify-vpc-attribute --region "${REGION}" --vpc-id "${VPC_A_ID}" --enable-dns-hostnames "{\"Value\":true}"
aws ec2 modify-vpc-attribute --region "${REGION}" --vpc-id "${VPC_A_ID}" --enable-dns-support "{\"Value\":true}"
echo "  -> VPC A created: ${VPC_A_ID}"

echo "  -> Creating subnets in VPC A..."
SUBNET_A_PUB_ID=$(aws ec2 create-subnet \
  --region "${REGION}" \
  --vpc-id "${VPC_A_ID}" \
  --cidr-block 10.10.1.0/24 \
  --availability-zone "${AZ}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=ewb-a-public},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "Subnet.SubnetId" --output text)

SUBNET_A_PRIV_ID=$(aws ec2 create-subnet \
  --region "${REGION}" \
  --vpc-id "${VPC_A_ID}" \
  --cidr-block 10.10.2.0/24 \
  --availability-zone "${AZ}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=ewb-a-private},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "Subnet.SubnetId" --output text)

echo "  -> Attaching Internet Gateway ewb-igw-a..."
IGW_A_ID=$(aws ec2 create-internet-gateway \
  --region "${REGION}" \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=ewb-igw-a},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "InternetGateway.InternetGatewayId" --output text)
aws ec2 attach-internet-gateway --region "${REGION}" --internet-gateway-id "${IGW_A_ID}" --vpc-id "${VPC_A_ID}"

echo "  -> Creating route tables for VPC A..."
RT_A_PUB_ID=$(aws ec2 create-route-table \
  --region "${REGION}" \
  --vpc-id "${VPC_A_ID}" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=ewb-rt-a-public},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "RouteTable.RouteTableId" --output text)

RT_A_PRIV_ID=$(aws ec2 create-route-table \
  --region "${REGION}" \
  --vpc-id "${VPC_A_ID}" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=ewb-rt-a-private},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "RouteTable.RouteTableId" --output text)

aws ec2 associate-route-table --region "${REGION}" --subnet-id "${SUBNET_A_PUB_ID}" --route-table-id "${RT_A_PUB_ID}" > /dev/null
aws ec2 associate-route-table --region "${REGION}" --subnet-id "${SUBNET_A_PRIV_ID}" --route-table-id "${RT_A_PRIV_ID}" > /dev/null

# Default route for public subnet
aws ec2 create-route --region "${REGION}" --route-table-id "${RT_A_PUB_ID}" --destination-cidr-block 0.0.0.0/0 --gateway-id "${IGW_A_ID}" > /dev/null

# -------------------------------------------------------------------------------------------------
# 3. Build VPC B & Subnet (Private only, No IGW)
# -------------------------------------------------------------------------------------------------
echo "[3/7] Creating VPC B (10.20.0.0/16)..."
VPC_B_ID=$(aws ec2 create-vpc \
  --region "${REGION}" \
  --cidr-block 10.20.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=ewb-vpc-b},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "Vpc.VpcId" --output text)

aws ec2 modify-vpc-attribute --region "${REGION}" --vpc-id "${VPC_B_ID}" --enable-dns-hostnames "{\"Value\":true}"
aws ec2 modify-vpc-attribute --region "${REGION}" --vpc-id "${VPC_B_ID}" --enable-dns-support "{\"Value\":true}"

SUBNET_B_PRIV_ID=$(aws ec2 create-subnet \
  --region "${REGION}" \
  --vpc-id "${VPC_B_ID}" \
  --cidr-block 10.20.1.0/24 \
  --availability-zone "${AZ}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=ewb-b-private},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "Subnet.SubnetId" --output text)

RT_B_PRIV_ID=$(aws ec2 create-route-table \
  --region "${REGION}" \
  --vpc-id "${VPC_B_ID}" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=ewb-rt-b-private},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "RouteTable.RouteTableId" --output text)

aws ec2 associate-route-table --region "${REGION}" --subnet-id "${SUBNET_B_PRIV_ID}" --route-table-id "${RT_B_PRIV_ID}" > /dev/null

# -------------------------------------------------------------------------------------------------
# 4. Create Security Groups & Inbound Rules
# -------------------------------------------------------------------------------------------------
echo "[4/7] Setting up Security Groups..."
MY_IP=$(curl -s https://checkip.amazonaws.com 2>/dev/null || echo "0.0.0.0")
if [[ ! "${MY_IP}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "Unable to determine a valid public IPv4 address. Set ADMIN_SOURCE_IP to your public IPv4 /32 and retry."
  exit 1
fi
MY_IP_CIDR="${ADMIN_SOURCE_IP:-${MY_IP}/32}"
if [[ ! "${MY_IP_CIDR}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/32$ ]]; then
  echo "ADMIN_SOURCE_IP must be an IPv4 address with /32."
  exit 1
fi

SG_BASTION_ID=$(aws ec2 create-security-group \
  --region "${REGION}" \
  --group-name "ewb-sg-bastion" \
  --description "Security group for bastion host" \
  --vpc-id "${VPC_A_ID}" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=ewb-sg-bastion},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --region "${REGION}" --group-id "${SG_BASTION_ID}" --protocol tcp --port 22 --cidr "${MY_IP_CIDR}"

SG_APP_A_ID=$(aws ec2 create-security-group \
  --region "${REGION}" \
  --group-name "ewb-sg-app-a" \
  --description "Security group for App-A" \
  --vpc-id "${VPC_A_ID}" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=ewb-sg-app-a},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --region "${REGION}" --group-id "${SG_APP_A_ID}" --protocol tcp --port 22 --cidr 10.10.1.10/32
aws ec2 authorize-security-group-ingress --region "${REGION}" --group-id "${SG_APP_A_ID}" --ip-permissions "IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges=[{CidrIp=10.20.1.10/32,Description='Echo request from App-B'}]"

SG_APP_B_ID=$(aws ec2 create-security-group \
  --region "${REGION}" \
  --group-name "ewb-sg-app-b" \
  --description "Security group for App-B" \
  --vpc-id "${VPC_B_ID}" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=ewb-sg-app-b},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --region "${REGION}" --group-id "${SG_APP_B_ID}" --protocol tcp --port 22 --cidr 10.10.1.10/32
aws ec2 authorize-security-group-ingress --region "${REGION}" --group-id "${SG_APP_B_ID}" --ip-permissions "IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges=[{CidrIp=10.10.2.10/32,Description='Echo request from App-A'}]"

# -------------------------------------------------------------------------------------------------
# 5. Launch EC2 Instances with Exact Static Private IPs
# -------------------------------------------------------------------------------------------------
echo "[5/7] Launching EC2 instances..."

# Bastion
BASTION_ID=$(aws ec2 run-instances \
  --region "${REGION}" \
  --image-id "${AMI_ID}" \
  --instance-type t3.micro \
  --key-name "${KEY_NAME}" \
  --subnet-id "${SUBNET_A_PUB_ID}" \
  --private-ip-address 10.10.1.10 \
  --associate-public-ip-address \
  --security-group-ids "${SG_BASTION_ID}" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ewb-bastion},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "Instances[0].InstanceId" --output text)

# App-A
APP_A_ID=$(aws ec2 run-instances \
  --region "${REGION}" \
  --image-id "${AMI_ID}" \
  --instance-type t3.micro \
  --key-name "${KEY_NAME}" \
  --subnet-id "${SUBNET_A_PRIV_ID}" \
  --private-ip-address 10.10.2.10 \
  --no-associate-public-ip-address \
  --security-group-ids "${SG_APP_A_ID}" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ewb-app-a},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "Instances[0].InstanceId" --output text)

# App-B
APP_B_ID=$(aws ec2 run-instances \
  --region "${REGION}" \
  --image-id "${AMI_ID}" \
  --instance-type t3.micro \
  --key-name "${KEY_NAME}" \
  --subnet-id "${SUBNET_B_PRIV_ID}" \
  --private-ip-address 10.20.1.10 \
  --no-associate-public-ip-address \
  --security-group-ids "${SG_APP_B_ID}" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ewb-app-b},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "Instances[0].InstanceId" --output text)

echo "  -> Waiting for instances to enter 'running' state..."
aws ec2 wait instance-running --region "${REGION}" --instance-ids "${BASTION_ID}" "${APP_A_ID}" "${APP_B_ID}"

BASTION_PUB_IP=$(aws ec2 describe-instances --region "${REGION}" --instance-ids "${BASTION_ID}" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

# -------------------------------------------------------------------------------------------------
# 6. Establish and Accept Peering Connection
# -------------------------------------------------------------------------------------------------
echo "[6/7] Creating and accepting VPC Peering connection (ewb-a-b-peer)..."
PCX_ID=$(aws ec2 create-vpc-peering-connection \
  --region "${REGION}" \
  --vpc-id "${VPC_A_ID}" \
  --peer-vpc-id "${VPC_B_ID}" \
  --tag-specifications "ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=ewb-a-b-peer},{Key=Project,Value=${TAG_PROJECT}},{Key=Student,Value=${TAG_STUDENT}}]" \
  --query "VpcPeeringConnection.VpcPeeringConnectionId" --output text)

# Accept peering
aws ec2 accept-vpc-peering-connection --region "${REGION}" --vpc-peering-connection-id "${PCX_ID}" > /dev/null

# -------------------------------------------------------------------------------------------------
# 7. Add Routes across Peering Connection
# -------------------------------------------------------------------------------------------------
echo "[7/7] Adding peering routes across both VPCs..."
aws ec2 create-route --region "${REGION}" --route-table-id "${RT_A_PRIV_ID}" --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id "${PCX_ID}" > /dev/null
aws ec2 create-route --region "${REGION}" --route-table-id "${RT_A_PUB_ID}"  --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id "${PCX_ID}" > /dev/null
aws ec2 create-route --region "${REGION}" --route-table-id "${RT_B_PRIV_ID}" --destination-cidr-block 10.10.0.0/16 --vpc-peering-connection-id "${PCX_ID}" > /dev/null

echo "==================================================================="
echo "Deployment Complete!"
echo "-------------------------------------------------------------------"
echo "VPC A ID:               ${VPC_A_ID}"
echo "VPC B ID:               ${VPC_B_ID}"
echo "Peering Connection ID:  ${PCX_ID}"
echo "Bastion Public IPv4:    ${BASTION_PUB_IP}"
echo "Bastion Private IPv4:   10.10.1.10"
echo "App-A Private IPv4:     10.10.2.10"
echo "App-B Private IPv4:     10.20.1.10"
echo "==================================================================="
echo "Next: Configure ~/.ssh/config and run test-connectivity.sh"
