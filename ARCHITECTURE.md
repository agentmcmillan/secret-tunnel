# ZeroTeir Architecture Documentation

**Version**: 1.0
**Date**: 2026-02-21

---

## 1. System Overview

ZeroTeir is a three-tier architecture consisting of:
1. **macOS Client Application** (Swift/SwiftUI menu bar app)
2. **AWS Serverless Control Plane** (Lambda + API Gateway)
3. **AWS VPN Server** (EC2 + Headscale + WireGuard)

The system is designed for **on-demand operation**: the VPN server (EC2 instance) only runs when actively in use, minimizing costs while maintaining a persistent Elastic IP.

---

## 2. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                  User                                        │
│                                    │                                         │
│                                    │ Clicks "Connect"                        │
│                                    ▼                                         │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                      macOS Menu Bar Application                        │  │
│  │                                                                         │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │                     UI Layer (SwiftUI)                           │  │  │
│  │  │                                                                   │  │  │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │  │  │
│  │  │  │ MenuBarView  │  │ SettingsView │  │ StatusView (metrics) │  │  │  │
│  │  │  │ - Icon       │  │ - AWS config │  │ - Public IP          │  │  │  │
│  │  │  │ - Dropdown   │  │ - Headscale  │  │ - Latency            │  │  │  │
│  │  │  │ - Connect/   │  │ - Keychain   │  │ - Data transfer      │  │  │  │
│  │  │  │   Disconnect │  │   storage    │  │ - Uptime             │  │  │  │
│  │  │  └──────────────┘  └──────────────┘  └──────────────────────┘  │  │  │
│  │  └───────────────────────────┬─────────────────────────────────────┘  │  │
│  │                              │                                         │  │
│  │  ┌───────────────────────────▼─────────────────────────────────────┐  │  │
│  │  │              Application State Machine                          │  │  │
│  │  │                                                                   │  │  │
│  │  │  States: DISCONNECTED → STARTING_INSTANCE →                     │  │  │
│  │  │          WAITING_HEADSCALE → CONNECTING_TUNNEL →                │  │  │
│  │  │          CONNECTED → DISCONNECTING → DISCONNECTED               │  │  │
│  │  │                                                                   │  │  │
│  │  │  - ConnectionService: Orchestrates state transitions            │  │  │
│  │  └───────────────────────────┬─────────────────────────────────────┘  │  │
│  │                              │                                         │  │
│  │  ┌───────────────────────────▼─────────────────────────────────────┐  │  │
│  │  │                    Service Layer                                 │  │  │
│  │  │                                                                   │  │  │
│  │  │  ┌──────────────────┐ ┌──────────────────┐ ┌─────────────────┐ │  │  │
│  │  │  │ InstanceManager  │ │ HeadscaleClient  │ │ TunnelManager   │ │  │  │
│  │  │  │                  │ │                  │ │                 │ │  │  │
│  │  │  │ - start()        │ │ - register()     │ │ - connect()     │ │  │  │
│  │  │  │ - stop()         │ │ - getConfig()    │ │ - disconnect()  │ │  │  │
│  │  │  │ - getStatus()    │ │ - getStatus()    │ │ - getStats()    │ │  │  │
│  │  │  └────────┬─────────┘ └────────┬─────────┘ └────────┬────────┘ │  │  │
│  │  │           │                    │                    │          │  │  │
│  │  │  ┌────────▼────────────────────▼────────────────────▼────────┐ │  │  │
│  │  │  │             KeychainService (Secure Storage)             │ │  │  │
│  │  │  │  - Lambda API key                                         │ │  │  │
│  │  │  │  - Headscale API key                                      │ │  │  │
│  │  │  │  - WireGuard private key                                  │ │  │  │
│  │  │  │  - Machine ID                                             │ │  │  │
│  │  │  └───────────────────────────────────────────────────────────┘ │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  │                              │                                         │  │
│  │  ┌───────────────────────────▼─────────────────────────────────────┐  │  │
│  │  │                    Network Layer                                 │  │  │
│  │  │                                                                   │  │  │
│  │  │  ┌──────────────────────────────┐  ┌────────────────────────┐  │  │  │
│  │  │  │    WireGuardKit Library      │  │    URLSession          │  │  │  │
│  │  │  │  - Creates utun interface    │  │  - HTTP/HTTPS client   │  │  │  │
│  │  │  │  - Manages WireGuard tunnel  │  │  - Lambda API calls    │  │  │  │
│  │  │  │  - Collects statistics       │  │  - Headscale API calls │  │  │  │
│  │  │  └──────────────────────────────┘  └────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        │ ① Lambda API              │ ② Headscale API           │ ③ WireGuard
        │ HTTPS (Port 443)          │ HTTPS (Port 443)          │ UDP (Port 51820)
        │                           │                           │
        ▼                           │                           │
