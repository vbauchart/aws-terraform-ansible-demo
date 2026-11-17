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

output "proxy_public_ip" {
  description = "Public IPv4 address of the Traefik proxy"
  value       = aws_instance.proxy.public_ip
}

output "proxy_ssm_session" {
  description = "AWS CLI command to connect to Proxy via SSM Session Manager (No SSH key needed)"
  value       = "aws ssm start-session --target ${aws_instance.proxy.id} --region ${var.aws_region_name}"
}

output "db_ssm_session" {
  description = "AWS CLI command to connect to DB via SSM Session Manager (No SSH key needed)"
  value       = "aws ssm start-session --target ${aws_instance.db.id} --region ${var.aws_region_name}"
}

output "web_ssm_sessions" {
  description = "AWS CLI commands to connect to Web instances via SSM Session Manager"
  value       = [for instance in aws_instance.web : "aws ssm start-session --target ${instance.id} --region ${var.aws_region_name}"]
}

output "wordpress_url" {
  description = "URL to access the WordPress website"
  value       = "http://${aws_instance.proxy.public_ip}/"
}

output "efs_mount_target_ip" {
  description = "Private IP of the EFS mount target"
  value       = aws_efs_mount_target.private_subnet.ip_address
}
