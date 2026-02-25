import SwiftUI

struct DownloadCard: View {
    let download: PrograrMediaRequest

    private let width: CGFloat = 140
    private var height: CGFloat { width * 1.5 }

    var body: some View {
        VStack(alignment: .leading, spacing: VersoSpacing.xs) {
            ZStack(alignment: .bottom) {
                // Poster image
                CachedAsyncImage(
                    url: download.posterUrl.flatMap { ImageURLBuilder.tmdbPosterURL(path: $0) },
                    cornerRadius: 14,
                    displaySize: CGSize(width: width, height: height)
                )
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                GradientOverlay(direction: .bottom, endOpacity: 0.9)
                    .frame(height: height * 0.5)
                    .clipShape(
                        UnevenRoundedRectangle(
                            bottomLeadingRadius: 12,
                            bottomTrailingRadius: 12
                        )
                    )

                // Download info overlay
                VStack(alignment: .leading, spacing: 4) {
                    Text(download.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

                    if let year = download.year {
                        Text(String(year))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    // Status + progress — prefer episode-level detail for series
                    if download.hasEpisodeActivity {
                        episodeProgress
                    } else if download.isDownloading, let progress = download.downloadProgress {
                        progressBar(progress: progress)
                        downloadDetails
                    } else {
                        statusLabel
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VersoSpacing.sm)
                .padding(.bottom, VersoSpacing.sm)
            }
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        }
        .frame(width: width)
    }

    private func progressBar(progress: Double) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(.white.opacity(0.15))
                .frame(height: 4)
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [.versoJade, .versoSilver],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(0, width - VersoSpacing.sm * 2) * progress / 100, height: 4)
        }
    }

    private var downloadDetails: some View {
        HStack(spacing: 4) {
            if let progress = download.downloadProgress {
                Text("\(Int(progress))%")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.versoSilver)
            }
            if let speed = download.formattedSpeed {
                Text(speed)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            if let eta = download.formattedETA {
                Text(eta)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    @ViewBuilder
    private var episodeProgress: some View {
        let active = download.episodeDownloads?.filter {
            guard let status = $0.downloadStatus else { return false }
            return ["downloading", "paused", "queued", "stalled"].contains(status)
        } ?? []

        if !active.isEmpty {
            let totalProgress = active.compactMap(\.downloadProgress).reduce(0, +)
            let averageProgress = totalProgress / Double(active.count)
            let fastest = active.max(by: { ($0.downloadSpeed ?? 0) < ($1.downloadSpeed ?? 0) })
            let label = active.count == 1
                ? "S\(active[0].seasonNumber)E\(active[0].episodeNumber)"
                : "\(active.count) episodes"

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.versoSilver)
                progressBar(progress: averageProgress)
                HStack(spacing: 4) {
                    Text("\(Int(averageProgress))%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.versoSilver)
                    if let speed = fastest?.formattedSpeed {
                        Text(speed)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    if let eta = fastest?.formattedETA {
                        Text(eta)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
    }

    private var statusLabel: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var statusColor: Color {
        switch download.downloadStatus {
        case "completed": return .green
        case "queued": return .orange
        case "paused": return .yellow
        default:
            if download.isMissing == true {
                return Color.versoSilver
            }
            switch download.requestStatus {
            case "approved", "processing": return Color.versoSilver
            default: return .versoSecondaryText
            }
        }
    }

    private var statusText: String {
        switch download.downloadStatus {
        case "completed": return "Complete"
        case "queued": return "Queued"
        case "paused": return "Paused"
        case "stalled": return "Stalled"
        default:
            if download.isMissing == true {
                return "Searching..."
            }
            if download.isNotAvailable == true {
                return "Unreleased"
            }
            switch download.requestStatus {
            case "approved": return "Searching..."
            case "pending": return "Pending"
            case "processing": return "Processing..."
            default: return "Pending"
            }
        }
    }
}
