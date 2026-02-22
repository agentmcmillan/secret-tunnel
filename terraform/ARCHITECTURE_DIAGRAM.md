# ZeroTeir Infrastructure Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud (us-east-1)                      │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                      VPC (Default)                            │ │
│  │                                                               │ │
│  │  ┌─────────────────────────────────────────────────────┐     │ │
│  │  │         EC2 Instance (t3.micro)                     │     │ │
│  │  │         Ubuntu 24.04 LTS                            │     │ │
│  │  │                                                     │     │ │
│  │  │  ┌──────────────────────────────────────┐          │     │ │
│  │  │  │      Headscale Control Server        │          │     │ │
│  │  │  │      - Port 8080 (HTTP)              │          │     │ │
│  │  │  │      - Port 50443 (gRPC)             │          │     │ │
│  │  │  │      - MagicDNS (100.64.0.0/10)      │          │     │ │
│  │  │  │      - DERP enabled                  │          │     │ │
│  │  │  └──────────────────────────────────────┘          │     │ │
│  │  │                     ▲                               │     │ │
│  │  │  ┌──────────────────┴───────────────────┐          │     │ │
│  │  │  │         Nginx Reverse Proxy          │          │     │ │
│  │  │  │         - Port 80 (HTTP)             │          │     │ │
│  │  │  │         - Port 443 (HTTPS)           │          │     │ │
│  │  │  │         - /health endpoint           │          │     │ │
│  │  │  └──────────────────────────────────────┘          │     │ │
│  │  │                                                     │     │ │
│  │  │  ┌──────────────────────────────────────┐          │     │ │
│  │  │  │         WireGuard VPN                │          │     │ │
│  │  │  │         - Port 51820/UDP             │          │     │ │
│  │  │  │         - Kernel module              │          │     │ │
│  │  │  └──────────────────────────────────────┘          │     │ │
│  │  │                                                     │     │ │
│  │  │  ┌──────────────────────────────────────┐          │     │ │
│  │  │  │      Security Features               │          │     │ │
│  │  │  │      - UFW Firewall                  │          │     │ │
│  │  │  │      - Fail2ban (SSH protection)     │          │     │ │
│  │  │  │      - iptables NAT                  │          │     │ │
│  │  │  │      - IP forwarding enabled         │          │     │ │
│  │  │  └──────────────────────────────────────┘          │     │ │
│  │  │                                                     │     │ │
│  │  │         Elastic IP: X.X.X.X (persistent)           │     │ │
│  │  │         EBS: 8GB gp3 (encrypted)                   │     │ │
│  │  │         State: Stopped (cost saving)               │     │ │
│  │  └─────────────────────────────────────────────────────┘     │ │
│  │                           ▲                                  │ │
│  │  ┌────────────────────────┴──────────────────────────────┐  │ │
│  │  │         Security Group: ZeroTeir-vpn-sg              │  │ │
│  │  │         - SSH: 22/TCP (from admin_ip)                │  │ │
│  │  │         - HTTPS: 443/TCP (0.0.0.0/0)                 │  │ │
│  │  │         - gRPC: 50443/TCP (0.0.0.0/0)                │  │ │
│  │  │         - WireGuard: 51820/UDP (0.0.0.0/0)           │  │ │
│  │  │         - HTTP: 80/TCP (0.0.0.0/0, Let's Encrypt)    │  │ │
│  │  │         - Egress: All traffic allowed                │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                   AWS Lambda Functions                        │ │
│  │                                                               │ │
│  │  ┌──────────────────────────────┐  ┌─────────────────────┐   │ │
│  │  │ Instance Control Lambda      │  │ Idle Monitor Lambda │   │ │
│  │  │ Runtime: Python 3.12         │  │ Runtime: Python 3.12│   │ │
│  │  │ Timeout: 60s                 │  │ Timeout: 60s        │   │ │
│  │  │                              │  │                     │   │ │
│  │  │ Functions:                   │  │ Functions:          │   │ │
│  │  │ - Start instance             │  │ - Check health      │   │ │
│  │  │ - Stop instance              │  │ - Count connections │   │ │
│  │  │ - Get status                 │  │ - Publish metrics   │   │ │
│  │  │                              │  │ - Auto-stop idle    │   │ │
│  │  └──────────────┬───────────────┘  └──────────▲──────────┘   │ │
│  │                 │                              │              │ │
│  │                 │                    ┌─────────┴──────────┐   │ │
│  │                 │                    │  EventBridge       │   │ │
│  │                 │                    │  Rate: 5 minutes   │   │ │
│  │                 │                    └────────────────────┘   │ │
│  └─────────────────┼──────────────────────────────────────────────┘ │
│                    │                                                │
│  ┌─────────────────┴──────────────────────────────────────────────┐ │
│  │              API Gateway (REST API)                            │ │
│  │                                                                │ │
│  │  Endpoints:                                                    │ │
│  │  - POST /instance/start   → Start VPN server                  │ │
│  │  - POST /instance/stop    → Stop VPN server                   │ │
│  │  - GET  /instance/status  → Get current state                 │ │
│  │                                                                │ │
│  │  Authentication: API Key (x-api-key header)                   │ │
│  │  Throttling: 10 req/s, burst 20                               │ │
│  │  CORS: Enabled for future web UI                              │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                      IAM Roles                                │ │
│  │                                                               │ │
│  │  ┌──────────────────────────────┐  ┌─────────────────────┐   │ │
│  │  │ Instance Control Role        │  │ Idle Monitor Role   │   │ │
│  │  │ - ec2:StartInstances         │  │ - ec2:StopInstances │   │ │
│  │  │ - ec2:StopInstances          │  │ - ec2:Describe*     │   │ │
│  │  │ - ec2:DescribeInstances      │  │ - cloudwatch:Put*   │   │ │
│  │  │ - logs:CreateLogGroup        │  │ - logs:CreateLog*   │   │ │
│  │  │ - logs:PutLogEvents          │  │ - logs:PutLogEvents │   │ │
│  │  │ (Scoped to specific instance)│  │ (Scoped resource)   │   │ │
│  │  └──────────────────────────────┘  └─────────────────────┘   │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                     CloudWatch                                │ │
│  │                                                               │ │
│  │  Log Groups:                                                  │ │
│  │  - /aws/lambda/ZeroTeir-instance-control (30-day retention)   │ │
│  │  - /aws/lambda/ZeroTeir-idle-monitor (30-day retention)       │ │
│  │                                                               │ │
│  │  Custom Metrics (namespace: ZeroTeir):                        │ │
│  │  - ActiveConnections (count of VPN clients)                   │ │
│  │  - InstanceState (0=stopped, 1=running)                       │ │
│  │                                                               │ │
│  │  Alarms:                                                      │ │
│  │  - Instance Running (state changes)                           │ │
│  │  - Active Connections (low connection alert)                  │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

                              ▲
                              │
                              │ HTTPS / API Calls
                              │
                   ┌──────────┴──────────┐
                   │                     │
          ┌────────┴────────┐   ┌────────┴────────┐
          │  macOS Client   │   │  Mobile Client  │
          │  (Future Epic)  │   │  (Future Epic)  │
          │                 │   │                 │
          │  - Menu bar UI  │   │  - iOS/Android  │
          │  - API client   │   │  - VPN control  │
          │  - Tailscale    │   │  - Tailscale    │
          └─────────────────┘   └─────────────────┘
```

## Data Flow Diagrams

### Start Instance Flow

```
User
  │
  │ 1. POST /instance/start + API key
  ▼
API Gateway
  │
  │ 2. Validate API key
  │ 3. Invoke Lambda
  ▼
Instance Control Lambda
  │
  │ 4. ec2:DescribeInstances (check current state)
  │ 5. ec2:StartInstances
  │ 6. Wait for "running" state (waiter pattern)
  │ 7. ec2:DescribeInstances (get public IP)
  ▼
Return Response
  │
  │ 8. JSON: { state: "running", publicIp: "X.X.X.X", ... }
  ▼
User receives confirmation
  │
  │ 9. Connect Tailscale client to Headscale URL
  ▼
VPN Connected
```

### Idle Monitor Flow

```
EventBridge (every 5 minutes)
  │
  │ 1. Trigger Lambda
  ▼
Idle Monitor Lambda
  │
  │ 2. ec2:DescribeInstances (get instance state)
  │
  ├─ If NOT running → Skip check, publish metrics
  │
  └─ If running:
     │
     │ 3. HTTP GET → http://ELASTIC_IP/health
     │
     ├─ If no response → 0 connections
     │
     └─ If responds:
        │
        │ 4. (Future) Query Headscale API for node list
        │ 5. Count nodes with lastSeen < 60 minutes
        │
        └─ If 0 active connections:
           │
           │ 6. ec2:StopInstances
           │ 7. cloudwatch:PutMetricData
           │
           ▼
        Instance Stopped (cost saving)
```

### VPN Connection Flow

```
Client Device
  │
  │ 1. tailscale up --login-server=https://ELASTIC_IP
  ▼
Headscale Server (EC2)
  │
  │ 2. Authenticate via pre-auth key or web flow
  │ 3. Assign IP from 100.64.0.0/10 range
  │ 4. Exchange WireGuard keys
  │ 5. Configure NAT traversal (DERP if needed)
  ▼
WireGuard Tunnel Established
  │
  │ 6. Encrypted traffic on port 51820/UDP
  │ 7. Routes traffic through VPN
  │ 8. Updates lastSeen timestamp
  ▼
Internet Access via VPN
  │
  │ 9. NAT masquerade via iptables
  │ 10. Firewall bypass achieved
  ▼
External Services (bypassing restrictive firewalls)
```

## Component Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                    Terraform Resources                      │
│                                                             │
│  main.tf                                                    │
│    ├─ aws_instance.vpn ←──────┐                            │
│    ├─ aws_eip.vpn              │                            │
│    ├─ aws_security_group.vpn   │ Dependencies               │
│    └─ aws_eip_association.vpn  │                            │
│                                 │                            │
│  lambda.tf                      │                            │
│    ├─ aws_lambda_function.instance_control                  │
│    │    └─ Needs: INSTANCE_ID ─┘                            │
│    ├─ aws_lambda_function.idle_monitor                      │
│    │    └─ Needs: INSTANCE_ID, HEADSCALE_URL                │
│    ├─ aws_api_gateway_rest_api                              │
│    ├─ aws_api_gateway_resources (x3)                        │
│    ├─ aws_api_gateway_methods (x3)                          │
│    ├─ aws_api_gateway_integrations (x3)                     │
│    ├─ aws_api_gateway_deployment                            │
│    ├─ aws_api_gateway_stage                                 │
│    ├─ aws_api_gateway_api_key                               │
│    ├─ aws_api_gateway_usage_plan                            │
│    ├─ aws_cloudwatch_event_rule                             │
│    └─ aws_cloudwatch_event_target                           │
│                                                             │
│  iam.tf                                                     │
│    ├─ aws_iam_role.instance_control_lambda                  │
│    ├─ aws_iam_role_policy.instance_control_lambda           │
│    ├─ aws_iam_role.idle_monitor_lambda                      │
│    └─ aws_iam_role_policy.idle_monitor_lambda               │
│                                                             │
│  cloudwatch.tf                                              │
│    ├─ aws_cloudwatch_log_group.instance_control             │
│    ├─ aws_cloudwatch_log_group.idle_monitor                 │
│    ├─ aws_cloudwatch_metric_alarm.instance_running          │
│    └─ aws_cloudwatch_metric_alarm.active_connections        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Resource Tags

All resources are tagged with:
- **Project**: ZeroTeir
- **Environment**: prod (configurable)
- **ManagedBy**: Terraform

Additional resource-specific tags:
- **Name**: Human-readable resource name

## Cost Breakdown

```
┌──────────────────────────┬──────────────┬────────────────┬──────────────┐
│ Resource                 │ Unit Cost    │ Usage          │ Monthly Cost │
├──────────────────────────┼──────────────┼────────────────┼──────────────┤
│ EC2 t3.micro             │ $0.0104/hour │ 72 hours (10%) │ $0.75        │
│ Elastic IP (unattached)  │ $0.005/hour  │ 648 hours (90%)│ $3.24        │
│ EBS gp3 8GB              │ $0.08/GB/mo  │ 8 GB           │ $0.64        │
│ Lambda (2 functions)     │ Free tier    │ < 1M requests  │ $0.00        │
│ API Gateway              │ Free tier    │ < 1M requests  │ $0.00        │
│ CloudWatch Logs          │ Free tier    │ < 5 GB/month   │ $0.00        │
│ Data Transfer            │ $0.09/GB     │ ~5 GB          │ $0.45        │
├──────────────────────────┴──────────────┴────────────────┼──────────────┤
│ TOTAL (with auto-stop)                                   │ ~$5.08/month │
└──────────────────────────────────────────────────────────┴──────────────┘

Note: Assumes 10% uptime (72 hours/month) with auto-stop enabled.
Running 24/7 would cost approximately $12/month (EC2 + EBS + Data Transfer).
```

## Security Layers

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Network (AWS Security Group)                      │
│   - Ingress filtering by port and protocol                 │
│   - SSH restricted to admin_ip only                        │
│   - WireGuard/HTTPS open for VPN clients                   │
└─────────────────────────────────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Host Firewall (UFW)                               │
│   - Additional filtering at instance level                 │
│   - Default deny, explicit allow rules                     │
└─────────────────────────────────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Application (Fail2ban)                            │
│   - Brute-force protection for SSH                         │
│   - Auto-ban after 5 failed attempts                       │
└─────────────────────────────────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: API Authentication (API Gateway)                  │
│   - API key required for all endpoints                     │
│   - Rate limiting (10 req/s, burst 20)                     │
└─────────────────────────────────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 5: IAM (Least Privilege)                             │
│   - Scoped permissions to specific resources               │
│   - No wildcard permissions                                │
│   - Separate roles for separate functions                  │
└─────────────────────────────────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 6: Data Encryption                                   │
│   - EBS volumes encrypted at rest                          │
│   - TLS for API Gateway (AWS managed)                      │
│   - WireGuard encryption in transit                        │
└─────────────────────────────────────────────────────────────┘
```

## Monitoring Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring Layers                        │
│                                                             │
│  Application Logs (CloudWatch Logs)                         │
│    ├─ Lambda execution logs (errors, warnings, info)        │
│    ├─ API Gateway access logs (requests, responses)         │
│    └─ Instance system logs (via CloudWatch agent - future)  │
│                                                             │
│  Custom Metrics (CloudWatch Metrics)                        │
│    ├─ ActiveConnections (VPN client count)                  │
│    ├─ InstanceState (running/stopped)                       │
│    └─ API latency (future enhancement)                      │
│                                                             │
│  Alarms (CloudWatch Alarms)                                 │
│    ├─ Instance state changes (info)                         │
│    ├─ No connections for 60 minutes (warning)               │
│    └─ Lambda errors (critical - future)                     │
│                                                             │
│  Health Checks                                              │
│    ├─ /health endpoint (Nginx → Headscale)                  │
│    ├─ EC2 instance status checks (AWS managed)              │
│    └─ Headscale service status (systemd)                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Flow

```
Developer Workstation
  │
  │ 1. terraform init
  │    └─ Download providers (AWS, Archive)
  │
  │ 2. terraform plan
  │    └─ Preview 30+ resources to create
  │
  │ 3. terraform apply
  ▼
Terraform Orchestration
  │
  ├─ Create IAM roles/policies
  │
  ├─ Create Security Group
  │
  ├─ Allocate Elastic IP
  │
  ├─ Package Lambda functions (zip)
  │
  ├─ Create Lambda functions
  │
  ├─ Create API Gateway
  │
  ├─ Create CloudWatch resources
  │
  ├─ Launch EC2 instance (stopped state)
  │  └─ Cloud-init executes on first boot
  │
  ├─ Associate Elastic IP
  │
  ├─ Create EventBridge rule
  │
  └─ Output configuration
     │
     │ - Elastic IP
     │ - API endpoint
     │ - API key (sensitive)
     │ - Usage instructions
     ▼
Infrastructure Ready

First Start (Manual or via API)
  │
  │ Instance boots and cloud-init runs:
  │
  ├─ Update system packages
  ├─ Install Headscale + WireGuard
  ├─ Configure network settings
  ├─ Setup firewall rules
  ├─ Start services
  └─ Create default namespace
     ▼
  VPN Server Ready for Clients
```

---

**Legend:**
- `→` HTTP/API Call
- `▼` Data/Control Flow
- `├─` Component/Step
- `└─` Sub-component/Final step
- `┌─` Container/Group start
- `└─` Container/Group end
