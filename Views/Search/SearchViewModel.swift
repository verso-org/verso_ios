import Foundation

@Observable
final class SearchViewModel {
    var query = ""
    var discoverResults: [SeerrSearchResult] = []
    var isSearching = false
    var error: String?

    // Trending
    var trendingResults: [SeerrSearchResult] = []
    var isLoadingSuggestions = false

    // Trending pagination
    var trendingPage = 1
    var trendingTotalPages = 1
    var isLoadingMoreTrending = false
    var hasMoreTrending: Bool { trendingPage < trendingTotalPages }

    // Live search suggestions
    var suggestions: [SeerrSearchResult] = []
    private var suggestionTask: Task<Void, Never>?

    private let jellyseerrClient: JellyseerrClient

    var hasJellyseerr: Bool {
        jellyseerrClient.isConfigured
    }

    init(jellyseerrClient: JellyseerrClient) {
        self.jellyseerrClient = jellyseerrClient
    }

    func loadSuggestions() async {
        guard jellyseerrClient.isConfigured else { return }
        isLoadingSuggestions = true

        do {
            let response = try await jellyseerrClient.getTrending()
            trendingResults = response.results
            trendingPage = response.page
            trendingTotalPages = response.totalPages
        } catch {
            // Silently fail — suggestions are non-critical
        }

        isLoadingSuggestions = false
    }

    func loadMoreTrending() async {
        guard !isLoadingMoreTrending && hasMoreTrending else { return }
        isLoadingMoreTrending = true

        do {
            let nextPage = trendingPage + 1
            let response = try await jellyseerrClient.getTrending(page: nextPage)
            trendingResults.append(contentsOf: response.results)
            trendingPage = response.page
            trendingTotalPages = response.totalPages
        } catch {
            // Silently fail — pagination is non-critical
        }

        isLoadingMoreTrending = false
    }

    func queryChanged() {
        suggestionTask?.cancel()
        discoverResults = []

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            return
        }

        suggestionTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            do {
                guard jellyseerrClient.isConfigured else { return }
                let response = try await jellyseerrClient.search(query: trimmed)
                guard !Task.isCancelled else { return }
                suggestions = response.results
            } catch {
                // Silently fail — suggestions are non-critical
            }
        }
    }

    func clearSuggestions() {
        suggestionTask?.cancel()
        suggestions = []
    }

    func search() async {
        clearSuggestions()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            discoverResults = []
            return
        }

        isSearching = true
        error = nil

        do {
            let response = try await jellyseerrClient.search(query: trimmed)
            discoverResults = response.results
        } catch {
            self.error = error.localizedDescription
        }

        isSearching = false
    }
}
