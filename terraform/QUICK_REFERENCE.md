# ZeroTeir Quick Reference Card

## Essential Commands

### Initial Setup
```bash
# Copy configuration
cp terraform.tfvars.example terraform.tfvars

# Edit variables (SET YOUR SSH KEY!)
vim terraform.tfvars

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy infrastructure
terraform apply
```

### Get Configuration
```bash
# All outputs
terraform output

# Specific values
terraform output -raw elastic_ip
terraform output -raw api_endpoint
terraform output -raw api_key
terraform output -raw instance_id

# Usage instructions
terraform output -raw usage_instructions
```

### Instance Control (API)
```bash
# Set environment variables
export API_KEY=$(terraform output -raw api_key)
export API_ENDPOINT=$(terraform output -raw api_endpoint)

# Start instance
curl -X POST "$API_ENDPOINT/instance/start" \
  -H "x-api-key: $API_KEY"

# Check status
curl "$API_ENDPOINT/instance/status" \
  -H "x-api-key: $API_KEY"

# Stop instance
curl -X POST "$API_ENDPOINT/instance/stop" \
  -H "x-api-key: $API_KEY"
```

### SSH Access
```bash
# Get IP
export ELASTIC_IP=$(terraform output -raw elastic_ip)

# SSH to instance
ssh -i ~/.ssh/YOUR_KEY.pem ubuntu@$ELASTIC_IP

# One-liner (auto-start if needed)
curl -X POST "$(terraform output -raw api_endpoint)/instance/start" \
  -H "x-api-key: $(terraform output -raw api_key)" && \
  sleep 30 && \
  ssh -i ~/.ssh/YOUR_KEY.pem ubuntu@$(terraform output -raw elastic_ip)
```

### Headscale Operations
```bash
# Create pre-auth key
sudo headscale preauthkeys create --namespace default --expiration 24h

# List namespaces
sudo headscale namespaces list

# List nodes
sudo headscale nodes list

# Delete expired nodes
sudo headscale nodes expire --identifier <node-id>

# Check service status
sudo systemctl status headscale

# View logs
sudo journalctl -u headscale -f
```

### Client Registration
```bash
# Install Tailscale client first
# macOS: brew install tailscale
# Linux: curl -fsSL https://tailscale.com/install.sh | sh

# Get Headscale URL
export HEADSCALE_URL=$(terraform output -raw headscale_url)

# Register client
sudo tailscale up \
  --login-server=$HEADSCALE_URL \
  --authkey=YOUR_PREAUTH_KEY

# Check status
tailscale status

# Get assigned IP
tailscale ip

# Ping other clients
ping 100.64.x.x
```

### CloudWatch Monitoring
```bash
# View instance control logs
aws logs tail /aws/lambda/ZeroTeir-instance-control --follow

# View idle monitor logs
aws logs tail /aws/lambda/ZeroTeir-idle-monitor --follow

# Get metrics
aws cloudwatch get-metric-statistics \
  --namespace ZeroTeir \
  --metric-name ActiveConnections \
  --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
  --period 300 \
  --statistics Average

# List alarms
aws cloudwatch describe-alarms --alarm-name-prefix ZeroTeir
```

### Troubleshooting
```bash
# Check cloud-init status
ssh ubuntu@$ELASTIC_IP 'sudo cloud-init status'

# View cloud-init logs
ssh ubuntu@$ELASTIC_IP 'sudo tail -100 /var/log/cloud-init-output.log'

# Test Headscale health
curl http://$(terraform output -raw elastic_ip)/health

# Check security group
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=ZeroTeir-vpn-sg"

# Check instance state
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw instance_id)

# View recent API calls
aws logs tail /aws/lambda/ZeroTeir-instance-control --since 1h

# Test API without starting
curl "$(terraform output -raw api_endpoint)/instance/status" \
  -H "x-api-key: $(terraform output -raw api_key)" | jq
```

### Maintenance
```bash
# Update infrastructure
terraform plan
terraform apply

# Taint resource for recreation
terraform taint aws_instance.vpn
terraform apply

# Refresh state
terraform refresh

# Show current state
terraform show

# Format Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate
```

