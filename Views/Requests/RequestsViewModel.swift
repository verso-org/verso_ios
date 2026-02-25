import Foundation

struct RequestWithDetails: Identifiable {
    let request: SeerrMediaRequest
    var posterPath: String?
    var title: String?
    var downloadProgress: PrograrMediaRequest?

    var id: Int { request.id }
}

@Observable
final class RequestsViewModel {
    var requests: [RequestWithDetails] = []
    var isLoading = true
    var error: String?

    private let client: JellyseerrClient
    private let prograrClient: PrograrClient?
    private var tmdbCache: [Int: (posterPath: String?, title: String?)] = [:]

    init(client: JellyseerrClient, prograrClient: PrograrClient? = nil) {
        self.client = client
        self.prograrClient = prograrClient?.isConfigured == true ? prograrClient : nil
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let response = try await client.getRequests()
            // Show requests immediately with basic info
            requests = response.results.map { RequestWithDetails(request: $0) }
            isLoading = false

            // Enrich with TMDB details and download progress concurrently
            let prograrRequests = await fetchPrograrRequests()

            await withTaskGroup(of: (Int, String?, String?, PrograrMediaRequest?).self) { group in
                for (index, detail) in requests.enumerated() {
                    guard let tmdbId = detail.request.media?.tmdbId,
                          let mediaType = detail.request.media?.mediaType else { continue }

                    let cached = tmdbCache[tmdbId]

                    group.addTask { [client] in
                        var posterPath = cached?.posterPath
                        var title = cached?.title

                        // Only fetch from API if not cached
                        if posterPath == nil && title == nil {
                            do {
                                if mediaType == "movie" {
                                    let movie = try await client.getMovie(tmdbId: tmdbId)
                                    posterPath = movie.posterPath
                                    title = movie.title
                                } else if mediaType == "tv" {
                                    let tv = try await client.getTv(tmdbId: tmdbId)
                                    posterPath = tv.posterPath
                                    title = tv.name
                                }
                            } catch {
                                // Silently skip failed enrichments
                            }
                        }

                        let progress = prograrRequests?.first(where: { $0.tmdbId == tmdbId })
                        return (index, posterPath, title, progress)
                    }
                }

                for await (index, posterPath, title, progress) in group {
                    if index < requests.count {
                        if let posterPath { requests[index].posterPath = posterPath }
                        if let title { requests[index].title = title }
                        if let progress { requests[index].downloadProgress = progress }
                    }
                    // Populate cache
                    if let tmdbId = requests[index].request.media?.tmdbId {
                        tmdbCache[tmdbId] = (posterPath, title)
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    private func fetchPrograrRequests() async -> [PrograrMediaRequest]? {
        guard let prograrClient else { return nil }
        return try? await prograrClient.getRequests()
    }
}
