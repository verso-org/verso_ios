import SwiftUI

struct VideoScrubber: View {
    @Binding var currentTime: Double
    let duration: Double
    var onScrubStart: () -> Void = {}
    var onScrubEnd: (Double) -> Void = { _ in }

    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return isDragging ? dragProgress : currentTime / duration
    }

    private let trackHeight: CGFloat = 3
    private let expandedTrackHeight: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let currentTrackHeight = isDragging ? expandedTrackHeight : trackHeight
            let thumbX = max(0, min(width * progress, width))

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: currentTrackHeight / 2)
                    .fill(.white.opacity(0.15))
                    .frame(height: currentTrackHeight)

                // Filled track with gradient glow
                RoundedRectangle(cornerRadius: currentTrackHeight / 2)
                    .fill(Color.versoGradient)
                    .frame(width: max(0, width * progress), height: currentTrackHeight)
                    .shadow(color: Color.versoJade.opacity(isDragging ? 0.6 : 0.35), radius: isDragging ? 10 : 5)

                // Vertical bar thumb
                Capsule()
                    .fill(.white)
                    .frame(width: isDragging ? 5 : 3, height: isDragging ? 22 : 16)
                    .shadow(color: Color.versoJade.opacity(0.5), radius: 6)
                    .offset(x: thumbX - (isDragging ? 2.5 : 1.5))

                // Time tooltip while scrubbing
                if isDragging {
                    Text(formatTime(dragProgress * duration))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                        .offset(
                            x: min(max(thumbX - 28, 0), width - 56),
                            y: -30
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .frame(height: 44)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onScrubStart()
                        }
                        let fraction = max(0, min(1, value.location.x / width))
                        dragProgress = fraction
                        currentTime = fraction * duration
                    }
                    .onEnded { value in
                        let fraction = max(0, min(1, value.location.x / width))
                        let seekTime = fraction * duration
                        isDragging = false
                        onScrubEnd(seekTime)
                    }
            )
            .animation(.easeInOut(duration: 0.2), value: isDragging)
        }
        .frame(height: 44)
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
