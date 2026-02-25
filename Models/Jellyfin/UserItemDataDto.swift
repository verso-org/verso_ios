import Foundation

struct UserItemDataDto: Codable {
    var playbackPositionTicks: Int64?
    var playCount: Int?
    var isFavorite: Bool?
    var played: Bool?
    var playedPercentage: Double?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case playCount = "PlayCount"
        case isFavorite = "IsFavorite"
        case played = "Played"
        case playedPercentage = "PlayedPercentage"
    }

    var progressPercentage: Double {
        playedPercentage ?? 0
    }
}
