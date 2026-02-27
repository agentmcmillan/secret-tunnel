import XCTest
@testable import SecretTunnel

final class WireGuardConfigTests: XCTestCase {

    func testPeerToWgQuickConfig() {
        let peer = WireGuardPeer(
            publicKey: "testPublicKey123=",
            endpoint: "1.2.3.4:51820",
            allowedIPs: "0.0.0.0/0",
            persistentKeepalive: 25
        )

        let config = peer.toWgQuickConfig()
        XCTAssertTrue(config.contains("[Peer]"))
        XCTAssertTrue(config.contains("PublicKey = testPublicKey123="))
        XCTAssertTrue(config.contains("Endpoint = 1.2.3.4:51820"))
        XCTAssertTrue(config.contains("AllowedIPs = 0.0.0.0/0"))
        XCTAssertTrue(config.contains("PersistentKeepalive = 25"))
    }

    func testPeerWithoutEndpoint() {
        let peer = WireGuardPeer(
            publicKey: "testKey=",
            endpoint: nil,
            allowedIPs: "192.168.0.0/20",
            persistentKeepalive: 25
        )

        let config = peer.toWgQuickConfig()
        XCTAssertFalse(config.contains("Endpoint"))
    }

    func testWireGuardConfigToWgQuick() {
        let config = WireGuardConfig(
            privateKey: "privateKeyBase64=",
            address: "100.64.0.1/32",
            dns: "1.1.1.1",
            peers: [
                WireGuardPeer(
                    publicKey: "serverKey=",
                    endpoint: "1.2.3.4:51820",
                    allowedIPs: "0.0.0.0/0",
                    persistentKeepalive: 25
                )
            ]
        )

        let wgQuick = config.toWgQuickConfig()
        XCTAssertTrue(wgQuick.contains("[Interface]"))
        XCTAssertTrue(wgQuick.contains("PrivateKey = privateKeyBase64="))
        XCTAssertTrue(wgQuick.contains("Address = 100.64.0.1/32"))
        XCTAssertTrue(wgQuick.contains("DNS = 1.1.1.1"))
        XCTAssertTrue(wgQuick.contains("[Peer]"))
        XCTAssertTrue(wgQuick.contains("PublicKey = serverKey="))
    }

    func testWireGuardConfigWithoutDNS() {
        let config = WireGuardConfig(
            privateKey: "key=",
            address: "100.64.0.1/32",
            dns: nil,
            peers: []
        )

        let wgQuick = config.toWgQuickConfig()
        XCTAssertFalse(wgQuick.contains("DNS"))
    }

    func testServerEndpoint() {
        let config = WireGuardConfig(
            privateKey: "key=",
            address: "100.64.0.1/32",
            peers: [
                WireGuardPeer(
                    publicKey: "pk=",
                    endpoint: "5.6.7.8:51820",
                    allowedIPs: "0.0.0.0/0",
                    persistentKeepalive: 25
                )
            ]
        )

        XCTAssertEqual(config.serverEndpoint, "5.6.7.8:51820")
    }

    func testServerEndpointEmpty() {
        let config = WireGuardConfig(
            privateKey: "key=",
            address: "100.64.0.1/32",
            peers: []
        )

        XCTAssertEqual(config.serverEndpoint, "")
    }

    func testMultiplePeers() {
        let config = WireGuardConfig(
            privateKey: "key=",
            address: "100.64.0.1/32",
            dns: "1.1.1.1",
            peers: [
                WireGuardPeer(publicKey: "awsKey=", endpoint: "1.2.3.4:51820", allowedIPs: "0.0.0.0/1, 128.0.0.0/1", persistentKeepalive: 25),
                WireGuardPeer(publicKey: "nasKey=", endpoint: nil, allowedIPs: "192.168.0.0/20", persistentKeepalive: 25)
            ]
        )

        let wgQuick = config.toWgQuickConfig()
        XCTAssertTrue(wgQuick.contains("PublicKey = awsKey="))
        XCTAssertTrue(wgQuick.contains("PublicKey = nasKey="))
        XCTAssertTrue(wgQuick.contains("AllowedIPs = 192.168.0.0/20"))
    }
}
