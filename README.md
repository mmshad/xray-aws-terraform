# X-Ray VPN AWS Terraform

Terraform script to deploy X-Ray VPN server on AWS with automatic TLS certificate provisioning.

## Features
- Automated X-Ray VPN server deployment on AWS
- Let's Encrypt TLS certificate automation
- DuckDNS dynamic DNS integration
- WebSocket transport with TLS
- Configurable for multiple server instances

## Prerequisites
- Terraform CLI (1.3.9+) installed
- AWS CLI installed
- AWS account with appropriate permissions
- DuckDNS account and token
- SSH key pair generated

## Quick Start

1. **Clone and Configure**
   ```bash
   git clone https://github.com/mmshad/xray-aws-terraform.git
   cd xray-aws-terraform
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit Configuration**
   Edit `terraform.tfvars` with your values:
   ```bash
   domain = "your-subdomain.duckdns.org"
   email  = "your-email@example.com"
   token  = "your-duckdns-token"
   ```

3. **Deploy**
   ```bash
   terraform init
   terraform validate
   terraform plan
   terraform apply
   ```

4. **Get Connection Details**
   After deployment, look for the green `vmess://` link in the output. Copy this link to your V2Ray/X-Ray client.

## Configuration

### Required Variables
- `domain`: Your DuckDNS subdomain (e.g., "myserver.duckdns.org")
- `email`: Email for Let's Encrypt certificate registration
- `token`: Your DuckDNS token for DNS updates

### Optional Variables
- `region`: AWS region (default: "us-east-1")
- `ec2_count`: Number of VPN servers (default: 1)
- `instance_type`: EC2 instance type (default: "t2.micro")
- `profile`: AWS CLI profile name (default: "xray_profile")

## Multiple Servers
To deploy multiple VPN servers, set `ec2_count` in your `terraform.tfvars`:
```bash
ec2_count = 3
```
Each server will have its own `vmess://` connection link in the output.

## Security Notes
- All traffic is encrypted with TLS
- Random ports are assigned for each deployment
- SSH access is available for troubleshooting
- Security groups allow necessary ports only

## Cleanup
To destroy the infrastructure:
```bash
terraform plan -destroy
terraform destroy
```

## Troubleshooting
- Ensure your DuckDNS token is correct
- Verify AWS credentials are properly configured
- Check AWS service quotas for EC2 instances
- DNS propagation may take a few minutes

## License
This project is licensed under the MIT License.

## Contributing
Pull requests are welcome. For major changes, please open an issue first.