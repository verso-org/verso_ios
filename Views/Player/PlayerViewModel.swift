import AVFoundation
import UIKit

@Observable
final class PlayerViewModel {
    private(set) var player: AVPlayer
    let subtitleStreams: [MediaStream]
    let audioStreams: [MediaStream]
    var selectedSubtitleIndex: Int?
    var selectedAudioIndex: Int?
    var subtitleOffset: TimeInterval = 0.0
    var currentSubtitleText: String?
    var currentSubtitleImage: UIImage?
    var currentSubtitleImageFrame: CGRect = .zero
    var playingResolution: String?
    var nextEpisode: BaseItemDto?
    var showNextUp = false

    // UI-binding properties for custom controls
    var currentTimeSeconds: Double = 0
    var durationSeconds: Double = 0
    var isPlaying: Bool = false
    var isScrubbing: Bool = false
    var displayTitle: String = ""

    private var itemId: String
    private var mediaSourceId: String?
    private let client: JellyfinClient
    private let itemType: String?
    private let seriesId: String?
    private let playSessionId = UUID().uuidString
    private var progressTimer: Task<Void, Never>?
    private var endObserver: (any NSObjectProtocol)?
    private var lastPlaybackTime: CMTime?
    private var subtitleCues: [SubtitleCue] = []
    private var pgsCues: [PGSSubtitleCue] = []
    private var timeObserver: Any?
    private var lastCueIndex: Int = -1
    private var lastPGSCueIndex: Int = -1
    private var usingBurnedInSubs = false
    private var currentAudioStreamIndex: Int?
    private var timeJumpedObserver: (any NSObjectProtocol)?
    private var uiTimeObserver: Any?
    private var resolutionObservation: NSKeyValueObservation?
    private var durationObservation: NSKeyValueObservation?
    private var creditsStartSeconds: Double?
    private var creditsObserver: Any?
    private var bufferEmptyObservation: NSKeyValueObservation?
    private var keepUpObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var stallTimer: Task<Void, Never>?
    private var subtitleCache: [Int: [SubtitleCue]] = [:]
    private var subtitlePrefetchTask: Task<Void, Never>?

    private var initialSubtitleIndex: Int?
    private var resumePositionTicks: Int64?

    init(client: JellyfinClient, itemId: String, mediaSourceId: String?, mediaSource: MediaSourceInfo?, itemType: String? = nil, seriesId: String? = nil, displayTitle: String = "", initialAudioIndex: Int? = nil, initialSubtitleIndex: Int? = nil, resumePositionTicks: Int64? = nil) {
        self.client = client
        self.itemId = itemId
        self.mediaSourceId = mediaSourceId
        self.itemType = itemType
        self.seriesId = seriesId
        self.displayTitle = displayTitle
        self.subtitleStreams = mediaSource?.mediaStreams?.filter { $0.type == .subtitle } ?? []

        let audio = mediaSource?.mediaStreams?.filter { $0.type == .audio } ?? []
        self.audioStreams = audio

        let autoResult = Self.autoSelectAudioWithPreference(from: audio)
        let audioIndex: Int?
        if let overrideIndex = initialAudioIndex, overrideIndex != autoResult.selectedIndex {
            audioIndex = overrideIndex
            self.selectedAudioIndex = overrideIndex
            self.currentAudioStreamIndex = overrideIndex
        } else {
            audioIndex = autoResult.streamIndexForURL
            self.selectedAudioIndex = initialAudioIndex ?? autoResult.selectedIndex
            self.currentAudioStreamIndex = autoResult.streamIndexForURL
        }

        if let url = client.streamURL(itemId: itemId, mediaSourceId: mediaSourceId, audioStreamIndex: audioIndex, startPositionTicks: resumePositionTicks) {
            print("[Player] stream URL: \(url.absoluteString)")
            let item = AVPlayerItem(url: url)
            item.preferredForwardBufferDuration = 30
            self.player = AVPlayer(playerItem: item)
        } else {
            print("[Player] failed to build stream URL")
            self.player = AVPlayer()
        }

        self.initialSubtitleIndex = initialSubtitleIndex
        self.resumePositionTicks = resumePositionTicks

        observePlaybackEnd()
    }

    // MARK: - Language Preferences

