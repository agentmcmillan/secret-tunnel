# Secret Tunnel macOS VPN App - Comprehensive Code Review

## Executive Summary

Secret Tunnel is a well-architected VPN-on-demand system combining macOS menu bar UI, AWS EC2 management, and Headscale/WireGuard connectivity. The v0.2.0 release demonstrates solid Swift development practices with appropriate use of modern async/await patterns, proper error handling, and sensible state management. However, there are several security, reliability, and architectural concerns that warrant attention before production deployment.

**Overall Assessment**: 7.5/10 - Solid foundation with notable areas for improvement in security, error resilience, and test coverage.

---

## 1. Code Quality & Swift Best Practices

### Strengths

1. **Modern Swift Concurrency**: Excellent use of async/await throughout
   - `ConnectionService.swift`: Proper async function organization with clear flow
   - `TunnelManager.swift`: Clean connection lifecycle management
   - No callback hell, good Task management

2. **Strong State Management**
   - `AppState.swift`: Observable pattern with `@Observable` macro (iOS 17+)
   - Clear separation between connection state and status
   - `ConnectionState` enum with proper exhaustive switching

3. **Sensible Error Handling**
   - Comprehensive `AppError` enum with descriptive cases
   - Error propagation through async chains is clean
   - Logging integrated at error boundaries

4. **Well-Organized Architecture**
   - Clear separation of concerns (Services, Models, State, Views)
   - Keychain abstraction via `KeychainService`
   - Network abstraction via `InstanceManager`, `HeadscaleClient`

### Issues & Improvements

#### Issue 1.1: Inconsistent Retry Logic Location
**Severity**: Medium | **File**: `InstanceManager.swift` (lines 83-101)

The retry logic is only implemented in `InstanceManager`, but `HeadscaleClient` lacks retry capability. This creates asymmetric resilience:

```swift
// InstanceManager has retries ✓
private func performRequestWithRetry<T: Decodable>(_ request: URLRequest) async throws -> T

// HeadscaleClient lacks retries ✗
private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T
```

**Recommendation**: Extract retry logic into a shared utility or add retry capability to `HeadscaleClient`.

#### Issue 1.2: Missing Timeout Handling in Latency Measurement
**Severity**: Medium | **File**: `NetworkMonitor.swift` (lines 64-80)

```swift
func measureLatency(to host: String) async -> TimeInterval? {
    let start = Date()
    let url = URL(string: "http://\(host)")!  // Force unwrap - what if host is malformed?
    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"
    request.timeoutInterval = 5
    
    do {
        _ = try await URLSession.shared.data(for: request)
        let latency = Date().timeIntervalSince(start)
        return latency
    } catch {
        Log.api.debug("Latency measurement failed: \(error.localizedDescription)")
        return nil
    }
}
```

Problems:
- Force unwraps `URL(string:)`
- Silently swallows all errors
- No distinction between timeout and network errors

**Recommendation**:
```swift
func measureLatency(to host: String) async -> TimeInterval? {
    guard let url = URL(string: "http://\(host)") else {
        Log.api.warning("Invalid host for latency measurement: \(host)")
        return nil
    }
    // ... rest of implementation
}
```

#### Issue 1.3: Weak Self Capture Without Nil Check
**Severity**: Low | **File**: `NetworkMonitor.swift` (lines 24-51)

```swift
monitor.pathUpdateHandler = { [weak self] path in
    Task { @MainActor in
        let wasConnected = self?.previouslyConnected ?? true  // ✓ Safe
        // ...
    }
}
```

This is actually handled correctly with optional chaining. Good pattern.

---

## 2. Security Concerns

### Critical Issues

#### Security 2.1: WireGuard Private Key Derivation
**Severity**: High | **File**: `ConnectionService.swift` (lines 261-269)

```swift
private func derivePublicKey(from base64PrivateKey: String) -> String {
    guard let keyData = Data(base64Encoded: base64PrivateKey) else { return "" }
    do {
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData)
        return privateKey.publicKey.rawRepresentation.base64EncodedString()
    } catch {
        return ""
    }
}
```

