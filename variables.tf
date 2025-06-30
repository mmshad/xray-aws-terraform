variable "region" {
  type    = string
  default = "us-east-1"
}

variable "ec2_count" {
  type        = number
  description = "number of EC2 instances for multiple VPN servers"
  default     = 1
}

variable "profile" {
  type    = string
  default = "xray_profile"
}

variable "domain" {
  description = "Your domain name (e.g., your-domain.duckdns.org)"
  type        = string
}

variable "email" {
  description = "Your email address for Let's Encrypt certificate"
  type        = string
}

variable "token" {
  description = "Your DuckDNS token"
  type        = string
}

variable "public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr_block" {
  type    = string
  default = "10.0.1.0/24"
}

variable "security_group_name_prefix" {
  description = "Prefix for the name of the security group"
  default     = "terra_"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "ssh_key_path" {
  type    = string
  default = "~/.ssh/id_rsa"
}

variable "protocol" {
  description = "X-Ray protocol to use (vmess or vless)"
  type        = string
  default     = "vmess"

  validation {
    condition     = contains(["vmess", "vless"], var.protocol)
    error_message = "Protocol must be either 'vmess' or 'vless'."
  }
}