    private static let preferredAudioLanguageKey = "preferredAudioLanguage"
    private static let preferredSubtitleLanguageKey = "preferredSubtitleLanguage"

    static var preferredAudioLanguage: String? {
        get { UserDefaults.standard.string(forKey: preferredAudioLanguageKey) }
        set { UserDefaults.standard.set(newValue, forKey: preferredAudioLanguageKey) }
    }

    /// `nil` means "Off" (user explicitly chose no subtitles). We use a sentinel to distinguish
    /// "never set" (key absent) from "explicitly Off" (key = empty string).
    static var preferredSubtitleLanguage: String? {
        get {
            let raw = UserDefaults.standard.string(forKey: preferredSubtitleLanguageKey)
            // Empty string = "Off", nil = never set, else language code
            return raw
        }
        set { UserDefaults.standard.set(newValue, forKey: preferredSubtitleLanguageKey) }
    }

    /// Whether the user has ever set a subtitle preference.
    static var hasSubtitlePreference: Bool {
        UserDefaults.standard.object(forKey: preferredSubtitleLanguageKey) != nil
    }

    // MARK: - Audio Auto-Selection

    struct AudioAutoSelection {
        /// The index to pass to streamURL (nil = use server default)
        let streamIndexForURL: Int?
        /// The index to display as selected in the UI
        let selectedIndex: Int?
    }

    /// Selects the best audio track, avoiding TrueHD/DTS codecs that require transcoding.
    /// Returns the auto-selected index for both stream URL and UI display.
    static func autoSelectAudio(from audioStreams: [MediaStream]) -> AudioAutoSelection {
        let directPlayCodecs: Set<String> = ["aac", "ac3", "eac3", "flac", "alac", "opus", "mp3"]
        let defaultAudio = audioStreams.first(where: { $0.isDefault == true }) ?? audioStreams.first
        let needsTranscode = defaultAudio.map { !directPlayCodecs.contains($0.codec?.lowercased() ?? "") } ?? false

        if needsTranscode {
            let codecPriority: [String: Int] = ["eac3": 0, "ac3": 1, "aac": 2, "flac": 3, "alac": 4, "opus": 5, "mp3": 6]
            let compatible = audioStreams
                .filter { directPlayCodecs.contains($0.codec?.lowercased() ?? "") }
                .sorted { codecPriority[$0.codec?.lowercased() ?? "", default: 99] < codecPriority[$1.codec?.lowercased() ?? "", default: 99] }
                .first
            return AudioAutoSelection(
                streamIndexForURL: compatible?.index,
                selectedIndex: compatible?.index ?? defaultAudio?.index
            )
        } else {
            return AudioAutoSelection(
                streamIndexForURL: nil,
                selectedIndex: defaultAudio?.index
            )
        }
    }

    /// Layers language preference on top of codec-aware auto-selection.
    /// If user has a preferred audio language, find the best direct-play track in that language first.
    static func autoSelectAudioWithPreference(from audioStreams: [MediaStream]) -> AudioAutoSelection {
        guard let preferred = preferredAudioLanguage, !preferred.isEmpty else {
            return autoSelectAudio(from: audioStreams)
        }

        let directPlayCodecs: Set<String> = ["aac", "ac3", "eac3", "flac", "alac", "opus", "mp3"]
        let codecPriority: [String: Int] = ["eac3": 0, "ac3": 1, "aac": 2, "flac": 3, "alac": 4, "opus": 5, "mp3": 6]

        // Filter to preferred language
        let langMatches = audioStreams.filter { $0.language?.lowercased() == preferred.lowercased() }

        if !langMatches.isEmpty {
            // Find best direct-play track in preferred language
            let compatible = langMatches
                .filter { directPlayCodecs.contains($0.codec?.lowercased() ?? "") }
                .sorted { codecPriority[$0.codec?.lowercased() ?? "", default: 99] < codecPriority[$1.codec?.lowercased() ?? "", default: 99] }

            if let best = compatible.first {
                // Check if this is the server default — if so, no need to override URL
                let defaultAudio = audioStreams.first(where: { $0.isDefault == true }) ?? audioStreams.first
                let isDefault = best.index == defaultAudio?.index
                return AudioAutoSelection(
                    streamIndexForURL: isDefault ? nil : best.index,
                    selectedIndex: best.index
                )
            }
            // All preferred-language tracks need transcoding — pick first anyway
            if let first = langMatches.first {
                let defaultAudio = audioStreams.first(where: { $0.isDefault == true }) ?? audioStreams.first
                let isDefault = first.index == defaultAudio?.index
                return AudioAutoSelection(
                    streamIndexForURL: isDefault ? nil : first.index,
                    selectedIndex: first.index
                )
            }
        }

        // No match for preferred language — fall back to codec-aware selection
        return autoSelectAudio(from: audioStreams)
    }

