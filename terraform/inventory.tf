# Ansible Inventory configured for EC2 Instance Connect Endpoint (EICE)
# Connects to private instances directly via AWS backbone tunnel (ProxyCommand)
resource "local_file" "inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0660"
  content         = <<-EOF
[proxy]
${aws_instance.proxy.private_ip} instance_id=${aws_instance.proxy.id}

[web]
%{for instance in aws_instance.web~}
${instance.private_ip} instance_id=${instance.id}
%{endfor~}

[db]
${aws_instance.db.private_ip} instance_id=${aws_instance.db.id}

[all:vars]
ansible_user = ec2-user
ansible_ssh_private_key_file = id_rsa_eice
ansible_ssh_common_args = '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="aws ec2-instance-connect open-tunnel --instance-id {{ instance_id }} --remote-port 22 --region ${var.aws_region_name}"'
nfs_wp_content_ip = ${aws_efs_mount_target.private_subnet.ip_address}:/
EOF
}
