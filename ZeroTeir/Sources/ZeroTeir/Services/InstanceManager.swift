import Foundation

class InstanceManager {
    let apiEndpoint: URL
    let apiKey: String

    enum InstanceError: Error {
        case invalidResponse
        case networkError(Error)
        case authenticationFailed
        case timeout
        case serverError(String)
    }

    init(apiEndpoint: URL, apiKey: String) {
        self.apiEndpoint = apiEndpoint
        self.apiKey = apiKey
    }

    func start(instanceType: String? = nil) async throws -> InstanceInfo {
        Log.instance.info("Starting instance...")

        let endpoint = apiEndpoint.appendingPathComponent("instance/start")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Constants.Timeouts.instanceStart

        if let instanceType {
            let body = ["instanceType": instanceType]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let response: InstanceStartResponse = try await performRequestWithRetry(request)

        let instanceInfo = InstanceInfo(
            instanceId: response.instanceId,
            status: .running,
            publicIp: response.publicIp,
            privateIp: nil
        )

        Log.instance.info("Instance started: \(response.instanceId), IP: \(response.publicIp)")
        return instanceInfo
    }

    func stop() async throws {
        Log.instance.info("Stopping instance...")

        let endpoint = apiEndpoint.appendingPathComponent("instance/stop")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = Constants.Timeouts.apiRequest

        let _: InstanceStopResponse = try await performRequestWithRetry(request)
        Log.instance.info("Instance stopped")
    }

    func getStatus() async throws -> InstanceInfo {
        Log.instance.info("Getting instance status...")

        let endpoint = apiEndpoint.appendingPathComponent("instance/status")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = Constants.Timeouts.apiRequest

        let response: InstanceStatusResponse = try await performRequestWithRetry(request)

        let instanceInfo = InstanceInfo(
            instanceId: response.instanceId,
            status: InstanceInfo.InstanceStatus(rawValue: response.status.lowercased()) ?? .unknown,
            publicIp: response.publicIp,
            privateIp: response.privateIp
        )

        Log.instance.info("Instance status: \(response.status)")
        return instanceInfo
    }

    private func performRequestWithRetry<T: Decodable>(_ request: URLRequest) async throws -> T {
        var lastError: Error?

        for attempt in 1...Constants.Retry.maxAttempts {
            do {
                return try await performRequest(request)
            } catch {
                lastError = error
                Log.api.warning("Request failed (attempt \(attempt)/\(Constants.Retry.maxAttempts)): \(error.localizedDescription)")

                if attempt < Constants.Retry.maxAttempts {
                    let delay = Constants.Retry.initialDelay * pow(Constants.Retry.backoffMultiplier, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? InstanceError.timeout
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstanceError.invalidResponse
        }

        Log.api.debug("Response status: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                return decoded
            } catch {
                Log.api.error("Failed to decode response: \(error.localizedDescription)")
                throw InstanceError.invalidResponse
            }
        case 401, 403:
            throw InstanceError.authenticationFailed
        case 400...499:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown client error"
            throw InstanceError.serverError(errorMessage)
        case 500...599:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw InstanceError.serverError(errorMessage)
        default:
            throw InstanceError.invalidResponse
        }
    }
}
