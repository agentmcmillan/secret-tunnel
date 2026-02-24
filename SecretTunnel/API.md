# ZeroTeir API Documentation

This document describes the expected API contracts for Lambda and Headscale services.

## Lambda API

The Lambda API manages EC2 instance lifecycle.

### Authentication

All requests require an API key in the header:
```
x-api-key: YOUR_API_KEY
```

### Base URL
```
https://your-api-gateway.execute-api.{region}.amazonaws.com/prod
```

---

### POST /instance/start

Start the EC2 instance and wait for it to be running.

**Request:**
```http
POST /instance/start HTTP/1.1
Host: your-api-gateway.execute-api.us-east-1.amazonaws.com
x-api-key: YOUR_API_KEY
```

**Response (200 OK):**
```json
{
  "instanceId": "i-1234567890abcdef0",
  "publicIp": "54.123.45.67",
  "status": "running"
}
```

**Response Fields:**
- `instanceId` (string): EC2 instance ID
- `publicIp` (string): Public IPv4 address
- `status` (string): Instance state (should be "running")

**Timeout:** 60 seconds

**Error Responses:**
- `401 Unauthorized`: Invalid API key
- `500 Internal Server Error`: Instance start failed
- `504 Gateway Timeout`: Instance didn't start in time

---

### POST /instance/stop

Stop the EC2 instance.

**Request:**
```http
POST /instance/stop HTTP/1.1
Host: your-api-gateway.execute-api.us-east-1.amazonaws.com
x-api-key: YOUR_API_KEY
```

**Response (200 OK):**
```json
{
  "instanceId": "i-1234567890abcdef0",
  "status": "stopping"
}
```

**Response Fields:**
- `instanceId` (string): EC2 instance ID
- `status` (string): Instance state (typically "stopping" or "stopped")

**Note:** This is a fire-and-forget operation. The client doesn't wait for the instance to fully stop.

**Error Responses:**
- `401 Unauthorized`: Invalid API key
- `500 Internal Server Error`: Instance stop failed

---

### GET /instance/status

Get current instance status.

**Request:**
```http
GET /instance/status HTTP/1.1
Host: your-api-gateway.execute-api.us-east-1.amazonaws.com
x-api-key: YOUR_API_KEY
```

**Response (200 OK):**
```json
{
  "instanceId": "i-1234567890abcdef0",
  "status": "running",
  "publicIp": "54.123.45.67",
  "privateIp": "10.0.1.42"
}
```

**Response Fields:**
- `instanceId` (string): EC2 instance ID
- `status` (string): Instance state ("pending", "running", "stopping", "stopped", "terminated")
- `publicIp` (string, nullable): Public IPv4 address (null if not running)
- `privateIp` (string, nullable): Private IPv4 address (null if not running)

**Error Responses:**
- `401 Unauthorized`: Invalid API key
- `404 Not Found`: Instance not found
- `500 Internal Server Error`: Failed to get status

---

## Headscale API

The Headscale API manages WireGuard coordination and routing.

### Authentication

All API requests (except /health) require Bearer token authentication:
```
Authorization: Bearer YOUR_API_KEY
```

### Base URL
```
https://your-headscale-server.com
```

---

### GET /health

Health check endpoint (no authentication required).

**Request:**
```http
GET /health HTTP/1.1
Host: your-headscale-server.com
```

**Response (200 OK):**
```
ok
```

**Used for:** Polling to determine when Headscale server is ready after instance start.

---

### GET /api/v1/machine

List all registered machines.

**Request:**
```http
GET /api/v1/machine HTTP/1.1
Host: your-headscale-server.com
Authorization: Bearer YOUR_API_KEY
```

**Response (200 OK):**
```json
{
  "machines": [
    {
      "id": "1",
      "name": "my-laptop",
      "nodeKey": "nodekey:abcd1234...",
      "ipAddresses": ["100.64.0.1"]
    },
    {
      "id": "2",
      "name": "vpn-server",
      "nodeKey": "nodekey:efgh5678...",
      "ipAddresses": ["100.64.0.2"]
    }
  ]
}
```

