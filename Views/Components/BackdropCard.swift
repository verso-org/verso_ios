import SwiftUI

struct BackdropCard: View {
    let title: String
    let imageURL: URL?
    var subtitle: String? = nil
    var progress: Double? = nil
    var width: CGFloat = 280

    private var height: CGFloat { width * 9 / 16 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                CachedAsyncImage(url: imageURL, cornerRadius: 14, displaySize: CGSize(width: width, height: height))
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                GradientOverlay(direction: .bottom, endOpacity: 0.8)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VersoSpacing.md)
                .padding(.bottom, progress != nil && progress! > 0 ? 10 : VersoSpacing.md)

                if let progress, progress > 0 {
                    VStack {
                        Spacer()
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(.white.opacity(0.15))
                                .frame(height: 3)
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.versoJade, .versoSilver],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: width * progress / 100, height: 3)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        }
        .frame(width: width)
    }
}
