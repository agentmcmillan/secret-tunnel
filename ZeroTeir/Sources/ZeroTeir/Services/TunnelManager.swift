import Foundation

class TunnelManager {
    enum TunnelError: Error {
        case wireguardNotInstalled
        case configWriteFailed
        case connectionFailed(String)
        case disconnectionFailed(String)
        case permissionDenied
        case invalidStats
    }

    private let configPath: URL
    private let interfaceName = Constants.WireGuard.interface

    init() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let configDirectory = homeDirectory.appendingPathComponent(Constants.configDirectory)
        self.configPath = configDirectory.appendingPathComponent(Constants.wireguardConfigName)

        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
    }

    func connect(config: WireGuardConfig) async throws {
        Log.tunnel.info("Connecting WireGuard tunnel...")

        try checkWireGuardInstalled()

        let configContent = config.toConfigFile()
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        Log.tunnel.info("WireGuard config written to: \(self.configPath.path)")

        let result = try await runWireGuardCommand(["up", configPath.path])

        if !result.success {
            Log.tunnel.error("Failed to bring up WireGuard tunnel: \(result.output)")
            throw TunnelError.connectionFailed(result.output)
        }

        Log.tunnel.info("WireGuard tunnel connected successfully")
    }

    func disconnect() async throws {
        Log.tunnel.info("Disconnecting WireGuard tunnel...")

        let result = try await runWireGuardCommand(["down", interfaceName])

        if !result.success {
            Log.tunnel.warning("Failed to bring down WireGuard tunnel: \(result.output)")
            throw TunnelError.disconnectionFailed(result.output)
        }

        Log.tunnel.info("WireGuard tunnel disconnected successfully")
    }

    func getStats() async throws -> WireGuardStats {
        let result = try await runCommand("/usr/local/bin/wg", arguments: ["show", interfaceName, "dump"])

        guard result.success else {
            throw TunnelError.invalidStats
        }

        let lines = result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else {
            throw TunnelError.invalidStats
        }

        let peerLine = lines[1]
        let fields = peerLine.components(separatedBy: .whitespaces)

        guard fields.count >= 6 else {
            throw TunnelError.invalidStats
        }

        let bytesReceived = UInt64(fields[5]) ?? 0
        let bytesSent = UInt64(fields[6]) ?? 0

        var lastHandshake: Date?
        if let timestamp = TimeInterval(fields[4]), timestamp > 0 {
            lastHandshake = Date(timeIntervalSince1970: timestamp)
        }

        let endpoint = fields.count > 3 ? fields[3] : nil

        return WireGuardStats(
            bytesSent: bytesSent,
            bytesReceived: bytesReceived,
            lastHandshake: lastHandshake,
            endpoint: endpoint
        )
    }

    func checkWireGuardInstalled() throws {
        let fileManager = FileManager.default
        let possiblePaths = [
            "/usr/local/bin/wg-quick",
            "/opt/homebrew/bin/wg-quick"
        ]

        let installed = possiblePaths.contains { fileManager.isExecutableFile(atPath: $0) }

        if !installed {
            Log.tunnel.error("WireGuard tools not found. Install via: brew install wireguard-tools")
            throw TunnelError.wireguardNotInstalled
        }
    }

    private func runWireGuardCommand(_ arguments: [String]) async throws -> CommandResult {
        let possiblePaths = [
            "/usr/local/bin/wg-quick",
            "/opt/homebrew/bin/wg-quick"
        ]

        guard let wgQuickPath = possiblePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw TunnelError.wireguardNotInstalled
        }

        let sudoScript = """
        do shell script "\(wgQuickPath) \(arguments.joined(separator: " "))" with administrator privileges
        """

        return try await runAppleScript(sudoScript)
    }

    private func runAppleScript(_ script: String) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        let combinedOutput = output + error

        return CommandResult(
            success: process.terminationStatus == 0,
            output: combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func runCommand(_ command: String, arguments: [String]) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        return CommandResult(
            success: process.terminationStatus == 0,
            output: (output + error).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

struct CommandResult {
    let success: Bool
    let output: String
}
