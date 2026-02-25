import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var viewModel: HomeViewModel?
    @State private var selectedHeroItem: BaseItemDto?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    if viewModel.isLoading {
                        LoadingView()
                    } else if let error = viewModel.error {
                        ErrorView(message: error) {
                            Task { await viewModel.load() }
                        }
                    } else {
                        scrollContent(viewModel: viewModel)
                    }
                } else {
                    LoadingView()
                }
            }
            .background(Color.versoBackground)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        authManager.logout()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            }
        }
        .task {
            let vm = HomeViewModel(
                client: authManager.jellyfinClient,
                prograrClient: authManager.prograrClient
            )
            viewModel = vm
            await vm.load()
        }
        .onDisappear { viewModel?.stopPolling() }
        .refreshable { await viewModel?.load() }
    }

    @ViewBuilder
    private func scrollContent(viewModel: HomeViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: VersoSpacing.section) {
                // Hero Carousel
                if !viewModel.featuredItems.isEmpty {
                    HeroCarouselView(
                        items: viewModel.featuredItems,
                        backdropURL: { item in backdropURL(for: item, maxWidth: 1280) },
                        logoURL: { item in logoURL(for: item) },
                        onSelect: { item in selectedHeroItem = item }
                    )
                    .padding(.top, -60)
                }

                // Continue Watching — poster cards with scroll-linked 3D
                if !viewModel.resumeItems.isEmpty {
                    VStack(alignment: .leading, spacing: VersoSpacing.md) {
                        sectionHeader("Continue Watching")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: VersoSpacing.md) {
                                ForEach(viewModel.resumeItems) { item in
                                    NavigationLink(value: item) {
                                        ContinueWatchingCard(
                                            title: item.name,
                                            subtitle: item.seriesName,
                                            imageURL: posterURL(for: item),
                                            progress: item.userData?.progressPercentage
                                        )
                                    }
                                    .buttonStyle(.cardPress)
                                }
                            }
                            .padding(.horizontal, VersoSpacing.lg)
                        }
                    }
                }

                // Active Downloads
                if !viewModel.activeDownloads.isEmpty {
                    VStack(alignment: .leading, spacing: VersoSpacing.md) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(Color.versoGradient)
                            Text("Downloading")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, VersoSpacing.lg)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: VersoSpacing.md) {
                                ForEach(viewModel.activeDownloads) { download in
                                    DownloadCard(download: download)
                                }
                            }
                            .padding(.horizontal, VersoSpacing.lg)
                        }
                    }
                }

                // Latest per library — cards with scroll-linked parallax
                ForEach(viewModel.latestByLibrary, id: \.library.id) { section in
                    VStack(alignment: .leading, spacing: VersoSpacing.md) {
                        sectionHeader("Latest in \(section.library.name)")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: VersoSpacing.md) {
                                ForEach(section.items) { item in
                                    NavigationLink(value: item) {
                                        PosterCard(
                                            title: item.name,
                                            imageURL: ImageURLBuilder.jellyfinImageURL(
                                                baseURL: authManager.jellyfinClient.baseURL,
                                                itemId: item.id,
                                                maxWidth: 200
                                            ),
                                            subtitle: item.productionYear.map(String.init)
                                        )
                                    }
                                    .buttonStyle(.cardPress)
                                }
                            }
                            .padding(.horizontal, VersoSpacing.lg)
                        }
                    }
                }
            }
            .padding(.bottom, VersoSpacing.xl + 72)
        }
        .navigationDestination(for: BaseItemDto.self) { item in
            ItemDetailView(itemId: item.id)
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedHeroItem != nil },
            set: { if !$0 { selectedHeroItem = nil } }
        )) {
            if let item = selectedHeroItem {
                ItemDetailView(itemId: item.id)
            }
        }
    }

    // MARK: - Section header with jade accent bar

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.versoJade)
                .frame(width: 3, height: 16)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, VersoSpacing.lg)
    }

    // MARK: - URL helpers

    private func backdropURL(for item: BaseItemDto, maxWidth: Int = 560) -> URL? {
        let baseURL = authManager.jellyfinClient.baseURL
        if item.type == "Episode", let seriesId = item.seriesId {
            return ImageURLBuilder.jellyfinImageURL(
                baseURL: baseURL, itemId: seriesId,
                imageType: .backdrop, maxWidth: maxWidth
            )
        }
        return ImageURLBuilder.jellyfinImageURL(
            baseURL: baseURL, itemId: item.id,
            imageType: .backdrop, maxWidth: maxWidth
        )
    }

    private func logoURL(for item: BaseItemDto) -> URL? {
        let baseURL = authManager.jellyfinClient.baseURL
        // Check if the item itself has a logo
        if item.imageTags?.logo != nil {
            return ImageURLBuilder.jellyfinImageURL(
                baseURL: baseURL, itemId: item.id,
                imageType: .logo, maxWidth: 600
            )
        }
        // For episodes, try the series logo
        if item.type == "Episode", let seriesId = item.seriesId {
            return ImageURLBuilder.jellyfinImageURL(
                baseURL: baseURL, itemId: seriesId,
                imageType: .logo, maxWidth: 600
            )
        }
        return nil
    }

    private func posterURL(for item: BaseItemDto) -> URL? {
        let baseURL = authManager.jellyfinClient.baseURL
        if item.type == "Episode", let seriesId = item.seriesId {
            return ImageURLBuilder.jellyfinImageURL(baseURL: baseURL, itemId: seriesId, maxWidth: 200)
        }
        return ImageURLBuilder.jellyfinImageURL(baseURL: baseURL, itemId: item.id, maxWidth: 200)
    }
}

// MARK: - Continue Watching Card (poster style with living progress bar)

struct ContinueWatchingCard: View {
    let title: String
    var subtitle: String? = nil
    let imageURL: URL?
    var progress: Double? = nil

    private let cardWidth: CGFloat = 120
    private var cardHeight: CGFloat { cardWidth * 1.5 }

    var body: some View {
        VStack(alignment: .leading, spacing: VersoSpacing.xs) {
            ZStack(alignment: .bottom) {
                CachedAsyncImage(url: imageURL, cornerRadius: 16, displaySize: CGSize(width: cardWidth, height: cardHeight))
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Progress bar at bottom edge
                if let progress, progress > 0 {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.white.opacity(0.15))
                            .frame(height: 3)
                        Rectangle()
                            .fill(Color.versoJade)
                            .frame(width: cardWidth * progress / 100, height: 3)
                    }
                    .clipShape(
                        UnevenRoundedRectangle(
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 16
                        )
                    )
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 3)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: cardWidth, alignment: .leading)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.versoSecondaryText)
                    .lineLimit(1)
                    .frame(width: cardWidth, alignment: .leading)
            }
        }
    }
}
