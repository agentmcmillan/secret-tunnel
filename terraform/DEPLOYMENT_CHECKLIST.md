# ZeroTeir Terraform Deployment Checklist

This checklist ensures a successful deployment of the ZeroTeir infrastructure.

## Pre-Deployment

### AWS Prerequisites
- [ ] AWS account with billing enabled
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Appropriate IAM permissions for EC2, Lambda, API Gateway, CloudWatch
- [ ] SSH key pair created in target AWS region

### Local Prerequisites
- [ ] Terraform >= 1.6.0 installed (`terraform --version`)
- [ ] Git repository cloned
- [ ] Navigate to terraform directory: `cd terraform/`

## Configuration

### Required Variables
- [ ] Copy example config: `cp terraform.tfvars.example terraform.tfvars`
- [ ] Set `ssh_key_name` to your AWS SSH key pair name
- [ ] Set `admin_ip` to your public IP (recommended) or keep as 0.0.0.0/0
- [ ] Review and adjust `aws_region` if needed
- [ ] Review other variables in `terraform.tfvars`

### Security Review
- [ ] Confirmed `admin_ip` is restricted (not 0.0.0.0/0)
- [ ] Confirmed SSH key exists in AWS
- [ ] Reviewed API Gateway throttling limits
- [ ] Understand auto-stop timeout settings

## Deployment

### Initialize
```bash
terraform init
```

Expected output:
- [ ] Providers downloaded successfully
- [ ] Terraform initialized successfully

### Validate
```bash
terraform validate
```

Expected output:
- [ ] Configuration is valid

### Plan
```bash
terraform plan -out=tfplan
```

Review the plan:
- [ ] ~30-35 resources to be created
- [ ] No unexpected resource changes
- [ ] No errors or warnings
- [ ] EC2 instance configuration looks correct
- [ ] Security group rules are appropriate
- [ ] Lambda functions configured properly

### Apply
```bash
terraform apply tfplan
```

Monitor output:
- [ ] All resources created successfully
- [ ] No errors during creation
- [ ] Outputs displayed correctly

**Expected Duration**: 2-3 minutes

## Post-Deployment Verification

### Retrieve Outputs
```bash
# View all outputs
terraform output

# Specific outputs
terraform output -raw elastic_ip
terraform output -raw api_endpoint
terraform output -raw api_key
terraform output -raw instance_id
```

Verify:
- [ ] Elastic IP is valid
- [ ] API endpoint URL is accessible
- [ ] API key is present (store securely!)
- [ ] Instance ID matches AWS console

### Test Instance Control API

#### Check Status
```bash
API_KEY=$(terraform output -raw api_key)
API_ENDPOINT=$(terraform output -raw api_endpoint)

curl "$API_ENDPOINT/instance/status" \
  -H "x-api-key: $API_KEY"
```

Expected:
- [ ] HTTP 200 response
- [ ] JSON with instance state (likely "stopped" initially)

#### Start Instance
```bash
curl -X POST "$API_ENDPOINT/instance/start" \
  -H "x-api-key: $API_KEY"
```

Expected:
- [ ] HTTP 200 response
- [ ] Instance starts successfully
- [ ] Public IP returned in response

**Wait Time**: 30-60 seconds for instance to start

#### Verify Instance Running
```bash
curl "$API_ENDPOINT/instance/status" \
  -H "x-api-key: $API_KEY"
```

Expected:
- [ ] State is "running"
- [ ] publicIp matches Elastic IP
- [ ] launchTime is recent

### Test SSH Access
```bash
ELASTIC_IP=$(terraform output -raw elastic_ip)
ssh -i ~/.ssh/YOUR_KEY.pem ubuntu@$ELASTIC_IP
```

Expected:
- [ ] SSH connection successful
- [ ] Ubuntu 24.04 LTS welcome message

### Verify Cloud-Init Completion
```bash
# On the instance
sudo cloud-init status
```

Expected:
- [ ] Status: done
- [ ] No errors

```bash
# Check cloud-init log
sudo tail -100 /var/log/cloud-init-output.log
```