**Problems**:
1. Silent failure (returns empty string) - cannot distinguish between invalid key and error
2. No logging on failure makes debugging difficult
3. Empty string could cause subtle bugs downstream

**Recommendation**:
```swift
private func derivePublicKey(from base64PrivateKey: String) throws -> String {
    guard let keyData = Data(base64Encoded: base64PrivateKey) else {
        throw AppError.configurationMissing("Invalid private key encoding")
    }
    let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData)
    return privateKey.publicKey.rawRepresentation.base64EncodedString()
}
```

#### Security 2.2: API Key Exposure in Transit
**Severity**: High | **File**: Multiple (InstanceManager.swift, HeadscaleClient.swift)

```swift
// InstanceManager.swift
request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

// HeadscaleClient.swift
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
```

**Problems**:
1. No certificate pinning - vulnerable to MITM attacks
2. URLs constructed from user-provided endpoints without validation
3. No attempt to verify SSL/TLS chain
4. Headscale URL could be http:// (line 83 in ConnectionService.swift doesn't validate scheme)

**Recommendation**:
- Implement certificate pinning for AWS API and Headscale servers
- Validate URLs are HTTPS:
```swift
guard headscaleURL.scheme == "https" else {
    throw AppError.configurationMissing("Headscale URL must use HTTPS")
}
```

#### Security 2.3: Headscale Pre-Auth Key Storage
**Severity**: Medium | **File**: `ConnectionService.swift` (lines 241-259)

```swift
try KeychainService.shared.save(key: "headscalePreAuthKey", value: preAuthKey.key)
```

The pre-auth key is saved to keychain but never validated or rotated. If compromised, it could enable unauthorized registration.

**Recommendation**:
- Add TTL to stored pre-auth keys
- Log key creation/usage
- Consider one-time use pre-auth keys (line 254 already uses `reusable: false`)

### Moderate Issues

#### Security 2.4: Plaintext Credential Logging
**Severity**: Medium | **File**: `HeadscaleClient.swift` (lines 159-163)

```swift
if let responseString = String(data: data, encoding: .utf8) {
    Log.api.debug("Response body: \(responseString)")
}
```

Response bodies could contain sensitive information (user IDs, machine IDs, etc.). While debug logging, it could be captured in system logs.

**Recommendation**:
```swift
Log.api.debug("Response received: \(data.count) bytes")  // Don't log content
```

#### Security 2.5: Instance Manager JSON Serialization Error Ignored
**Severity**: Low | **File**: `InstanceManager.swift` (lines 30-32)

```swift
if let instanceType {
    let body = ["instanceType": instanceType]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)  // try? swallows errors
}
```

Uses `try?` which silently fails. If JSON encoding fails, the request body is nil.

---

## 3. Architecture & Error Handling

### Strengths

1. **Clear State Machines**: `ConnectionState` enum properly models the connection lifecycle
2. **Rollback Mechanism**: `ConnectionService.rollback()` ensures cleanup on failure
3. **Monitoring Task**: Background monitoring task properly cancels on disconnect
4. **Network Recovery**: `handleNetworkRecovery()` detects and handles stale handshakes

### Issues

#### Architecture 3.1: Race Condition in Network State Updates
**Severity**: Medium | **File**: `NetworkMonitor.swift` (lines 24-51)

```swift
monitor.pathUpdateHandler = { [weak self] path in
    Task { @MainActor in
        let wasConnected = self?.previouslyConnected ?? true
        let nowConnected = path.status == .satisfied
        self?.isConnected = nowConnected
        self?.previouslyConnected = nowConnected  // State update race condition
        
        // SSID detection
        let newSSID = self?.getCurrentSSID()
        let oldSSID = self?.previousSSID
        self?.currentSSID = newSSID
        self?.previousSSID = newSSID
    }
}
```

**Problem**: Multiple state mutations without synchronization. If two network changes occur rapidly, state could be inconsistent.

