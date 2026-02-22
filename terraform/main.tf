# Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Local Variables
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Use custom domain if provided, otherwise use Elastic IP
  headscale_url = var.headscale_domain != "" ? "https://${var.headscale_domain}" : "https://${aws_eip.vpn.public_ip}"
}

# Data Sources
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for VPN Server
resource "aws_security_group" "vpn" {
  name        = "${var.project_name}-vpn-sg"
  description = "Security group for ZeroTeir VPN server"

  # SSH access from admin IP
  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  # Headscale HTTPS
  ingress {
    description = "Headscale HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Headscale gRPC (for control plane)
  ingress {
    description = "Headscale gRPC"
    from_port   = 50443
    to_port     = 50443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # WireGuard VPN
  ingress {
    description = "WireGuard VPN"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (for Let's Encrypt ACME challenge)
  ingress {
    description = "HTTP for Let's Encrypt"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-vpn-sg"
  }
}

# Elastic IP for VPN Server
resource "aws_eip" "vpn" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-vpn-eip"
  }
}

# EC2 Instance for VPN Server
resource "aws_instance" "vpn" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  vpc_security_group_ids = [aws_security_group.vpn.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true

    tags = {
      Name = "${var.project_name}-vpn-root-volume"
    }
  }

  # Cloud-init configuration for automatic setup
  user_data = templatefile("${path.module}/files/cloud-init.yaml", {
    headscale_version = var.headscale_version
    headscale_url     = local.headscale_url
    elastic_ip        = aws_eip.vpn.public_ip
  })

  # Instance starts in stopped state to save costs
  # Will be started via API on first connection
  lifecycle {
    ignore_changes = [
      # Ignore user_data changes after creation to prevent replacement
      user_data,
      # Allow instance to be stopped/started without Terraform interference
      instance_state
    ]
  }

  tags = {
    Name = "${var.project_name}-vpn-server"
  }
}

# Associate Elastic IP with Instance
resource "aws_eip_association" "vpn" {
  instance_id   = aws_instance.vpn.id
  allocation_id = aws_eip.vpn.id
}