┌─────────────────────────────────────────────────────────────────────────────┐
│                             AWS Infrastructure                               │
│  Region: us-east-1 (configurable)                                            │
│                                                                               │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                     Control Plane (Serverless)                          │ │
│  │                                                                          │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │                        API Gateway (REST API)                     │  │ │
│  │  │                                                                    │  │ │
│  │  │  Endpoints:                                                        │  │ │
│  │  │  - POST   /instance/start   → Start EC2 instance                  │  │ │
│  │  │  - POST   /instance/stop    → Stop EC2 instance                   │  │ │
│  │  │  - GET    /instance/status  → Get instance state + IP             │  │ │
│  │  │                                                                    │  │ │
│  │  │  Authentication: API Key (x-api-key header)                       │  │ │
│  │  │  Throttling: 10 requests/second (burst: 20)                       │  │ │
│  │  └──────────────────────────────┬───────────────────────────────────┘  │ │
│  │                                 │                                       │ │
│  │  ┌──────────────────────────────▼───────────────────────────────────┐  │ │
│  │  │                    Lambda Functions (Python 3.12)                 │  │ │
│  │  │                                                                    │  │ │
│  │  │  1. InstanceControlHandler                                        │  │ │
│  │  │     - Receives API Gateway requests                               │  │ │
│  │  │     - Calls EC2 API (boto3):                                      │  │ │
│  │  │       * ec2.start_instances(InstanceIds=[...])                    │  │ │
│  │  │       * ec2.stop_instances(InstanceIds=[...])                     │  │ │
│  │  │       * ec2.describe_instances(InstanceIds=[...])                 │  │ │
│  │  │     - Returns JSON response with instance state                   │  │ │
│  │  │                                                                    │  │ │
│  │  │  2. IdleMonitorHandler (triggered by EventBridge every 5 min)    │  │ │
│  │  │     - Queries Headscale API for active connections               │  │ │
│  │  │     - If all machines idle > 60 minutes:                          │  │ │
│  │  │       * Stops EC2 instance                                        │  │ │
│  │  │       * Publishes CloudWatch metric                               │  │ │
│  │  │       * (Optional) Sends SNS notification                         │  │ │
│  │  │                                                                    │  │ │
│  │  │  IAM Role Permissions (least privilege):                          │  │ │
│  │  │  - ec2:StartInstances (specific instance ID)                      │  │ │
│  │  │  - ec2:StopInstances (specific instance ID)                       │  │ │
│  │  │  - ec2:DescribeInstances (specific instance ID)                   │  │ │
│  │  │  - logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents   │  │ │
│  │  │  - cloudwatch:PutMetricData                                       │  │ │
│  │  └────────────────────────────────────────────────────────────────────  │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                    EventBridge (CloudWatch Events)                      │ │
│  │                                                                          │ │
│  │  Rule: IdleCheckSchedule                                                │ │
│  │  - Schedule: rate(5 minutes)                                            │ │
│  │  - Target: IdleMonitorHandler Lambda                                    │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                  Data Plane (VPN Server - EC2)                          │ │
│  │                                                                          │ │
│  │  Instance Type: t3.micro (2 vCPU, 1 GB RAM)                            │ │
│  │  OS: Ubuntu 24.04 LTS (ami-0c55b159cbfafe1f0)                          │ │
│  │  Elastic IP: X.X.X.X (persistent, static)                              │ │
│  │                                                                          │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │                      Headscale Server                             │  │ │
│  │  │                                                                    │  │ │
│  │  │  - Version: Latest stable (installed via cloud-init)             │  │ │
│  │  │  - Config: /etc/headscale/config.yaml                            │  │ │
│  │  │  - Ports:                                                          │  │ │
│  │  │    * 443 (HTTPS) - API + web UI                                   │  │ │
│  │  │    * 8080 (HTTP) - Metrics (internal only)                        │  │ │
│  │  │                                                                    │  │ │
│  │  │  Key Features:                                                     │  │ │
│  │  │  - Machine registration & key management                          │  │ │
│  │  │  - MagicDNS (100.64.0.0/10 subnet)                                │  │ │
│  │  │  - ACLs (access control between nodes)                            │  │ │
│  │  │  - DERP relay (fallback when direct connection fails)             │  │ │
│  │  │                                                                    │  │ │
│  │  │  SSL Certificate: Let's Encrypt (auto-renewed via certbot)       │  │ │
│  │  │                                                                    │  │ │
│  │  │  API Endpoints (used by macOS app):                               │  │ │
│  │  │  - POST   /api/v1/machine/register                                │  │ │
│  │  │  - GET    /api/v1/machine                                         │  │ │
│  │  │  - GET    /api/v1/machine/{id}                                    │  │ │
│  │  │  - DELETE /api/v1/machine/{id}                                    │  │ │
│  │  │  - GET    /health                                                 │  │ │
│  │  └────────────────────────────────────────────────────────────────────  │ │
│  │                                                                          │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │                   WireGuard VPN Endpoint                          │  │ │
│  │  │                                                                    │  │ │
│  │  │  - Port: 51820/UDP                                                │  │ │
│  │  │  - Interface: wg0                                                 │  │ │
│  │  │  - Subnet: 100.64.0.0/10 (Headscale MagicDNS range)              │  │ │
│  │  │  - Server IP: 100.64.0.1                                          │  │ │
│  │  │                                                                    │  │ │
│  │  │  Kernel Module: wireguard (built into Ubuntu 24.04)              │  │ │
│  │  │  Configuration: Managed by Headscale                              │  │ │
│  │  │                                                                    │  │ │
│  │  │  Features:                                                         │  │ │
│  │  │  - NAT traversal (STUN-like behavior via Headscale)              │  │ │
│  │  │  - Peer discovery (coordinated by Headscale)                      │  │ │
│  │  │  - IP forwarding (routes client traffic to internet)              │  │ │
│  │  └────────────────────────────────────────────────────────────────────  │ │
│  │                                                                          │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │                      System Services                              │  │ │
│  │  │                                                                    │  │ │
│  │  │  - systemd: Manages Headscale service                             │  │ │
│  │  │  - iptables: NAT and firewall rules                               │  │ │
│  │  │  - fail2ban: Brute-force protection for SSH                       │  │ │
│  │  │  - unattended-upgrades: Automatic security updates                │  │ │
│  │  │  - CloudWatch Agent: Logs and metrics to CloudWatch               │  │ │
│  │  └────────────────────────────────────────────────────────────────────  │ │
│  │                                                                          │ │
│  │  Security Group Rules:                                                  │ │
│  │  - Ingress:                                                             │ │
│  │    * 22/TCP (SSH) - From your IP only                                  │ │
│  │    * 443/TCP (HTTPS) - From 0.0.0.0/0 (Headscale API)                 │ │
│  │    * 51820/UDP (WireGuard) - From 0.0.0.0/0                            │ │
│  │  - Egress: 0.0.0.0/0 (allow all outbound)                              │ │
│  │                                                                          │ │
│  │  Storage: 8 GB gp3 EBS volume (root)                                   │ │
│  │                                                                          │ │
│  │  cloud-init: Executed on first boot                                    │ │
│  │  - Installs packages (headscale, wireguard, certbot)                   │ │
│  │  - Configures Headscale with Elastic IP                                │ │
│  │  - Obtains Let's Encrypt certificate                                   │ │
│  │  - Starts services                                                      │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                     Observability (CloudWatch)                          │ │
│  │                                                                          │ │
│  │  Log Groups:                                                            │ │
│  │  - /aws/lambda/InstanceControlHandler                                  │ │
│  │  - /aws/lambda/IdleMonitorHandler                                      │ │
│  │  - /aws/ec2/zeroteir-vpn                                               │ │
│  │                                                                          │ │
│  │  Metrics:                                                               │ │
│  │  - ZeroTeir/InstanceState (running/stopped)                            │ │
│  │  - ZeroTeir/ActiveConnections (count)                                  │ │
│  │  - ZeroTeir/DataTransfer (bytes)                                       │ │
│  │  - ZeroTeir/InstanceUptime (seconds)                                   │ │
│  │                                                                          │ │
│  │  Alarms (optional):                                                     │ │
│  │  - HighDataTransfer: Trigger if >100 GB/month                          │ │
│  │  - InstanceAlwaysOn: Trigger if uptime >24 hours                       │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Component Details