**Recommendation**: Use synchronized state updates:
```swift
Task { @MainActor in
    let oldState = (isConnected: self?.isConnected ?? false, ssid: self?.currentSSID)
    let newState = (isConnected: path.status == .satisfied, ssid: self?.getCurrentSSID())
    
    // Atomic update
    self?.isConnected = newState.isConnected
    self?.currentSSID = newState.ssid
    // ... trigger callbacks
}
```

#### Architecture 3.2: Disconnect Fire-and-Forget
**Severity**: High | **File**: `ConnectionService.swift` (lines 138-150)

```swift
func disconnect() async {
    // ...
    Task.detached {  // Fire and forget!
        do {
            let apiKey = try self.appState.settings.getLambdaApiKey()
            // ... stop instance
        } catch {
            Log.connection.warning("Instance stop failed: \(error.localizedDescription)")
        }
    }
    
    connectionStartTime = nil
    await appState.updateState(.disconnected)  // Continues before instance stop completes
}
```

**Problems**:
1. Instance stop happens in background with no await
2. User might close app before instance stops
3. No way to know if instance actually stopped
4. Could leave EC2 instance running, incurring charges

**Recommendation**:
```swift
func disconnect() async {
    Log.connection.info("Starting disconnect flow...")
    stopMonitoring()
    appState.updateState(.disconnecting)
    
    do {
        try await tunnelManager.disconnect()
    } catch {
        Log.connection.warning("Tunnel disconnect failed: \(error.localizedDescription)")
    }
    
    // Wait for instance stop
    do {
        let apiKey = try appState.settings.getLambdaApiKey()
        guard let lambdaURL = URL(string: appState.settings.lambdaApiEndpoint) else {
            throw AppError.configurationMissing("Lambda endpoint")
        }
        let instanceManager = InstanceManager(apiEndpoint: lambdaURL, apiKey: apiKey)
        try await instanceManager.stop()
        Log.connection.info("Instance stopped")
    } catch {
        Log.connection.error("Instance stop failed (will incur charges): \(error.localizedDescription)")
        appState.updateState(.error(.instanceStopFailed(error.localizedDescription)))
        return
    }
    
    connectionStartTime = nil
    await appState.updateState(.disconnected)
}
```

#### Architecture 3.3: Missing Handler for Tunnel Extension Failures
**Severity**: Medium | **File**: `TunnelManager.swift` (lines 51-90)

The tunnel connection only logs status changes via `setupStatusObserver()`, but there's no mechanism to automatically reconnect if the extension crashes or tunnel drops unexpectedly.

**Recommendation**: Add a recovery handler:
```swift
private func setupStatusObserver() {
    statusObserver = NotificationCenter.default.addObserver(
        forName: .NEVPNStatusDidChange,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        // ... existing code
        
        // Auto-reconnect if connection drops unexpectedly
        if case .connected = appState.connectionState,
           case .disconnected = status {
            Log.tunnel.warning("Tunnel disconnected unexpectedly, initiating reconnect...")
            Task { await connectionService.handleUnexpectedDisconnect() }
        }
    }
}
```

---

## 4. Terraform Best Practices

### Strengths

1. **IAM Principle of Least Privilege**: Roles have specific resource ARNs
2. **CloudWatch Integration**: Comprehensive monitoring and logging
3. **Security Group Restrictions**: SSH limited to admin IP
4. **Common Tags**: Consistent tagging for resource management

### Issues

#### Terraform 4.1: Overly Permissive EC2 Describe Permissions
**Severity**: Medium | **File**: `iam.tf` (lines 43-46, 100-104)

```hcl
{
  Effect = "Allow"
  Action = [
    "ec2:DescribeInstances",
    "ec2:DescribeInstanceStatus"
  ]
  Resource = "*"  # Should be restricted
}
```

**Problem**: `DescribeInstances` on `*` allows reading all EC2 instances in the account.

**Recommendation**: Restrict to specific instance:
```hcl
{
  Effect = "Allow"
  Action = [
    "ec2:DescribeInstances",
    "ec2:DescribeInstanceStatus"
  ]
  Resource = aws_instance.vpn.arn
}
```

