import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject private var authManager: AuthManager
    let itemId: String
    @State private var viewModel: ItemDetailViewModel?
    @State private var showPlayer = false
    @State private var showToolbarBackground = false
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?
    @Environment(\.dismiss) private var dismiss

    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.error {
                    ErrorView(message: error) {
                        Task { await viewModel.load() }
                    }
                } else if let item = viewModel.item {
                    detailContent(item: item, viewModel: viewModel)
                }
            } else {
                LoadingView()
            }
        }
        .background(Color.versoBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(showToolbarBackground ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel?.item?.name ?? "")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .opacity(showToolbarBackground ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: showToolbarBackground)
            }
        }
        .task {
            let vm = ItemDetailViewModel(client: authManager.jellyfinClient, itemId: itemId)
            viewModel = vm
            await vm.load()
        }
        .alert("Delete from Server", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await viewModel?.deleteItem()
                        dismiss()
                    } catch {
                        deleteError = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \"\(viewModel?.item?.name ?? "this item")\" from your Jellyfin server's disk. This cannot be undone.")
        }
        .alert("Unable to Delete", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .fullScreenCover(isPresented: $showPlayer, onDismiss: {
            Task { await viewModel?.refreshPlayState() }
        }) {
            if let vm = viewModel, let itemId = vm.playableItemId {
                PlayerView(
                    client: authManager.jellyfinClient,
                    itemId: itemId,
                    mediaSourceId: vm.mediaSourceId,
                    mediaSource: vm.item?.mediaSources?.first,
                    itemType: vm.item?.type,
                    seriesId: vm.item?.seriesId,
                    displayTitle: vm.item.map { item in
                        if item.type == "Episode", let s = item.parentIndexNumber, let e = item.indexNumber {
                            return "S\(s) E\(e) · \(item.name)"
                        }
                        return item.name
                    },
                    initialAudioIndex: nil,
                    initialSubtitleIndex: nil,
                    resumePositionTicks: vm.item?.userData?.playbackPositionTicks
                )
            }
        }
    }

    // MARK: - Detail Content (Immersive Full-Screen)

    @ViewBuilder
    private func detailContent(item: BaseItemDto, viewModel: ItemDetailViewModel) -> some View {
        ZStack {
            // Full-screen backdrop behind everything
            Color.versoBackground
                .ignoresSafeArea()
                .overlay {
                    CachedAsyncImage(
                        url: backdropURL(item: item),
                        displaySize: CGSize(width: 1280, height: 720)
                    )
                    .clipped()
                    .ignoresSafeArea()
                }

            // Dark gradient overlay for readability
            LinearGradient(
                stops: [
                    .init(color: Color.versoBackground.opacity(0.1), location: 0),
                    .init(color: Color.versoBackground.opacity(0.4), location: 0.25),
                    .init(color: Color.versoBackground.opacity(0.75), location: 0.5),
                    .init(color: Color.versoBackground.opacity(0.92), location: 0.7),
                    .init(color: Color.versoBackground, location: 0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Content overlaid on backdrop
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Top spacer to let backdrop breathe
                    Color.clear
                        .frame(height: screenHeight * 0.12)

                    // Invisible marker: when this scrolls off screen, show toolbar
                    Color.clear
                        .frame(height: 1)
                        .onAppear { showToolbarBackground = false }
                        .onDisappear { showToolbarBackground = true }

                    // Logo + Poster row
                    HStack(alignment: .bottom, spacing: VersoSpacing.xl) {
                        // Right side: Poster image
                        CachedAsyncImage(
                            url: posterURL(item: item),
                            cornerRadius: 14,
                            displaySize: CGSize(width: 400, height: 600)
                        )
                        .frame(width: 180, height: 270)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.6), radius: 16, y: 8)

                        // Left side: Logo or Title + metadata
                        VStack(alignment: .leading, spacing: VersoSpacing.sm) {
                            if let logoUrl = logoURL(item: item) {
                                CachedAsyncImage(url: logoUrl, cornerRadius: 0, displaySize: CGSize(width: 500, height: 160))
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 320, maxHeight: 160)
                                    .shadow(color: .black.opacity(0.8), radius: 20, y: 8)
                            } else {
                                Text(item.name)
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.8), radius: 12, y: 4)
                            }

                            // Metadata line: Year · Rating · Seasons/Runtime · ★ Rating
                            HStack(spacing: 0) {
                                if let year = item.productionYear {
                                    Text(String(year))
                                }
                                if let rating = item.officialRating {
                                    Text(" \u{00B7} ").foregroundStyle(.white.opacity(0.4))
                                    Text(rating)
                                }
                                if item.type == "Series", let childCount = item.childCount {
                                    Text(" \u{00B7} ").foregroundStyle(.white.opacity(0.4))
                                    Text(childCount == 1 ? "1 Season" : "\(childCount) Seasons")
                                } else if item.type == "Episode" {
                                    if let s = item.parentIndexNumber, let e = item.indexNumber {
                                        Text(" \u{00B7} ").foregroundStyle(.white.opacity(0.4))
                                        Text("S\(s) E\(e)")
                                    }
                                } else if let minutes = item.runtimeMinutes {
                                    Text(" \u{00B7} ").foregroundStyle(.white.opacity(0.4))
                                    let h = minutes / 60
                                    let m = minutes % 60
                                    Text(h > 0 ? "\(h)h \(m)m" : "\(m) min")
                                }
                                if let communityRating = item.communityRating {
                                    Text(" \u{00B7} ").foregroundStyle(.white.opacity(0.4))
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.yellow)
                                    Text(" " + String(format: "%.1f", communityRating))
                                }
                            }
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.6), radius: 8, y: 2)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, VersoSpacing.xl)
                    .frame(maxWidth: 800, alignment: .leading)

                    // Community rating badge
                    if let communityRating = item.communityRating {
                        HStack(spacing: VersoSpacing.sm) {
                            ratingBadge(
                                icon: "star.fill",
                                iconColor: .yellow,
                                value: String(format: "%.1f", communityRating),
                                label: "Community"
                            )
                        }
                        .padding(.horizontal, VersoSpacing.xl)
                        .padding(.top, VersoSpacing.md)
                        .frame(maxWidth: 800, alignment: .leading)
                    }

                    // Overview
                    if let overview = item.overview {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                            .padding(.horizontal, VersoSpacing.xl)
                            .padding(.top, VersoSpacing.md)
                            .frame(maxWidth: 800, alignment: .leading)
                    }

                    // Action buttons — square transparent icons
                    actionButtonsRow(item: item, viewModel: viewModel)
                        .padding(.top, VersoSpacing.lg)
                        .frame(maxWidth: 800, alignment: .leading)

                    // Metadata info bar
                    metadataInfoBar(item: item)
                        .padding(.top, VersoSpacing.lg)
                        .frame(maxWidth: 800, alignment: .leading)

                    // Cast section
                    if let people = item.people, !people.isEmpty {
                        let actors = Array(people.filter { $0.type == "Actor" }.prefix(12))
                        if !actors.isEmpty {
                            castSection(actors: actors)
                                .padding(.top, VersoSpacing.lg)
                        }
                    }

                    // Seasons
                    if viewModel.isSeries && !viewModel.seasons.isEmpty {
                        seasonsSection(item: item, viewModel: viewModel)
                            .padding(.top, VersoSpacing.lg)
                    }

                    Spacer().frame(height: VersoSpacing.xxl + 72)
                }
            }
        }
    }

    // MARK: - Rating Badge

    private func ratingBadge(icon: String, iconColor: Color, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Action Buttons Row (Square Transparent)

    @ViewBuilder
    private func actionButtonsRow(item: BaseItemDto, viewModel: ItemDetailViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VersoSpacing.md) {
                // Play
                if viewModel.isMovie || viewModel.isEpisode {
                    actionButton(icon: "play.fill", label: "Play") {
                        showPlayer = true
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: showPlayer)
                }

                // Watched toggle
                if viewModel.isMovie || viewModel.isEpisode || viewModel.isSeries {
                    actionButton(
                        icon: item.userData?.played == true ? "checkmark" : "eye",
                        label: item.userData?.played == true ? "Watched" : "Unwatched",
                        isActive: item.userData?.played == true
                    ) {
                        Task { await viewModel.toggleWatched() }
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: item.userData?.played)
                }

                // Delete
                actionButton(icon: "trash", label: "Delete", tint: .red) {
                    showDeleteConfirmation = true
                }
            }
            .padding(.horizontal, VersoSpacing.lg)
        }
    }

    private func actionButton(
        icon: String,
        label: String,
        isActive: Bool = false,
        tint: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isActive ? Color.versoJade : tint)
                    .frame(width: 56, height: 56)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isActive ? Color.versoJade.opacity(0.4) : Color.white.opacity(0.15),
                                lineWidth: 1
                            )
                    )
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Metadata Info Bar (Genres · Director · Studio)

    @ViewBuilder
    private func metadataInfoBar(item: BaseItemDto) -> some View {
        let directors = item.people?.filter { $0.type == "Director" }.map(\.name) ?? []
        let writers = item.people?.filter { $0.type == "Writer" }.map(\.name) ?? []

        let columns: [(String, String)] = {
            var result: [(String, String)] = []
            if let genres = item.genres, !genres.isEmpty {
                result.append(("GENRES", genres.prefix(3).joined(separator: ", ")))
            }
            if !directors.isEmpty {
                result.append(("DIRECTOR", directors.prefix(2).joined(separator: ", ")))
            }
            if !writers.isEmpty {
                result.append(("WRITERS", writers.prefix(2).joined(separator: ", ")))
            }
            if let year = item.productionYear {
                result.append(("YEAR", String(year)))
            }
            if let official = item.officialRating {
                result.append(("RATING", official))
            }
            if let minutes = item.runtimeMinutes {
                let h = minutes / 60
                let m = minutes % 60
                result.append(("RUNTIME", h > 0 ? "\(h)h \(m)m" : "\(m) min"))
            }
            return result
        }()

        if !columns.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { index, col in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(col.0)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.versoSecondaryText)
                            Text(col.1)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }
                        .frame(minWidth: 100, alignment: .leading)
                        .padding(.horizontal, VersoSpacing.md)
                        .padding(.vertical, VersoSpacing.md)

                        if index < columns.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 0.5)
                                .padding(.vertical, VersoSpacing.sm)
                        }
                    }
                }
                .padding(.horizontal, VersoSpacing.sm)
            }
            .background(Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.horizontal, VersoSpacing.lg)
        }
    }

    // MARK: - Cast Section

    @ViewBuilder
    private func castSection(actors: [BaseItemPerson]) -> some View {
        VStack(alignment: .leading, spacing: VersoSpacing.md) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.versoJade)
                    .frame(width: 3, height: 16)
                Text("Cast")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, VersoSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VersoSpacing.md) {
                    ForEach(actors, id: \.id) { person in
                        VStack(spacing: VersoSpacing.xs) {
                            CachedAsyncImage(
                                url: ImageURLBuilder.jellyfinImageURL(
                                    baseURL: authManager.jellyfinClient.baseURL,
                                    itemId: person.id,
                                    imageType: .primary,
                                    maxWidth: 200,
                                    quality: 80
                                ),
                                displaySize: CGSize(width: 80, height: 80)
                            )
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )

                            Text(person.name)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .frame(width: 88)

                            if let role = person.role {
                                Text(role)
                                    .font(.caption2)
                                    .foregroundStyle(Color.versoSecondaryText)
                                    .lineLimit(1)
                                    .frame(width: 88)
                            }
                        }
                    }
                }
                .padding(.horizontal, VersoSpacing.lg)
            }
        }
    }

    // MARK: - Seasons Section

    @ViewBuilder
    private func seasonsSection(item: BaseItemDto, viewModel: ItemDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: VersoSpacing.md) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.versoJade)
                    .frame(width: 3, height: 16)
                Text("Seasons")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, VersoSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VersoSpacing.md) {
                    ForEach(viewModel.seasons) { season in
                        NavigationLink {
                            SeasonListView(
                                seriesId: item.id,
                                seasonId: season.id,
                                seasonName: season.name
                            )
                        } label: {
                            VStack(spacing: VersoSpacing.xs) {
                                CachedAsyncImage(
                                    url: ImageURLBuilder.jellyfinImageURL(
                                        baseURL: authManager.jellyfinClient.baseURL,
                                        itemId: season.id,
                                        imageType: .primary,
                                        maxWidth: 200,
                                        quality: 80
                                    ),
                                    cornerRadius: 12,
                                    displaySize: CGSize(width: 120, height: 180)
                                )
                                .frame(width: 110, height: 165)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                )

                                Text(season.name)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .frame(width: 110)

                                if let childCount = season.childCount {
                                    Text("\(childCount) episodes")
                                        .font(.caption2)
                                        .foregroundStyle(Color.versoSecondaryText)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, VersoSpacing.lg)
            }
        }
    }

    // MARK: - URL Helpers

    private func backdropURL(item: BaseItemDto) -> URL? {
        let baseURL = authManager.jellyfinClient.baseURL
        if item.type == "Episode", let seriesId = item.seriesId {
            return ImageURLBuilder.jellyfinImageURL(
                baseURL: baseURL, itemId: seriesId,
                imageType: .backdrop, maxWidth: 1280
            )
        }
        return ImageURLBuilder.jellyfinImageURL(
            baseURL: baseURL, itemId: item.id,
            imageType: .backdrop, maxWidth: 1280
        )
    }

    private func posterURL(item: BaseItemDto) -> URL? {
        let baseURL = authManager.jellyfinClient.baseURL
        if item.type == "Episode", let seriesId = item.seriesId {
            return ImageURLBuilder.jellyfinImageURL(
                baseURL: baseURL, itemId: seriesId, maxWidth: 400
            )
        }
        return ImageURLBuilder.jellyfinImageURL(
            baseURL: baseURL, itemId: item.id, maxWidth: 400
        )
    }

    private func logoURL(item: BaseItemDto) -> URL? {
        let baseURL = authManager.jellyfinClient.baseURL
        if item.imageTags?.logo != nil {
            return ImageURLBuilder.jellyfinImageURL(
                baseURL: baseURL, itemId: item.id,
                imageType: .logo, maxWidth: 600
            )
        }
        if item.type == "Episode", let seriesId = item.seriesId {
            return ImageURLBuilder.jellyfinImageURL(
                baseURL: baseURL, itemId: seriesId,
                imageType: .logo, maxWidth: 600
            )
        }
        return nil
    }
}