### 3.1 macOS Application

**Language**: Swift 5.9+
**UI Framework**: SwiftUI
**Minimum macOS**: 13.0 (Ventura)

#### Key Classes

```swift
// State Management
class AppState: ObservableObject {
    @Published var connectionState: ConnectionState
    @Published var connectionStatus: ConnectionStatus?
    @Published var error: Error?
}

enum ConnectionState {
    case disconnected
    case startingInstance
    case waitingForHeadscale
    case connectingTunnel
    case connected
    case disconnecting
}

// Orchestration
class ConnectionService {
    private let instanceManager: InstanceManager
    private let headscaleClient: HeadscaleClient
    private let tunnelManager: TunnelManager

    func connect() async throws -> ConnectionStatus
    func disconnect() async throws
}

// AWS Instance Management
class InstanceManager {
    private let apiEndpoint: URL
    private let apiKey: String

    func start() async throws -> InstanceInfo
    func stop() async throws
    func getStatus() async throws -> InstanceState
}

// Headscale API Client
class HeadscaleClient {
    private let serverUrl: URL
    private let apiKey: String

    func register(machineKey: String) async throws -> MachineInfo
    func getConfig() async throws -> WireGuardConfig
    func getStatus() async throws -> MachineStatus
}

// WireGuard Tunnel Management
class TunnelManager {
    func connect(config: WireGuardConfig) async throws
    func disconnect() async throws
    func getStats() -> TunnelStats
}

// Secure Storage
class KeychainService {
    func store(key: String, value: String) throws
    func retrieve(key: String) throws -> String
    func delete(key: String) throws
}
```

