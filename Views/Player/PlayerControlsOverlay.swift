import SwiftUI

struct PlayerControlsOverlay: View {
    let viewModel: PlayerViewModel
    var onClose: () -> Void
    var onTrackPicker: () -> Void

    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Tap area to toggle controls
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleControls()
                }

            if controlsVisible {
                // Gradient scrims
                VStack(spacing: 0) {
                    GradientOverlay(direction: .top, color: .black, endOpacity: 0.5)
                        .frame(height: 100)
                    Spacer()
                    GradientOverlay(direction: .bottom, color: .black, endOpacity: 0.5)
                        .frame(height: 140)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    // MARK: - Top Bar
                    HStack(spacing: VersoSpacing.md) {
                        // Close — glass capsule
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                                )
                        }

                        Spacer()

                        Text(viewModel.displayTitle)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.6), radius: 8)

                        Spacer()

                        // Tracks — glass capsule, gradient border when active
                        Button(action: onTrackPicker) {
                            Image(systemName: viewModel.selectedSubtitleIndex != nil ? "captions.bubble.fill" : "captions.bubble")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(viewModel.selectedSubtitleIndex != nil ? Color.versoJade : .white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [.versoJade, .versoSilver],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                        .opacity(viewModel.selectedSubtitleIndex != nil ? 1 : 0)
                                )
                        }
                    }
                    .padding(.horizontal, VersoSpacing.xl)
                    .padding(.top, VersoSpacing.md)

                    Spacer()

                    // MARK: - Center Transport Pill
                    HStack(spacing: 0) {
                        Button { viewModel.skipBackward() } label: {
                            Image(systemName: "gobackward.10")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 64, height: 54)
                        }

                        Rectangle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 0.5, height: 26)

                        Button { viewModel.togglePlayPause() } label: {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 54)
                        }

                        Rectangle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 0.5, height: 26)

                        Button { viewModel.skipForward() } label: {
                            Image(systemName: "goforward.10")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 64, height: 54)
                        }
                    }
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    )

                    Spacer()

                    // MARK: - Bottom Scrubber + Time
                    VStack(spacing: VersoSpacing.sm) {
                        VideoScrubber(
                            currentTime: Binding(
                                get: { viewModel.currentTimeSeconds },
                                set: { viewModel.currentTimeSeconds = $0 }
                            ),
                            duration: viewModel.durationSeconds,
                            onScrubStart: {
                                viewModel.isScrubbing = true
                                cancelHideTimer()
                            },
                            onScrubEnd: { time in
                                viewModel.seekTo(seconds: time)
                                viewModel.isScrubbing = false
                                scheduleHide()
                            }
                        )

                        HStack {
                            Text(formatTime(viewModel.currentTimeSeconds))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer()
                            Text("-" + formatTime(max(0, viewModel.durationSeconds - viewModel.currentTimeSeconds)))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, VersoSpacing.xl)
                    .padding(.bottom, VersoSpacing.lg)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: controlsVisible)
        .onChange(of: viewModel.isPlaying) { _, playing in
            if playing {
                scheduleHide()
            } else {
                cancelHideTimer()
                controlsVisible = true
            }
        }
        .onAppear {
            scheduleHide()
        }
        .onDisappear {
            cancelHideTimer()
        }
    }

    private func toggleControls() {
        controlsVisible.toggle()
        if controlsVisible {
            scheduleHide()
        } else {
            cancelHideTimer()
        }
    }

    private func scheduleHide() {
        cancelHideTimer()
        guard viewModel.isPlaying else { return }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            controlsVisible = false
        }
    }

    private func cancelHideTimer() {
        hideTask?.cancel()
        hideTask = nil
    }

    private func formatTime(_ totalSeconds: Double) -> String {
        guard totalSeconds.isFinite && totalSeconds >= 0 else { return "0:00" }
        let total = Int(totalSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
