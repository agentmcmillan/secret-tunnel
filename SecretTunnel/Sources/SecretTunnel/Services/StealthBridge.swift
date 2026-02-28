import Foundation
import Network

/// Bridges local UDP traffic to a remote TCP+TLS connection for stealth mode.
/// WireGuard sends UDP packets to 127.0.0.1:localPort, which this bridge
/// wraps in TLS and forwards to the remote stunnel server on TCP 443.
class StealthBridge {
    private var listener: NWListener?
    private var tcpConnection: NWConnection?
    private var udpConnection: NWConnection?
    private let queue = DispatchQueue(label: "com.secrettunnel.stealthbridge")

    let localPort: UInt16
    let remoteHost: String
    let remotePort: UInt16

    private(set) var isRunning = false

    init(localPort: UInt16 = 51821, remoteHost: String, remotePort: UInt16 = 443) {
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
    }

    func start() async throws {
        guard !isRunning else { return }

        Log.tunnel.info("StealthBridge: Starting UDP:\(self.localPort) -> TLS:\(self.remoteHost):\(self.remotePort)")

        // Create TLS TCP connection to remote stunnel server
        let tlsParams = NWProtocolTLS.Options()
        // Accept self-signed cert from stunnel (server uses auto-generated cert)
        sec_protocol_options_set_verify_block(tlsParams.securityProtocolOptions, { _, _, completionHandler in
            completionHandler(true)
        }, queue)

        let tcpParams = NWProtocolTCP.Options()
        tcpParams.enableKeepalive = true
        tcpParams.keepaliveInterval = 25

        let params = NWParameters(tls: tlsParams, tcp: tcpParams)
        let host = NWEndpoint.Host(remoteHost)
        let port = NWEndpoint.Port(rawValue: remotePort)!

        tcpConnection = NWConnection(host: host, port: port, using: params)

        // Wait for TCP connection to be ready
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false
            tcpConnection?.stateUpdateHandler = { [weak self] state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    Log.tunnel.info("StealthBridge: TLS connection established")
                    continuation.resume()
                case .failed(let error):
                    resumed = true
                    Log.tunnel.error("StealthBridge: TLS connection failed: \(error)")
                    continuation.resume(throwing: error)
                case .cancelled:
                    resumed = true
                    continuation.resume(throwing: NWError.posix(.ECANCELED))
                default:
                    break
                }
            }
            tcpConnection?.start(queue: queue)
        }

        // Start local UDP listener for WireGuard packets
        let udpParams = NWParameters.udp
        listener = try NWListener(using: udpParams, on: NWEndpoint.Port(rawValue: localPort)!)

        listener?.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            self.handleUDPConnection(connection)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false
            listener?.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    Log.tunnel.info("StealthBridge: UDP listener ready on port \(self.localPort)")
                    continuation.resume()
                case .failed(let error):
                    resumed = true
                    Log.tunnel.error("StealthBridge: UDP listener failed: \(error)")
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener?.start(queue: queue)
        }

        isRunning = true
        startReceivingFromTCP()
        Log.tunnel.info("StealthBridge: Running")
    }

    func stop() {
        Log.tunnel.info("StealthBridge: Stopping")
        isRunning = false
        listener?.cancel()
        listener = nil
        tcpConnection?.cancel()
        tcpConnection = nil
        udpConnection?.cancel()
        udpConnection = nil
    }

    // MARK: - UDP → TCP forwarding

    private func handleUDPConnection(_ connection: NWConnection) {
        // Keep track of the most recent UDP "connection" (WireGuard source)
        self.udpConnection?.cancel()
        self.udpConnection = connection

        connection.stateUpdateHandler = { state in
            if case .ready = state {
                self.receiveUDPPackets(from: connection)
            }
        }
        connection.start(queue: queue)
    }

    private func receiveUDPPackets(from connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self, self.isRunning else { return }

            if let data, !data.isEmpty {
                self.sendToTCP(data)
            }

            if error == nil {
                self.receiveUDPPackets(from: connection)
            }
        }
    }

    private func sendToTCP(_ data: Data) {
        // Frame the UDP packet with a 2-byte length prefix for TCP stream
        var length = UInt16(data.count).bigEndian
        var framed = Data(bytes: &length, count: 2)
        framed.append(data)

        tcpConnection?.send(content: framed, completion: .contentProcessed({ error in
            if let error {
                Log.tunnel.warning("StealthBridge: TCP send error: \(error)")
            }
        }))
    }

    // MARK: - TCP → UDP forwarding

    private func startReceivingFromTCP() {
        receiveLengthPrefix()
    }

    private func receiveLengthPrefix() {
        tcpConnection?.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] data, _, _, error in
            guard let self, self.isRunning else { return }

            if let data, data.count == 2 {
                let length = Int(data.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian })
                self.receivePayload(length: length)
            } else if let error {
                Log.tunnel.warning("StealthBridge: TCP receive error: \(error)")
            }
        }
    }

    private func receivePayload(length: Int) {
        tcpConnection?.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, _, error in
            guard let self, self.isRunning else { return }

            if let data, !data.isEmpty {
                self.sendToUDP(data)
            }

            if error == nil {
                self.receiveLengthPrefix()
            } else {
                Log.tunnel.warning("StealthBridge: TCP payload receive error: \(String(describing: error))")
            }
        }
    }

    private func sendToUDP(_ data: Data) {
        udpConnection?.send(content: data, completion: .contentProcessed({ error in
            if let error {
                Log.tunnel.warning("StealthBridge: UDP send error: \(error)")
            }
        }))
    }
}