#### Dependencies

- **WireGuardKit**: Apple's official WireGuard library for iOS/macOS
  - Source: https://github.com/WireGuard/wireguard-apple
  - Integration: Swift Package Manager
  - Purpose: Create and manage WireGuard tunnel interface

- **No other external dependencies** (keep it lightweight)

---

### 3.2 AWS Lambda Functions

**Runtime**: Python 3.12
**Memory**: 256 MB
**Timeout**: 60 seconds

#### Function 1: InstanceControlHandler

```python
import boto3
import json
import os

ec2 = boto3.client('ec2')
INSTANCE_ID = os.environ['INSTANCE_ID']
REGION = os.environ['REGION']

def lambda_handler(event, context):
    action = event['requestContext']['resourcePath']

    if action == '/instance/start':
        return start_instance()
    elif action == '/instance/stop':
        return stop_instance()
    elif action == '/instance/status':
        return get_status()
    else:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'Not found'})
        }

def start_instance():
    ec2.start_instances(InstanceIds=[INSTANCE_ID])

    # Wait for instance to be running
    waiter = ec2.get_waiter('instance_running')
    waiter.wait(InstanceIds=[INSTANCE_ID])

    # Get public IP
    response = ec2.describe_instances(InstanceIds=[INSTANCE_ID])
    public_ip = response['Reservations'][0]['Instances'][0]['PublicIpAddress']

    return {
        'statusCode': 200,
        'body': json.dumps({
            'status': 'running',
            'publicIp': public_ip
        })
    }

def stop_instance():
    ec2.stop_instances(InstanceIds=[INSTANCE_ID])
    return {
        'statusCode': 200,
        'body': json.dumps({'status': 'stopping'})
    }

def get_status():
    response = ec2.describe_instances(InstanceIds=[INSTANCE_ID])
    instance = response['Reservations'][0]['Instances'][0]

    return {
        'statusCode': 200,
        'body': json.dumps({
            'status': instance['State']['Name'],
            'publicIp': instance.get('PublicIpAddress'),
            'launchTime': instance['LaunchTime'].isoformat()
        })
    }
```

#### Function 2: IdleMonitorHandler

