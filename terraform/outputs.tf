output "vpc_a_id" {
  description = "VPC A ID (ewb-vpc-a)"
  value       = aws_vpc.vpc_a.id
}

output "vpc_b_id" {
  description = "VPC B ID (ewb-vpc-b)"
  value       = aws_vpc.vpc_b.id
}

output "subnet_a_public_id" {
  description = "Subnet A Public ID"
  value       = aws_subnet.subnet_a_public.id
}

output "subnet_a_private_id" {
  description = "Subnet A Private ID"
  value       = aws_subnet.subnet_a_private.id
}

output "subnet_b_private_id" {
  description = "Subnet B Private ID"
  value       = aws_subnet.subnet_b_private.id
}

output "peering_connection_id" {
  description = "VPC Peering Connection ID (ewb-a-b-peer)"
  value       = var.enable_peering ? aws_vpc_peering_connection.peer[0].id : null
}

output "bastion_instance_id" {
  description = "Bastion Instance ID"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Bastion Public IPv4 Address (use in ~/.ssh/config)"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Bastion Private IPv4 Address"
  value       = aws_instance.bastion.private_ip
}

output "app_a_instance_id" {
  description = "App-A Instance ID"
  value       = aws_instance.app_a.id
}

output "app_a_private_ip" {
  description = "App-A Private IPv4 Address"
  value       = aws_instance.app_a.private_ip
}

output "app_b_instance_id" {
  description = "App-B Instance ID"
  value       = aws_instance.app_b.id
}

output "app_b_private_ip" {
  description = "App-B Private IPv4 Address"
  value       = aws_instance.app_b.private_ip
}

output "ssh_config_snippet" {
  description = "Pre-configured SSH configuration block for ~/.ssh/config"
  value       = <<-EOT
    Host ewb-bastion
      HostName ${aws_instance.bastion.public_ip}
      User ec2-user
      IdentityFile ~/.ssh/ewb-lab.pem
      IdentitiesOnly yes

    Host ewb-app-a
      HostName ${aws_instance.app_a.private_ip}
      User ec2-user
      IdentityFile ~/.ssh/ewb-lab.pem
      IdentitiesOnly yes
      ProxyJump ewb-bastion

    Host ewb-app-b
      HostName ${aws_instance.app_b.private_ip}
      User ec2-user
      IdentityFile ~/.ssh/ewb-lab.pem
      IdentitiesOnly yes
      ProxyJump ewb-bastion
  EOT
}
