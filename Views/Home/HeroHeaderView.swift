import SwiftUI

struct HeroCarouselView: View {
    let items: [BaseItemDto]
    let backdropURL: (BaseItemDto) -> URL?
    let logoURL: (BaseItemDto) -> URL?
    let onSelect: (BaseItemDto) -> Void

    @State private var currentPage = 0

    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen carousel
            TabView(selection: $currentPage) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    heroPage(item: item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: screenHeight)

            // Frosted info panel at bottom
            if let currentItem = items[safe: currentPage] {
                VStack(alignment: .leading, spacing: 6) {
                    // Metadata line: Year · Rating · Runtime · Genres
                    HStack(spacing: 0) {
                        if let year = currentItem.productionYear {
                            Text(String(year))
                        }
                        if let rating = currentItem.officialRating {
                            Text(" \u{2022} ").foregroundStyle(.white.opacity(0.4))
                            Text(rating)
                        }
                        if let minutes = currentItem.runtimeMinutes {
                            Text(" \u{2022} ").foregroundStyle(.white.opacity(0.4))
                            Text(formattedRuntime(minutes))
                        }
                        if let genres = currentItem.genres, !genres.isEmpty {
                            Text(" \u{2022} ").foregroundStyle(.white.opacity(0.4))
                            Text(genres.prefix(3).joined(separator: " \u{2022} "))
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                    // Rating row
                    if let communityRating = currentItem.communityRating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", communityRating))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }

                    // Overview
                    if let overview = currentItem.overview {
                        Text(overview)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                            .lineSpacing(2)
                    }
                }
                .padding(.horizontal, VersoSpacing.lg)
                .padding(.vertical, VersoSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.versoCard.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
                .padding(.horizontal, VersoSpacing.lg)
                .padding(.bottom, VersoSpacing.xxl + 16)
                .contentShape(Rectangle())
                .onTapGesture { onSelect(currentItem) }
                .animation(.easeInOut(duration: 0.3), value: currentPage)
            }

            // Page dots
            if items.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<items.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                            .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.bottom, VersoSpacing.md)
            }
        }
        .frame(height: screenHeight)
        .task {
            // Single auto-advance task tied to view lifecycle — automatically cancelled on disappear
            guard items.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentPage = (currentPage + 1) % items.count
                }
            }
        }
    }

    @ViewBuilder
    private func heroPage(item: BaseItemDto) -> some View {
        Color.clear
            .overlay {
                CachedAsyncImage(url: backdropURL(item), displaySize: CGSize(width: screenWidth * 2, height: screenHeight * 2))
            }
            .clipped()
            .overlay {
                // Bottom gradient for readability
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.3),
                        .init(color: Color.versoBackground.opacity(0.4), location: 0.6),
                        .init(color: Color.versoBackground.opacity(0.85), location: 0.85),
                        .init(color: Color.versoBackground, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                // Logo image overlay (if available)
                if let url = logoURL(item) {
                    CachedAsyncImage(url: url, cornerRadius: 0, displaySize: CGSize(width: 500, height: 200))
                        .frame(maxWidth: screenWidth * 0.55, maxHeight: 120)
                        .aspectRatio(contentMode: .fit)
                        .shadow(color: .black.opacity(0.7), radius: 16, y: 6)
                        .padding(.leading, VersoSpacing.lg)
                        .padding(.bottom, 200)
                }
            }
    }

    private func formattedRuntime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