```python
import boto3
import requests
import os
from datetime import datetime, timedelta

ec2 = boto3.client('ec2')
cloudwatch = boto3.client('cloudwatch')

INSTANCE_ID = os.environ['INSTANCE_ID']
HEADSCALE_URL = os.environ['HEADSCALE_URL']
HEADSCALE_API_KEY = os.environ['HEADSCALE_API_KEY']
IDLE_THRESHOLD_MINUTES = 60

def lambda_handler(event, context):
    # Get instance state
    response = ec2.describe_instances(InstanceIds=[INSTANCE_ID])
    state = response['Reservations'][0]['Instances'][0]['State']['Name']

    if state != 'running':
        return {'message': 'Instance not running, skipping check'}

    # Check Headscale for active connections
    headers = {'Authorization': f'Bearer {HEADSCALE_API_KEY}'}
    machines_response = requests.get(
        f'{HEADSCALE_URL}/api/v1/machine',
        headers=headers
    )

    machines = machines_response.json()['machines']

    # Check if any machine has been active in last IDLE_THRESHOLD_MINUTES
    now = datetime.utcnow()
    any_active = False

    for machine in machines:
        last_seen = datetime.fromisoformat(machine['lastSeen'].replace('Z', '+00:00'))
        idle_time = (now - last_seen).total_seconds() / 60

        if idle_time < IDLE_THRESHOLD_MINUTES:
            any_active = True
            break

    # Publish metric
    cloudwatch.put_metric_data(
        Namespace='ZeroTeir',
        MetricData=[{
            'MetricName': 'ActiveConnections',
            'Value': 1 if any_active else 0,
            'Unit': 'Count'
        }]
    )

    # Stop instance if idle
    if not any_active:
        ec2.stop_instances(InstanceIds=[INSTANCE_ID])
        return {'message': 'Instance stopped due to inactivity'}

    return {'message': 'Instance active, keeping running'}
```

---

### 3.3 Terraform Infrastructure

**Provider**: AWS Provider ~> 5.0
**State Backend**: S3 + DynamoDB (recommended) or local

#### Directory Structure

```
terraform/
├── main.tf              # Main resources (EC2, EIP, SG)
├── lambda.tf            # Lambda functions and API Gateway
├── cloudwatch.tf        # CloudWatch logs, metrics, alarms
├── iam.tf               # IAM roles and policies
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── versions.tf          # Provider versions
└── files/
    ├── cloud-init.yaml  # EC2 user data
    ├── lambda_instance_control.py
    └── lambda_idle_monitor.py
```

#### Key Resources

```hcl
# EC2 Instance
resource "aws_instance" "vpn_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.vpn.id]
  key_name               = var.ssh_key_name

  user_data = file("${path.module}/files/cloud-init.yaml")

  tags = {
    Name = "zeroteir-vpn-server"
  }
}

# Elastic IP
resource "aws_eip" "vpn" {
  instance = aws_instance.vpn_server.id
  domain   = "vpc"
}

# Security Group
resource "aws_security_group" "vpn" {
  name = "zeroteir-vpn"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Lambda Function
resource "aws_lambda_function" "instance_control" {
  function_name = "zeroteir-instance-control"
  runtime       = "python3.12"
  handler       = "lambda_instance_control.lambda_handler"
  role          = aws_iam_role.lambda.arn
  timeout       = 60

  filename = data.archive_file.lambda_instance_control.output_path

  environment {
    variables = {
      INSTANCE_ID = aws_instance.vpn_server.id
      REGION      = var.region
    }
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "vpn_control" {
  name = "zeroteir-vpn-control"
}

# EventBridge Rule for idle check
resource "aws_cloudwatch_event_rule" "idle_check" {
  name                = "zeroteir-idle-check"
  schedule_expression = "rate(5 minutes)"
}
```

---

## 4. Data Flow

### 4.1 Connection Establishment Flow

```
[macOS App]                [Lambda API]              [EC2 Instance]
     │                          │                          │
     │ 1. POST /instance/start  │                          │
     ├─────────────────────────>│                          │
     │                          │ 2. StartInstances()      │
     │                          ├─────────────────────────>│
     │                          │                          │ (boots up)
     │                          │ 3. Wait for running      │
     │                          │<─────────────────────────┤
     │ 4. {status: running}     │                          │
     │<─────────────────────────┤                          │
     │                          │                          │
     │ 5. GET /health           │                          │
     ├──────────────────────────────────────────────────────>│
     │ 6. {status: ok}          │                          │
     │<──────────────────────────────────────────────────────┤
     │                          │                          │
     │ 7. POST /api/v1/machine/register                    │
     ├──────────────────────────────────────────────────────>│ (Headscale)
     │ 8. {machineId, nodeKey}  │                          │
     │<──────────────────────────────────────────────────────┤
     │                          │                          │
     │ 9. GET /api/v1/machine/{id}                         │
     ├──────────────────────────────────────────────────────>│
     │ 10. {wireguardConfig}    │                          │
     │<──────────────────────────────────────────────────────┤
     │                          │                          │
     │ 11. Configure WireGuard  │                          │
     │      interface (utun)    │                          │
     │                          │                          │
     │ 12. WireGuard handshake  │                          │
     │<═════════════════════════════════════════════════════>│ (UDP 51820)
     │                          │                          │
     │ 13. Tunnel established   │                          │
     │                          │                          │
```

