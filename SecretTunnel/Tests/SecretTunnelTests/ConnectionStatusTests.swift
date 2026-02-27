import XCTest
@testable import SecretTunnel

final class ConnectionStatusTests: XCTestCase {

    func testFormattedLatency() {
        let status = ConnectionStatus(
            connectedIP: "1.2.3.4",
            latency: 0.045,
            bytesSent: 0,
            bytesReceived: 0,
            uptime: 0,
            lastHandshake: nil
        )
        XCTAssertEqual(status.formattedLatency, "45 ms")
    }

    func testFormattedLatencyNil() {
        let status = ConnectionStatus(
            connectedIP: "1.2.3.4",
            latency: nil,
            bytesSent: 0,
            bytesReceived: 0,
            uptime: 0,
            lastHandshake: nil
        )
        XCTAssertEqual(status.formattedLatency, "N/A")
    }

    func testFormattedUptime_seconds() {
        let status = ConnectionStatus(
            connectedIP: "1.2.3.4",
            latency: nil,
            bytesSent: 0,
            bytesReceived: 0,
            uptime: 45,
            lastHandshake: nil
        )
        XCTAssertEqual(status.formattedUptime, "45s")
    }

    func testFormattedUptime_minutes() {
        let status = ConnectionStatus(
            connectedIP: "1.2.3.4",
            latency: nil,
            bytesSent: 0,
            bytesReceived: 0,
            uptime: 125,
            lastHandshake: nil
        )
        XCTAssertEqual(status.formattedUptime, "2m 5s")
    }

    func testFormattedUptime_hours() {
        let status = ConnectionStatus(
            connectedIP: "1.2.3.4",
            latency: nil,
            bytesSent: 0,
            bytesReceived: 0,
            uptime: 3725,
            lastHandshake: nil
        )
        XCTAssertEqual(status.formattedUptime, "1h 2m 5s")
    }

    func testFormattedBytes() {
        let status = ConnectionStatus(
            connectedIP: "1.2.3.4",
            latency: nil,
            bytesSent: 1048576,
            bytesReceived: 2097152,
            uptime: 0,
            lastHandshake: nil
        )
        XCTAssertEqual(status.formattedBytesSent, "1 MB")
        XCTAssertEqual(status.formattedBytesReceived, "2 MB")
    }

    func testHandshakeStale_nilHandshake() {
        let status = ConnectionStatus(
            connectedIP: "1.2.3.4",
            latency: nil,
            bytesSent: 0,
            bytesReceived: 0,
            uptime: 0,
            lastHandshake: nil
        )
        XCTAssertTrue(status.isHandshakeStale)
    }

    func testHandshakeStale_recentHandshake() {
        let status = ConnectionStatus(
            connectedIP: "1.2.3.4",
            latency: nil,
            bytesSent: 0,
            bytesReceived: 0,
            uptime: 0,
            lastHandshake: Date()
        )
        XCTAssertFalse(status.isHandshakeStale)
    }

    func testHandshakeStale_oldHandshake() {
        let status = ConnectionStatus(
            connectedIP: "1.2.3.4",
            latency: nil,
            bytesSent: 0,
            bytesReceived: 0,
            uptime: 0,
            lastHandshake: Date().addingTimeInterval(-300)
        )
        XCTAssertTrue(status.isHandshakeStale)
    }
}
