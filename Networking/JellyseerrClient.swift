import Foundation

final class JellyseerrClient: @unchecked Sendable {
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    let baseURL: String
    let apiKey: String?

    init(baseURL: String = "", apiKey: String? = nil) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    var isConfigured: Bool {
        !baseURL.isEmpty && apiKey != nil
    }

    // MARK: - Search

    func search(query: String, page: Int = 1) async throws -> SeerrSearchResponse {
        let url = try buildURL(path: "/api/v1/search", queryItems: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "language", value: "en")
        ])
        let data = try await authenticatedGet(url: url)
        return try decoder.decode(SeerrSearchResponse.self, from: data)
    }

    // MARK: - Trending

    func getTrending(page: Int = 1) async throws -> SeerrSearchResponse {
        let url = try buildURL(path: "/api/v1/discover/trending", queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "language", value: "en")
        ])
        let data = try await authenticatedGet(url: url)
        return try decoder.decode(SeerrSearchResponse.self, from: data)
    }

    // MARK: - Movie Details

    func getMovie(tmdbId: Int) async throws -> SeerrMovieResult {
        let url = try buildURL(path: "/api/v1/movie/\(tmdbId)")
        let data = try await authenticatedGet(url: url)
        return try decoder.decode(SeerrMovieResult.self, from: data)
    }

    // MARK: - TV Details

    func getTv(tmdbId: Int) async throws -> SeerrTvResult {
        let url = try buildURL(path: "/api/v1/tv/\(tmdbId)")
        let data = try await authenticatedGet(url: url)
        return try decoder.decode(SeerrTvResult.self, from: data)
    }

    // MARK: - Create Request

    func createRequest(body: SeerrRequestBody) async throws -> SeerrMediaRequest {
        let url = try buildURL(path: "/api/v1/request")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(SeerrMediaRequest.self, from: data)
    }

    // MARK: - Service Config

    func getRadarrServers() async throws -> [SeerrServiceServer] {
        let url = try buildURL(path: "/api/v1/service/radarr")
        let data = try await authenticatedGet(url: url)
        return try decoder.decode([SeerrServiceServer].self, from: data)
    }

    func getRadarrDetail(serverId: Int) async throws -> SeerrServiceDetail {
        let url = try buildURL(path: "/api/v1/service/radarr/\(serverId)")
        let data = try await authenticatedGet(url: url)
        return try decoder.decode(SeerrServiceDetail.self, from: data)
    }

    func getSonarrServers() async throws -> [SeerrServiceServer] {
        let url = try buildURL(path: "/api/v1/service/sonarr")
        let data = try await authenticatedGet(url: url)
        return try decoder.decode([SeerrServiceServer].self, from: data)
    }

    func getSonarrDetail(serverId: Int) async throws -> SeerrServiceDetail {
        let url = try buildURL(path: "/api/v1/service/sonarr/\(serverId)")
        let data = try await authenticatedGet(url: url)
        return try decoder.decode(SeerrServiceDetail.self, from: data)
    }

    // MARK: - List Requests

    func getRequests(page: Int = 1, pageSize: Int = 20) async throws -> SeerrRequestsResponse {
        let url = try buildURL(path: "/api/v1/request", queryItems: [
            URLQueryItem(name: "take", value: "\(pageSize)"),
            URLQueryItem(name: "skip", value: "\((page - 1) * pageSize)"),
            URLQueryItem(name: "sort", value: "added")
        ])
        let data = try await authenticatedGet(url: url)
        return try decoder.decode(SeerrRequestsResponse.self, from: data)
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
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
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