### 4.2 Auto-Stop Flow

```
[EventBridge]          [Lambda IdleMonitor]        [EC2 Instance]
     │                          │                          │
     │ Every 5 minutes          │                          │
     ├─────────────────────────>│                          │
     │                          │ GET /api/v1/machine      │
     │                          ├─────────────────────────>│ (Headscale)
     │                          │ {machines: [{lastSeen}]} │
     │                          │<─────────────────────────┤
     │                          │                          │
     │                          │ Check lastSeen           │
     │                          │ timestamps               │
     │                          │                          │
     │                          │ If all idle > 60 min:    │
     │                          │ StopInstances()          │
     │                          ├─────────────────────────>│
     │                          │                          │ (shuts down)
     │                          │                          │
```

---

## 5. Security Architecture

### 5.1 Authentication & Authorization

| Component | Authentication Method | Authorization |
|-----------|----------------------|---------------|
| **Lambda API** | API Key (x-api-key header) | API Gateway Usage Plan |
| **Headscale API** | Bearer Token | Headscale ACLs |
| **WireGuard** | Public/Private Key Pairs | Headscale peer authorization |
| **SSH (EC2)** | SSH Key Pair | EC2 key pair, no password auth |

### 5.2 Network Security

**macOS App → Lambda API**:
- Transport: HTTPS (TLS 1.3)
- Certificate: AWS-managed (API Gateway)

**macOS App → Headscale API**:
- Transport: HTTPS (TLS 1.3)
- Certificate: Let's Encrypt (auto-renewed)

**macOS App → WireGuard**:
- Transport: WireGuard protocol (Noise protocol framework)
- Encryption: ChaCha20-Poly1305
- Key Exchange: Curve25519

**EC2 Instance**:
- Security Group: Minimal ingress rules (SSH from admin IP only, VPN ports from 0.0.0.0/0)
- Firewall: iptables configured to only forward VPN traffic
- SSH: Key-based authentication only, fail2ban for brute-force protection

### 5.3 Secrets Management

| Secret | Storage | Access |
|--------|---------|--------|
| **Lambda API Key** | macOS Keychain | macOS app only |
| **Headscale API Key** | macOS Keychain | macOS app only |
| **WireGuard Private Key** | macOS Keychain | macOS app only |
| **SSH Private Key** | User's ~/.ssh/ | Admin only |
| **EC2 Instance ID** | UserDefaults (not secret) | macOS app only |

**Key Rotation**:
- Lambda API Key: Rotate every 90 days (manual)
- Headscale API Key: Rotate every 90 days (manual)
- WireGuard Keys: Rotate on demand (or every 90 days)
- SSH Key: Rotate on demand

---

## 6. Performance Characteristics

### 6.1 Latency

| Operation | Expected Latency | Notes |
|-----------|------------------|-------|
| **Start Instance** | 30-60 seconds | EC2 boot time |
| **Headscale Ready** | 5-10 seconds | After instance running |
| **WireGuard Handshake** | 1-3 seconds | Initial connection |
| **Lambda API Call** | 100-500 ms | Cold start: 1-2 seconds |
| **Connection Establishment (Total)** | 40-75 seconds | End-to-end |
| **Disconnect** | 1-2 seconds | Tunnel teardown |
| **Ping (over VPN)** | +20-50 ms | vs. direct connection |

### 6.2 Throughput

| Metric | Expected Value | Notes |
|--------|----------------|-------|
| **WireGuard Throughput** | 500-1000 Mbps | t3.micro network: up to 5 Gbps burst |
| **Typical Usage** | 10-100 Mbps | Web browsing, video streaming |
| **Data Transfer Cost** | $0.09/GB | AWS outbound data transfer |

### 6.3 Reliability

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Connection Success Rate** | >95% | Successful connections / total attempts |
| **Connection Uptime** | >99% | Time connected / time intended to be connected |
| **Instance Start Success** | >99% | Successful starts / total start attempts |
| **Lambda Availability** | >99.9% | AWS SLA |