    /// Finds the first subtitle matching the user's preferred language.
    static func autoSelectSubtitle(from subtitleStreams: [MediaStream]) -> Int? {
        guard hasSubtitlePreference else { return nil }
        guard let preferred = preferredSubtitleLanguage, !preferred.isEmpty else {
            // User explicitly chose "Off" last time
            return nil
        }
        return subtitleStreams.first(where: { $0.language?.lowercased() == preferred.lowercased() })?.index
    }

    func play() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        detectResolution()
        startUITimeObserver()
        observeBufferState()

        // Report start at resume position (server uses StartTimeTicks so HLS starts there)
        let ticks = resumePositionTicks ?? 0
        resumePositionTicks = nil
        Task { await client.reportPlaybackStart(itemId: itemId, mediaSourceId: mediaSourceId, positionTicks: ticks, playSessionId: playSessionId) }
        startProgressTimer()
        prefetchNextAndDetectCredits()

        // Apply initial subtitle: explicit override or auto-selected from preferences
        let subIdx = initialSubtitleIndex ?? Self.autoSelectSubtitle(from: subtitleStreams)
        initialSubtitleIndex = nil
        if let subIdx, let stream = subtitleStreams.first(where: { $0.index == subIdx }) {
            if stream.isTextSubtitle {
                prefetchThenApplySubtitle(stream: stream)
            } else {
                selectSubtitle(stream: stream)
            }
        }
    }

    private func detectResolution() {
        resolutionObservation?.invalidate()
        guard let item = player.currentItem else { return }
        resolutionObservation = item.observe(\.presentationSize, options: [.new, .initial]) { [weak self] item, _ in
            let size = item.presentationSize
            guard size != .zero else { return }
            let resolution = "\(Int(size.width))x\(Int(size.height))"
            // Dispatch to main thread — KVO fires on AVPlayer's internal thread
            // but @Observable properties must be mutated on main to avoid data races
            DispatchQueue.main.async {
                if resolution != self?.playingResolution {
                    self?.playingResolution = resolution
                }
            }
        }
    }

    func cleanup() {
        progressTimer?.cancel()
        progressTimer = nil
        removeEndObserver()
        removeTimeObserver()
        removeUITimeObserver()
        removeCreditsObserver()
        removeBufferObservers()
        resolutionObservation?.invalidate()
        resolutionObservation = nil
        subtitlePrefetchTask?.cancel()
        subtitlePrefetchTask = nil
        subtitleCache.removeAll()

        let ticks = currentPositionTicks()
        Task { await client.reportPlaybackStopped(itemId: itemId, mediaSourceId: mediaSourceId, positionTicks: ticks, playSessionId: playSessionId) }

        player.pause()
        player.replaceCurrentItem(with: nil)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func selectSubtitle(stream: MediaStream?) {
        guard stream?.index != selectedSubtitleIndex else { return }

        guard let stream else {
            disableSubtitles()
            return
        }

        selectedSubtitleIndex = stream.index

        // Save language preference
        if let lang = stream.language {
            Self.preferredSubtitleLanguage = lang
        }

        if stream.isBitmapSubtitle {
            selectBitmapSubtitle(stream: stream)
        } else {
            selectTextSubtitle(stream: stream)
        }
    }

    func selectAudio(stream: MediaStream) {
        guard stream.index != selectedAudioIndex else { return }
        selectedAudioIndex = stream.index
        currentAudioStreamIndex = stream.index

        // Save language preference
        if let lang = stream.language {
            Self.preferredAudioLanguage = lang
        }

        let subtitleIndex = usingBurnedInSubs ? selectedSubtitleIndex : nil
        let subtitleMethod: JellyfinClient.SubtitleMethod? = usingBurnedInSubs ? .encode : nil
        reloadStream(subtitleStreamIndex: subtitleIndex, subtitleMethod: subtitleMethod, audioStreamIndex: stream.index)
    }

    func disableSubtitles() {
        let wasBurnedIn = usingBurnedInSubs
        Self.preferredSubtitleLanguage = ""

        removeTimeObserver()
        subtitleCues = []
        pgsCues = []
        currentSubtitleText = nil
        currentSubtitleImage = nil
        currentSubtitleImageFrame = .zero
        lastCueIndex = -1
        lastPGSCueIndex = -1
        selectedSubtitleIndex = nil
        usingBurnedInSubs = false

        if wasBurnedIn {
            reloadStream(subtitleStreamIndex: nil, subtitleMethod: nil)
        }
    }

    func adjustOffset(by delta: TimeInterval) {
        subtitleOffset += delta
        lastCueIndex = -1
        lastPGSCueIndex = -1
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func skipForward(_ seconds: Double = 10) {
        let current = player.currentTime().seconds
        guard current.isFinite else { return }
        let target = min(current + seconds, durationSeconds)
        // Allow keyframe-aligned seeking for snappy skip response
        let tolerance = CMTime(seconds: 0.5, preferredTimescale: 600)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: tolerance, toleranceAfter: tolerance)
    }

    func skipBackward(_ seconds: Double = 10) {
        let current = player.currentTime().seconds
        guard current.isFinite else { return }
        let target = max(current - seconds, 0)
        let tolerance = CMTime(seconds: 0.5, preferredTimescale: 600)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: tolerance, toleranceAfter: tolerance)
    }

    func seekTo(seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - UI Time Observer

    private func startUITimeObserver() {
        removeUITimeObserver()
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        uiTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, !self.isScrubbing else { return }
            let seconds = time.seconds
            if seconds.isFinite && seconds != self.currentTimeSeconds {
                self.currentTimeSeconds = seconds
            }
            if let duration = self.player.currentItem?.duration.seconds,
               duration.isFinite && duration != self.durationSeconds {
                self.durationSeconds = duration
            }
            let playing = self.player.timeControlStatus == .playing
            if playing != self.isPlaying {
                self.isPlaying = playing
            }
        }
    }

    private func removeUITimeObserver() {
        if let uiTimeObserver {
            player.removeTimeObserver(uiTimeObserver)
        }
        uiTimeObserver = nil
    }

    // MARK: - Stall Detection & Recovery

    private func observeBufferState() {
        removeBufferObservers()

        guard let item = player.currentItem else { return }

        bufferEmptyObservation = item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] _, change in
            guard change.newValue == true else { return }
            // KVO fires on AVPlayer's internal thread — dispatch to main
            DispatchQueue.main.async {
                guard let self else { return }
                let buffered = self.player.currentItem?.loadedTimeRanges.map { $0.timeRangeValue.end.seconds }.max() ?? 0
                let current = self.player.currentTime().seconds
                print("[Player] buffer EMPTY at \(String(format: "%.1f", current))s, buffered to \(String(format: "%.1f", buffered))s, resolution: \(self.playingResolution ?? "unknown")")
                self.startStallTimer()
            }
        }

        keepUpObservation = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] _, change in
            guard change.newValue == true else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                self.cancelStallTimer()
                let buffered = self.player.currentItem?.loadedTimeRanges.map { $0.timeRangeValue.end.seconds }.max() ?? 0
                let current = self.player.currentTime().seconds
                print("[Player] buffer recovered at \(String(format: "%.1f", current))s, buffered to \(String(format: "%.1f", buffered))s")
                if self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                    self.player.play()
                }
            }
        }

        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            DispatchQueue.main.async {
                print("[Player] item FAILED: \(item.error?.localizedDescription ?? "unknown error")")
                self?.attemptRecovery()
            }
        }
    }

    private func startStallTimer() {
        cancelStallTimer()
        stallTimer = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled, let self else { return }
            // Still stalled after 30s — attempt recovery
            if self.player.timeControlStatus != .playing {
                self.attemptRecovery()
            }
        }
    }

    private func cancelStallTimer() {
        stallTimer?.cancel()
        stallTimer = nil
    }

    private func attemptRecovery() {
        let time = player.currentTime()
        guard time.seconds.isFinite else { return }
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.player.play()
        }
    }

    private func removeBufferObservers() {
        bufferEmptyObservation?.invalidate()
        bufferEmptyObservation = nil
        keepUpObservation?.invalidate()
        keepUpObservation = nil
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        cancelStallTimer()
    }

    // MARK: - Subtitle Prefetch

    /// Fetch a single text subtitle track and apply it once cached.
    /// Only the user's pre-selected track is fetched; all others are on-demand.
    private func prefetchThenApplySubtitle(stream: MediaStream) {
        subtitlePrefetchTask?.cancel()
        guard let mediaSourceId else { return }

        let itemId = self.itemId
        subtitlePrefetchTask = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }

            print("[Subtitle] fetching selected track \(stream.index)...")
            if let (index, cues) = await self.fetchAndParse(stream: stream, itemId: itemId, mediaSourceId: mediaSourceId) {
                self.subtitleCache[index] = cues
                print("[Subtitle] cached track \(index), \(cues.count) cues — applying")
                // Now apply it; selectSubtitle will find it in the cache (instant)
                self.selectSubtitle(stream: stream)
            }
        }
    }

    private func fetchAndParse(stream: MediaStream, itemId: String, mediaSourceId: String) async -> (Int, [SubtitleCue])? {
        // Always request VTT — Jellyfin converts SRT/SSA/etc. server-side
        let format = "vtt"
        do {
            let start = CFAbsoluteTimeGetCurrent()
            let content = try await client.getSubtitleContent(
                itemId: itemId,
                mediaSourceId: mediaSourceId,
                streamIndex: stream.index,
                format: format
            )
            let cues = SubtitleParser.parseWebVTT(content)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            print("[Subtitle] prefetched stream \(stream.index) (\(format)): \(String(format: "%.2f", elapsed))s, \(cues.count) cues")
            return (stream.index, cues)
        } catch {
            print("[Subtitle] prefetch failed stream \(stream.index): \(error)")
            return nil
        }
    }

    // MARK: - Text Subtitles (external VTT + client-side rendering)

    private func selectTextSubtitle(stream: MediaStream) {
        let wasBurnedIn = usingBurnedInSubs

        removeTimeObserver()
        subtitleCues = []
        pgsCues = []
        currentSubtitleText = nil
        currentSubtitleImage = nil
        currentSubtitleImageFrame = .zero
        lastCueIndex = -1
        lastPGSCueIndex = -1
        usingBurnedInSubs = false

        if wasBurnedIn {
            reloadStream(subtitleStreamIndex: nil, subtitleMethod: nil)
        }

        guard let mediaSourceId else { return }

        // Use prefetched cues if available — instant selection
        if let cached = subtitleCache[stream.index] {
            print("[Subtitle] cache HIT stream \(stream.index): \(cached.count) cues")
            subtitleCues = cached
            startTimeObserver()
            return
        }

        // Cache miss — fetch on demand (always VTT — Jellyfin converts server-side)
        let rawFormat = "vtt"

        Task {
            let totalStart = CFAbsoluteTimeGetCurrent()
            do {
                let fetchStart = CFAbsoluteTimeGetCurrent()
                let content = try await client.getSubtitleContent(
                    itemId: itemId,
                    mediaSourceId: mediaSourceId,
                    streamIndex: stream.index,
                    format: rawFormat
                )
                let fetchEnd = CFAbsoluteTimeGetCurrent()
                let byteCount = content.utf8.count
                print("[Subtitle] fetch \(rawFormat) stream \(stream.index): \(String(format: "%.2f", fetchEnd - fetchStart))s, \(byteCount) bytes")

                let parseStart = CFAbsoluteTimeGetCurrent()
                let cues = SubtitleParser.parseWebVTT(content)
                let parseEnd = CFAbsoluteTimeGetCurrent()
                print("[Subtitle] parse: \(String(format: "%.2f", parseEnd - parseStart))s, \(cues.count) cues")

                subtitleCache[stream.index] = cues
                await MainActor.run {
                    subtitleCues = cues
                    startTimeObserver()
                }
                let totalEnd = CFAbsoluteTimeGetCurrent()
                print("[Subtitle] total text sub load: \(String(format: "%.2f", totalEnd - totalStart))s")
            } catch {
                let totalEnd = CFAbsoluteTimeGetCurrent()
                print("[Subtitle] text sub FAILED after \(String(format: "%.2f", totalEnd - totalStart))s: \(error)")
                await MainActor.run {
                    usingBurnedInSubs = true
                    reloadStream(subtitleStreamIndex: stream.index, subtitleMethod: .encode)
                }
            }
        }
    }

    private func startTimeObserver() {
        removeTimeObserver()
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateSubtitleForTime(time.seconds)
        }
        observeTimeJumped()
    }

    private func updateSubtitleForTime(_ time: TimeInterval) {
        let adjustedTime = time + subtitleOffset
        if !pgsCues.isEmpty {
            updatePGSSubtitleForTime(adjustedTime)
            return
        }
        let activeCues = findActiveCues(at: adjustedTime)
        let newText = activeCues.isEmpty ? nil : activeCues.map(\.text).joined(separator: "\n")
        if newText != currentSubtitleText {
            currentSubtitleText = newText
        }
    }

    /// Finds ALL active cues at the given time, handling overlapping cue ranges.
    /// Binary search for the rightmost cue with startTime <= time, then scans
    /// backwards to collect every cue whose endTime >= time.
    private func findActiveCues(at time: TimeInterval) -> [SubtitleCue] {
        guard !subtitleCues.isEmpty else { return [] }

        // Binary search: find rightmost cue with startTime <= time
        var low = 0
        var high = subtitleCues.count - 1
        var rightmost = -1

        while low <= high {
            let mid = (low + high) / 2
            if subtitleCues[mid].startTime <= time {
                rightmost = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        guard rightmost >= 0 else { return [] }

        // Scan backwards from rightmost collecting all cues still active at this time
        var active: [SubtitleCue] = []
        for i in stride(from: rightmost, through: 0, by: -1) {
            let cue = subtitleCues[i]
            if cue.endTime >= time {
                active.append(cue)
            }
            // No subtitle cue lasts more than 30s — safe to stop scanning
            if time - cue.startTime > 30 { break }
        }

        return active.reversed()
    }

    private func removeTimeObserver() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        removeTimeJumpedObserver()
    }

    private func observeTimeJumped() {
        removeTimeJumpedObserver()
        guard let item = player.currentItem else { return }
        timeJumpedObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.timeJumpedNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.lastCueIndex = -1
            self.lastPGSCueIndex = -1
            self.currentSubtitleText = nil
            self.currentSubtitleImage = nil
        }
    }

    private func removeTimeJumpedObserver() {
        if let timeJumpedObserver {
            NotificationCenter.default.removeObserver(timeJumpedObserver)
        }
        timeJumpedObserver = nil
    }

    // MARK: - Bitmap Subtitles (client-side PGS with burn-in fallback)

    private func selectBitmapSubtitle(stream: MediaStream) {
        removeTimeObserver()
        subtitleCues = []
        pgsCues = []
        currentSubtitleText = nil
        currentSubtitleImage = nil
        currentSubtitleImageFrame = .zero
        lastCueIndex = -1
        lastPGSCueIndex = -1
        usingBurnedInSubs = false

        guard let mediaSourceId else {
            // Can't fetch without source ID — fall back to burn-in
            usingBurnedInSubs = true
            reloadStream(subtitleStreamIndex: stream.index, subtitleMethod: .encode)
            return
        }

        Task {
            let totalStart = CFAbsoluteTimeGetCurrent()
            do {
                let fetchStart = CFAbsoluteTimeGetCurrent()
                let data = try await client.getPGSSubtitleData(
                    itemId: itemId,
                    mediaSourceId: mediaSourceId,
                    streamIndex: stream.index
                )
                let fetchEnd = CFAbsoluteTimeGetCurrent()
                print("[Subtitle] PGS fetch stream \(stream.index): \(String(format: "%.2f", fetchEnd - fetchStart))s, \(data.count) bytes")

                let parseStart = CFAbsoluteTimeGetCurrent()
                let cues = PGSSubtitleParser.parse(data)
                let parseEnd = CFAbsoluteTimeGetCurrent()
                print("[Subtitle] PGS parse: \(String(format: "%.2f", parseEnd - parseStart))s, \(cues.count) cues")

                guard !cues.isEmpty else {
                    throw URLError(.cannotDecodeContentData)
                }
                await MainActor.run {
                    pgsCues = cues
                    startTimeObserver()
                }
                let totalEnd = CFAbsoluteTimeGetCurrent()
                print("[Subtitle] total PGS sub load: \(String(format: "%.2f", totalEnd - totalStart))s")
            } catch {
                let totalEnd = CFAbsoluteTimeGetCurrent()
                print("[Subtitle] PGS sub FAILED after \(String(format: "%.2f", totalEnd - totalStart))s: \(error)")
                // Client-side PGS failed — fall back to server burn-in
                await MainActor.run {
                    usingBurnedInSubs = true
                    reloadStream(subtitleStreamIndex: stream.index, subtitleMethod: .encode)
                }
            }
        }
    }

    private func updatePGSSubtitleForTime(_ time: TimeInterval) {
        let previousIndex = lastPGSCueIndex
        let cue = findPGSCue(at: time)

        // Same cue as before — skip redundant image creation
        if lastPGSCueIndex == previousIndex && lastPGSCueIndex >= 0 { return }

        if let cue {
            guard cue.screenWidth > 0, cue.screenHeight > 0 else {
                currentSubtitleImage = nil
                return
            }
            let img = cue.makeImage()
            let nFrame = CGRect(
                x: CGFloat(cue.screenX) / CGFloat(cue.screenWidth),
                y: CGFloat(cue.screenY) / CGFloat(cue.screenHeight),
                width: CGFloat(cue.imageWidth) / CGFloat(cue.screenWidth),
                height: CGFloat(cue.imageHeight) / CGFloat(cue.screenHeight)
            )
            currentSubtitleImage = img
            currentSubtitleImageFrame = nFrame
        } else {
            currentSubtitleImage = nil
            currentSubtitleImageFrame = .zero
        }
    }

    private func findPGSCue(at time: TimeInterval) -> PGSSubtitleCue? {
        if lastPGSCueIndex >= 0 && lastPGSCueIndex < pgsCues.count {
            let cue = pgsCues[lastPGSCueIndex]
            if time >= cue.startTime && time <= cue.endTime {
                return cue
            }
        }

        var low = 0
        var high = pgsCues.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let cue = pgsCues[mid]

            if time < cue.startTime {
                high = mid - 1
            } else if time > cue.endTime {
                low = mid + 1
            } else {
                lastPGSCueIndex = mid
                return cue
            }
        }

        lastPGSCueIndex = -1
        return nil
    }

    // MARK: - Stream reload (preserves playback position)

    private func reloadStream(
        subtitleStreamIndex: Int?,
        subtitleMethod: JellyfinClient.SubtitleMethod?,
        audioStreamIndex: Int? = nil
    ) {
        lastPlaybackTime = player.currentTime()
        let wasPlaying = player.timeControlStatus == .playing

        let audioIndex = audioStreamIndex ?? currentAudioStreamIndex
        guard let url = client.streamURL(
            itemId: itemId,
            mediaSourceId: mediaSourceId,
            subtitleStreamIndex: subtitleStreamIndex,
            subtitleMethod: subtitleMethod,
            audioStreamIndex: audioIndex
        ) else { return }

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 30
        player.replaceCurrentItem(with: item)

        guard let time = lastPlaybackTime else { return }

        // Use KVO to wait for readyToPlay instead of polling
        var observation: NSKeyValueObservation?
        observation = item.observe(\.status, options: [.new]) { [weak self] playerItem, _ in
            guard playerItem.status != .unknown else { return }
            observation?.invalidate()
            observation = nil
            guard playerItem.status == .readyToPlay, let self else { return }
            self.player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                if wasPlaying { self.player.play() }
            }
        }
    }

    // MARK: - Playback Reporting

    private func currentPositionTicks() -> Int64 {
        let seconds = player.currentTime().seconds
        guard seconds.isFinite && seconds >= 0 else { return 0 }
        return Int64(seconds * 10_000_000)
    }

    private func startProgressTimer() {
        progressTimer?.cancel()
        progressTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled, let self else { return }
                let ticks = self.currentPositionTicks()
                let paused = self.player.timeControlStatus != .playing
                await self.client.reportPlaybackProgress(
                    itemId: self.itemId,
                    mediaSourceId: self.mediaSourceId,
                    positionTicks: ticks,
                    isPaused: paused,
                    playSessionId: self.playSessionId
                )
            }
        }
    }

    // MARK: - End of Playback / Next Up

    private func observePlaybackEnd() {
        removeEndObserver()
        guard let item = player.currentItem else { return }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackEnded()
        }
    }

    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    private func handlePlaybackEnded() {
        progressTimer?.cancel()
        let ticks = currentPositionTicks()
        Task {
            await client.reportPlaybackStopped(itemId: itemId, mediaSourceId: mediaSourceId, positionTicks: ticks, playSessionId: playSessionId)
        }
        // Show Next Up if not already visible from credits detection
        if !showNextUp, nextEpisode != nil {
            showNextUp = true
        }
    }

    func playNextEpisode() {
        guard let next = nextEpisode else { return }
        let newMediaSourceId = next.mediaSources?.first?.id
        itemId = next.id
        mediaSourceId = newMediaSourceId

        removeEndObserver()
        removeTimeObserver()
        removeCreditsObserver()
        subtitlePrefetchTask?.cancel()
        subtitleCache.removeAll()
        creditsStartSeconds = nil
        subtitleCues = []
        pgsCues = []
        currentSubtitleText = nil
        currentSubtitleImage = nil
        currentSubtitleImageFrame = .zero
        lastCueIndex = -1
        lastPGSCueIndex = -1
        selectedSubtitleIndex = nil
        usingBurnedInSubs = false

        guard let url = client.streamURL(itemId: next.id, mediaSourceId: newMediaSourceId) else { return }
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 30
        player.replaceCurrentItem(with: item)
        observePlaybackEnd()

        showNextUp = false
        nextEpisode = nil

        player.play()
        let ticks: Int64 = 0
        Task { await client.reportPlaybackStart(itemId: itemId, mediaSourceId: mediaSourceId, positionTicks: ticks, playSessionId: playSessionId) }
        startProgressTimer()
        prefetchNextAndDetectCredits()
    }

    // MARK: - Credits Detection

    private func prefetchNextAndDetectCredits() {
        guard itemType == "Episode", let seriesId else { return }

        Task {
            // Pre-fetch next episode
            do {
                let currentId = self.itemId
                let nextUp = try await client.getNextUp(seriesId: seriesId)
                if let next = nextUp.first(where: { $0.id != currentId }) {
                    await MainActor.run { nextEpisode = next }
                }
            } catch {
                // Next-up fetch failed — non-critical
            }

            // Detect credits chapter
            do {
                let item = try await client.getItem(id: itemId)
                let creditsChapter = item.chapters?.first { chapter in
                    guard let name = chapter.name?.lowercased() else { return false }
                    return name.contains("credit")
                }

                await MainActor.run {
                    if let creditsChapter {
                        creditsStartSeconds = creditsChapter.startSeconds
                    }
                    setupCreditsObserver()
                }
            } catch {
                // Chapter fetch failed — fall back to duration-based heuristic
                await MainActor.run { setupCreditsObserver() }
            }
        }
    }

    private func setupCreditsObserver() {
        removeCreditsObserver()

        guard let currentItem = player.currentItem else { return }

        // If duration is already known, set up immediately
        let d = currentItem.duration.seconds
        if d.isFinite && d > 0 {
            installBoundaryObserver(duration: d)
            return
        }

        // Otherwise observe status until readyToPlay, then read duration
        durationObservation?.invalidate()
        durationObservation = currentItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            self?.durationObservation?.invalidate()
            self?.durationObservation = nil
            let dur = item.duration.seconds
            guard dur.isFinite && dur > 0 else { return }
            self?.installBoundaryObserver(duration: dur)
        }
    }

    private func installBoundaryObserver(duration: Double) {
        let threshold: Double
        if let credits = creditsStartSeconds {
            threshold = credits
        } else {
            threshold = max(duration - 30, duration * 0.9)
            creditsStartSeconds = threshold
        }

        let time = CMTime(seconds: threshold, preferredTimescale: 600)
        creditsObserver = player.addBoundaryTimeObserver(
            forTimes: [NSValue(time: time)],
            queue: .main
        ) { [weak self] in
            guard let self, self.nextEpisode != nil else { return }
            self.showNextUp = true
        }
    }

    private func removeCreditsObserver() {
        if let creditsObserver {
            player.removeTimeObserver(creditsObserver)
        }
        creditsObserver = nil
        durationObservation?.invalidate()
        durationObservation = nil
    }
}
