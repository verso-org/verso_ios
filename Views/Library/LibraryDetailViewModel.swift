import Foundation

@Observable
final class LibraryDetailViewModel {
    var items: [BaseItemDto] = []
    var isLoading = true
    var isLoadingMore = false
    var error: String?
    var totalCount = 0

    private let client: JellyfinClient
    private let libraryId: String
    private let collectionType: String?
    private let pageSize = 50

    init(client: JellyfinClient, libraryId: String, collectionType: String? = nil) {
        self.client = client
        self.libraryId = libraryId
        self.collectionType = collectionType
    }

    private var includeItemTypes: String? {
        switch collectionType?.lowercased() {
        case "movies": return "Movie"
        case "tvshows": return "Series"
        default: return nil
        }
    }

    var hasMore: Bool {
        items.count < totalCount
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let response = try await client.getItems(
                parentId: libraryId,
                includeItemTypes: includeItemTypes,
                startIndex: 0,
                limit: pageSize,
                fields: "Overview,MediaSources"
            )
            items = response.items
            totalCount = response.totalRecordCount
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        do {
            let response = try await client.getItems(
                parentId: libraryId,
                includeItemTypes: includeItemTypes,
                startIndex: items.count,
                limit: pageSize,
                fields: "Overview,MediaSources"
            )
            items.append(contentsOf: response.items)
        } catch {
            // Silently fail on pagination
        }
        isLoadingMore = false
    }
}