### Backup & Restore
```bash
# Backup Terraform state
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d)

# Backup Headscale database
ssh ubuntu@$ELASTIC_IP \
  'sudo cp /var/lib/headscale/db.sqlite /tmp/db.sqlite && \
   sudo chown ubuntu /tmp/db.sqlite'
scp -i ~/.ssh/YOUR_KEY.pem \
  ubuntu@$ELASTIC_IP:/tmp/db.sqlite \
  headscale-backup-$(date +%Y%m%d).sqlite

# Backup API key
terraform output -raw api_key > api_key.secret
chmod 600 api_key.secret
```

### Cost Management
```bash
# Check if instance is running
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[0].Instances[0].State.Name'

# Manual stop (cost saving)
curl -X POST "$(terraform output -raw api_endpoint)/instance/stop" \
  -H "x-api-key: $(terraform output -raw api_key)"

# Check auto-stop is working
aws logs tail /aws/lambda/ZeroTeir-idle-monitor --since 30m | grep -i stop
```

### Cleanup
```bash
# Destroy all infrastructure
terraform destroy

# Destroy specific resource
terraform destroy -target=aws_instance.vpn

# Remove Terraform state (CAREFUL!)
rm -rf .terraform terraform.tfstate*
```

## File Locations on Instance

| Path | Description |
|------|-------------|
| `/etc/headscale/config.yaml` | Headscale configuration |
| `/etc/headscale/acl.yaml` | ACL policy |
| `/var/lib/headscale/db.sqlite` | Headscale database |
| `/var/log/cloud-init-output.log` | Cloud-init execution log |
| `/var/log/auth.log` | SSH authentication logs |
| `/etc/nginx/sites-available/headscale` | Nginx config |
| `/etc/systemd/system/headscale.service` | Systemd service |

## Port Reference

