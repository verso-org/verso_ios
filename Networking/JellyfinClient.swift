import Foundation

final class JellyfinClient: @unchecked Sendable {
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,
            diskCapacity: 50 * 1024 * 1024
        )
        return URLSession(configuration: config)
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    let baseURL: String
    let accessToken: String?
    let userId: String?
    private let deviceId: String

    init(baseURL: String = "", accessToken: String? = nil, userId: String? = nil) {
        self.baseURL = baseURL
        self.accessToken = accessToken
        self.userId = userId
        self.deviceId = KeychainService.get(key: "deviceId") ?? {
            let id = UUID().uuidString
            KeychainService.set(id, forKey: "deviceId")
            return id
        }()
    }

    // MARK: - Auth

    func authenticate(username: String, password: String) async throws -> JellyfinAuthResponse {
        let url = try buildURL(path: "/Users/AuthenticateByName")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeaderValue(token: nil), forHTTPHeaderField: "Authorization")

        let body = ["Username": username, "Pw": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(JellyfinAuthResponse.self, from: data)
    }

    // MARK: - Libraries (Views)

    func getViews() async throws -> [BaseItemDto] {
        guard let userId else { throw NetworkError.unauthorized }
        let url = try buildURL(path: "/Users/\(userId)/Views")
        let data = try await authenticatedGet(url: url)
        let response = try decoder.decode(ItemsResponse.self, from: data)
        return response.items
    }

    // MARK: - Items

    func getItems(
        parentId: String? = nil,
        includeItemTypes: String? = nil,
        sortBy: String = "SortName",
        sortOrder: String = "Ascending",
        startIndex: Int = 0,
        limit: Int = 50,
        recursive: Bool = true,
        fields: String = "Overview,People,MediaSources"
    ) async throws -> ItemsResponse {
        guard let userId else { throw NetworkError.unauthorized }
        var queryItems = [
            URLQueryItem(name: "SortBy", value: sortBy),
            URLQueryItem(name: "SortOrder", value: sortOrder),
            URLQueryItem(name: "StartIndex", value: "\(startIndex)"),
            URLQueryItem(name: "Limit", value: "\(limit)"),
            URLQueryItem(name: "Recursive", value: "\(recursive)"),
            URLQueryItem(name: "Fields", value: fields)
        ]
        if let parentId { queryItems.append(URLQueryItem(name: "ParentId", value: parentId)) }
        if let includeItemTypes { queryItems.append(URLQueryItem(name: "IncludeItemTypes", value: includeItemTypes)) }

        let url = try buildURL(path: "/Users/\(userId)/Items", queryItems: queryItems)
        let data = try await authenticatedGet(url: url)
        return try decoder.decode(ItemsResponse.self, from: data)
    }

    func getItem(id: String) async throws -> BaseItemDto {
        guard let userId else { throw NetworkError.unauthorized }
        let url = try buildURL(path: "/Users/\(userId)/Items/\(id)", queryItems: [
            URLQueryItem(name: "Fields", value: "Overview,People,MediaSources,MediaStreams,Chapters")
        ])
        let data = try await authenticatedGet(url: url)
        return try decoder.decode(BaseItemDto.self, from: data)
    }

    // MARK: - Resume Items (Continue Watching)

    func getResumeItems(limit: Int = 12) async throws -> [BaseItemDto] {
        guard let userId else { throw NetworkError.unauthorized }
        let url = try buildURL(path: "/Users/\(userId)/Items/Resume", queryItems: [
            URLQueryItem(name: "Limit", value: "\(limit)"),
            URLQueryItem(name: "Fields", value: "Overview,MediaSources"),
            URLQueryItem(name: "MediaTypes", value: "Video")
        ])
        let data = try await authenticatedGet(url: url)
        let response = try decoder.decode(ItemsResponse.self, from: data)
        return response.items
    }

    // MARK: - Latest Items

    func getLatestItems(parentId: String, limit: Int = 16) async throws -> [BaseItemDto] {
        guard let userId else { throw NetworkError.unauthorized }
        let url = try buildURL(path: "/Users/\(userId)/Items/Latest", queryItems: [
            URLQueryItem(name: "ParentId", value: parentId),
            URLQueryItem(name: "Limit", value: "\(limit)"),
            URLQueryItem(name: "Fields", value: "Overview,MediaSources")
        ])
        let data = try await authenticatedGet(url: url)
        return try decoder.decode([BaseItemDto].self, from: data)
    }

    // MARK: - Seasons & Episodes

    func getSeasons(seriesId: String) async throws -> [BaseItemDto] {
        guard let userId else { throw NetworkError.unauthorized }
        let url = try buildURL(path: "/Shows/\(seriesId)/Seasons", queryItems: [
            URLQueryItem(name: "UserId", value: userId),
            URLQueryItem(name: "Fields", value: "Overview")
        ])
        let data = try await authenticatedGet(url: url)
        let response = try decoder.decode(ItemsResponse.self, from: data)
        return response.items
    }

    func getEpisodes(seriesId: String, seasonId: String) async throws -> [BaseItemDto] {
        guard let userId else { throw NetworkError.unauthorized }
        let url = try buildURL(path: "/Shows/\(seriesId)/Episodes", queryItems: [
            URLQueryItem(name: "SeasonId", value: seasonId),
            URLQueryItem(name: "UserId", value: userId),
            URLQueryItem(name: "Fields", value: "Overview,MediaSources,MediaStreams,Chapters")
        ])
        let data = try await authenticatedGet(url: url)
        let response = try decoder.decode(ItemsResponse.self, from: data)
        return response.items
    }

    // MARK: - Search

    func search(query: String, limit: Int = 24) async throws -> SearchHintResponse {
        let url = try buildURL(path: "/Search/Hints", queryItems: [
            URLQueryItem(name: "searchTerm", value: query),
            URLQueryItem(name: "Limit", value: "\(limit)"),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie,Series,Episode")
        ])
        let data = try await authenticatedGet(url: url)
        return try decoder.decode(SearchHintResponse.self, from: data)
    }

    // MARK: - Streaming URL

    enum SubtitleMethod: String {
        case hls = "Hls"
        case encode = "Encode"
        case external = "External"
    }

    func streamURL(
        itemId: String,
        mediaSourceId: String? = nil,
        subtitleStreamIndex: Int? = nil,
        subtitleMethod: SubtitleMethod? = nil,
        audioStreamIndex: Int? = nil,
        startPositionTicks: Int64? = nil
    ) -> URL? {
        // Use main.m3u8 (single-variant) instead of master.m3u8 (multi-variant) to avoid
        // AVPlayer falling back to SDR transcode variants when PQ/DV direct play is available
        var components = URLComponents(string: "\(baseURL)/Videos/\(itemId)/main.m3u8")
        let isBurnIn = subtitleMethod == .encode
        var queryItems = [
            URLQueryItem(name: "DeviceId", value: deviceId),
            URLQueryItem(name: "api_key", value: accessToken),
            URLQueryItem(name: "PlaySessionId", value: UUID().uuidString),
            URLQueryItem(name: "VideoCodec", value: "h264,hevc,av1"),
            URLQueryItem(name: "AudioCodec", value: "aac,ac3,eac3,flac,alac,opus,mp3"),
            URLQueryItem(name: "MaxStreamingBitrate", value: "200000000"),
            URLQueryItem(name: "MaxVideoWidth", value: "3840"),
            URLQueryItem(name: "MaxVideoHeight", value: "2160"),
            URLQueryItem(name: "VideoBitDepth", value: "10"),
            // When burning in subtitles, video can't be stream-copied — force high-quality transcode
            URLQueryItem(name: "AllowVideoStreamCopy", value: isBurnIn ? "false" : "true"),
            URLQueryItem(name: "AllowAudioStreamCopy", value: "true"),
            URLQueryItem(name: "SegmentContainer", value: "mp4"),
            URLQueryItem(name: "TranscodingMaxAudioChannels", value: "6"),
        ]
        if isBurnIn {
            // Explicit high bitrate so server doesn't default to low-quality transcode
            queryItems.append(URLQueryItem(name: "VideoBitRate", value: "60000000"))
        }
        if let mediaSourceId {
            queryItems.append(URLQueryItem(name: "MediaSourceId", value: mediaSourceId))
        }
        if let subtitleMethod {
            queryItems.append(URLQueryItem(name: "SubtitleMethod", value: subtitleMethod.rawValue))
        }
        if let subtitleStreamIndex {
            queryItems.append(URLQueryItem(name: "SubtitleStreamIndex", value: "\(subtitleStreamIndex)"))
        }
        if let audioStreamIndex {
            queryItems.append(URLQueryItem(name: "AudioStreamIndex", value: "\(audioStreamIndex)"))
        }
        if let startPositionTicks, startPositionTicks > 0 {
            queryItems.append(URLQueryItem(name: "StartTimeTicks", value: "\(startPositionTicks)"))
        }
        components?.queryItems = queryItems
        return components?.url
    }

    // MARK: - Subtitles

    func getSubtitleContent(itemId: String, mediaSourceId: String, streamIndex: Int, format: String = "vtt") async throws -> String {
        let url = try buildURL(
            path: "/Videos/\(itemId)/\(mediaSourceId)/Subtitles/\(streamIndex)/0/Stream.\(format)"
        )
        print("[Network] subtitle request: \(url.absoluteString)")
        let start = CFAbsoluteTimeGetCurrent()
        let data = try await authenticatedGet(url: url)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        print("[Network] subtitle response: \(String(format: "%.2f", elapsed))s, \(data.count) bytes")
        guard let content = String(data: data, encoding: .utf8) else {
            throw NetworkError.invalidResponse
        }
        return content
    }

    func getPGSSubtitleData(itemId: String, mediaSourceId: String, streamIndex: Int) async throws -> Data {
        let url = try buildURL(
            path: "/Videos/\(itemId)/\(mediaSourceId)/Subtitles/\(streamIndex)/0/Stream.pgssub"
        )
        print("[Network] PGS subtitle request: \(url.absoluteString)")
        let start = CFAbsoluteTimeGetCurrent()
        let data = try await authenticatedGet(url: url)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        print("[Network] PGS subtitle response: \(String(format: "%.2f", elapsed))s, \(data.count) bytes")
        // Validate PGS/SUP magic bytes ("PG" = 0x50 0x47)
        guard data.count >= 13, data[0] == 0x50, data[1] == 0x47 else {
            throw NetworkError.invalidResponse
        }
        return data
    }

    // MARK: - Playback Reporting

    func reportPlaybackStart(itemId: String, mediaSourceId: String?, positionTicks: Int64, playSessionId: String) async {
        try? await authenticatedPost(
            path: "/Sessions/Playing",
            body: playbackBody(itemId: itemId, mediaSourceId: mediaSourceId, positionTicks: positionTicks, isPaused: false, playSessionId: playSessionId)
        )
    }

    func reportPlaybackProgress(itemId: String, mediaSourceId: String?, positionTicks: Int64, isPaused: Bool, playSessionId: String) async {
        try? await authenticatedPost(
            path: "/Sessions/Playing/Progress",
            body: playbackBody(itemId: itemId, mediaSourceId: mediaSourceId, positionTicks: positionTicks, isPaused: isPaused, playSessionId: playSessionId)
        )
    }

    func reportPlaybackStopped(itemId: String, mediaSourceId: String?, positionTicks: Int64, playSessionId: String) async {
        try? await authenticatedPost(
            path: "/Sessions/Playing/Stopped",
            body: playbackBody(itemId: itemId, mediaSourceId: mediaSourceId, positionTicks: positionTicks, playSessionId: playSessionId)
        )
    }

    private func playbackBody(itemId: String, mediaSourceId: String?, positionTicks: Int64, isPaused: Bool = false, playSessionId: String) -> [String: Any] {
        var body: [String: Any] = [
            "ItemId": itemId,
            "PositionTicks": positionTicks,
            "PlaySessionId": playSessionId,
            "IsPaused": isPaused,
            "IsMuted": false
        ]
        if let mediaSourceId { body["MediaSourceId"] = mediaSourceId }
        return body
    }

    // MARK: - Mark Played / Unplayed

    func markPlayed(itemId: String) async throws {
        guard let userId else { throw NetworkError.unauthorized }
        let url = try buildURL(path: "/Users/\(userId)/PlayedItems/\(itemId)")
        try await authenticatedRequest(url: url, method: "POST")
    }

    func markUnplayed(itemId: String) async throws {
        guard let userId else { throw NetworkError.unauthorized }
        let url = try buildURL(path: "/Users/\(userId)/PlayedItems/\(itemId)")
        try await authenticatedRequest(url: url, method: "DELETE")
    }

    // MARK: - Next Up

    func getNextUp(seriesId: String) async throws -> [BaseItemDto] {
        guard let userId else { throw NetworkError.unauthorized }
        let url = try buildURL(path: "/Shows/NextUp", queryItems: [
            URLQueryItem(name: "SeriesId", value: seriesId),
            URLQueryItem(name: "UserId", value: userId),
            URLQueryItem(name: "Fields", value: "MediaSources,MediaStreams")
        ])
        let data = try await authenticatedGet(url: url)
        let response = try decoder.decode(ItemsResponse.self, from: data)
        return response.items
    }

    // MARK: - Library Management

    func refreshLibrary() async {
        try? await authenticatedPost(path: "/Library/Refresh", body: [:])
    }

    func deleteItem(id: String) async throws {
        let url = try buildURL(path: "/Items/\(id)")
        try await authenticatedRequest(url: url, method: "DELETE")
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
        request.setValue(authHeaderValue(token: accessToken), forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return data
    }

    private func authenticatedPost(path: String, body: [String: Any]) async throws {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeaderValue(token: accessToken), forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    @discardableResult
    private func authenticatedRequest(url: URL, method: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(authHeaderValue(token: accessToken), forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return data
    }

    private func authHeaderValue(token: String?) -> String {
        var header = "MediaBrowser Client=\"Verso\", Device=\"iPhone\", DeviceId=\"\(deviceId)\", Version=\"1.0\""
        if let token {
            header += ", Token=\"\(token)\""
        }
        return header
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
