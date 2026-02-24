import Foundation

struct ConnectionStatus: Equatable {
    let connectedIP: String
    let latency: TimeInterval?
    let bytesSent: UInt64
    let bytesReceived: UInt64
    let uptime: TimeInterval
    let lastHandshake: Date?

    var formattedLatency: String {
        guard let latency = latency else { return "N/A" }
        return String(format: "%.0f ms", latency * 1000)
    }

    var formattedBytesSent: String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesSent), countStyle: .binary)
    }

    var formattedBytesReceived: String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesReceived), countStyle: .binary)
    }

    var formattedUptime: String {
        let hours = Int(uptime) / 3600
        let minutes = Int(uptime) / 60 % 60
        let seconds = Int(uptime) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    var isHandshakeStale: Bool {
        guard let lastHandshake = lastHandshake else { return true }
        return Date().timeIntervalSince(lastHandshake) > Constants.Polling.handshakeStaleThreshold
    }
}

struct WireGuardStats: Equatable {
    let bytesSent: UInt64
    let bytesReceived: UInt64
    let lastHandshake: Date?
    let endpoint: String?
}