| Port | Protocol | Service | Access |
|------|----------|---------|--------|
| 22 | TCP | SSH | Admin IP only |
| 80 | TCP | HTTP (Nginx) | All (Let's Encrypt) |
| 443 | TCP | HTTPS (Nginx) | All (Headscale) |
| 50443 | TCP | gRPC | All (Headscale control) |
| 51820 | UDP | WireGuard | All (VPN data) |
| 3478 | UDP | STUN | All (NAT traversal) |
| 8080 | TCP | Headscale | Localhost only |
| 9090 | TCP | Metrics | Localhost only |

## Environment Variables Template

```bash
# Save to ~/.zshrc or ~/.bashrc for convenience

# Terraform
export TF_VAR_ssh_key_name="your-key-name"
export TF_VAR_admin_ip="YOUR_IP/32"

# API Access
export ZEROTEIR_API_KEY="your-api-key-here"
export ZEROTEIR_API_ENDPOINT="https://xxxxx.execute-api.us-east-1.amazonaws.com/prod"
export ZEROTEIR_ELASTIC_IP="X.X.X.X"

# Aliases
alias vpn-start='curl -X POST "$ZEROTEIR_API_ENDPOINT/instance/start" -H "x-api-key: $ZEROTEIR_API_KEY"'
alias vpn-stop='curl -X POST "$ZEROTEIR_API_ENDPOINT/instance/stop" -H "x-api-key: $ZEROTEIR_API_KEY"'
alias vpn-status='curl "$ZEROTEIR_API_ENDPOINT/instance/status" -H "x-api-key: $ZEROTEIR_API_KEY" | jq'
alias vpn-ssh='ssh -i ~/.ssh/YOUR_KEY.pem ubuntu@$ZEROTEIR_ELASTIC_IP'
alias vpn-logs='aws logs tail /aws/lambda/ZeroTeir-instance-control --follow'
```

## Terraform Variable Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | us-east-1 | AWS region |
| `instance_type` | t3.micro | EC2 instance type |
| `root_volume_size` | 8 | EBS volume size (GB) |
| `ssh_key_name` | REQUIRED | AWS SSH key name |
| `admin_ip` | 0.0.0.0/0 | IP allowed SSH access |
| `headscale_version` | 0.23.0 | Headscale version |
| `idle_timeout_minutes` | 60 | Auto-stop timeout |
| `idle_check_rate_minutes` | 5 | Check frequency |
| `log_retention_days` | 30 | CloudWatch log retention |
| `api_throttle_rate_limit` | 10 | API req/sec |
| `api_throttle_burst_limit` | 20 | API burst capacity |

## Common Issues & Solutions

### Issue: Instance won't start
```bash
# Check CloudWatch logs
aws logs tail /aws/lambda/ZeroTeir-instance-control --since 10m

# Check instance limits
aws ec2 describe-account-attributes --attribute-names max-instances

# Try manual start
aws ec2 start-instances --instance-ids $(terraform output -raw instance_id)
```

### Issue: Can't SSH to instance
```bash
# Verify instance is running
curl "$API_ENDPOINT/instance/status" -H "x-api-key: $API_KEY" | jq .state

# Check security group allows your IP
curl https://checkip.amazonaws.com
# Update terraform.tfvars with your IP and apply

# Verify SSH key
ssh-keygen -y -f ~/.ssh/YOUR_KEY.pem
```

### Issue: Headscale not accessible
```bash
# Check if cloud-init finished
ssh ubuntu@$ELASTIC_IP 'sudo cloud-init status'

# Check Headscale service
ssh ubuntu@$ELASTIC_IP 'sudo systemctl status headscale'

# Check Nginx
ssh ubuntu@$ELASTIC_IP 'sudo systemctl status nginx'

# Test locally first
ssh ubuntu@$ELASTIC_IP 'curl http://localhost:8080/health'
```

### Issue: Auto-stop not working
```bash
# Check EventBridge rule
aws events list-rules --name-prefix ZeroTeir

# Check idle monitor logs
aws logs tail /aws/lambda/ZeroTeir-idle-monitor --follow

# Test idle monitor manually
aws lambda invoke \
  --function-name ZeroTeir-idle-monitor \
  --payload '{}' \
  response.json && cat response.json
```

### Issue: API key not working
```bash
# Verify key
terraform output -raw api_key

# Test with verbose output
curl -v "$API_ENDPOINT/instance/status" \
  -H "x-api-key: $(terraform output -raw api_key)"

# Regenerate key
terraform taint aws_api_gateway_api_key.instance_control
terraform apply
```

## Security Checklist

- [ ] Changed `admin_ip` from 0.0.0.0/0 to specific IP
- [ ] API key saved in password manager
- [ ] Terraform state backed up
- [ ] SSH key stored securely
- [ ] CloudTrail enabled for audit logging
- [ ] MFA enabled on AWS account
- [ ] API Gateway throttling configured
- [ ] CloudWatch alarms configured
- [ ] Regular security updates enabled (unattended-upgrades)
- [ ] Fail2ban enabled and configured

## Cost Optimization Checklist

- [ ] Auto-stop enabled (idle_timeout_minutes configured)
- [ ] Instance stops when idle
- [ ] Using t3.micro (cheapest suitable instance)
- [ ] EBS volume sized appropriately (8GB)
- [ ] CloudWatch logs retention set (30 days)
- [ ] No unnecessary data transfer
- [ ] Elastic IP associated when instance running
- [ ] Monitoring costs in AWS billing dashboard

## Daily Operations

**Morning (if using VPN for work):**
```bash
vpn-start  # Start instance
sleep 30   # Wait for boot
vpn-status # Verify running
sudo tailscale up --login-server=$(terraform output -raw headscale_url)
```

**Evening (end of day):**
```bash
sudo tailscale down  # Disconnect VPN
vpn-stop            # Stop instance (or let auto-stop handle it)
```

**Weekly:**
```bash
# Check costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost

# Check logs for errors
vpn-logs | grep -i error

# Verify auto-stop working
aws logs tail /aws/lambda/ZeroTeir-idle-monitor --since 1w | grep stopped
```

**Monthly:**
```bash
# Backup Headscale database
# Review security group rules
# Check for Headscale updates
# Review CloudWatch metrics
# Verify API key hasn't leaked
```

---

**For full documentation, see:**
- README.md - Complete guide
- DEPLOYMENT_CHECKLIST.md - Step-by-step deployment
- ARCHITECTURE_DIAGRAM.md - Visual diagrams
- IMPLEMENTATION_SUMMARY.md - Technical details
