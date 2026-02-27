import Foundation

struct Machine: Codable {
    let id: String
    let name: String
    let nodeKey: String?
    let ipAddresses: [String]?
}

struct Route: Codable {
    let id: String
    let machineId: String?
    let prefix: String
    let enabled: Bool
}

struct PreAuthKey: Codable {
    let id: String
    let key: String
    let reusable: Bool
    let ephemeral: Bool
    let used: Bool
    let expiration: String
    let createdAt: String
}

struct MachinesResponse: Codable {
    let machines: [Machine]
}

struct RoutesResponse: Codable {
    let routes: [Route]
}

struct PreAuthKeyRequest: Codable {
    let user: String
    let reusable: Bool
    let ephemeral: Bool
    let expiration: String?
}

struct PreAuthKeyResponse: Codable {
    let preAuthKey: PreAuthKey
}

class HeadscaleClient {
    let serverURL: URL
    let apiKey: String

    enum HeadscaleError: Error {
        case invalidResponse
        case networkError(Error)
        case authenticationFailed
        case serverError(String)
        case timeout
    }

    init(serverURL: URL, apiKey: String) {
        self.serverURL = serverURL
        self.apiKey = apiKey
    }

    func checkHealth() async throws -> Bool {
        Log.api.info("Checking Headscale health...")

        let endpoint = serverURL.appendingPathComponent("health")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            let isHealthy = httpResponse.statusCode == 200
            Log.api.info("Headscale health check: \(isHealthy ? "healthy" : "unhealthy")")
            return isHealthy
        } catch {
            Log.api.error("Headscale health check failed: \(error.localizedDescription)")
            return false
        }
    }

    func listMachines() async throws -> [Machine] {
        Log.api.info("Listing Headscale machines...")

        let endpoint = serverURL.appendingPathComponent("api/v1/machine")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = Constants.Timeouts.apiRequest

        let response: MachinesResponse = try await performRequestWithRetry(request)
        Log.api.info("Found \(response.machines.count) machines")
        return response.machines
    }

    func getRoutes() async throws -> [Route] {
        Log.api.info("Getting Headscale routes...")

        let endpoint = serverURL.appendingPathComponent("api/v1/routes")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = Constants.Timeouts.apiRequest

        let response: RoutesResponse = try await performRequestWithRetry(request)
        Log.api.info("Found \(response.routes.count) routes")
        return response.routes
    }

    func createPreAuthKey(user: String, reusable: Bool = false, expiration: Date? = nil) async throws -> PreAuthKey {
        Log.api.info("Creating Headscale pre-auth key for user: \(user)")

        let endpoint = serverURL.appendingPathComponent("api/v1/preauthkey")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Constants.Timeouts.apiRequest

        let expirationString: String?
        if let expiration = expiration {
            let formatter = ISO8601DateFormatter()
            expirationString = formatter.string(from: expiration)
        } else {
            expirationString = nil
        }

        let requestBody = PreAuthKeyRequest(
            user: user,
            reusable: reusable,
            ephemeral: false,
            expiration: expirationString
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let response: PreAuthKeyResponse = try await performRequestWithRetry(request)
        Log.api.info("Created pre-auth key: \(response.preAuthKey.id)")
        return response.preAuthKey
    }

    private func performRequestWithRetry<T: Decodable>(_ request: URLRequest) async throws -> T {
        var lastError: Error?

        for attempt in 1...Constants.Retry.maxAttempts {
            do {
                return try await performRequest(request)
            } catch {
                lastError = error
                Log.api.warning("Headscale request failed (attempt \(attempt)/\(Constants.Retry.maxAttempts)): \(error.localizedDescription)")

                if attempt < Constants.Retry.maxAttempts {
                    let delay = Constants.Retry.initialDelay * pow(Constants.Retry.backoffMultiplier, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? HeadscaleError.timeout
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HeadscaleError.invalidResponse
        }

        Log.api.debug("Headscale response status: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                return decoded
            } catch {
                Log.api.error("Failed to decode Headscale response: \(error.localizedDescription)")
                if let responseString = String(data: data, encoding: .utf8) {
                    Log.api.debug("Response body: \(responseString)")
                }
                throw HeadscaleError.invalidResponse
            }
        case 401, 403:
            throw HeadscaleError.authenticationFailed
        case 400...499:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown client error"
            throw HeadscaleError.serverError(errorMessage)
        case 500...599:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw HeadscaleError.serverError(errorMessage)
        default:
            throw HeadscaleError.invalidResponse
        }
    }
}
