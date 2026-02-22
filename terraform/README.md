# ZeroTeir Terraform Infrastructure

This directory contains the complete Terraform infrastructure for the ZeroTeir on-demand VPN project.

## Overview

The infrastructure includes:
- **EC2 Instance**: Ubuntu 24.04 LTS server running Headscale + WireGuard
- **Elastic IP**: Static public IP for the VPN server
- **Security Groups**: Properly configured for SSH, HTTPS, gRPC, and WireGuard
- **Lambda Functions**:
  - Instance control API (start/stop/status)
  - Idle monitor for auto-stopping
- **API Gateway**: REST API with API key authentication
- **CloudWatch**: Logging, metrics, and alarms
- **EventBridge**: Scheduled idle monitoring

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** >= 1.6.0 installed
4. **SSH Key Pair** created in AWS EC2

## Quick Start

### 1. Configure Variables

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
vim terraform.tfvars
```

**Required variables:**
- `ssh_key_name`: Name of your AWS SSH key pair (must already exist)

**Recommended to customize:**
- `admin_ip`: Restrict SSH access to your IP (get it with `curl https://checkip.amazonaws.com`)
- `aws_region`: AWS region for deployment

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

Review the resources that will be created.

### 4. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted.

### 5. Get Your Configuration

```bash
# View all outputs
terraform output

# Get API key (sensitive)
terraform output -raw api_key

# Get usage instructions
terraform output -raw usage_instructions
```

## Architecture

### Resources Created

| Resource | Purpose | Cost Impact |
|----------|---------|-------------|
| EC2 t3.micro | VPN server | $0.0104/hour when running |
| Elastic IP | Static IP | $0.005/hour when not attached |
| EBS gp3 8GB | Storage | $0.08/month |
| Lambda Functions | Control & monitoring | Free tier eligible |
| API Gateway | REST API | Free tier eligible |
| CloudWatch Logs | Logging | 5GB/month free tier |

**Estimated Monthly Cost**: ~$3-5 (assuming 10-20% uptime)

### Security Features

- **Encrypted EBS volumes**
- **API Key authentication** for instance control
- **API Gateway throttling** to prevent abuse
- **Minimal IAM permissions** (scoped to specific resources)
- **UFW firewall** on the instance
- **Fail2ban** for SSH brute-force protection
- **Unattended security updates**

### Auto-Stop Feature

The idle monitor Lambda runs every 5 minutes and:
1. Checks if the instance is running
2. Queries Headscale for active connections
3. Stops the instance if no connections for 60 minutes
4. Publishes metrics to CloudWatch

## Usage

### Start the VPN

```bash
curl -X POST "$(terraform output -raw api_endpoint)/instance/start" \
  -H "x-api-key: $(terraform output -raw api_key)"
```

### Check Status

```bash
curl "$(terraform output -raw api_endpoint)/instance/status" \
  -H "x-api-key: $(terraform output -raw api_key)"
```

### Stop the VPN

```bash
curl -X POST "$(terraform output -raw api_endpoint)/instance/stop" \
  -H "x-api-key: $(terraform output -raw api_key)"
```

### SSH to Instance

```bash
# Wait for instance to be running, then:
ssh -i ~/.ssh/your-key.pem ubuntu@$(terraform output -raw elastic_ip)
```

### View Logs

```bash
# Instance control logs
aws logs tail "$(terraform output -raw log_group_instance_control)" --follow

# Idle monitor logs
aws logs tail "$(terraform output -raw log_group_idle_monitor)" --follow
```

### View Metrics

```bash
# CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace ZeroTeir \
  --metric-name ActiveConnections \
  --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
  --period 300 \
  --statistics Average
```

## Headscale Configuration

After the instance starts for the first time, cloud-init will:
1. Install Headscale and WireGuard
2. Configure Headscale with your Elastic IP
3. Create a default namespace
4. Start all services

### Create Headscale Auth Key

```bash
# SSH to the instance
ssh -i ~/.ssh/your-key.pem ubuntu@$(terraform output -raw elastic_ip)

# Create a pre-auth key
sudo headscale preauthkeys create --namespace default --expiration 24h

# Use this key to register clients
```

### Register Clients

On your client device:

```bash
# Install Tailscale client
# macOS: brew install tailscale
# Linux: See https://tailscale.com/download

# Register with your Headscale server
sudo tailscale up --login-server=$(terraform output -raw headscale_url) --authkey=YOUR_KEY
```

## Maintenance

### Update Headscale Version

1. Edit `terraform.tfvars`:
   ```
   headscale_version = "0.24.0"  # or newer
   ```

2. Taint the instance to force recreation:
   ```bash
   terraform taint aws_instance.vpn
   terraform apply
   ```

### View Cloud-Init Logs

```bash
# SSH to instance, then:
sudo tail -f /var/log/cloud-init-output.log
```

### Check Headscale Status

```bash
# SSH to instance, then:
sudo systemctl status headscale
sudo headscale nodes list
```

## Customization

### Use Custom Domain

Instead of the Elastic IP, you can use a custom domain:

1. Edit `terraform.tfvars`:
   ```
   headscale_domain = "vpn.example.com"
   ```

2. Create DNS A record pointing to the Elastic IP

3. Apply changes:
   ```bash
   terraform apply
   ```

4. SSH to instance and run certbot:
   ```bash
   sudo certbot --nginx -d vpn.example.com
   ```

### Adjust Auto-Stop Timeout

Edit `terraform.tfvars`:
```
idle_timeout_minutes = 120  # Stop after 2 hours
idle_check_rate_minutes = 10  # Check every 10 minutes
```

### Change Instance Type

For better performance:
```
instance_type = "t3.small"  # 2 vCPU, 2 GB RAM
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: The Elastic IP will be released and you'll get a new IP if you recreate.

## Troubleshooting

### Instance Won't Start

```bash
# Check CloudWatch logs
aws logs tail /aws/lambda/ZeroTeir-instance-control --follow

# Check instance status
aws ec2 describe-instances --instance-ids $(terraform output -raw instance_id)
```

### Can't Connect to Headscale

```bash
# Check security group
aws ec2 describe-security-groups --group-ids $(terraform show -json | jq -r '.values.root_module.resources[] | select(.type=="aws_security_group") | .values.id')

# Test connectivity
curl -v http://$(terraform output -raw elastic_ip)/health
```

### Auto-Stop Not Working

```bash
# Check idle monitor logs
aws logs tail /aws/lambda/ZeroTeir-idle-monitor --follow

# Check EventBridge rule
aws events list-rules --name-prefix ZeroTeir
```

## Files

- `main.tf` - EC2 instance, EIP, security groups
- `lambda.tf` - Lambda functions and API Gateway
- `cloudwatch.tf` - Logs, metrics, alarms
- `iam.tf` - IAM roles and policies
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `versions.tf` - Provider versions
- `files/cloud-init.yaml` - EC2 initialization
- `files/lambda_instance_control.py` - Instance control Lambda
- `files/lambda_idle_monitor.py` - Idle monitoring Lambda

## Support

For issues or questions:
1. Check the main project README
2. Review CloudWatch logs
3. Check AWS console for resource status
4. Open an issue on GitHub

## License

Same as parent project.
