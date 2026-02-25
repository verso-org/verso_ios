import Foundation

struct SeerrSeason: Codable, Identifiable {
    let id: Int
    let seasonNumber: Int
    let episodeCount: Int?
    let name: String?
    let airDate: String?
}

struct SeerrTvResult: Codable, Identifiable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let mediaType: String?
    let mediaInfo: SeerrMediaInfo?
    let seasons: [SeerrSeason]?

    var year: String? {
        guard let date = firstAirDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
}

struct SeerrMediaInfo: Codable {
    let id: Int?
    let status: Int?
    let requests: [SeerrMediaRequest]?

    var statusText: String {
        switch status {
        case 1: return "Unknown"
        case 2: return "Pending"
        case 3: return "Processing"
        case 4: return "Partially Available"
        case 5: return "Available"
        default: return "Unknown"
        }
    }

    var isAvailable: Bool {
        status == 5
    }
}
