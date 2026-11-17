# VPC
resource "aws_vpc" "wordpress" {
  cidr_block                       = "10.1.0.0/16"
  enable_dns_hostnames             = true
  enable_dns_support               = true
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "wordpress"
  }
}

# Subnets
resource "aws_subnet" "wordpress_public" {
  vpc_id                  = aws_vpc.wordpress.id
  cidr_block              = "10.1.1.0/24"
  ipv6_cidr_block         = cidrsubnet(aws_vpc.wordpress.ipv6_cidr_block, 8, 1)
  availability_zone       = var.aws_az_name
  map_public_ip_on_launch = true

  tags = {
    Name = "wordpress_public"
  }
}

resource "aws_subnet" "wordpress_private" {
  vpc_id                  = aws_vpc.wordpress.id
  cidr_block              = "10.1.2.0/24"
  ipv6_cidr_block         = cidrsubnet(aws_vpc.wordpress.ipv6_cidr_block, 8, 2)
  availability_zone       = var.aws_az_name
  map_public_ip_on_launch = false

  tags = {
    Name = "wordpress_private"
  }
}

# Internet Gateway (100% Free)
resource "aws_internet_gateway" "wordpress" {
  vpc_id = aws_vpc.wordpress.id

  tags = {
    Name = "wordpress"
  }
}

# Egress-Only Internet Gateway for IPv6 (100% Free)
# Allows instances in private subnet to initiate outbound IPv6 traffic at zero cost
resource "aws_egress_only_internet_gateway" "wordpress" {
  vpc_id = aws_vpc.wordpress.id

  tags = {
    Name = "wordpress_eigw"
  }
}

# Public Route Table
resource "aws_route_table" "wordpress_public" {
  vpc_id = aws_vpc.wordpress.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wordpress.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.wordpress.id
  }

  tags = {
    Name = "wordpress_public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.wordpress_public.id
  route_table_id = aws_route_table.wordpress_public.id
}

# Private Route Table
# Uses Proxy instance as free NAT Gateway for IPv4, avoiding the costly AWS NAT Gateway ($32+/month).
resource "aws_route_table" "wordpress_private" {
  vpc_id = aws_vpc.wordpress.id

  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.proxy.primary_network_interface_id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.wordpress.id
  }

  tags = {
    Name = "wordpress_private"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.wordpress_private.id
  route_table_id = aws_route_table.wordpress_private.id
}

# ==============================================================================
# EC2 Instance Connect Endpoint (EICE) - 100% GRATUIT (0,00 €)
# Connect to private EC2 instances over the AWS backbone without opening port 22
# to the internet, without public IPs, and without any NAT Gateway dependency!
# ==============================================================================

resource "aws_security_group" "eice" {
  name        = "wordpress_eice_sg"
  description = "Security group for EC2 Instance Connect Endpoint"
  vpc_id      = aws_vpc.wordpress.id

  # EICE requires NO inbound rules. Connections originate from AWS control plane.

  # Outbound SSH rule targeting all VPC instances on port 22
  egress {
    description = "Allow outbound SSH to instances in VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.wordpress.cidr_block]
  }

  tags = {
    Name = "wordpress_eice_sg"
  }
}

resource "aws_ec2_instance_connect_endpoint" "eice" {
  subnet_id          = aws_subnet.wordpress_private.id
  security_group_ids = [aws_security_group.eice.id]

  tags = {
    Name = "wordpress_eice"
  }
}

# ==============================================================================
# Security Groups - Port 22 is strictly restricted to EICE (Zero 0.0.0.0/0 SSH!)
# ==============================================================================

resource "aws_security_group" "wordpress_public" {
  name        = "wordpress_public"
  description = "Allow HTTP from world, SSH from EICE only, and NAT forwarding"
  vpc_id      = aws_vpc.wordpress.id

  ingress {
    description = "HTTP from world"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH strictly restricted to EC2 Instance Connect Endpoint
  ingress {
    description     = "SSH from EC2 Instance Connect Endpoint only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.eice.id]
  }

  # Allow NAT forwarding traffic originating from private subnet
  ingress {
    description = "NAT forwarding from private subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_subnet.wordpress_private.cidr_block]
  }

  egress {
    description = "Outbound to world"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress_proxy_sg"
  }
}

resource "aws_security_group" "wordpress_web" {
  name        = "wordpress_web"
  description = "Allow HTTP from proxy and SSH from EICE only"
  vpc_id      = aws_vpc.wordpress.id

  ingress {
    description     = "HTTP from proxy"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress_public.id]
  }

  # SSH strictly restricted to EC2 Instance Connect Endpoint
  ingress {
    description     = "SSH from EC2 Instance Connect Endpoint only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.eice.id]
  }

  egress {
    description = "Outbound to world via NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress_web_sg"
  }
}

resource "aws_security_group" "wordpress_db" {
  name        = "wordpress_db"
  description = "Allow DB traffic from web instances and SSH from EICE only"
  vpc_id      = aws_vpc.wordpress.id

  ingress {
    description     = "MySQL from web instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress_web.id]
  }

  # SSH strictly restricted to EC2 Instance Connect Endpoint
  ingress {
    description     = "SSH from EC2 Instance Connect Endpoint only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.eice.id]
  }

  egress {
    description = "Outbound to world via NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress_db_sg"
  }
}

resource "aws_security_group" "wordpress_nfs" {
  name        = "wordpress_nfs"
  description = "Allow NFS traffic for EFS from web instances"
  vpc_id      = aws_vpc.wordpress.id

  ingress {
    description     = "NFS from web instances"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress_web.id]
  }

  egress {
    description = "Outbound NFS response"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress_nfs_sg"
  }
}