#### Terraform 4.2: CloudWatch Metric Permissions Lack Specificity
**Severity**: Low | **File**: `iam.tf` (lines 118-125)

```hcl
{
  Effect = "Allow"
  Action = [
    "cloudwatch:PutMetricData"
  ]
  Resource = "*"  # Should have conditions
  Condition = {
    StringEquals = {
      "cloudwatch:namespace" = var.project_name
    }
  }
}
```

**Problem**: Condition on Resource `*` is less secure than it could be.

**Recommendation**: Add additional conditions:
```hcl
Condition = {
  StringEquals = {
    "cloudwatch:namespace" = var.project_name
  }
  StringLike = {
    "cloudwatch:metricName" = [
      "InstanceState",
      "ActiveConnections"
    ]
  }
}
```

#### Terraform 4.3: Missing Lambda Function Implementation
**Severity**: High | **File**: Missing from reviewed files

The IAM roles reference Lambda functions (`instance_control_lambda`, `idle_monitor_lambda`) but the actual Lambda code isn't defined in the reviewed terraform files.

**Recommendation**: Ensure Lambda code exists and implements:
- Instance start/stop with proper status checking
- Idle monitoring with CloudWatch metrics
- Error handling and logging

---

## 5. Test Coverage & Quality

### Current Status
- **Total Tests**: 5 test files, ~348 lines of test code
- **Test Classes**: `WireGuardConfigTests`, `ConnectionStateTests`, `ConnectionStatusTests`, `ConstantsTests`, `AppErrorTests`
- **Coverage Focus**: Models and utility functions

### Strengths

1. **WireGuardConfig Tests**: Comprehensive coverage (8 test cases)
   - Peer configuration generation
   - Multiple peers handling
   - Optional endpoint handling
   - Good assertions

2. **Model Tests**: Good coverage of formatters
   - Uptime formatting
   - Byte count formatting
   - Latency formatting

### Critical Gaps

#### Testing 5.1: No ConnectionService Tests
**Severity**: High

The core business logic (`ConnectionService.swift`) lacks any tests:
- No tests for `connect()` flow
- No tests for `disconnect()` flow
- No tests for error handling/rollback
- No tests for network recovery

**Recommendation**: Add comprehensive service tests:
```swift
class ConnectionServiceTests: XCTestCase {
    var appState: AppState!
    var connectionService: ConnectionService!
    var mockInstanceManager: MockInstanceManager!
    var mockHeadscaleClient: MockHeadscaleClient!
    
    func testConnectFlow() async {
        // Test full connection lifecycle
    }
    
    func testDisconnectStopsInstance() async {
        // Test that instance is stopped on disconnect
    }
    
    func testNetworkRecoveryReconnects() async {
        // Test stale connection detection
    }
}
```

#### Testing 5.2: No Integration Tests
**Severity**: High

No tests for:
- Headscale registration flow
- Instance lifecycle management
- Tunnel status monitoring

#### Testing 5.3: No Security Tests
**Severity**: Medium

Missing tests for:
- API key not exposed in logs
- HTTPS enforcement
- Keychain operations
- Pre-auth key storage

**Recommendation**: Add security-focused tests:
```swift
func testAPIKeyNotExposedInLogs() {
    // Verify sensitive data isn't logged
}

func testHeadscaleURLMustBeHTTPS() {
    // Verify URL scheme validation
}
```

---

## 6. Specific Code Issues & Bugs

### Issue 6.1: Server Public Key Selection Logic
**Severity**: Medium | **File**: `ConnectionService.swift` (lines 224-239)

```swift
private func fetchServerPublicKey(headscaleClient: HeadscaleClient) async throws -> String {
    let machines = try await headscaleClient.listMachines()
    
    // Find the AWS exit node — it's typically the first machine or the one with a public IP
    guard let server = machines.first else {
        throw AppError.headscaleTimeout  // Wrong error type!
    }
    
    guard let nodeKey = server.nodeKey, !nodeKey.isEmpty else {
        throw AppError.tunnelFailed("Server node has no public key")
    }
    
    return nodeKey
}
```

