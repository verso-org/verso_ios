import SwiftUI

struct PosterCard: View {
    let title: String
    let imageURL: URL?
    var subtitle: String? = nil
    var width: CGFloat = 120
    var communityRating: Double? = nil
    var isWatched: Bool = false
    var secondarySubtitle: String? = nil

    private var height: CGFloat { width * 1.5 }

    var body: some View {
        VStack(alignment: .leading, spacing: VersoSpacing.xs) {
            ZStack {
                CachedAsyncImage(url: imageURL, cornerRadius: 16, displaySize: CGSize(width: width, height: height))
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Rating badge
                if let rating = communityRating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(6)
                }

                // Watched checkmark
                if isWatched {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.versoJade)
                        .background(Circle().fill(.black.opacity(0.5)).padding(-2))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(6)
                }
            }
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 3)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: width, alignment: .leading)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.versoSecondaryText)
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)
            }

            if let secondarySubtitle {
                Text(secondarySubtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.versoSecondaryText.opacity(0.7))
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)
            }
        }
    }
}
