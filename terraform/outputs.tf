output "proxy_id" {
  description = "EC2 Instance ID of the Proxy"
  value       = aws_instance.proxy.id
}

output "web_ids" {
  description = "EC2 Instance IDs of the Web servers"
  value       = aws_instance.web[*].id
}

output "db_id" {
  description = "EC2 Instance ID of the Database"
  value       = aws_instance.db.id
}

output "eice_id" {
  description = "EC2 Instance Connect Endpoint ID"
  value       = aws_ec2_instance_connect_endpoint.eice.id
}

output "proxy_public_ip" {
  description = "Public IPv4 address of the Traefik proxy"
  value       = aws_instance.proxy.public_ip
}

output "wordpress_url" {
  description = "URL to access the WordPress website"
  value       = "http://${aws_instance.proxy.public_ip}/"
}

output "efs_mount_target_ip" {
  description = "Private IP of the EFS mount target"
  value       = aws_efs_mount_target.private_subnet.ip_address
}

output "ssh_commands_eice_direct" {
  description = "Direct AWS CLI commands to connect to instances via EICE (Zero SSH key required, ephemeral key pushed by AWS)"
  value = {
    proxy = "aws ec2-instance-connect ssh --instance-id ${aws_instance.proxy.id} --connection-type eice"
    db    = "aws ec2-instance-connect ssh --instance-id ${aws_instance.db.id} --connection-type eice"
    web   = [for instance in aws_instance.web : "aws ec2-instance-connect ssh --instance-id ${instance.id} --connection-type eice"]
  }
}