Verify:
- [ ] Headscale installed
- [ ] WireGuard installed
- [ ] Services started
- [ ] Completion message present

### Verify Headscale
```bash
# On the instance
sudo systemctl status headscale
```

Expected:
- [ ] Service active (running)
- [ ] No errors in logs

```bash
# Test Headscale CLI
sudo headscale namespaces list
```

Expected:
- [ ] "default" namespace exists

```bash
# Test Headscale API
curl http://localhost:8080/health
```

Expected:
- [ ] "healthy" response

### Test from Public Internet
```bash
# From your local machine
ELASTIC_IP=$(terraform output -raw elastic_ip)
curl http://$ELASTIC_IP/health
```

Expected:
- [ ] "healthy" response (proxied through Nginx)

### Verify CloudWatch Logs

#### Instance Control Lambda
```bash
aws logs tail /aws/lambda/ZeroTeir-instance-control --since 10m
```

Expected:
- [ ] Log group exists
- [ ] Logs from recent API calls visible

#### Idle Monitor Lambda
```bash
aws logs tail /aws/lambda/ZeroTeir-idle-monitor --since 10m
```

Expected:
- [ ] Log group exists
- [ ] EventBridge is triggering Lambda every 5 minutes
- [ ] No errors in logs

### Verify CloudWatch Metrics
```bash
aws cloudwatch list-metrics --namespace ZeroTeir
```

Expected:
- [ ] ActiveConnections metric exists
- [ ] InstanceState metric exists

### Test Auto-Stop (Optional)

**WARNING**: This will stop your instance after idle timeout

1. Wait for idle timeout (default: 60 minutes)
2. Ensure no Headscale clients connected
3. Check logs:
   ```bash
   aws logs tail /aws/lambda/ZeroTeir-idle-monitor --follow
   ```

Expected:
- [ ] Lambda detects 0 active connections
- [ ] Instance stopped automatically
- [ ] CloudWatch metrics updated

## Headscale Client Setup

### Create Pre-Auth Key
```bash
# SSH to instance
ssh -i ~/.ssh/YOUR_KEY.pem ubuntu@$(terraform output -raw elastic_ip)

# Create auth key
sudo headscale preauthkeys create --namespace default --expiration 24h
```

Expected:
- [ ] Pre-auth key generated
- [ ] Save key securely

### Register Client
```bash
# On client device (install Tailscale first)
HEADSCALE_URL=$(terraform output -raw headscale_url)

sudo tailscale up \
  --login-server=$HEADSCALE_URL \
  --authkey=YOUR_PREAUTH_KEY
```

Expected:
- [ ] Client registers successfully
- [ ] Client receives 100.64.x.x IP
- [ ] Can ping other clients

### Verify Client Connection
```bash
# On instance
sudo headscale nodes list
```

Expected:
- [ ] Client appears in node list
- [ ] Status shows as "connected"

## Cost Verification

### Check AWS Billing Dashboard
- [ ] Navigate to AWS Billing Dashboard
- [ ] Confirm resources are within expected costs
- [ ] Set up billing alerts if not already configured

### Expected Monthly Costs
- EC2 t3.micro (20% uptime): ~$1.50
- Elastic IP (when detached): ~$3.60
- EBS 8GB gp3: ~$0.08
- Lambda (free tier): $0
- API Gateway (free tier): $0
- CloudWatch Logs (< 5GB): $0

**Total Expected**: $3-5/month

## Security Hardening (Optional)

### Restrict Admin IP
- [ ] Update `terraform.tfvars` with your specific IP
- [ ] Run `terraform apply` to update security group

### Enable AWS CloudTrail
- [ ] Enable CloudTrail for API audit logging
- [ ] Review recent API calls

### Rotate API Key
```bash
# Taint and recreate API key
terraform taint aws_api_gateway_api_key.instance_control
terraform apply
```

### Configure Custom Domain (Optional)
1. [ ] Purchase/configure domain
2. [ ] Set `headscale_domain` in `terraform.tfvars`
3. [ ] Apply changes: `terraform apply`
4. [ ] Create DNS A record
5. [ ] SSH to instance and run certbot for HTTPS

