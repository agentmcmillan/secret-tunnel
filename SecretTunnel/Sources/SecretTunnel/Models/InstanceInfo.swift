import Foundation

struct InstanceInfo: Codable, Equatable {
    let instanceId: String
    let status: InstanceStatus
    let publicIp: String?
    let privateIp: String?

    enum InstanceStatus: String, Codable {
        case pending
        case running
        case stopping
        case stopped
        case terminated
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = InstanceStatus(rawValue: rawValue.lowercased()) ?? .unknown
        }
    }
}

struct InstanceStartResponse: Codable {
    let instanceId: String
    let publicIp: String
    let status: String
}

struct InstanceStatusResponse: Codable {
    let instanceId: String
    let status: String
    let publicIp: String?
    let privateIp: String?
}

struct InstanceStopResponse: Codable {
    let instanceId: String
    let status: String
}
