import SwiftUI

struct RequestsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var viewModel: RequestsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if !authManager.jellyseerrClient.isConfigured {
                    ContentUnavailableView(
                        "Jellyseerr Not Configured",
                        systemImage: "gear.badge.xmark",
                        description: Text("Add your Jellyseerr URL and API key in login to enable requests")
                    )
                } else if let viewModel {
                    if viewModel.isLoading {
                        LoadingView()
                    } else if let error = viewModel.error {
                        ErrorView(message: error) {
                            Task { await viewModel.load() }
                        }
                    } else if viewModel.requests.isEmpty {
                        ContentUnavailableView(
                            "No Requests",
                            systemImage: "tray",
                            description: Text("Your content requests will appear here")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: VersoSpacing.md) {
                                ForEach(Array(viewModel.requests.enumerated()), id: \.element.id) { index, item in
                                    requestRow(item)
                                        .staggeredAppearance(index: index)
                                }
                            }
                            .padding(VersoSpacing.lg)
                        }
                    }
                } else {
                    LoadingView()
                }
            }
            .background(Color.versoBackground)
            .navigationTitle("Requests")
        }
        .task {
            guard authManager.jellyseerrClient.isConfigured else { return }
            let vm = RequestsViewModel(
                client: authManager.jellyseerrClient,
                prograrClient: authManager.prograrClient
            )
            viewModel = vm
            await vm.load()
        }
        .refreshable {
            await viewModel?.load()
        }
    }

    private func requestRow(_ item: RequestWithDetails) -> some View {
        HStack(spacing: VersoSpacing.md) {
            CachedAsyncImage(
                url: item.posterPath.flatMap { ImageURLBuilder.tmdbPosterURL(path: $0) },
                displaySize: CGSize(width: 50, height: 75)
            )
            .frame(width: 50, height: 75)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: VersoSpacing.xs) {
                Text(item.request.media?.mediaType?.uppercased() ?? "MEDIA")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.versoSecondaryText)

                Text(item.title ?? "Request #\(item.request.id)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let progress = item.downloadProgress, progress.isActive {
                    downloadProgressView(progress)
                } else if let progress = item.downloadProgress {
                    prograrStatusView(progress)
                } else if let date = item.request.createdAt {
                    Text(String(date.prefix(10)))
                        .font(.caption)
                        .foregroundStyle(Color.versoSecondaryText)
                }
            }

            Spacer()

            StatusBadge(status: item.request.status)
        }
        .padding(VersoSpacing.md)
        .background(Color.versoCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func prograrStatusView(_ progress: PrograrMediaRequest) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(prograrStatusColor(progress))
                .frame(width: 6, height: 6)
            Text(prograrStatusText(progress))
                .font(.caption)
                .foregroundStyle(prograrStatusColor(progress))
        }
    }

    private func prograrStatusText(_ progress: PrograrMediaRequest) -> String {
        if progress.isMissing == true {
            return "Searching..."
        }
        if progress.isNotAvailable == true {
            return "Unreleased"
        }
        switch progress.requestStatus {
        case "approved": return "Searching..."
        case "pending": return "Pending"
        case "processing": return "Processing..."
        default: return "Pending"
        }
    }

    private func prograrStatusColor(_ progress: PrograrMediaRequest) -> Color {
        if progress.isMissing == true {
            return Color.versoSilver
        }
        switch progress.requestStatus {
        case "approved", "processing": return Color.versoSilver
        default: return .versoSecondaryText
        }
    }

    private func downloadProgressView(_ progress: PrograrMediaRequest) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.versoCardBorder)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.versoGradient)
                        .frame(width: geo.size.width * CGFloat((progress.downloadProgress ?? 0) / 100.0), height: 6)
                }
            }
            .frame(height: 6)

            // Speed + ETA
            HStack(spacing: VersoSpacing.sm) {
                if let pct = progress.downloadProgress {
                    Text(String(format: "%.1f%%", pct))
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
                if let speed = progress.formattedSpeed {
                    Text(speed)
                        .font(.caption2)
                        .foregroundStyle(Color.versoSecondaryText)
                }
                if let eta = progress.formattedETA {
                    Text(eta)
                        .font(.caption2)
                        .foregroundStyle(Color.versoSecondaryText)
                }
            }
        }
    }
}