**Problems**:
1. Assumes first machine is the exit node - fragile assumption
2. No validation that `nodeKey` is actually a valid WireGuard public key
3. Wrong error type: `.headscaleTimeout` when machines list is empty

**Recommendation**:
```swift
private func fetchServerPublicKey(headscaleClient: HeadscaleClient) async throws -> String {
    let machines = try await headscaleClient.listMachines()
    
    // Find exit node (filter by role or name convention)
    guard let server = machines.first(where: { $0.name.contains("exit") || $0.name.contains("vpn") })
        ?? machines.first else {
        throw AppError.headscaleUnreachable("No exit node found in Headscale")
    }
    
    guard let nodeKey = server.nodeKey, 
          !nodeKey.isEmpty,
          isValidWireGuardKey(nodeKey) else {
        throw AppError.tunnelFailed("Server node has no valid public key")
    }
    
    return nodeKey
}

private func isValidWireGuardKey(_ key: String) -> Bool {
    // WireGuard keys are base64-encoded 32-byte values
    guard let data = Data(base64Encoded: key) else { return false }
    return data.count == 32
}
```

### Issue 6.2: Connection Status Update Missing IP Info
**Severity**: Medium | **File**: `ConnectionService.swift` (lines 343-368)

```swift
let stats = try await tunnelManager.getStats()
// ... 
var latency: TimeInterval?
if let endpoint = stats.endpoint {
    // ✗ endpoint is always nil (see TunnelManager.swift line 130)
    let host = endpoint.components(separatedBy: ":").first ?? endpoint
    latency = await networkMonitor.measureLatency(to: host)
}
```

Looking at `TunnelManager.getStats()` (line 130):
```swift
let wireGuardStats = WireGuardStats(
    bytesSent: stats.txBytes,
    bytesReceived: stats.rxBytes,
    lastHandshake: lastHandshake,
    endpoint: nil  // Always nil!
)
```

The endpoint is hardcoded to nil, so latency measurement never happens.

**Recommendation**: Extract endpoint from WireGuard config:
```swift
let status = ConnectionStatus(
    connectedIP: config.serverEndpoint,  // Use from config
    latency: latency,
    // ...
)
```

### Issue 6.3: Kill Switch Configuration Not Applied on Reconnect
**Severity**: Medium | **File**: `ConnectionService.swift` (line 104)

```swift
try await tunnelManager.connect(config: config, killSwitch: appState.settings.killSwitchEnabled)
```

If kill switch setting changes while connected, reconnection is needed. But there's no handler for this setting change.

**Recommendation**: Add a Settings observer:
```swift
var settingsObserver: AnyCancellable?

init(appState: AppState) {
    // ... existing code
    
    settingsObserver = appState.$settings.sink { [weak self] _ in
        guard let self, self.appState.connectionState.isConnected else { return }
        
        // Reconnect if kill switch changed
        Task { @MainActor in
            await self.handleSettingsChange()
        }
    }
}
```

---

## 7. Performance & Reliability

### Issue 7.1: Polling Interval May Be Too Aggressive
**Severity**: Low | **File**: `Constants.swift` (line 19)

```swift
static let connectionMonitorInterval: TimeInterval = 5  // Poll every 5 seconds
```

Polling every 5 seconds continuously while connected may:
- Drain battery on macOS
- Increase CPU usage
- Create unnecessary network overhead

**Recommendation**: Increase to 15-30 seconds for monitoring:
```swift
static let connectionMonitorInterval: TimeInterval = 15
```

### Issue 7.2: No Backoff for Failed Headscale Health Checks
**Severity**: Medium | **File**: `ConnectionService.swift` (lines 159-173)

```swift
while Date() < timeout {
    if try await client.checkHealth() {
        return
    }
    try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))  // Fixed 2-second interval
}
```

If Headscale is slow to start, this hammers it with health checks every 2 seconds for 30 seconds.

