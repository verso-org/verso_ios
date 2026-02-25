import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var viewModel: SearchViewModel?
    @State private var requestItem: SeerrSearchResult?

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: VersoSpacing.md)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    searchContent(viewModel: viewModel)
                } else {
                    LoadingView()
                }
            }
            .background(Color.versoBackground)
            .navigationTitle("Discover")
            .toolbar {
                if authManager.jellyseerrClient.isConfigured {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            RequestsView()
                        } label: {
                            Image(systemName: "list.bullet.clipboard")
                        }
                    }
                }
            }
        }
        .task {
            let vm = SearchViewModel(
                jellyseerrClient: authManager.jellyseerrClient
            )
            viewModel = vm
            await vm.loadSuggestions()
        }
    }

    @ViewBuilder
    private func searchContent(viewModel: SearchViewModel) -> some View {
        VStack(spacing: 0) {
            if viewModel.isSearching {
                LoadingView()
            } else if let error = viewModel.error {
                ErrorView(message: error) {
                    Task { await viewModel.search() }
                }
            } else if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                trendingContent(viewModel: viewModel)
            } else {
                ScrollView {
                    discoverResultsGrid(viewModel: viewModel)
                }
            }
        }
        .searchable(text: Binding(
            get: { viewModel.query },
            set: {
                viewModel.query = $0
                viewModel.queryChanged()
            }
        ), prompt: "Search TMDB")
        .searchSuggestions {
            ForEach(viewModel.suggestions) { result in
                Button {
                    requestItem = result
                    viewModel.clearSuggestions()
                } label: {
                    suggestionLabel(
                        title: result.title,
                        year: result.year,
                        type: result.mediaType.capitalized
                    )
                }
            }
        }
        .onSubmit(of: .search) {
            viewModel.clearSuggestions()
            Task { await viewModel.search() }
        }
        .sheet(item: $requestItem) { item in
            RequestSheet(item: item)
        }
    }

    // MARK: - Trending

    @ViewBuilder
    private func trendingContent(viewModel: SearchViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VersoSpacing.section) {
                trendingSection(viewModel: viewModel)
            }
            .padding(.top, VersoSpacing.md)
        }
    }

    @ViewBuilder
    private func trendingSection(viewModel: SearchViewModel) -> some View {
        if !viewModel.trendingResults.isEmpty {
            VStack(alignment: .leading, spacing: VersoSpacing.md) {
                Text("Trending")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, VersoSpacing.lg)

                LazyVGrid(columns: columns, spacing: VersoSpacing.lg) {
                    ForEach(Array(viewModel.trendingResults.enumerated()), id: \.element.id) { index, result in
                        Button {
                            requestItem = result
                        } label: {
                            PosterCard(
                                title: result.title,
                                imageURL: result.posterPath.flatMap { ImageURLBuilder.tmdbPosterURL(path: $0) },
                                subtitle: result.year
                            )
                            .overlay(alignment: .topTrailing) {
                                if let mediaInfo = result.mediaInfo {
                                    StatusBadge(status: mediaInfo.status ?? 0)
                                        .padding(VersoSpacing.xs)
                                }
                            }
                        }
                        .buttonStyle(.cardPress)
                        .staggeredAppearance(index: index)
                        .onAppear {
                            if index == viewModel.trendingResults.count - 1 {
                                Task { await viewModel.loadMoreTrending() }
                            }
                        }
                    }
                }
                .padding(.horizontal, VersoSpacing.lg)

                if viewModel.isLoadingMoreTrending {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VersoSpacing.md)
                }
            }
        } else if viewModel.isLoadingSuggestions {
            LoadingView()
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private func discoverResultsGrid(viewModel: SearchViewModel) -> some View {
        if viewModel.discoverResults.isEmpty && !viewModel.query.isEmpty {
            ContentUnavailableView("No results", systemImage: "magnifyingglass")
        } else {
            LazyVGrid(columns: columns, spacing: VersoSpacing.lg) {
                ForEach(Array(viewModel.discoverResults.enumerated()), id: \.element.id) { index, result in
                    Button {
                        requestItem = result
                    } label: {
                        PosterCard(
                            title: result.title,
                            imageURL: result.posterPath.flatMap { ImageURLBuilder.tmdbPosterURL(path: $0) },
                            subtitle: result.year
                        )
                        .overlay(alignment: .topTrailing) {
                            if let mediaInfo = result.mediaInfo {
                                StatusBadge(status: mediaInfo.status ?? 0)
                                    .padding(VersoSpacing.xs)
                            }
                        }
                    }
                    .buttonStyle(.cardPress)
                    .staggeredAppearance(index: index)
                }
            }
            .padding(VersoSpacing.lg)
        }
    }

    // MARK: - Suggestion Label

    private func suggestionLabel(title: String, year: String?, type: String?) -> some View {
        HStack(spacing: VersoSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let year {
                    Text(year)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let type {
                Text(type)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
}

extension SearchHint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: SearchHint, rhs: SearchHint) -> Bool {
        lhs.id == rhs.id
    }
}
