variable "aws_region" {
  description = "Target AWS Region for the lab deployment"
  type        = string
  default     = "ap-south-1"
}

variable "availability_zone" {
  description = "Target AZ for all subnets to minimize latency and ensure consistency"
  type        = string
  default     = "ap-south-1a"
}

variable "project_tag" {
  description = "Project tag value requested by the lab workbook"
  type        = string
  default     = "EWB-VPC-Peering"
}

variable "student_name" {
  description = "Student name for resource tagging"
  type        = string
  default     = "Aman Kumar"
}

variable "key_name" {
  description = "Name of the existing or created EC2 Key Pair (ewb-lab)"
  type        = string
  default     = "ewb-lab"
}

variable "admin_source_ip" {
  description = "Your workstation public IP CIDR for SSH access to Bastion (e.g. 203.0.113.25/32)"
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_source_ip, 0)) && can(regex("/32$", var.admin_source_ip))
    error_message = "admin_source_ip must be a valid IPv4 /32 address."
  }
}

variable "instance_type" {
  description = "EC2 instance size for the lab hosts"
  type        = string
  default     = "t3.micro"
}

variable "enable_peering" {
  description = "Create the peering connection and peer routes after the baseline test"
  type        = bool
  default     = true
}
