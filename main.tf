terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.3.9"
}

# local variables
locals {
  user_data = templatefile("${path.module}/install-xray.sh", {
    DOMAIN = var.domain
    EMAIL  = var.email
    TOKEN  = var.token
  })
}

# Specify cloud provider
provider "aws" {
  region  = var.region
  profile = var.profile
}

# Add public key
resource "aws_key_pair" "xray_key_pair" {
  key_name   = "xray_vpn_key_${formatdate("MM_DD_hh_mm", timestamp())}"
  public_key = file(var.public_key_path)
}

# Define VPC
resource "aws_vpc" "xray_vpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "xray_vpn_${timestamp()}"
  }
}

# Define VPC subnets
resource "aws_subnet" "xray_subnet" {
  vpc_id     = aws_vpc.xray_vpc.id
  cidr_block = var.subnet_cidr_block

  tags = {
    Name = "xray_subnet_${timestamp()}"
  }
}

# Add internet gateway
resource "aws_internet_gateway" "xray_ig" {
  vpc_id = aws_vpc.xray_vpc.id

  tags = {
    Name = "xray_ig_${timestamp()}"
  }
}

# Create route table for a public subnet 
resource "aws_route_table" "xray_public_rt" {
  vpc_id = aws_vpc.xray_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.xray_ig.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.xray_ig.id
  }

  tags = {
    Name = "xray_prt_${timestamp()}"
  }
}

# Associate public subnets with the route table
resource "aws_route_table_association" "xray_public_1_rt_a" {
  subnet_id      = aws_subnet.xray_subnet.id
  route_table_id = aws_route_table.xray_public_rt.id
}

module "security_group" {
  source = "./modules/security_group"

  vpc_id      = aws_vpc.xray_vpc.id
  name_prefix = var.security_group_name_prefix
}

resource "aws_instance" "xray_server" {
  count         = var.ec2_count
  ami           = var.instance_ami
  instance_type = var.instance_type
  key_name      = aws_key_pair.xray_key_pair.key_name

  subnet_id                   = aws_subnet.xray_subnet.id
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true

  user_data = local.user_data

  tags = {
    Name = "xry_${timestamp()}"
  }

  provisioner "remote-exec" {
    inline = [
      "timeout 300s bash -c 'sudo tail -f /var/log/cloud-init-output.log | while read line; do echo $line; echo $line | grep 'vmess://' && break; done'"
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_key_path)
      host        = self.public_ip
    }
  }
}
