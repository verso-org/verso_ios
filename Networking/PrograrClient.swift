import Foundation

final class PrograrClient: @unchecked Sendable {
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    let baseURL: String
    let apiKey: String?

    init(baseURL: String = "", apiKey: String? = nil) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    var isConfigured: Bool {
        !baseURL.isEmpty
    }

    // MARK: - All Requests

    func getRequests() async throws -> [PrograrMediaRequest] {
        let url = try buildURL(path: "/api/requests")
        let data = try await authenticatedGet(url: url)
        return try decoder.decode([PrograrMediaRequest].self, from: data)
    }

    // MARK: - Requests by TMDB ID

    func getRequests(tmdbId: Int) async throws -> [PrograrMediaRequest] {
        let url = try buildURL(path: "/api/requests", queryItems: [
            URLQueryItem(name: "tmdbId", value: "\(tmdbId)")
        ])
        let data = try await authenticatedGet(url: url)
        return try decoder.decode([PrograrMediaRequest].self, from: data)
    }

    // MARK: - Health Check

    func healthCheck() async throws -> Bool {
        let url = try buildURL(path: "/api/health")
        let data = try await authenticatedGet(url: url)
        return !data.isEmpty
    }

    // MARK: - Helpers

    private func buildURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: baseURL + path) else {
            throw NetworkError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        return url
    }

    private func authenticatedGet(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        if let apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        }
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return data
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200...299: return
        case 401: throw NetworkError.unauthorized
        case 404: throw NetworkError.notFound
        case 500...599: throw NetworkError.serverError
        default: throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }
    }
}
