# X-Ray VPN AWS Terraform

Terraform script to deploy X-Ray VPN server on AWS with automatic TLS certificate provisioning.

## Features
- Automated X-Ray VPN server deployment on AWS
- Let's Encrypt TLS certificate automation
- Dynamic DNS integration with DuckDNS or Cloudflare
- WebSocket transport with TLS
- Configurable for multiple server instances

## Prerequisites
- Terraform CLI (1.3.9+) installed
- AWS CLI installed
- AWS account with appropriate permissions
- Either a DuckDNS or Cloudflare account (see setup instructions below)
- SSH key pair generated

### AWS Credentials Setup
1. **Create AWS Access Keys**
   - Log into your AWS Console
   - Go to IAM → Users → Your User → Security credentials
   - Create a new Access Key and note down the Access Key ID and Secret Access Key

2. **Configure AWS Profile**
   Create or edit `~/.aws/credentials` file with your AWS credentials:
   ```ini
   [xray_profile]
   aws_access_key_id = YOUR_ACCESS_KEY_ID
   aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
   ```

   Alternatively, you can set a different profile name in `terraform.tfvars`:
   ```bash
   profile = "your-custom-profile-name"
   ```

### Dynamic DNS Setup

#### Option 1: DuckDNS
1. **Create DuckDNS Account**
   - Visit [DuckDNS.org](https://www.duckdns.org)
   - Sign in with your preferred account (Google, GitHub, etc.)

2. **Create a Subdomain**
   - On the DuckDNS dashboard, enter your desired subdomain name
   - Click "add domain" (e.g., if you enter "myserver", you'll get "myserver.duckdns.org")
   - Note down your full domain name

3. **Get Your Token**
   - Your DuckDNS token is displayed at the top of the dashboard page
   - Copy this token - you'll need it for the `terraform.tfvars` file

4. **Test Your Setup (Optional)**
   You can test your DuckDNS setup by running:
   ```bash
   curl "https://www.duckdns.org/update?domains=YOUR_DUCKDNS_DOMAIN&token=YOUR_DUCKDNS_TOKEN&ip=1.2.3.4"
   ```

#### Option 2: Cloudflare
1. **Get a Cloudflare API Token**
   - Log into your Cloudflare account.
   - Go to **My Profile** → **API Tokens**.
   - Create a new API token with the following permissions:
     - Zone → DNS → Edit
   - Copy the generated token.

2. **Add Your Domain to Cloudflare**
   - Ensure your domain is added to your Cloudflare account.
   - Note down your domain name (e.g., `example.com`).

3. **Configure Variables**
   In your `terraform.tfvars` file, add the following:
   ```bash
   cloudflare_api_token = "your-cloudflare-api-token"
   cloudflare_domain = "yourdomain.com"
   cloudflare_subdomain = "app"  # Optional, default is "app"
   ```

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
   # For DuckDNS
   duckdns_domain = "your-subdomain.duckdns.org"  # Your DuckDNS domain from setup above
   certbot_email  = "your-email@example.com"      # Email for Let's Encrypt certificates
   duckdns_token  = "your-duckdns-token"          # DuckDNS token from your dashboard

   # For Cloudflare
   cloudflare_api_token = "your-cloudflare-api-token"
   cloudflare_domain = "yourdomain.com"
   cloudflare_subdomain = "app"  # Optional, default is "app"
   ```

3. **Deploy**
   ```bash
   terraform init
   terraform validate
   terraform plan
   terraform apply
   ```

4. **Get Connection Details**
   After deployment, look for the green connection link in the output:
   - For VMESS protocol: `vmess://` link
   - For VLESS protocol: `vless://` link

   Copy this link to your V2Ray/X-Ray client.

## Configuration

### Required Variables
- `duckdns_domain`: Your DuckDNS domain (e.g., "myserver.duckdns.org") or Cloudflare domain (e.g., "example.com")
- `certbot_email`: Email for Let's Encrypt certificate registration - used for certificate renewal notifications
- `duckdns_token`: Your DuckDNS token for DNS updates - found on your DuckDNS dashboard
- `cloudflare_api_token`: Your Cloudflare API token for DNS updates
- `cloudflare_domain`: Your Cloudflare domain name
- `cloudflare_subdomain`: Subdomain for Cloudflare (default: "app")

### Optional Variables
- `region`: AWS region (default: "us-east-1")
- `ec2_count`: Number of VPN servers (default: 1)
- `instance_type`: EC2 instance type (default: "t2.micro")
  > **Note**: `t2.micro` may not be available in all AWS regions. If you encounter availability issues, consider using `t3.micro` which offers better performance but may come with slightly higher costs. For example, `t2.micro` is not available in `eu-north-1`.
- `protocol`: X-Ray protocol to use - either "vmess" or "vless" (default: "vmess")
- `profile`: AWS CLI profile name (default: "xray_profile")

## Multiple Servers
To deploy multiple VPN servers, set `ec2_count` in your `terraform.tfvars`:
```bash
ec2_count = 3
```
Each server will have its own connection link in the output.

## Multiple Servers with Unique Subdomains
To deploy multiple VPN servers, set `ec2_count` in your `terraform.tfvars`:
```bash
ec2_count = 3
```
Each server will automatically be assigned a unique subdomain based on the `base_subdomain` variable. For example, if `base_subdomain` is set to `app`, the servers will use the subdomains `app1`, `app2`, and `app3`.

### Example Configuration
```bash
base_subdomain = "app"  # Base subdomain for VPN servers
ec2_count = 3           # Number of servers to deploy
```

After deployment, each server's connection link will be displayed in the output, using its unique subdomain.

## Protocol Selection
This project supports both VMESS and VLESS protocols:

### VMESS (Default)
- More widely supported by V2Ray clients
- Uses legacy protocol with additional encryption layer
- Recommended for maximum compatibility

### VLESS
- Newer, more efficient protocol
- Better performance with lower overhead
- Requires newer V2Ray/Xray clients

### Switching Protocols
To use VLESS instead of VMESS, add this line to your `terraform.tfvars`:
```bash
protocol = "vless"
```

The deployment will automatically generate the appropriate connection link (`vmess://` or `vless://`) based on your selection.

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
- Ensure your DuckDNS or Cloudflare credentials are correct
- Verify AWS credentials are properly configured
- Check AWS service quotas for EC2 instances
- DNS propagation may take a few minutes

## License
This project is licensed under the MIT License.

## Contributing
Pull requests are welcome. For major changes, please open an issue first.