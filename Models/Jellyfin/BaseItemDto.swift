import Foundation

struct BaseItemDto: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String?
    let overview: String?
    let seriesName: String?
    let seriesId: String?
    let seasonId: String?
    let parentIndexNumber: Int?
    let indexNumber: Int?
    let productionYear: Int?
    let communityRating: Double?
    let officialRating: String?
    let runTimeTicks: Int64?
    let genres: [String]?
    let collectionType: String?
    let imageTags: ImageTags?
    let backdropImageTags: [String]?
    var userData: UserItemDataDto?
    let mediaSources: [MediaSourceInfo]?
    let people: [BaseItemPerson]?
    let chapters: [ChapterInfo]?
    let childCount: Int?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case overview = "Overview"
        case seriesName = "SeriesName"
        case seriesId = "SeriesId"
        case seasonId = "SeasonId"
        case parentIndexNumber = "ParentIndexNumber"
        case indexNumber = "IndexNumber"
        case productionYear = "ProductionYear"
        case communityRating = "CommunityRating"
        case officialRating = "OfficialRating"
        case runTimeTicks = "RunTimeTicks"
        case genres = "Genres"
        case collectionType = "CollectionType"
        case imageTags = "ImageTags"
        case backdropImageTags = "BackdropImageTags"
        case userData = "UserData"
        case mediaSources = "MediaSources"
        case people = "People"
        case chapters = "Chapters"
        case childCount = "ChildCount"
    }

    var runtimeMinutes: Int? {
        guard let ticks = runTimeTicks else { return nil }
        return Int(ticks / 600_000_000)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BaseItemDto, rhs: BaseItemDto) -> Bool {
        lhs.id == rhs.id && lhs.userData?.played == rhs.userData?.played
    }
}

struct ImageTags: Codable {
    let primary: String?
    let backdrop: String?
    let thumb: String?
    let logo: String?

    enum CodingKeys: String, CodingKey {
        case primary = "Primary"
        case backdrop = "Backdrop"
        case thumb = "Thumb"
        case logo = "Logo"
    }
}

struct BaseItemPerson: Codable {
    let id: String
    let name: String
    let role: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case role = "Role"
        case type = "Type"
    }
}

struct ItemsResponse: Codable {
    let items: [BaseItemDto]
    let totalRecordCount: Int

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}
