import SwiftUI

struct StatusView: View {
    let status: ConnectionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Details")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Status:")
                        .foregroundColor(.secondary)
                    Text("Connected")
                        .foregroundColor(.green)
                }

                GridRow {
                    Text("IP Address:")
                        .foregroundColor(.secondary)
                    Text(status.connectedIP)
                }

                GridRow {
                    Text("Latency:")
                        .foregroundColor(.secondary)
                    Text(status.formattedLatency)
                }

                GridRow {
                    Text("Data Sent:")
                        .foregroundColor(.secondary)
                    Text(status.formattedBytesSent)
                }

                GridRow {
                    Text("Data Received:")
                        .foregroundColor(.secondary)
                    Text(status.formattedBytesReceived)
                }

                GridRow {
                    Text("Uptime:")
                        .foregroundColor(.secondary)
                    Text(status.formattedUptime)
                }

                if let lastHandshake = status.lastHandshake {
                    GridRow {
                        Text("Last Handshake:")
                            .foregroundColor(.secondary)
                        Text(lastHandshake, style: .relative)
                    }
                }
            }
            .font(.system(.body, design: .monospaced))
        }
        .padding()
    }
}
