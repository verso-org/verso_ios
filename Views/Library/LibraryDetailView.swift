import SwiftUI

struct LibraryDetailView: View {
    @EnvironmentObject private var authManager: AuthManager
    let library: BaseItemDto
    @State private var viewModel: LibraryDetailViewModel?
    @State private var selectedLetter: String?

    private let alphabet = ["#"] + (65...90).map { String(UnicodeScalar($0)) }

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: VersoSpacing.md)
    ]

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.error {
                    ErrorView(message: error) {
                        Task { await viewModel.load() }
                    }
                } else {
                    libraryContent(viewModel: viewModel)
                }
            } else {
                LoadingView()
            }
        }
        .background(Color.versoBackground)
        .navigationTitle(library.name)
        .task {
            let vm = LibraryDetailViewModel(
                client: authManager.jellyfinClient,
                libraryId: library.id,
                collectionType: library.collectionType
            )
            viewModel = vm
            await vm.load()
        }
    }

    @ViewBuilder
    private func libraryContent(viewModel: LibraryDetailViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: VersoSpacing.md) {
                    // Item count header
                    Text("\(library.name) \u{00B7} \(viewModel.totalCount) Items")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.versoSecondaryText)
                        .padding(.horizontal, VersoSpacing.lg)
                        .padding(.top, VersoSpacing.sm)

                    // Alphabet filter bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 3) {
                            ForEach(alphabet, id: \.self) { letter in
                                Button {
                                    selectedLetter = letter
                                    scrollToLetter(letter, items: viewModel.items, proxy: proxy)
                                } label: {
                                    Text(letter)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(selectedLetter == letter ? .white : Color.versoSecondaryText.opacity(0.6))
                                        .frame(width: 28, height: 28)
                                        .background(
                                            selectedLetter == letter
                                                ? Color.versoJade.opacity(0.25)
                                                : Color.clear
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .sensoryFeedback(.selection, trigger: selectedLetter)
                            }
                        }
                        .padding(.horizontal, VersoSpacing.lg)
                    }

                    // Grid
                    LazyVGrid(columns: columns, spacing: VersoSpacing.lg) {
                        ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                            NavigationLink(value: item) {
                                PosterCard(
                                    title: item.name,
                                    imageURL: ImageURLBuilder.jellyfinImageURL(
                                        baseURL: authManager.jellyfinClient.baseURL,
                                        itemId: item.id
                                    ),
                                    subtitle: buildSubtitle(for: item),
                                    communityRating: item.communityRating,
                                    isWatched: item.userData?.played == true,
                                    secondarySubtitle: item.genres?.first
                                )
                            }
                            .buttonStyle(.cardPress)
                            .staggeredAppearance(index: index % 20)
                            .id("item-\(item.id)")
                            .onAppear {
                                let threshold = max(0, viewModel.items.count - 5)
                                if index >= threshold {
                                    Task { await viewModel.loadMore() }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, VersoSpacing.lg)

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, VersoSpacing.xl + 72)
            }
        }
    }

    private func scrollToLetter(_ letter: String, items: [BaseItemDto], proxy: ScrollViewProxy) {
        let target: BaseItemDto?
        if letter == "#" {
            target = items.first { item in
                guard let first = item.name.first else { return false }
                return !first.isLetter
            }
        } else {
            target = items.first { item in
                item.name.uppercased().hasPrefix(letter)
            }
        }
        if let target {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo("item-\(target.id)", anchor: .top)
            }
        }
    }

    private func buildSubtitle(for item: BaseItemDto) -> String? {
        var parts: [String] = []
        if let year = item.productionYear {
            parts.append(String(year))
        }
        if item.type == "Series", let count = item.childCount {
            parts.append("\(count) season\(count == 1 ? "" : "s")")
        } else if let minutes = item.runtimeMinutes {
            parts.append("\(minutes) min")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }
}
