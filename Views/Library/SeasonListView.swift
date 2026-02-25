import SwiftUI

struct SeasonListView: View {
    @EnvironmentObject private var authManager: AuthManager
    let seriesId: String
    let seasonId: String
    let seasonName: String

    @State private var episodes: [BaseItemDto] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedEpisode: BaseItemDto?

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if let error {
                ErrorView(message: error) { load() }
            } else {
                ScrollView {
                    LazyVStack(spacing: VersoSpacing.md) {
                        ForEach(Array(episodes.enumerated()), id: \.element.id) { index, episode in
                            Button {
                                selectedEpisode = episode
                            } label: {
                                episodeRow(episode)
                            }
                            .buttonStyle(.plain)
                            .staggeredAppearance(index: index)
                            .contextMenu {
                                Button {
                                    toggleWatched(episode: episode)
                                } label: {
                                    Label(
                                        episode.userData?.played == true ? "Mark as Unwatched" : "Mark as Watched",
                                        systemImage: episode.userData?.played == true ? "eye.slash" : "eye.fill"
                                    )
                                }
                            }
                        }
                    }
                    .padding(VersoSpacing.lg)
                    .padding(.bottom, 72)
                }
            }
        }
        .background(Color.versoBackground)
        .navigationTitle(seasonName)
        .task { load() }
        .fullScreenCover(item: $selectedEpisode, onDismiss: {
            load()
        }) { episode in
            PlayerView(
                client: authManager.jellyfinClient,
                itemId: episode.id,
                mediaSourceId: episode.mediaSources?.first?.id,
                mediaSource: episode.mediaSources?.first,
                itemType: "Episode",
                seriesId: seriesId,
                displayTitle: {
                    if let s = episode.parentIndexNumber, let e = episode.indexNumber {
                        return "S\(s) E\(e) · \(episode.name)"
                    }
                    return episode.name
                }(),
                initialAudioIndex: nil,
                initialSubtitleIndex: nil,
                resumePositionTicks: episode.userData?.playbackPositionTicks
            )
        }
    }

    private func episodeRow(_ episode: BaseItemDto) -> some View {
        HStack(spacing: VersoSpacing.md) {
            // Episodes typically store their thumbnail as Primary image
            // Use backdrop as fallback for the 16:9 thumbnail
            CachedAsyncImage(url: episodeImageURL(episode), displaySize: CGSize(width: 130, height: 74))
                .frame(width: 130, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: VersoSpacing.xs) {
                if let num = episode.indexNumber {
                    Text("Episode \(num)")
                        .font(.caption)
                        .foregroundStyle(Color.versoSecondaryText)
                }
                Text(episode.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let minutes = episode.runtimeMinutes {
                    Text("\(minutes) min")
                        .font(.caption2)
                        .foregroundStyle(Color.versoSecondaryText)
                }
            }

            Spacer()

            if let progress = episode.userData?.progressPercentage, progress > 0 {
                CircularProgressView(progress: progress / 100)
                    .frame(width: 28, height: 28)
            } else if episode.userData?.played == true {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.versoJade)
            }
        }
        .padding(VersoSpacing.md)
        .background(Color.versoCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func episodeImageURL(_ episode: BaseItemDto) -> URL? {
        let baseURL = authManager.jellyfinClient.baseURL
        // Try Primary first (episode still), then Backdrop, then Thumb
        if episode.imageTags?.primary != nil {
            return ImageURLBuilder.jellyfinImageURL(
                baseURL: baseURL, itemId: episode.id,
                imageType: .primary, maxWidth: 300, quality: 70
            )
        }
        if episode.backdropImageTags?.isEmpty == false {
            return ImageURLBuilder.jellyfinImageURL(
                baseURL: baseURL, itemId: episode.id,
                imageType: .backdrop, maxWidth: 300, quality: 70
            )
        }
        if episode.imageTags?.thumb != nil {
            return ImageURLBuilder.jellyfinImageURL(
                baseURL: baseURL, itemId: episode.id,
                imageType: .thumb, maxWidth: 300, quality: 70
            )
        }
        // Fallback: use series Primary image via seriesId
        if let seriesId = episode.seriesId {
            return ImageURLBuilder.jellyfinImageURL(
                baseURL: baseURL, itemId: seriesId,
                imageType: .backdrop, maxWidth: 300, quality: 70
            )
        }
        return ImageURLBuilder.jellyfinImageURL(
            baseURL: baseURL, itemId: episode.id,
            imageType: .primary, maxWidth: 300, quality: 70
        )
    }

    private func toggleWatched(episode: BaseItemDto) {
        Task {
            do {
                if episode.userData?.played == true {
                    try await authManager.jellyfinClient.markUnplayed(itemId: episode.id)
                } else {
                    try await authManager.jellyfinClient.markPlayed(itemId: episode.id)
                }
                load()
            } catch {
                // Silently fail
            }
        }
    }

    private func load() {
        Task {
            isLoading = true
            error = nil
            do {
                episodes = try await authManager.jellyfinClient.getEpisodes(
                    seriesId: seriesId,
                    seasonId: seasonId
                )
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.versoSecondaryText.opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.versoJade, .versoSilver],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}