---

## 7. Cost Breakdown

### 7.1 Fixed Costs (Monthly)

| Component | Cost | Notes |
|-----------|------|-------|
| **Elastic IP (not attached)** | $3.60 | When instance stopped |
| **EBS Volume (8 GB gp3)** | $0.64 | Always allocated |
| **Data Transfer (first 1 GB)** | $0.00 | Free tier |
| **Lambda Free Tier** | $0.00 | 1M requests/month free |
| **CloudWatch Logs (first 5 GB)** | $0.00 | Free tier |
| **Total Fixed** | **$4.24/month** | Baseline cost |

### 7.2 Variable Costs (Usage-Based)

| Component | Rate | Example (4 hrs/day) |
|-----------|------|---------------------|
| **EC2 Instance (t3.micro)** | $0.0104/hour | 120 hrs/mo = $1.25 |
| **Elastic IP (attached)** | $0.00/hour | Free when attached |
| **Data Transfer** | $0.09/GB | 50 GB = $4.50 |
| **Lambda (beyond free tier)** | $0.20/1M requests | ~$0.00 (well under limit) |
| **Total Variable** | - | **$5.75/month** |

**Total Monthly Cost (typical usage)**: $4.24 + $5.75 = **$9.99/month**

---

## 8. Monitoring & Observability

### 8.1 CloudWatch Metrics

**Custom Metrics** (namespace: `ZeroTeir`):

| Metric Name | Type | Description | Alarm Threshold |
|-------------|------|-------------|-----------------|
| `InstanceState` | Gauge | 1=running, 0=stopped | N/A |
| `ActiveConnections` | Gauge | Number of active WireGuard peers | N/A |
| `DataTransfer` | Counter | Bytes transferred through VPN | >100 GB/month |
| `InstanceUptime` | Gauge | Seconds instance has been running | >86400 (24 hrs) |
| `ConnectionFailures` | Counter | Failed connection attempts | >5/hour |

**AWS Metrics** (automatic):
- EC2 Instance: CPU, Network, Disk
- Lambda: Invocations, Duration, Errors
- API Gateway: Request Count, Latency, 4xx/5xx Errors

### 8.2 Log Aggregation

**Log Groups**:
- `/aws/lambda/zeroteir-instance-control` - Lambda logs
- `/aws/lambda/zeroteir-idle-monitor` - Idle monitor logs
- `/aws/ec2/zeroteir-vpn` - EC2 system logs (via CloudWatch Agent)

**Log Retention**: 30 days (configurable)

**Key Log Events**:
- Instance started/stopped
- Connection established/terminated
- Authentication failures
- Error stack traces

---

## 9. Disaster Recovery

### 9.1 Backup Strategy

**What to Backup**:
1. **Terraform State** (if using local state)
   - Recommendation: Use S3 backend with versioning
2. **Headscale Database** (SQLite file on EC2)
   - Path: `/var/lib/headscale/db.sqlite`
   - Frequency: Daily snapshot (via cron → S3)
3. **macOS App Settings** (optional)
   - Stored in Keychain (auto-backed up by iCloud)

**Backup Automation**:
```bash
# Daily cron job on EC2 instance
0 2 * * * aws s3 cp /var/lib/headscale/db.sqlite s3://zeroteir-backups/headscale-$(date +\%Y\%m\%d).sqlite
```

### 9.2 Recovery Procedures

**Scenario 1: EC2 Instance Failure**
1. Terminate failed instance
2. Update Terraform with new instance ID
3. Apply Terraform (creates new instance with same Elastic IP)
4. Restore Headscale database from S3 backup
5. Restart Headscale service

**Scenario 2: Elastic IP Lost**
1. Allocate new Elastic IP via Terraform
2. Update macOS app settings with new IP
3. Update Headscale config with new server URL
4. Re-register machines with Headscale

**Scenario 3: Corrupted Terraform State**
1. If using S3 backend with versioning: Restore previous version
2. If local state: Manually import resources (`terraform import`)

**Recovery Time Objective (RTO)**: <1 hour
**Recovery Point Objective (RPO)**: <24 hours (daily backups)

---

## 10. Future Architecture Enhancements

### Phase 2: Stealth Mode (Obfuscation)

