# -------------------------------------------------------------------------------------------------
# AWS VPC Peering Lab - Complete Infrastructure Definition
# Workbook: EWB Cloud Labs - AWS Architect Associate Project 01
# -------------------------------------------------------------------------------------------------

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =================================================================================================
# VPC A (10.10.0.0/16)
# =================================================================================================

resource "aws_vpc" "vpc_a" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ewb-vpc-a"
  }
}

resource "aws_internet_gateway" "igw_a" {
  vpc_id = aws_vpc.vpc_a.id

  tags = {
    Name = "ewb-igw-a"
  }
}

# Subnets in VPC A
resource "aws_subnet" "subnet_a_public" {
  vpc_id                  = aws_vpc.vpc_a.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "ewb-a-public"
  }
}

resource "aws_subnet" "subnet_a_private" {
  vpc_id                  = aws_vpc.vpc_a.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "ewb-a-private"
  }
}

# Route Tables in VPC A
resource "aws_route_table" "rt_a_public" {
  vpc_id = aws_vpc.vpc_a.id

  tags = {
    Name = "ewb-rt-a-public"
  }
}

resource "aws_route_table" "rt_a_private" {
  vpc_id = aws_vpc.vpc_a.id

  tags = {
    Name = "ewb-rt-a-private"
  }
}

# Explicit Subnet Associations for VPC A
resource "aws_route_table_association" "assoc_a_public" {
  subnet_id      = aws_subnet.subnet_a_public.id
  route_table_id = aws_route_table.rt_a_public.id
}

resource "aws_route_table_association" "assoc_a_private" {
  subnet_id      = aws_subnet.subnet_a_private.id
  route_table_id = aws_route_table.rt_a_private.id
}

# Default Route to Internet Gateway for Public Subnet
resource "aws_route" "route_a_public_internet" {
  route_table_id         = aws_route_table.rt_a_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw_a.id
}

# =================================================================================================
# VPC B (10.20.0.0/16) - Strictly Private Workload VPC
# =================================================================================================

resource "aws_vpc" "vpc_b" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ewb-vpc-b"
  }
}

# Subnet in VPC B
resource "aws_subnet" "subnet_b_private" {
  vpc_id                  = aws_vpc.vpc_b.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "ewb-b-private"
  }
}

# Route Table in VPC B
resource "aws_route_table" "rt_b_private" {
  vpc_id = aws_vpc.vpc_b.id

  tags = {
    Name = "ewb-rt-b-private"
  }
}

# Explicit Subnet Association for VPC B
resource "aws_route_table_association" "assoc_b_private" {
  subnet_id      = aws_subnet.subnet_b_private.id
  route_table_id = aws_route_table.rt_b_private.id
}

# =================================================================================================
# VPC Peering Connection (ewb-a-b-peer)
# =================================================================================================

resource "aws_vpc_peering_connection" "peer" {
  count       = var.enable_peering ? 1 : 0
  vpc_id      = aws_vpc.vpc_a.id
  peer_vpc_id = aws_vpc.vpc_b.id
  auto_accept = true

  tags = {
    Name = "ewb-a-b-peer"
  }
}

# Routes across Peering Connection
resource "aws_route" "route_a_private_to_b" {
  count                     = var.enable_peering ? 1 : 0
  route_table_id            = aws_route_table.rt_a_private.id
  destination_cidr_block    = "10.20.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.peer[0].id
}

resource "aws_route" "route_a_public_to_b" {
  count = var.enable_peering ? 1 : 0
  # Public route table requires route to VPC B so Bastion can ProxyJump into App-B
  route_table_id            = aws_route_table.rt_a_public.id
  destination_cidr_block    = "10.20.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.peer[0].id
}

resource "aws_route" "route_b_private_to_a" {
  count                     = var.enable_peering ? 1 : 0
  # Return path to VPC A
  route_table_id            = aws_route_table.rt_b_private.id
  destination_cidr_block    = "10.10.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.peer[0].id
}

# =================================================================================================
# Security Groups (Strictly scoped /32 host rules)
# =================================================================================================

# 1. Bastion Host Security Group (VPC A)
resource "aws_security_group" "sg_bastion" {
  name        = "ewb-sg-bastion"
  description = "Security group for administration bastion host"
  vpc_id      = aws_vpc.vpc_a.id

  ingress {
    description = "SSH from authorized management workstation"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_source_ip]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ewb-sg-bastion"
  }
}

# 2. App-A Security Group (VPC A)
resource "aws_security_group" "sg_app_a" {
  name        = "ewb-sg-app-a"
  description = "Security group for private workload App-A"
  vpc_id      = aws_vpc.vpc_a.id

  ingress {
    description = "SSH management from Bastion private IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.1.10/32"]
  }

  ingress {
    description = "ICMP Echo Request from App-B private IP"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["10.20.1.10/32"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ewb-sg-app-a"
  }
}

# 3. App-B Security Group (VPC B)
resource "aws_security_group" "sg_app_b" {
  name        = "ewb-sg-app-b"
  description = "Security group for private workload App-B"
  vpc_id      = aws_vpc.vpc_b.id

  ingress {
    description = "SSH management from Bastion private IP via ProxyJump"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.1.10/32"]
  }

  ingress {
    description = "ICMP Echo Request from App-A private IP"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["10.10.2.10/32"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ewb-sg-app-b"
  }
}

# =================================================================================================
# Compute Instances (Amazon Linux 2023, static private IPs)
# =================================================================================================

# 1. Bastion Host (VPC A Public Subnet)
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.subnet_a_public.id
  private_ip                  = "10.10.1.10"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg_bastion.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "ewb-bastion"
  }
}

# 2. App-A Host (VPC A Private Subnet)
resource "aws_instance" "app_a" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.subnet_a_private.id
  private_ip                  = "10.10.2.10"
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.sg_app_a.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "ewb-app-a"
  }
}

# 3. App-B Host (VPC B Private Subnet)
resource "aws_instance" "app_b" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.subnet_b_private.id
  private_ip                  = "10.20.1.10"
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.sg_app_b.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "ewb-app-b"
  }
}
