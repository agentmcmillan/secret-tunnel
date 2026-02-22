import Foundation

struct TunnelStats: Codable {
    let rxBytes: UInt64
    let txBytes: UInt64
    let lastHandshakeEpoch: UInt64
}
