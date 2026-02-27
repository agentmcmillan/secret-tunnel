import XCTest
@testable import SecretTunnel

final class ConstantsTests: XCTestCase {

    func testPricingHourlyRate() {
        XCTAssertEqual(Constants.Pricing.hourlyRate(for: "t3.micro"), 0.0104)
        XCTAssertEqual(Constants.Pricing.hourlyRate(for: "t3.small"), 0.0208)
        XCTAssertEqual(Constants.Pricing.hourlyRate(for: "t4g.micro"), 0.0084)
    }

    func testPricingFallbackRate() {
        XCTAssertEqual(Constants.Pricing.hourlyRate(for: "unknown.type"), 0.0104)
    }

    func testPersistentMonthlyCost() {
        let expected = Constants.Pricing.elasticIPMonthly + (Constants.Pricing.ebsPerGBMonthly * Constants.Pricing.defaultVolumeGB)
        XCTAssertEqual(Constants.Pricing.persistentMonthlyCost, expected, accuracy: 0.01)
    }

    func testEstimatedMonthlyCost() {
        let cost = Constants.Pricing.estimatedMonthlyCost(instanceType: "t3.micro", hoursPerDay: 2)
        let expectedCompute = 0.0104 * 2 * 30.0
        let expected = Constants.Pricing.persistentMonthlyCost + expectedCompute
        XCTAssertEqual(cost, expected, accuracy: 0.01)
    }

    func testFormatCost() {
        XCTAssertEqual(Constants.Pricing.formatCost(4.29), "$4.29")
        XCTAssertEqual(Constants.Pricing.formatCost(0.0), "$0.00")
    }

    func testFormatRate() {
        XCTAssertEqual(Constants.Pricing.formatRate(0.0104), "$0.0104/hr")
    }

    func testBundleIdentifiers() {
        XCTAssertEqual(Constants.bundleIdentifier, "com.secrettunnel.vpn")
        XCTAssertEqual(Constants.tunnelBundleIdentifier, "com.secrettunnel.vpn.tunnel")
        XCTAssertEqual(Constants.appGroupIdentifier, "group.com.secrettunnel.vpn")
    }

    func testWireGuardDefaults() {
        XCTAssertEqual(Constants.WireGuard.port, 51820)
        XCTAssertEqual(Constants.WireGuard.persistentKeepalive, 25)
    }

    func testHomeNetworkDefaults() {
        XCTAssertEqual(Constants.HomeNetwork.defaultSubnet, "192.168.0.0/20")
        XCTAssertEqual(Constants.HomeNetwork.defaultDNS, "192.168.1.1")
    }
}
