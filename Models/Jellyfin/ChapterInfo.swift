import Foundation

struct ChapterInfo: Codable {
    let startPositionTicks: Int64
    let name: String?

    enum CodingKeys: String, CodingKey {
        case startPositionTicks = "StartPositionTicks"
        case name = "Name"
    }

    var startSeconds: Double {
        Double(startPositionTicks) / 10_000_000
    }
}