**Machine Fields:**
- `id` (string): Machine ID
- `name` (string): Machine name/hostname
- `nodeKey` (string): WireGuard node key
- `ipAddresses` (string[]): Assigned IP addresses

**Error Responses:**
- `401 Unauthorized`: Invalid API key
- `500 Internal Server Error`: Failed to list machines

---

### GET /api/v1/routes

List all routes.

**Request:**
```http
GET /api/v1/routes HTTP/1.1
Host: your-headscale-server.com
Authorization: Bearer YOUR_API_KEY
```

**Response (200 OK):**
```json
{
  "routes": [
    {
      "id": "1",
      "machineId": "2",
      "prefix": "0.0.0.0/0",
      "enabled": true
    }
  ]
}
```

**Route Fields:**
- `id` (string): Route ID
- `machineId` (string): Machine that advertises this route
- `prefix` (string): IP prefix (CIDR notation)
- `enabled` (boolean): Whether route is active

**Error Responses:**
- `401 Unauthorized`: Invalid API key
- `500 Internal Server Error`: Failed to get routes

---

### POST /api/v1/preauthkey

Create a pre-authentication key for machine registration.

**Request:**
```http
POST /api/v1/preauthkey HTTP/1.1
Host: your-headscale-server.com
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json

{
  "user": "default",
  "reusable": false,
  "ephemeral": false,
  "expiration": "2026-12-31T23:59:59Z"
}
```

**Request Fields:**
- `user` (string): User/namespace for the machine
- `reusable` (boolean): Whether key can be used multiple times
- `ephemeral` (boolean): Whether machine is ephemeral
- `expiration` (string, optional): ISO8601 timestamp for key expiration

**Response (200 OK):**
```json
{
  "preAuthKey": {
    "id": "1",
    "key": "preauthkey:abcdef123456...",
    "reusable": false,
    "ephemeral": false,
    "used": false,
    "expiration": "2026-12-31T23:59:59Z",
    "createdAt": "2026-02-22T10:00:00Z"
  }
}
```

**PreAuthKey Fields:**
- `id` (string): Key ID
- `key` (string): The actual pre-auth key (use this for registration)
- `reusable` (boolean): Can be used multiple times
- `ephemeral` (boolean): Creates ephemeral machines
- `used` (boolean): Has been used
- `expiration` (string): ISO8601 expiration timestamp
- `createdAt` (string): ISO8601 creation timestamp

**Error Responses:**
- `401 Unauthorized`: Invalid API key
- `400 Bad Request`: Invalid request parameters
- `500 Internal Server Error`: Failed to create key

---

## WireGuard Configuration

While not an HTTP API, the WireGuard configuration is generated based on Headscale data.

### Config File Format

**Location:** `~/.zeroteir/wg0.conf`

**Example:**
```ini
[Interface]
PrivateKey = GENERATED_OR_STORED_PRIVATE_KEY
Address = 100.64.0.1/32
DNS = 1.1.1.1

[Peer]
PublicKey = SERVER_PUBLIC_KEY_FROM_HEADSCALE
Endpoint = EC2_PUBLIC_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

**Fields:**
- `PrivateKey`: Client's WireGuard private key (generated on first run)
- `Address`: IP address assigned by Headscale
- `DNS`: DNS server to use when connected
- `PublicKey`: Server's WireGuard public key (from Headscale)
- `Endpoint`: EC2 public IP and WireGuard port
- `AllowedIPs`: Routes to tunnel (0.0.0.0/0 = all traffic)
- `PersistentKeepalive`: Keep-alive interval in seconds

---

## Integration Notes

### Connection Flow Data Dependencies

1. **Start Instance** (Lambda)
   - Input: None (uses pre-configured instance)
   - Output: `publicIp` → used as WireGuard endpoint

2. **Wait for Headscale**
   - Input: Headscale URL from settings
   - Action: Poll `/health` every 2s for 30s
   - Output: Health status → proceed when healthy

3. **Get WireGuard Config** (Phase 2 - not fully implemented)
   - Input: Pre-auth key from Headscale
   - Action: Register machine, get assigned IP
   - Output: IP address, server public key → build WireGuard config

4. **Connect Tunnel** (Local)
   - Input: WireGuard config
   - Action: Write config file, run `wg-quick up`
   - Output: Active tunnel

### Current Limitations

**Phase 1 (Current):**
- WireGuard config uses placeholder values
- Full Headscale machine registration not implemented
- Pre-auth key creation exists but isn't used

**Phase 2 (Planned):**
- Automatic machine registration via pre-auth key
- Dynamic IP assignment from Headscale
- Retrieve server public key from Headscale
- Full config generation from Headscale data

### API Retry Strategy

All API calls implement retry logic:
- Max attempts: 3
- Backoff: Exponential (1s, 2s, 4s)
- Timeout: 30s per request (60s for instance start)

### Error Handling

API errors are mapped to `AppError` types:
- `401/403` → `AppError.authenticationFailed`
- `504` → `AppError.timeout`
- Network errors → `AppError.networkError(message)`
- Server errors → `AppError.instanceStartFailed(message)` or similar

---

## Example API Implementation (Lambda)

### Python/Boto3 Example

```python
import boto3
import json

