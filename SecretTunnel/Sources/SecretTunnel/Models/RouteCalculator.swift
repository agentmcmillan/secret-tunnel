import Foundation

/// Calculates WireGuard AllowedIPs by subtracting excluded CIDRs from the full IPv4 range.
/// WireGuard routes traffic based on AllowedIPs — to exclude specific subnets,
/// we split 0.0.0.0/0 into the complementary set that doesn't include the exclusions.
enum RouteCalculator {

    /// Given a list of CIDR exclusions, returns the AllowedIPs string that covers
    /// all of 0.0.0.0/0 EXCEPT the excluded ranges.
    static func allowedIPsExcluding(_ exclusions: [String]) -> String {
        // Start with the full IPv4 range
        var ranges: [(UInt32, UInt32)] = [(0, UInt32.max)]

        for exclusion in exclusions {
            guard let (network, mask) = parseCIDR(exclusion) else { continue }
            let start = network & mask
            let end = start | ~mask

            ranges = ranges.flatMap { range -> [(UInt32, UInt32)] in
                subtract(range: range, exclude: (start, end))
            }
        }

        // Convert remaining ranges back to CIDRs
        let cidrs = ranges.flatMap { rangeToCIDRs(start: $0.0, end: $0.1) }
        return cidrs.joined(separator: ", ")
    }

    /// Parse a CIDR string like "192.168.1.0/24" into (network, mask) as UInt32
    static func parseCIDR(_ cidr: String) -> (UInt32, UInt32)? {
        let parts = cidr.split(separator: "/")
        guard let ipStr = parts.first,
              let ip = parseIP(String(ipStr)) else { return nil }

        let prefixLen: Int
        if parts.count == 2, let p = Int(parts[1]) {
            prefixLen = p
        } else {
            prefixLen = 32
        }

        guard prefixLen >= 0 && prefixLen <= 32 else { return nil }

        let mask: UInt32 = prefixLen == 0 ? 0 : ~UInt32(0) << (32 - prefixLen)
        return (ip, mask)
    }

    /// Parse dotted-quad IP to UInt32
    static func parseIP(_ ip: String) -> UInt32? {
        let octets = ip.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { return nil }
        return (UInt32(octets[0]) << 24) | (UInt32(octets[1]) << 16) |
               (UInt32(octets[2]) << 8) | UInt32(octets[3])
    }

    /// Convert UInt32 to dotted-quad string
    static func ipToString(_ ip: UInt32) -> String {
        "\(ip >> 24 & 0xFF).\(ip >> 16 & 0xFF).\(ip >> 8 & 0xFF).\(ip & 0xFF)"
    }

    /// Subtract an exclusion range from a given range, returning 0-2 remaining ranges
    private static func subtract(range: (UInt32, UInt32), exclude: (UInt32, UInt32)) -> [(UInt32, UInt32)] {
        let (rStart, rEnd) = range
        let (eStart, eEnd) = exclude

        // No overlap
        if eStart > rEnd || eEnd < rStart {
            return [range]
        }

        var result: [(UInt32, UInt32)] = []

        // Part before the exclusion
        if eStart > rStart {
            result.append((rStart, eStart - 1))
        }

        // Part after the exclusion
        if eEnd < rEnd {
            result.append((eEnd + 1, rEnd))
        }

        return result
    }

    /// Convert a contiguous IP range to the minimal set of CIDR blocks
    static func rangeToCIDRs(start: UInt32, end: UInt32) -> [String] {
        var cidrs: [String] = []
        var current = start

        while current <= end {
            // Find the largest CIDR block starting at 'current' that fits within [current, end]
            let trailingZeros = current == 0 ? 32 : Int(current.trailingZeroBitCount)
            var maxBits = min(trailingZeros, 32)

            // Ensure the block doesn't extend past 'end'
            while maxBits > 0 {
                let blockSize = UInt64(1) << maxBits
                if UInt64(current) + blockSize - 1 <= UInt64(end) {
                    break
                }
                maxBits -= 1
            }

            let prefix = 32 - maxBits
            cidrs.append("\(ipToString(current))/\(prefix)")

            let blockSize = UInt64(1) << maxBits
            let next = UInt64(current) + blockSize
            if next > UInt64(UInt32.max) {
                break
            }
            current = UInt32(next)
        }

        return cidrs
    }
}