```
macOS App
    │
    │ HTTPS (Port 443, looks like web traffic)
    ▼
stunnel (TLS wrapper)
    │
    │ WireGuard (wrapped in TLS)
    ▼
EC2 Instance
    │
    ├─> stunnel (unwraps TLS)
    └─> WireGuard
```

**Changes Required**:
- Add stunnel to EC2 instance (cloud-init)
- macOS app: Configure stunnel client
- Security Group: Allow TCP 443 for stunnel

### Phase 3: Multi-Region

```
macOS App
    │
    ├─> Lambda API (us-east-1)
    │       └─> EC2 (us-east-1)
    │
    ├─> Lambda API (us-west-2)
    │       └─> EC2 (us-west-2)
    │
    └─> Lambda API (eu-west-1)
            └─> EC2 (eu-west-1)
```

**Changes Required**:
- Terraform: Deploy to multiple regions (modules)
- macOS app: Region selector in UI
- Lambda: Regional endpoints (API Gateway)

### Phase 4: HA & Failover

```
macOS App
    │
    │ Primary: us-east-1
    ▼
Route 53 Health Check ──┐
    │                   │ If unhealthy
    │                   ▼
    ├──> EC2 (us-east-1)
    │
    └──> EC2 (us-west-2) [Failover]
```

**Changes Required**:
- Route 53: Health checks + DNS failover
- Headscale: Replicate database between regions
- macOS app: Automatic failover logic

---

## 11. Appendix

### 11.1 Network Diagram (Detailed)

```
                                 Internet
                                     │
                                     │
          ┌──────────────────────────┼──────────────────────────┐
          │                          │                          │
          │                          │                          │
    ┌─────▼──────┐            ┌─────▼──────┐           ┌──────▼─────┐
    │ Corporate  │            │  Public    │           │   Hotel    │
    │  Network   │            │  WiFi      │           │   WiFi     │
    │ (firewall) │            │  (open)    │           │ (captive   │
    │            │            │            │           │  portal)   │
    └─────┬──────┘            └─────┬──────┘           └──────┬─────┘
          │                          │                          │
          │ WireGuard UDP 51820      │ WireGuard UDP 51820      │ (blocked)
          │ (may be blocked)         │ (works)                  │
          │                          │                          │
          └──────────────────────────┼──────────────────────────┘
                                     │
                                     │
                              ┌──────▼──────┐
                              │   AWS       │
                              │  Region     │
                              │             │
                              │ ┌─────────┐ │
                              │ │   EC2   │ │
                              │ │ (Elastic│ │
                              │ │   IP)   │ │
                              │ └────┬────┘ │
                              │      │      │
                              │ ┌────▼────┐ │
                              │ │Headscale│ │
                              │ │+ Wire   │ │
                              │ │ Guard   │ │
                              │ └─────────┘ │
                              └─────────────┘
```

### 11.2 State Transition Table

| Current State | Event | Next State | Actions |
|---------------|-------|------------|---------|
| DISCONNECTED | User clicks Connect | STARTING_INSTANCE | Call Lambda start API |
| STARTING_INSTANCE | Instance running | WAITING_HEADSCALE | Poll Headscale health |
| STARTING_INSTANCE | Timeout (60s) | ERROR | Show error, stop instance |
| WAITING_HEADSCALE | Health check OK | CONNECTING_TUNNEL | Get WireGuard config |
| WAITING_HEADSCALE | Timeout (30s) | ERROR | Show error, stop instance |
| CONNECTING_TUNNEL | Tunnel established | CONNECTED | Start monitoring |
| CONNECTING_TUNNEL | Timeout (30s) | ERROR | Show error, stop instance |
| CONNECTED | User clicks Disconnect | DISCONNECTING | Tear down tunnel |
| CONNECTED | Network change | RECONNECTING | Re-establish tunnel |
| CONNECTED | Tunnel dropped | RECONNECTING | Attempt reconnect (3x) |
| RECONNECTING | Reconnect success | CONNECTED | Resume monitoring |
| RECONNECTING | Retry exhausted | ERROR | Show error, stop instance |
| DISCONNECTING | Tunnel down | DISCONNECTED | Call Lambda stop API |
| ERROR | User clicks Retry | STARTING_INSTANCE | Restart flow |
| ERROR | User clicks Dismiss | DISCONNECTED | Clear error |

---

**Document Version**: 1.0
**Last Updated**: 2026-02-21
**Maintained By**: ZeroTeir Project

