import Foundation

@Observable
final class LibraryListViewModel {
    var libraries: [BaseItemDto] = []
    var latestByLibrary: [(library: BaseItemDto, items: [BaseItemDto])] = []
    var collections: [BaseItemDto] = []
    var topRated: [BaseItemDto] = []
    var randomPicks: [BaseItemDto] = []
    var isLoading = true
    var error: String?

    // Search state
    var searchResults: [SearchHint] = []
    var searchSuggestions: [SearchHint] = []
    var isSearching = false
    var searchError: String?
    private var suggestionTask: Task<Void, Never>?

    private let client: JellyfinClient

    init(client: JellyfinClient) {
        self.client = client
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            libraries = try await client.getViews()

            // Latest per library (parallel)
            let eligibleLibraries = libraries.filter { lib in
                guard let ct = lib.collectionType else { return false }
                return ["movies", "tvshows"].contains(ct)
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

            // Top Rated
            async let topRatedResponse = client.getItems(
                includeItemTypes: "Movie,Series",
                sortBy: "CommunityRating",
                sortOrder: "Descending",
                limit: 16,
                fields: "Overview"
            )

            // Random Picks
            async let randomResponse = client.getItems(
                includeItemTypes: "Movie,Series",
                sortBy: "Random",
                limit: 16,
                fields: "Overview"
            )

            // Collections (server-side BoxSets from TMDB data)
            async let collectionsResponse = client.getItems(
                includeItemTypes: "BoxSet",
                sortBy: "SortName",
                limit: 50
            )

            topRated = try await topRatedResponse.items
            randomPicks = try await randomResponse.items
            collections = try await collectionsResponse.items
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Search

    func searchQueryChanged(_ query: String) {
        suggestionTask?.cancel()
        searchResults = []

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchSuggestions = []
            return
        }

        suggestionTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            do {
                let response = try await client.search(query: trimmed, limit: 8)
                guard !Task.isCancelled else { return }
                searchSuggestions = response.searchHints
            } catch {
                // Silently fail — suggestions are non-critical
            }
        }
    }

    func search(query: String) async {
        clearSearchSuggestions()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        searchError = nil

        do {
            let response = try await client.search(query: trimmed)
            searchResults = response.searchHints
        } catch {
            searchError = error.localizedDescription
        }

        isSearching = false
    }

    func clearSearchSuggestions() {
        suggestionTask?.cancel()
        searchSuggestions = []
    }
}
