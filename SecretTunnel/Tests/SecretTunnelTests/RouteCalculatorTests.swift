import XCTest
@testable import SecretTunnel

final class RouteCalculatorTests: XCTestCase {

    func testParseIP() {
        XCTAssertEqual(RouteCalculator.parseIP("0.0.0.0"), 0)
        XCTAssertEqual(RouteCalculator.parseIP("255.255.255.255"), UInt32.max)
        XCTAssertEqual(RouteCalculator.parseIP("192.168.1.0"), 0xC0A80100)
        XCTAssertEqual(RouteCalculator.parseIP("10.0.0.0"), 0x0A000000)
        XCTAssertNil(RouteCalculator.parseIP("invalid"))
        XCTAssertNil(RouteCalculator.parseIP("1.2.3"))
    }

    func testIPToString() {
        XCTAssertEqual(RouteCalculator.ipToString(0), "0.0.0.0")
        XCTAssertEqual(RouteCalculator.ipToString(UInt32.max), "255.255.255.255")
        XCTAssertEqual(RouteCalculator.ipToString(0xC0A80100), "192.168.1.0")
    }

    func testParseCIDR() {
        let result = RouteCalculator.parseCIDR("192.168.1.0/24")
        XCTAssertNotNil(result)
        if let (network, mask) = result {
            XCTAssertEqual(network, 0xC0A80100)
            XCTAssertEqual(mask, 0xFFFFFF00)
        }

        let single = RouteCalculator.parseCIDR("10.0.0.1/32")
        XCTAssertNotNil(single)
        if let (_, mask) = single {
            XCTAssertEqual(mask, UInt32.max)
        }

        XCTAssertNil(RouteCalculator.parseCIDR("invalid"))
    }

    func testRangeToCIDRsSingleBlock() {
        // 192.168.1.0 to 192.168.1.255 = /24
        let cidrs = RouteCalculator.rangeToCIDRs(start: 0xC0A80100, end: 0xC0A801FF)
        XCTAssertEqual(cidrs, ["192.168.1.0/24"])
    }

    func testExcludeSingleSubnet() {
        // Exclude 10.0.0.0/8 from 0.0.0.0/0
        let result = RouteCalculator.allowedIPsExcluding(["10.0.0.0/8"])
        // Should NOT contain anything in 10.x.x.x range
        XCTAssertFalse(result.contains("10.0.0.0"))
        // Should contain routes that cover 0.0.0.0-9.255.255.255 and 11.0.0.0-255.255.255.255
        XCTAssertTrue(result.contains("0.0.0.0/5"))
        XCTAssertTrue(result.contains("11.0.0.0/8"))
    }

    func testExcludeMultipleSubnets() {
        let result = RouteCalculator.allowedIPsExcluding(["10.0.0.0/8", "192.168.0.0/16"])
        XCTAssertFalse(result.contains("10.0.0.0"))
        XCTAssertFalse(result.contains("192.168.0.0"))
    }

    func testExcludeEmptyList() {
        let result = RouteCalculator.allowedIPsExcluding([])
        XCTAssertEqual(result, "0.0.0.0/0")
    }

    func testExcludeInvalidCIDR() {
        // Invalid entries should be skipped
        let result = RouteCalculator.allowedIPsExcluding(["invalid", "10.0.0.0/8"])
        XCTAssertFalse(result.contains("10.0.0.0"))
    }

    func testExcludeSingleHost() {
        let result = RouteCalculator.allowedIPsExcluding(["192.168.1.1/32"])
        XCTAssertFalse(result.isEmpty)
        // The result should be a set of CIDRs that cover everything except 192.168.1.1
    }
}
