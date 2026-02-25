import Foundation

@Observable
final class HomeViewModel {
    var resumeItems: [BaseItemDto] = []
    var latestByLibrary: [(library: BaseItemDto, items: [BaseItemDto])] = []
    var activeDownloads: [PrograrMediaRequest] = []
    var isLoading = true
    var error: String?

    private(set) var featuredItems: [BaseItemDto] = []

    private func updateFeaturedItems() {
        var result: [BaseItemDto] = []
        var seen = Set<String>()
        for item in resumeItems {
            if seen.insert(item.id).inserted {
                result.append(item)
            }
            if result.count >= 5 { break }
        }
        if result.count < 5 {
            for section in latestByLibrary {
                for item in section.items {
                    if seen.insert(item.id).inserted {
                        result.append(item)
                    }
                    if result.count >= 5 { break }
                }
                if result.count >= 5 { break }
            }
        }
        featuredItems = result
    }

    private let client: JellyfinClient
    private let prograrClient: PrograrClient?
    private var pollingTask: Task<Void, Never>?
    private var previouslyActiveIds: Set<Int> = []

    init(client: JellyfinClient, prograrClient: PrograrClient? = nil) {
        self.client = client
        self.prograrClient = prograrClient?.isConfigured == true ? prograrClient : nil
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            async let resume = client.getResumeItems()
            async let views = client.getViews()

            resumeItems = try await resume
            let libraries = try await views

            let eligibleLibraries = libraries.filter { lib in
                guard let ct = lib.collectionType else { return false }
                return ["movies", "tvshows", "music"].contains(ct)
            }
            let latest = try await withThrowingTaskGroup(
                of: (BaseItemDto, [BaseItemDto])?.self
            ) { group in
                for library in eligibleLibraries {
                    group.addTask {
                        let items = try await self.client.getLatestItems(parentId: library.id)
                        return items.isEmpty ? nil : (library, items)
                    }
                }
                var results: [(BaseItemDto, [BaseItemDto])] = []
                for try await result in group {
                    if let result { results.append(result) }
                }
                return results
            }
            // Preserve library ordering
            latestByLibrary = eligibleLibraries.compactMap { lib in
                latest.first(where: { $0.0.id == lib.id })
            }
            updateFeaturedItems()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false

        // Fetch downloads concurrently — don't block the main content spinner
        Task { [weak self] in
            await self?.loadDownloads()
            self?.startPolling()
        }
    }

    func loadDownloads() async {
        guard let prograrClient else {
            activeDownloads = []
            return
        }
        do {
            let all = try await prograrClient.getRequests()
            let nonAvailableIds = Set(all.filter { $0.requestStatus != "available" }.map(\.id))

            // Detect completions: previously tracked IDs no longer pending
            let completed = previouslyActiveIds.subtracting(nonAvailableIds)
            if !completed.isEmpty {
                await client.refreshLibrary()
                try? await Task.sleep(for: .seconds(3))
                await refreshLatest()
            }

            previouslyActiveIds = nonAvailableIds
            activeDownloads = all.filter { $0.isActive }
        } catch {
            // Silently fail — downloads are supplementary
            activeDownloads = []
        }
    }

    /// Lightweight refresh — only re-fetches latest items per library, not resume/views.
    private func refreshLatest() async {
        let currentLibraries = latestByLibrary.map(\.library)
        guard !currentLibraries.isEmpty else { return }
        do {
            let latest = try await withThrowingTaskGroup(
                of: (BaseItemDto, [BaseItemDto])?.self
            ) { group in
                for library in currentLibraries {
                    group.addTask {
                        let items = try await self.client.getLatestItems(parentId: library.id)
                        return items.isEmpty ? nil : (library, items)
                    }
                }
                var results: [(BaseItemDto, [BaseItemDto])] = []
                for try await result in group {
                    if let result { results.append(result) }
                }
                return results
            }
            latestByLibrary = currentLibraries.compactMap { lib in
                latest.first(where: { $0.0.id == lib.id })
            }
            updateFeaturedItems()
        } catch {
            // Non-critical — keep existing data
        }
    }

    // MARK: - Download Polling

    func startPolling() {
        guard prograrClient != nil, !activeDownloads.isEmpty else { return }
        stopPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await self?.loadDownloads()
                // Stop polling if no more active downloads
                if self?.activeDownloads.isEmpty == true { break }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
