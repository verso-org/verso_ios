import Foundation

struct SearchHintResponse: Codable {
    let searchHints: [SearchHint]
    let totalRecordCount: Int

    enum CodingKeys: String, CodingKey {
        case searchHints = "SearchHints"
        case totalRecordCount = "TotalRecordCount"
    }
}

struct SearchHint: Codable, Identifiable {
    let id: String
    let name: String
    let type: String?
    let productionYear: Int?
    let primaryImageTag: String?
    let thumbImageTag: String?
    let seriesName: String?
    let indexNumber: Int?
    let parentIndexNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case productionYear = "ProductionYear"
        case primaryImageTag = "PrimaryImageTag"
        case thumbImageTag = "ThumbImageTag"
        case seriesName = "SeriesName"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
    }
}
