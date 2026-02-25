import SwiftUI

struct PrePlaySheet: View {
    let audioStreams: [MediaStream]
    let subtitleStreams: [MediaStream]
    let initialAudioIndex: Int?
    let onPlay: (_ audioIndex: Int?, _ subtitleIndex: Int?) -> Void
    let onCancel: () -> Void

    @State private var selectedAudioIndex: Int?
    @State private var selectedSubtitleIndex: Int?

    var body: some View {
        NavigationStack {
            List {
                if !audioStreams.isEmpty {
                    Section("Audio") {
                        ForEach(audioStreams, id: \.index) { stream in
                            Button {
                                selectedAudioIndex = stream.index
                            } label: {
                                HStack {
                                    Text(stream.audioDisplayLabel)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedAudioIndex == stream.index {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.versoJade)
                                    }
                                }
                            }
                        }
                    }
                }

                if !subtitleStreams.isEmpty {
                    Section("Subtitles") {
                        Button {
                            selectedSubtitleIndex = nil
                        } label: {
                            HStack {
                                Text("Off")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedSubtitleIndex == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.versoJade)
                                }
                            }
                        }

                        ForEach(subtitleStreams, id: \.index) { stream in
                            Button {
                                selectedSubtitleIndex = stream.index
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
                                    if selectedSubtitleIndex == stream.index {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.versoJade)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Audio & Subtitles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { onCancel() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onPlay(selectedAudioIndex, selectedSubtitleIndex)
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.versoJade, .versoSilver],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .versoJade.opacity(0.4), radius: 14, y: 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            selectedAudioIndex = initialAudioIndex
        }
    }
}
