import Foundation

struct PrograrMediaRequest: Codable, Identifiable {
    let id: Int
    let mediaType: String
    let title: String
    let posterUrl: String?
    let year: Int?
    let requestStatus: String?
    let requestedBy: String?
    let requestedAt: String?
    let downloadStatus: String?
    private let _downloadProgress: Double?
    let downloadSpeed: Int?
    let etaSeconds: Int?
    let queuePosition: Int?
    let queueStatus: String?
    let quality: String?
    let tmdbId: Int?
    let tvdbId: Int?
    let isMissing: Bool?
    let isNotAvailable: Bool?
    let episodeDownloads: [PrograrEpisodeDownload]?

    /// Progress as percentage (0–100), used directly from the server
    var downloadProgress: Double? {
        _downloadProgress
    }

    private enum CodingKeys: String, CodingKey {
        case id, mediaType, title, posterUrl, year
        case requestStatus, requestedBy, requestedAt, downloadStatus
        case _downloadProgress = "downloadProgress"
        case downloadSpeed, etaSeconds
        case queuePosition, queueStatus, quality
        case tmdbId, tvdbId, isMissing, isNotAvailable, episodeDownloads
    }

    var isDownloading: Bool {
        guard let status = downloadStatus else { return false }
        return ["downloading", "paused", "queued", "stalled"].contains(status)
    }

    var hasEpisodeActivity: Bool {
        episodeDownloads?.contains(where: {
            guard let status = $0.downloadStatus else { return false }
            return ["downloading", "paused", "queued", "stalled"].contains(status)
        }) ?? false
    }

    var isActive: Bool {
        isDownloading || hasEpisodeActivity
    }

    var formattedSpeed: String? {
        guard let speed = downloadSpeed, speed > 0 else { return nil }
        let mbps = Double(speed) / 1_048_576.0
        if mbps >= 1.0 {
            return String(format: "%.1f MB/s", mbps)
        } else {
            let kbps = Double(speed) / 1024.0
            return String(format: "%.0f KB/s", kbps)
        }
    }

    var formattedETA: String? {
        guard let eta = etaSeconds, eta > 0,
              let speed = downloadSpeed, speed > 0 else { return nil }
        let days = eta / 86400
        let hours = (eta % 86400) / 3600
        let minutes = (eta % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct PrograrEpisodeDownload: Codable {
    let seasonNumber: Int
    let episodeNumber: Int
    let episodeTitle: String?
    let downloadStatus: String?
    private let _downloadProgress: Double?
    let downloadSpeed: Int?
    let etaSeconds: Int?
    let quality: String?

    var downloadProgress: Double? {
        _downloadProgress
    }

    var formattedSpeed: String? {
        guard let speed = downloadSpeed, speed > 0 else { return nil }
        let mbps = Double(speed) / 1_048_576.0
        if mbps >= 1.0 {
            return String(format: "%.1f MB/s", mbps)
        } else {
            let kbps = Double(speed) / 1024.0
            return String(format: "%.0f KB/s", kbps)
        }
    }

    var formattedETA: String? {
        guard let eta = etaSeconds, eta > 0,
              let speed = downloadSpeed, speed > 0 else { return nil }
        let days = eta / 86400
        let hours = (eta % 86400) / 3600
        let minutes = (eta % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case seasonNumber, episodeNumber, episodeTitle, downloadStatus
        case _downloadProgress = "downloadProgress"
        case downloadSpeed, etaSeconds, quality
    }
}
