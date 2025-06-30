variable "region" {
  type    = string
  default = "us-east-1"
}

variable "ec2_count" {
  type        = number
  description = "Number of EC2 instances for multiple VPN servers. Each instance will have a unique subdomain (e.g., vpn1, vpn2, ...)."
  default     = 1
}

variable "profile" {
  type    = string
  default = "xray_profile"
}

variable "certbot_email" {
  description = "Your email address for Let's Encrypt certificate"
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

variable "cloudflare_api_token" {
  description = "Cloudflare API token for managing DNS records"
  type        = string
  default     = ""
}

variable "cloudflare_domain" {
  description = "Custom domain managed via Cloudflare"
  type        = string
  default     = ""
}

variable "cloudflare_subdomain" {
  description = "Subdomain for the custom domain managed via Cloudflare"
  type        = string
  default     = "vpn"
}

variable "duckdns_domain" {
  description = "Your DuckDNS domain (e.g., your-subdomain.duckdns.org)"
  type        = string
  default     = ""  
}

variable "duckdns_token" {
  description = "Your DuckDNS token"
  type        = string
  default     = ""  
}

variable "base_subdomain" {
  description = "Base subdomain for VPN servers (e.g., 'app' for app1, app2, ...)."
  type        = string
  default     = "app"
}
