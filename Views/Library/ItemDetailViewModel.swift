import Foundation

@MainActor @Observable
final class ItemDetailViewModel {
    var item: BaseItemDto?
    var seasons: [BaseItemDto] = []
    var isLoading = true
    var error: String?

    private let client: JellyfinClient
    private let itemId: String

    init(client: JellyfinClient, itemId: String) {
        self.client = client
        self.itemId = itemId
    }

    var isSeries: Bool {
        item?.type == "Series"
    }

    var isMovie: Bool {
        item?.type == "Movie"
    }

    var isEpisode: Bool {
        item?.type == "Episode"
    }

    var playableItemId: String? {
        item?.id
    }

    var mediaSourceId: String? {
        item?.mediaSources?.first?.id
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            async let fetchItem = client.getItem(id: itemId)
            async let fetchSeasons = client.getSeasons(seriesId: itemId)

            item = try await fetchItem
            if isSeries {
                seasons = try await fetchSeasons
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Lightweight refresh after player dismiss — only updates play state, not full reload.
    func refreshPlayState() async {
        guard let freshItem = try? await client.getItem(id: itemId) else { return }
        item?.userData = freshItem.userData
    }

    enum DeleteError: LocalizedError {
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Your Jellyfin account doesn't have permission to delete items. Enable \"Allow media deletion\" in the server dashboard."
            }
        }
    }

    func deleteItem() async throws {
        guard let id = item?.id else { return }
        do {
            try await client.deleteItem(id: id)
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 403 {
            throw DeleteError.permissionDenied
        }
    }

    func toggleWatched() async {
        guard var item else { return }
        let wasPlayed = item.userData?.played == true

        // Optimistic update — flip immediately
        if item.userData != nil {
            item.userData?.played = !wasPlayed
        } else {
            item.userData = UserItemDataDto(playbackPositionTicks: 0, playCount: nil, isFavorite: nil, played: true, playedPercentage: nil)
        }
        self.item = item

        do {
            if wasPlayed {
                try await client.markUnplayed(itemId: item.id)
            } else {
                try await client.markPlayed(itemId: item.id)
            }
        } catch {
            // Roll back on failure
            self.item?.userData?.played = wasPlayed
        }
    }
}
