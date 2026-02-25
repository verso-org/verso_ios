import Foundation

@Observable
final class RequestSheetViewModel {
    let item: SeerrSearchResult
    private let client: JellyseerrClient
    private let prograrClient: PrograrClient?

    var servers: [SeerrServiceServer] = []
    var selectedServer: SeerrServiceServer?
    var profiles: [SeerrServiceProfile] = []
    var selectedProfile: SeerrServiceProfile?
    var seasons: [SeerrSeason] = []
    var selectedSeasons: Set<Int> = []
    var downloadInfo: PrograrMediaRequest?

    var isLoadingConfig = false
    var isLoadingProfiles = false
    var isRequesting = false
    var error: String?
    var success = false

    var isMovie: Bool { item.mediaType == "movie" }

    var canSubmit: Bool {
        if isRequesting || success { return false }
        if let mediaInfo = item.mediaInfo, mediaInfo.isAvailable { return false }
        if !isMovie && selectedSeasons.isEmpty { return false }
        return true
    }

    var allSeasonsSelected: Bool {
        !seasons.isEmpty && selectedSeasons.count == seasons.count
    }

    init(item: SeerrSearchResult, client: JellyseerrClient, prograrClient: PrograrClient? = nil) {
        self.item = item
        self.client = client
        self.prograrClient = prograrClient?.isConfigured == true ? prograrClient : nil
    }

    func loadConfig() async {
        isLoadingConfig = true
        defer { isLoadingConfig = false }

        if isMovie {
            async let serversTask: Void = loadServers { try await self.client.getRadarrServers() }
            async let downloadTask: Void = loadDownloadInfo()
            _ = await (serversTask, downloadTask)
        } else {
            async let serversTask: Void = loadServers { try await self.client.getSonarrServers() }
            async let seasonsTask: Void = loadSeasons()
            async let downloadTask: Void = loadDownloadInfo()
            _ = await (serversTask, seasonsTask, downloadTask)
        }
    }

    private func loadServers(_ fetch: @Sendable () async throws -> [SeerrServiceServer]) async {
        do {
            let result = try await fetch()
            servers = result
            if let defaultServer = result.first(where: { $0.isDefault && !$0.is4k })
                ?? result.first(where: { !$0.is4k })
                ?? result.first
            {
                selectedServer = defaultServer
                await loadProfiles(for: defaultServer)
            }
        } catch {
            // Non-critical — user can still request without a profile
        }
    }

    private func loadProfiles(for server: SeerrServiceServer) async {
        isLoadingProfiles = true
        defer { isLoadingProfiles = false }

        do {
            let detail: SeerrServiceDetail
            if isMovie {
                detail = try await client.getRadarrDetail(serverId: server.id)
            } else {
                detail = try await client.getSonarrDetail(serverId: server.id)
            }
            profiles = detail.profiles
            selectedProfile = detail.profiles.first(where: { $0.id == server.activeProfileId })
                ?? detail.profiles.first
        } catch {
            profiles = []
            selectedProfile = nil
        }
    }

    private func loadSeasons() async {
        do {
            let tvDetail = try await client.getTv(tmdbId: item.tmdbId)
            let filtered = (tvDetail.seasons ?? []).filter { $0.seasonNumber != 0 }
            seasons = filtered
            selectedSeasons = Set(filtered.map(\.seasonNumber))
        } catch {
            // Non-critical — seasons won't be shown
        }
    }

    private func loadDownloadInfo() async {
        guard let prograrClient else { return }
        do {
            let results = try await prograrClient.getRequests(tmdbId: item.tmdbId)
            downloadInfo = results.first
        } catch {
            // Non-critical
        }
    }

    func selectServer(_ server: SeerrServiceServer) async {
        selectedServer = server
        await loadProfiles(for: server)
    }

    func toggleSeason(_ seasonNumber: Int) {
        if selectedSeasons.contains(seasonNumber) {
            selectedSeasons.remove(seasonNumber)
        } else {
            selectedSeasons.insert(seasonNumber)
        }
    }

    func toggleAllSeasons() {
        if allSeasonsSelected {
            selectedSeasons.removeAll()
        } else {
            selectedSeasons = Set(seasons.map(\.seasonNumber))
        }
    }

    func submitRequest() async {
        isRequesting = true
        error = nil

        do {
            let body = SeerrRequestBody(
                mediaType: item.mediaType,
                mediaId: item.tmdbId,
                seasons: isMovie ? nil : Array(selectedSeasons).sorted(),
                profileId: selectedProfile?.id,
                rootFolder: selectedServer?.activeDirectory,
                serverId: selectedServer?.id
            )
            _ = try await client.createRequest(body: body)
            success = true
        } catch {
            self.error = error.localizedDescription
        }

        isRequesting = false
    }
}
