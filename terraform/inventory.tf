# Ansible Inventory configured for AWS Systems Manager (SSM)
# Zero SSH keys, zero open port 22, connects directly via AWS SSM API
resource "local_file" "inventory" {
  filename        = "../ansible/inventory.ini"
  file_permission = "0660"
  content         = <<-EOF
[proxy]
${aws_instance.proxy.id}

[proxy:vars]
ansible_connection = aws_ssm
ansible_aws_ssm_region = ${var.aws_region_name}
ansible_user = ec2-user

[web]
%{for instance in aws_instance.web~}
${instance.id}
%{endfor~}

[web:vars]
ansible_connection = aws_ssm
ansible_aws_ssm_region = ${var.aws_region_name}
ansible_user = ec2-user
nfs_wp_content_ip = ${aws_efs_mount_target.private_subnet.ip_address}:/

[db]
${aws_instance.db.id}

[db:vars]
ansible_connection = aws_ssm
ansible_aws_ssm_region = ${var.aws_region_name}
ansible_user = ec2-user
EOF
}
