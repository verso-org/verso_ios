import SwiftUI

struct LibraryItem: Hashable {
    let dto: BaseItemDto
    func hash(into hasher: inout Hasher) { hasher.combine(dto.id) }
    static func == (lhs: LibraryItem, rhs: LibraryItem) -> Bool { lhs.dto.id == rhs.dto.id }
}

struct LibraryListView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var viewModel: LibraryListViewModel?
    @State private var searchQuery = ""

    private let columns = [
        GridItem(.flexible(), spacing: VersoSpacing.lg),
        GridItem(.flexible(), spacing: VersoSpacing.lg)
    ]

    private let searchColumns = [
        GridItem(.adaptive(minimum: 110), spacing: VersoSpacing.md)
    ]

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
                    } else if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        searchResultsContent(viewModel: viewModel)
                    } else {
                        scrollContent(viewModel: viewModel)
                    }
                } else {
                    LoadingView()
                }
            }
            .background(Color.versoBackground)
            .navigationTitle("Library")
            .searchable(text: $searchQuery, prompt: "Search your library")
            .searchSuggestions {
                if let viewModel {
                    ForEach(viewModel.searchSuggestions) { hint in
                        NavigationLink(value: hint) {
                            HStack(spacing: VersoSpacing.sm) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hint.name)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    if let year = hint.productionYear {
                                        Text(String(year))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if let type = hint.type {
                                    Text(type)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                            }
                        }
                        .searchCompletion(hint.name)
                    }
                }
            }
            .onChange(of: searchQuery) { _, newValue in
                viewModel?.searchQueryChanged(newValue)
            }
            .onSubmit(of: .search) {
                viewModel?.clearSearchSuggestions()
                Task {
                    await viewModel?.search(query: searchQuery)
                }
            }
            .navigationDestination(for: LibraryItem.self) { item in
                LibraryDetailView(library: item.dto)
            }
            .navigationDestination(for: BaseItemDto.self) { item in
                ItemDetailView(itemId: item.id)
            }
            .navigationDestination(for: SearchHint.self) { hint in
                ItemDetailView(itemId: hint.id)
            }
        }
        .task {
            let vm = LibraryListViewModel(client: authManager.jellyfinClient)
            viewModel = vm
            await vm.load()
        }
        .refreshable {
            await viewModel?.load()
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private func searchResultsContent(viewModel: LibraryListViewModel) -> some View {
        if viewModel.isSearching {
            LoadingView()
        } else if let error = viewModel.searchError {
            ErrorView(message: error) {
                Task { await viewModel.search(query: searchQuery) }
            }
        } else if viewModel.searchResults.isEmpty {
            ContentUnavailableView("No results", systemImage: "magnifyingglass")
        } else {
            ScrollView {
                LazyVGrid(columns: searchColumns, spacing: VersoSpacing.lg) {
                    ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, hint in
                        NavigationLink(value: hint) {
                            PosterCard(
                                title: hint.name,
                                imageURL: ImageURLBuilder.jellyfinImageURL(
                                    baseURL: authManager.jellyfinClient.baseURL,
                                    itemId: hint.id
                                ),
                                subtitle: hint.productionYear.map(String.init)
                            )
                        }
                        .buttonStyle(.cardPress)
                        .staggeredAppearance(index: index)
                    }
                }
                .padding(VersoSpacing.lg)
            }
        }
    }

    // MARK: - Scroll Content

    @ViewBuilder
    private func scrollContent(viewModel: LibraryListViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: VersoSpacing.section) {
                // Library cards grid
                LazyVGrid(columns: columns, spacing: VersoSpacing.xl) {
                    ForEach(Array(viewModel.libraries.enumerated()), id: \.element.id) { index, library in
                        NavigationLink(value: LibraryItem(dto: library)) {
                            libraryCard(library)
                        }
                        .buttonStyle(.cardPress)
                        .staggeredAppearance(index: index)
                    }
                }
                .padding(.horizontal, VersoSpacing.lg)

                // Franchises
                if !viewModel.collections.isEmpty {
                    VStack(alignment: .leading, spacing: VersoSpacing.md) {
                        sectionHeader("Franchises")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: VersoSpacing.md) {
                                ForEach(viewModel.collections) { collection in
                                    NavigationLink(value: LibraryItem(dto: collection)) {
                                        PosterCard(
                                            title: collection.name,
                                            imageURL: ImageURLBuilder.jellyfinImageURL(
                                                baseURL: authManager.jellyfinClient.baseURL,
                                                itemId: collection.id
                                            ),
                                            subtitle: nil
                                        )
                                    }
                                    .buttonStyle(.cardPress)
                                }
                            }
                            .padding(.horizontal, VersoSpacing.lg)
                        }
                    }
                }

                // Recently Added per library
                ForEach(viewModel.latestByLibrary, id: \.library.id) { section in
                    VStack(alignment: .leading, spacing: VersoSpacing.md) {
                        sectionHeader("Recently Added in \(section.library.name)")
                        horizontalPosterRow(items: section.items)
                    }
                }

                // Top Rated
                if !viewModel.topRated.isEmpty {
                    VStack(alignment: .leading, spacing: VersoSpacing.md) {
                        sectionHeader("Top Rated")
                        horizontalPosterRow(items: viewModel.topRated, showRating: true)
                    }
                }

                // Random Picks
                if !viewModel.randomPicks.isEmpty {
                    VStack(alignment: .leading, spacing: VersoSpacing.md) {
                        sectionHeader("You Might Like")
                        horizontalPosterRow(items: viewModel.randomPicks)
                    }
                }
            }
            .padding(.vertical, VersoSpacing.lg)
            .padding(.bottom, 72)
        }
    }

    // MARK: - Reusable Components

    private func horizontalPosterRow(items: [BaseItemDto], showRating: Bool = false) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: VersoSpacing.md) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        PosterCard(
                            title: item.name,
                            imageURL: ImageURLBuilder.jellyfinImageURL(
                                baseURL: authManager.jellyfinClient.baseURL,
                                itemId: item.id
                            ),
                            subtitle: itemSubtitle(for: item),
                            communityRating: showRating ? item.communityRating : nil,
                            isWatched: item.userData?.played == true
                        )
                    }
                    .buttonStyle(.cardPress)
                }
            }
            .padding(.horizontal, VersoSpacing.lg)
        }
    }

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

    private func libraryCard(_ library: BaseItemDto) -> some View {
        Color.clear
            .frame(height: 200)
            .overlay {
                CachedAsyncImage(
                    url: ImageURLBuilder.jellyfinImageURL(
                        baseURL: authManager.jellyfinClient.baseURL,
                        itemId: library.id,
                        imageType: .primary,
                        maxWidth: 500
                    ),
                    displaySize: CGSize(width: 500, height: 200)
                )
            }
            .overlay {
                // Cinematic multi-stop gradient
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Color.versoBackground.opacity(0.4), location: 0.4),
                        .init(color: Color.versoBackground.opacity(0.85), location: 0.75),
                        .init(color: Color.versoBackground.opacity(0.95), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                Text(library.name)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 8, y: 3)
                    .padding(.horizontal, VersoSpacing.lg)
                    .padding(.vertical, VersoSpacing.md)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
    }

    private func itemSubtitle(for item: BaseItemDto) -> String? {
        switch item.type {
        case "Series":
            if let childCount = item.childCount {
                return childCount == 1 ? "1 Season" : "\(childCount) Seasons"
            }
            return item.productionYear.map(String.init)
        case "Movie":
            var parts: [String] = []
            if let year = item.productionYear {
                parts.append(String(year))
            }
            if let minutes = item.runtimeMinutes {
                let h = minutes / 60
                let m = minutes % 60
                parts.append(h > 0 ? "\(h)h \(m)m" : "\(m)m")
            }
            return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
        default:
            return item.productionYear.map(String.init)
        }
    }
}