**Recommendation**: Implement exponential backoff:
```swift
var delay: TimeInterval = Constants.Polling.headscaleHealthInterval
while Date() < timeout {
    if try await client.checkHealth() {
        return
    }
    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    delay = min(delay * 1.5, 10)  // Cap at 10 seconds
}
```

### Issue 7.3: No Mechanism to Clean Up Stale Pre-Auth Keys
**Severity**: Low | **File**: `ConnectionService.swift` (line 254)

Pre-auth keys are created but never cleaned up if connection fails midway. Over time, orphaned keys accumulate in Headscale.

**Recommendation**: Add cleanup logic or set expiration on pre-auth keys:
```swift
let preAuthKey = try await headscaleClient.createPreAuthKey(
    user: namespace,
    reusable: false,
    expiration: Date().addingTimeInterval(3600)  // Expire in 1 hour
)
```

---

## 8. Security Best Practices Summary

### Critical (Must Fix Before Production)
1. **Certificate pinning** for AWS and Headscale endpoints
2. **Error propagation** instead of silent failures in key derivation
3. **Await instance stop** instead of fire-and-forget

### High Priority
1. Add comprehensive logging for security events
2. Implement URL scheme validation (HTTPS only)
3. Add pre-auth key TTL and cleanup

### Medium Priority
1. Extract retry logic to shared utility
2. Add response content sanitization (don't log sensitive data)
3. Implement symmetric error handling across services

---

## 9. Recommendations Summary

### Immediate (1-2 weeks)
- [ ] Fix instance stop fire-and-forget (Architecture 3.2)
- [ ] Add certificate pinning for API endpoints
- [ ] Add ConnectionService tests
- [ ] Fix server public key selection logic (Issue 6.1)
- [ ] Add HTTPS URL validation

### Short Term (1 month)
- [ ] Implement symmetric retry logic in HeadscaleClient
- [ ] Add security-focused tests
- [ ] Fix latency measurement URL validation
- [ ] Implement Settings change observer for kill switch
- [ ] Improve error types for consistency

### Medium Term (2-3 months)
- [ ] Add integration tests
- [ ] Implement exponential backoff for health checks
- [ ] Add pre-auth key cleanup mechanism
- [ ] Optimize polling intervals
- [ ] Add comprehensive logging for audit trail

### Long Term
- [ ] Consider network state machine instead of callbacks
- [ ] Add metrics/telemetry for reliability monitoring
- [ ] Implement graceful shutdown for app termination
- [ ] Add support for multiple exit nodes

---

## 10. Positive Highlights

1. **Excellent use of Swift async/await**: The codebase demonstrates modern concurrency patterns
2. **Strong state management**: Observable pattern is well-applied
3. **Good error types**: AppError enum is comprehensive and descriptive
4. **Sensible architecture**: Clean separation of concerns
5. **Proper cleanup**: Deinit methods properly clean up observers
6. **Keychain integration**: Credentials handled via secure storage, not hardcoded
7. **Comprehensive Terraform**: Good IAM practices and CloudWatch integration
8. **Clear logging**: Categorized logging with appropriate levels
9. **Network recovery**: Stale connection detection is thoughtful
10. **Kill switch implementation**: Properly uses NetworkExtension includeAllNetworks

---

## Test Coverage Goals

Current: ~348 lines of test code
Target for 1.0: ~2000+ lines (reasonable target for 5000+ lines of app code)

### Priority Test Areas
1. **ConnectionService** (critical path)
2. **Error handling & rollback**
3. **Network recovery scenarios**
4. **Keychain operations**
5. **Headscale integration**
6. **Instance lifecycle**

---

## Conclusion

Secret Tunnel demonstrates competent Swift development with good architectural decisions. The main concerns center on security (certificate pinning, error handling), reliability (fire-and-forget patterns, retry consistency), and test coverage. With focused effort on the critical issues, this project is well-positioned for production use.

The team should prioritize the Critical and High Priority items before launch, then work through the medium-term recommendations for a hardened 1.1 release.
