import Foundation

enum ConnectionState: Equatable {
    case disconnected
    case startingInstance
    case waitingForHeadscale
    case connectingTunnel
    case connected
    case disconnecting
    case error(AppError)

    var displayName: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .startingInstance:
            return "Starting instance..."
        case .waitingForHeadscale:
            return "Waiting for Headscale..."
        case .connectingTunnel:
            return "Connecting tunnel..."
        case .connected:
            return "Connected"
        case .disconnecting:
            return "Disconnecting..."
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }

    var isConnecting: Bool {
        switch self {
        case .startingInstance, .waitingForHeadscale, .connectingTunnel:
            return true
        default:
            return false
        }
    }

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

enum AppError: Error, Equatable {
    case instanceStartFailed(String)
    case instanceStopFailed(String)
    case headscaleTimeout
    case headscaleUnreachable(String)
    case tunnelFailed(String)
    case configurationMissing(String)
    case networkError(String)
    case authenticationFailed
    case timeout
    case unknownError(String)

    var localizedDescription: String {
        switch self {
        case .instanceStartFailed(let message):
            return "Failed to start instance: \(message)"
        case .instanceStopFailed(let message):
            return "Failed to stop instance: \(message)"
        case .headscaleTimeout:
            return "Headscale health check timed out"
        case .headscaleUnreachable(let message):
            return "Headscale unreachable: \(message)"
        case .tunnelFailed(let message):
            return "Tunnel connection failed: \(message)"
        case .configurationMissing(let field):
            return "Missing configuration: \(field)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationFailed:
            return "Authentication failed"
        case .timeout:
            return "Operation timed out"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}