ec2 = boto3.client('ec2')
INSTANCE_ID = 'i-1234567890abcdef0'

def start_instance(event, context):
    # Start instance
    ec2.start_instances(InstanceIds=[INSTANCE_ID])

    # Wait for running state
    waiter = ec2.get_waiter('instance_running')
    waiter.wait(InstanceIds=[INSTANCE_ID])

    # Get instance details
    response = ec2.describe_instances(InstanceIds=[INSTANCE_ID])
    instance = response['Reservations'][0]['Instances'][0]

    return {
        'statusCode': 200,
        'body': json.dumps({
            'instanceId': INSTANCE_ID,
            'publicIp': instance['PublicIpAddress'],
            'status': instance['State']['Name']
        })
    }

def stop_instance(event, context):
    ec2.stop_instances(InstanceIds=[INSTANCE_ID])

    return {
        'statusCode': 200,
        'body': json.dumps({
            'instanceId': INSTANCE_ID,
            'status': 'stopping'
        })
    }

def get_status(event, context):
    response = ec2.describe_instances(InstanceIds=[INSTANCE_ID])
    instance = response['Reservations'][0]['Instances'][0]

    return {
        'statusCode': 200,
        'body': json.dumps({
            'instanceId': INSTANCE_ID,
            'status': instance['State']['Name'],
            'publicIp': instance.get('PublicIpAddress'),
            'privateIp': instance.get('PrivateIpAddress')
        })
    }
```

---

## Testing APIs

### Test Lambda API

```bash
# Test start
curl -X POST \
  -H "x-api-key: YOUR_KEY" \
  https://your-api.com/instance/start

# Test status
curl -H "x-api-key: YOUR_KEY" \
  https://your-api.com/instance/status

# Test stop
curl -X POST \
  -H "x-api-key: YOUR_KEY" \
  https://your-api.com/instance/stop
```

### Test Headscale API

```bash
# Test health
curl https://your-headscale.com/health

# Test machines
curl -H "Authorization: Bearer YOUR_KEY" \
  https://your-headscale.com/api/v1/machine

# Test routes
curl -H "Authorization: Bearer YOUR_KEY" \
  https://your-headscale.com/api/v1/routes

# Create pre-auth key
curl -X POST \
  -H "Authorization: Bearer YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user":"default","reusable":false}' \
  https://your-headscale.com/api/v1/preauthkey
```

---

## API Versioning

### Lambda API
- Current version: v1 (implicit)
- Breaking changes will be introduced as new path versions (/v2/instance/start)

### Headscale API
- Current version: v1 (explicit in path)
- Official Headscale API versioning applies
- Refer to Headscale documentation for changes

---

## Security Considerations

1. **API Keys**: Store only in macOS Keychain, never in code or logs
2. **HTTPS**: All API calls must use HTTPS
3. **Key Rotation**: Support updating keys without reinstall
4. **Audit Logs**: Lambda/Headscale should log all API access
5. **Rate Limiting**: APIs should implement rate limiting to prevent abuse
