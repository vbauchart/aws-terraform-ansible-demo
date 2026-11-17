# IAM Role & Instance Profile for AWS Systems Manager (SSM)
# Allows secure access to EC2 instances without SSH keys or open port 22
resource "aws_iam_role" "ssm_role" {
  name = "wordpress_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "wordpress_ssm_role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "wordpress_ssm_instance_profile"
  role = aws_iam_role.ssm_role.name
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
# Using Amazon Linux 2023 with pre-installed and activated SSM Agent

# Proxy / Bastion / NAT Instance
# Acts as reverse proxy (Traefik) AND provides free NAT forwarding for private instances,
# completely eliminating the costly AWS NAT Gateway ($32+/month).
resource "aws_instance" "proxy" {
  ami                  = var.ami_image
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  subnet_id            = aws_subnet.wordpress_public.id
  vpc_security_group_ids = [aws_security_group.wordpress_public.id]

  # Required for NAT routing
  source_dest_check = false

  user_data = <<-EOF
    #!/bin/bash
    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-ipforward.conf

    # Install iptables (Amazon Linux 2023 lacks iptables by default)
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
  count                = var.web_instance_count
  ami                  = var.ami_image
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  subnet_id            = aws_subnet.wordpress_private.id
  vpc_security_group_ids = [aws_security_group.wordpress_web.id]

  tags = {
    Name = "wordpress_web_${count.index}"
  }
}

resource "aws_instance" "db" {
  ami                  = var.ami_image
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  subnet_id            = aws_subnet.wordpress_private.id
  vpc_security_group_ids = [aws_security_group.wordpress_db.id]

  tags = {
    Name = "wordpress_db"
  }
}
