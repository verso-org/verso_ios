import SwiftUI
import AVKit

struct PlayerView: View {
    let client: JellyfinClient
    let itemId: String
    let mediaSourceId: String?
    var mediaSource: MediaSourceInfo?
    var itemType: String?
    var seriesId: String?
    var displayTitle: String? = nil
    var initialAudioIndex: Int? = nil
    var initialSubtitleIndex: Int? = nil
    var resumePositionTicks: Int64? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PlayerViewModel?
    @State private var showSubtitlePicker = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let viewModel {
                CustomPlayerRepresentable(
                    player: viewModel.player,
                    subtitleText: viewModel.currentSubtitleText,
                    subtitleImage: viewModel.currentSubtitleImage,
                    subtitleImageFrame: viewModel.currentSubtitleImageFrame
                )
                .ignoresSafeArea()

                PlayerControlsOverlay(
                    viewModel: viewModel,
                    onClose: { dismiss() },
                    onTrackPicker: { showSubtitlePicker = true }
                )
            }

            // Next Up overlay
            if let viewModel, viewModel.showNextUp, let next = viewModel.nextEpisode {
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Up Next")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.7))
                            Text(next.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            if let s = next.parentIndexNumber, let e = next.indexNumber {
                                Text("S\(s) E\(e)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        Spacer()
                        Button {
                            viewModel.playNextEpisode()
                        } label: {
                            Text("Play")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [.versoJade, .versoSilver],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: viewModel.showNextUp)
            }
        }
        .statusBarHidden()
        .onAppear {
            guard viewModel == nil else { return }
            let vm = PlayerViewModel(
                client: client,
                itemId: itemId,
                mediaSourceId: mediaSourceId,
                mediaSource: mediaSource,
                itemType: itemType,
                seriesId: seriesId,
                displayTitle: displayTitle ?? "",
                initialAudioIndex: initialAudioIndex,
                initialSubtitleIndex: initialSubtitleIndex,
                resumePositionTicks: resumePositionTicks
            )
            viewModel = vm
            vm.play()
        }
        .onDisappear {
            viewModel?.cleanup()
        }
        .sheet(isPresented: $showSubtitlePicker) {
            if let viewModel {
                TrackPickerSheet(viewModel: viewModel)
            }
        }
    }
}

// MARK: - UIViewControllerRepresentable bridge

private struct CustomPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    let subtitleText: String?
    let subtitleImage: UIImage?
    let subtitleImageFrame: CGRect

    func makeUIViewController(context: Context) -> CustomPlayerViewController {
        let vc = CustomPlayerViewController()
        vc.configure(player: player)
        return vc
    }

    func updateUIViewController(_ vc: CustomPlayerViewController, context: Context) {
        vc.updateSubtitleText(subtitleText)
        vc.updateSubtitleImage(subtitleImage, frame: subtitleImageFrame)
    }
}

// MARK: - Track Picker Sheet

private struct TrackPickerSheet: View {
    let viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // MARK: Audio
                if !viewModel.audioStreams.isEmpty {
                    Section("Audio") {
                        ForEach(viewModel.audioStreams, id: \.index) { stream in
                            Button {
                                viewModel.selectAudio(stream: stream)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(stream.audioDisplayLabel)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if viewModel.selectedAudioIndex == stream.index {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                // MARK: Subtitles
                if !viewModel.subtitleStreams.isEmpty {
                    Section {
                        Button {
                            viewModel.disableSubtitles()
                            dismiss()
                        } label: {
                            HStack {
                                Text("Off")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if viewModel.selectedSubtitleIndex == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    } header: {
                        Text("Subtitles")
                    }

                    Section("Available Tracks") {
                        ForEach(viewModel.subtitleStreams, id: \.index) { stream in
                            Button {
                                viewModel.selectSubtitle(stream: stream)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stream.displayLabel)
                                            .foregroundStyle(.primary)
                                        if stream.isBitmapSubtitle {
                                            Text("Image-based")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if viewModel.selectedSubtitleIndex == stream.index {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        Text("No subtitle tracks available")
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Subtitles")
                    }
                }

                if viewModel.selectedSubtitleIndex != nil {
                    Section("Timing Offset") {
                        HStack {
                            Button {
                                viewModel.adjustOffset(by: -0.25)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.borderless)

                            Spacer()

                            Text(formatOffset(viewModel.subtitleOffset))
                                .font(.system(.body, design: .monospaced))
                                .frame(minWidth: 60)

                            Spacer()

                            Button {
                                viewModel.adjustOffset(by: 0.25)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.borderless)

                            if viewModel.subtitleOffset != 0 {
                                Button {
                                    viewModel.subtitleOffset = 0
                                    viewModel.adjustOffset(by: 0)
                                } label: {
                                    Text("Reset")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .padding(.leading, 8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Stream Info") {
                    HStack {
                        Text("Resolution")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(viewModel.playingResolution ?? "Loading...")
                            .foregroundStyle(.primary)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .navigationTitle("Tracks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func formatOffset(_ offset: TimeInterval) -> String {
        if offset == 0 { return "0.00s" }
        let sign = offset > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", offset))s"
    }
}
