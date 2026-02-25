import SwiftUI

struct RequestSheet: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    let item: SeerrSearchResult

    @State private var viewModel: RequestSheetViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    contentSection
                }
            }
            .background(Color.versoBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .task {
                let vm = RequestSheetViewModel(
                    item: item,
                    client: authManager.jellyseerrClient,
                    prograrClient: authManager.prograrClient
                )
                viewModel = vm
                await vm.loadConfig()
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            CachedAsyncImage(
                url: item.backdropPath.flatMap { ImageURLBuilder.tmdbBackdropURL(path: $0) },
                displaySize: CGSize(width: UIScreen.main.bounds.width, height: 220)
            )
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipped()

            GradientOverlay(direction: .full, color: .versoBackground, endOpacity: 1.0)
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(spacing: VersoSpacing.lg) {
            // Poster
            CachedAsyncImage(
                url: item.posterPath.flatMap { ImageURLBuilder.tmdbPosterURL(path: $0) },
                displaySize: CGSize(width: 120, height: 180)
            )
            .frame(width: 120, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
            .offset(y: -50)
            .padding(.bottom, -50)

            // Title
            Text(item.title)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Year + Status
            HStack(spacing: VersoSpacing.sm) {
                if let year = item.year {
                    Text(year)
                        .font(.subheadline)
                        .foregroundStyle(Color.versoSecondaryText)
                }
                if let mediaInfo = item.mediaInfo, let status = mediaInfo.status {
                    StatusBadge(status: status)
                }
            }

            // Overview
            if let overview = item.overview {
                Text(overview)
                    .font(.subheadline)
                    .foregroundStyle(Color.versoSecondaryText)
                    .lineLimit(4)
                    .multilineTextAlignment(.center)
                    .padding(VersoSpacing.md)
                    .frame(maxWidth: .infinity)
                    .background(Color.versoCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if let vm = viewModel {
                qualityProfileSection(vm: vm)

                if !vm.isMovie {
                    seasonSection(vm: vm)
                }

                if let downloadInfo = vm.downloadInfo, downloadInfo.isActive {
                    downloadProgressSection(downloadInfo)
                }

                actionSection(vm: vm)
            }
        }
        .padding(.horizontal, VersoSpacing.lg)
        .padding(.bottom, VersoSpacing.xxl)
    }

    // MARK: - Quality Profile Picker

    @ViewBuilder
    private func qualityProfileSection(vm: RequestSheetViewModel) -> some View {
        if vm.isLoadingConfig {
            ProgressView()
                .tint(.white)
                .padding(.vertical, VersoSpacing.lg)
        } else if !vm.servers.isEmpty {
            VStack(alignment: .leading, spacing: VersoSpacing.sm) {
                Text("Quality Profile")
                    .font(.headline)
                    .foregroundStyle(.white)

                // Server picker (only if multiple servers)
                if vm.servers.count > 1 {
                    Menu {
                        ForEach(vm.servers) { server in
                            Button {
                                Task { await vm.selectServer(server) }
                            } label: {
                                HStack {
                                    Text(server.name + (server.is4k ? " (4K)" : ""))
                                    if server.id == vm.selectedServer?.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(vm.selectedServer?.name ?? "Select Server")
                                .foregroundStyle(.white)
                            if vm.selectedServer?.is4k == true {
                                Text("4K")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.versoJade.opacity(0.3))
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(Color.versoSecondaryText)
                        }
                        .padding(VersoSpacing.md)
                        .background(Color.versoCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                // Profile capsules
                if vm.isLoadingProfiles {
                    ProgressView()
                        .tint(.white)
                        .padding(.vertical, VersoSpacing.sm)
                } else if !vm.profiles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: VersoSpacing.sm) {
                            ForEach(vm.profiles) { profile in
                                Button {
                                    vm.selectedProfile = profile
                                } label: {
                                    Text(profile.name)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, VersoSpacing.md)
                                        .padding(.vertical, VersoSpacing.sm)
                                        .background(
                                            profile.id == vm.selectedProfile?.id
                                                ? AnyShapeStyle(Color.versoGradient)
                                                : AnyShapeStyle(Color.versoCard)
                                        )
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Season Selector

    @ViewBuilder
    private func seasonSection(vm: RequestSheetViewModel) -> some View {
        if !vm.seasons.isEmpty {
            VStack(alignment: .leading, spacing: VersoSpacing.sm) {
                HStack {
                    Text("Seasons")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        vm.toggleAllSeasons()
                    } label: {
                        Text(vm.allSeasonsSelected ? "Deselect All" : "Select All")
                            .font(.subheadline)
                            .foregroundStyle(Color.versoJade)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: VersoSpacing.sm) {
                    ForEach(vm.seasons) { season in
                        let isSelected = vm.selectedSeasons.contains(season.seasonNumber)
                        Button {
                            vm.toggleSeason(season.seasonNumber)
                        } label: {
                            VStack(spacing: 4) {
                                Text("Season \(season.seasonNumber)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                if let count = season.episodeCount {
                                    Text("\(count) episodes")
                                        .font(.caption2)
                                        .foregroundStyle(Color.versoSecondaryText)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, VersoSpacing.md)
                            .background(isSelected ? Color.versoJade.opacity(0.15) : Color.versoCard)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isSelected ? Color.versoJade : Color.clear, lineWidth: 1.5)
                            )
                            .overlay(alignment: .topTrailing) {
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.versoJade)
                                        .padding(6)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Download Progress

    private func downloadProgressSection(_ info: PrograrMediaRequest) -> some View {
        VStack(alignment: .leading, spacing: VersoSpacing.sm) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Color.versoSilver)
                Text("Downloading")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if let status = info.downloadStatus {
                    Text(status.capitalized)
                        .font(.caption)
                        .foregroundStyle(Color.versoSecondaryText)
                }
            }

            if let progress = info.downloadProgress {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.versoCardBorder)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.versoGradient)
                            .frame(width: geo.size.width * CGFloat(progress / 100.0), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(String(format: "%.1f%%", progress))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Spacer()
                    if let speed = info.formattedSpeed {
                        Text(speed)
                            .font(.caption)
                            .foregroundStyle(Color.versoSecondaryText)
                    }
                    if let eta = info.formattedETA {
                        Text("ETA: \(eta)")
                            .font(.caption)
                            .foregroundStyle(Color.versoSecondaryText)
                    }
                }
            }

            // Episode-level progress for TV shows
            if let episodes = info.episodeDownloads, !episodes.isEmpty {
                let activeEpisodes = episodes.filter {
                    guard let status = $0.downloadStatus else { return false }
                    return ["downloading", "paused", "queued", "stalled"].contains(status)
                }
                if !activeEpisodes.isEmpty {
                    ForEach(activeEpisodes, id: \.episodeNumber) { ep in
                        HStack(spacing: VersoSpacing.sm) {
                            Text("S\(ep.seasonNumber)E\(ep.episodeNumber)")
                                .font(.caption.monospaced())
                                .foregroundStyle(Color.versoSecondaryText)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.versoCardBorder)
                                        .frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.versoJade)
                                        .frame(width: geo.size.width * CGFloat((ep.downloadProgress ?? 0) / 100.0), height: 4)
                                }
                            }
                            .frame(height: 4)

                            if let pct = ep.downloadProgress {
                                Text(String(format: "%.0f%%", pct))
                                    .font(.caption2)
                                    .foregroundStyle(Color.versoSecondaryText)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
        .padding(VersoSpacing.md)
        .background(Color.versoCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action Area

    private func actionSection(vm: RequestSheetViewModel) -> some View {
        VStack(spacing: VersoSpacing.sm) {
            if let mediaInfo = item.mediaInfo, mediaInfo.isAvailable {
                Label("Already available", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if vm.success {
                Label("Request submitted!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                if let error = vm.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await vm.submitRequest() }
                } label: {
                    if vm.isRequesting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Request \(vm.isMovie ? "Movie" : "TV Show")")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(.white)
                .background(
                    vm.canSubmit
                        ? AnyShapeStyle(Color.versoGradient)
                        : AnyShapeStyle(Color.versoCard)
                )
                .clipShape(Capsule())
                .shadow(color: .versoJade.opacity(vm.canSubmit ? 0.3 : 0), radius: 8, y: 4)
                .disabled(!vm.canSubmit)
            }
        }
    }
}