## Backup Critical Data

### Save Configuration
```bash
# Backup terraform state (CRITICAL!)
cp terraform.tfstate terraform.tfstate.backup

# Save outputs
terraform output > outputs.txt
terraform output -raw api_key > api_key.secret
chmod 600 api_key.secret

# Save tfvars
cp terraform.tfvars terraform.tfvars.backup
```

Store securely:
- [ ] `terraform.tfstate` backed up
- [ ] API key saved securely
- [ ] Configuration variables documented

### Headscale Database Backup
```bash
# On instance
sudo cp /var/lib/headscale/db.sqlite /home/ubuntu/headscale-backup.sqlite
sudo chown ubuntu:ubuntu /home/ubuntu/headscale-backup.sqlite

# Download to local
scp -i ~/.ssh/YOUR_KEY.pem ubuntu@$ELASTIC_IP:headscale-backup.sqlite .
```

- [ ] Database backup created
- [ ] Backup downloaded locally

## Monitoring Setup

### CloudWatch Alarms
- [ ] Verify alarm for instance state exists
- [ ] Verify alarm for active connections exists
- [ ] Configure SNS notifications (optional)

### Log Retention
- [ ] Confirm log retention set to 30 days
- [ ] Adjust if needed for compliance

## Documentation

### Update Project Docs
- [ ] Document Elastic IP in project README
- [ ] Document API endpoint
- [ ] Save API key in password manager
- [ ] Update team documentation with access instructions

### Create Runbook
- [ ] Document common operations
- [ ] Document troubleshooting steps
- [ ] Document emergency procedures

## Troubleshooting

If any step fails, check:

### Terraform Errors
- [ ] AWS credentials valid (`aws sts get-caller-identity`)
- [ ] SSH key exists in correct region
- [ ] IAM permissions sufficient
- [ ] No resource name conflicts

### Instance Won't Start
- [ ] Check CloudWatch logs
- [ ] Verify security group rules
- [ ] Check AWS service health dashboard
- [ ] Try manual start from AWS console

### Can't Connect to Instance
- [ ] Verify instance is running
- [ ] Check security group allows your IP
- [ ] Verify SSH key is correct
- [ ] Try AWS Session Manager as alternative

### Headscale Not Working
- [ ] Check cloud-init logs
- [ ] Verify Headscale service status
- [ ] Check Nginx configuration
- [ ] Test localhost connectivity first

### Auto-Stop Not Working
- [ ] Check EventBridge rule enabled
- [ ] Review idle monitor logs
- [ ] Verify IAM permissions
- [ ] Check metric publishing

## Cleanup (If Testing)

To destroy everything:
```bash
terraform destroy
```

Confirm:
- [ ] All resources destroyed
- [ ] Elastic IP released
- [ ] CloudWatch logs deleted (if configured)
- [ ] No unexpected charges

## Completion

- [ ] All checklist items completed
- [ ] Infrastructure deployed successfully
- [ ] Headscale operational
- [ ] Clients can connect
- [ ] Monitoring configured
- [ ] Backups created
- [ ] Documentation updated

**Date Completed**: _______________
**Deployed By**: _______________
**Notes**: _______________

---

## Quick Reference

### Important URLs
- AWS Console: https://console.aws.amazon.com
- Elastic IP: `terraform output -raw elastic_ip`
- API Endpoint: `terraform output -raw api_endpoint`
- Headscale URL: `terraform output -raw headscale_url`

### Important Commands
```bash
# Start instance
curl -X POST "$(terraform output -raw api_endpoint)/instance/start" -H "x-api-key: $(terraform output -raw api_key)"

# Check status
curl "$(terraform output -raw api_endpoint)/instance/status" -H "x-api-key: $(terraform output -raw api_key)"

# SSH to instance
ssh -i ~/.ssh/YOUR_KEY.pem ubuntu@$(terraform output -raw elastic_ip)

# View logs
aws logs tail /aws/lambda/ZeroTeir-instance-control --follow

# Update infrastructure
terraform plan && terraform apply
```
