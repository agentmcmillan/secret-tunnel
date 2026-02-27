import XCTest
@testable import SecretTunnel

final class AppErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertTrue(AppError.instanceStartFailed("timeout").localizedDescription.contains("timeout"))
        XCTAssertTrue(AppError.instanceStopFailed("busy").localizedDescription.contains("busy"))
        XCTAssertTrue(AppError.headscaleTimeout.localizedDescription.contains("Headscale"))
        XCTAssertTrue(AppError.headscaleUnreachable("offline").localizedDescription.contains("offline"))
        XCTAssertTrue(AppError.tunnelFailed("config").localizedDescription.contains("config"))
        XCTAssertTrue(AppError.configurationMissing("API Key").localizedDescription.contains("API Key"))
        XCTAssertTrue(AppError.networkError("dns").localizedDescription.contains("dns"))
        XCTAssertTrue(AppError.authenticationFailed.localizedDescription.contains("Authentication"))
        XCTAssertTrue(AppError.timeout.localizedDescription.contains("timed out"))
        XCTAssertTrue(AppError.unknownError("oops").localizedDescription.contains("oops"))
    }

    func testEquality() {
        XCTAssertEqual(AppError.headscaleTimeout, AppError.headscaleTimeout)
        XCTAssertEqual(AppError.tunnelFailed("a"), AppError.tunnelFailed("a"))
        XCTAssertNotEqual(AppError.tunnelFailed("a"), AppError.tunnelFailed("b"))
        XCTAssertEqual(AppError.authenticationFailed, AppError.authenticationFailed)
    }
}
