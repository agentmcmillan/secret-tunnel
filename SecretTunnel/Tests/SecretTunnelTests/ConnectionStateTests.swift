import XCTest
@testable import SecretTunnel

final class ConnectionStateTests: XCTestCase {

    func testDisplayNames() {
        XCTAssertEqual(ConnectionState.disconnected.displayName, "Disconnected")
        XCTAssertEqual(ConnectionState.connected.displayName, "Connected")
        XCTAssertEqual(ConnectionState.startingInstance.displayName, "Starting instance...")
        XCTAssertEqual(ConnectionState.waitingForHeadscale.displayName, "Waiting for Headscale...")
        XCTAssertEqual(ConnectionState.connectingTunnel.displayName, "Connecting tunnel...")
        XCTAssertEqual(ConnectionState.disconnecting.displayName, "Disconnecting...")
    }

    func testIsConnecting() {
        XCTAssertTrue(ConnectionState.startingInstance.isConnecting)
        XCTAssertTrue(ConnectionState.waitingForHeadscale.isConnecting)
        XCTAssertTrue(ConnectionState.connectingTunnel.isConnecting)
        XCTAssertFalse(ConnectionState.disconnected.isConnecting)
        XCTAssertFalse(ConnectionState.connected.isConnecting)
        XCTAssertFalse(ConnectionState.disconnecting.isConnecting)
    }

    func testIsConnected() {
        XCTAssertTrue(ConnectionState.connected.isConnected)
        XCTAssertFalse(ConnectionState.disconnected.isConnected)
        XCTAssertFalse(ConnectionState.startingInstance.isConnected)
        XCTAssertFalse(ConnectionState.error(.timeout).isConnected)
    }

    func testErrorDisplayName() {
        let state = ConnectionState.error(.headscaleTimeout)
        XCTAssertTrue(state.displayName.contains("Headscale"))
    }

    func testEquality() {
        XCTAssertEqual(ConnectionState.connected, ConnectionState.connected)
        XCTAssertNotEqual(ConnectionState.connected, ConnectionState.disconnected)
        XCTAssertEqual(
            ConnectionState.error(.headscaleTimeout),
            ConnectionState.error(.headscaleTimeout)
        )
    }
}
