# Automated SSH Key Pair for Ansible & EICE tunneling
# Generated automatically by Terraform: zero manual ssh-keygen required!
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "wp_key" {
  key_name   = "wordpress_key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_file" "ssh_private_key" {
  filename        = "${path.module}/../ansible/id_rsa_eice"
  file_permission = "0600"
  content         = tls_private_key.ssh.private_key_pem
}

# EFS Single AZ (Free Tier: 5 GB/month)
resource "aws_efs_file_system" "web_content" {
  creation_token         = "web_content"
  encrypted              = true
  availability_zone_name = var.aws_az_name

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "web_content"
  }
}

resource "aws_efs_mount_target" "private_subnet" {
  file_system_id  = aws_efs_file_system.web_content.id
  subnet_id       = aws_subnet.wordpress_private.id
  security_groups = [aws_security_group.wordpress_nfs.id]
}

# EC2 Instances (Free Tier: 750h/month total for t2.micro or t3.micro)
# Using Amazon Linux 2023 with pre-installed EC2 Instance Connect service

# Proxy / Bastion / NAT Instance
# Acts as reverse proxy (Traefik) AND provides free NAT forwarding for private instances,
# completely eliminating the costly AWS NAT Gateway ($32+/month).
resource "aws_instance" "proxy" {
  ami                    = var.ami_image
  instance_type          = var.instance_type
  key_name               = aws_key_pair.wp_key.key_name
  subnet_id              = aws_subnet.wordpress_public.id
  vpc_security_group_ids = [aws_security_group.wordpress_public.id]

  # Required for NAT routing
  source_dest_check = false

  user_data = <<-EOF
    #!/bin/bash
    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-ipforward.conf

    # Install iptables (Amazon Linux 2023 uses nftables by default)
    dnf install -y iptables-nft

    # Detect default outgoing network interface
    IFACE=$(ip route show default | awk '{print $5}')

    # Allow kernel forwarding across interfaces
    iptables -P FORWARD ACCEPT
    iptables -A FORWARD -i $IFACE -j ACCEPT
    iptables -A FORWARD -o $IFACE -j ACCEPT

    # Enable NAT MASQUERADE
    iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
  EOF

  tags = {
    Name = "wordpress_proxy"
  }
}

resource "aws_instance" "web" {
  count                  = var.web_instance_count
  ami                    = var.ami_image
  instance_type          = var.instance_type
  key_name               = aws_key_pair.wp_key.key_name
  subnet_id              = aws_subnet.wordpress_private.id
  vpc_security_group_ids = [aws_security_group.wordpress_web.id]

  tags = {
    Name = "wordpress_web_${count.index}"
  }
}

resource "aws_instance" "db" {
  ami                    = var.ami_image
  instance_type          = var.instance_type
  key_name               = aws_key_pair.wp_key.key_name
  subnet_id              = aws_subnet.wordpress_private.id
  vpc_security_group_ids = [aws_security_group.wordpress_db.id]

  tags = {
    Name = "wordpress_db"
  }
}
