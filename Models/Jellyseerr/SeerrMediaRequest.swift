import Foundation

struct SeerrMediaRequest: Codable, Identifiable {
    let id: Int
    let status: Int
    let type: String
    let createdAt: String?
    let updatedAt: String?
    let media: SeerrRequestMedia?
    let requestedBy: SeerrRequestUser?

    var statusText: String {
        switch status {
        case 1: return "Pending"
        case 2: return "Approved"
        case 3: return "Declined"
        default: return "Unknown"
        }
    }

    var isPending: Bool { status == 1 }
    var isApproved: Bool { status == 2 }
    var isDeclined: Bool { status == 3 }
}

struct SeerrRequestMedia: Codable {
    let id: Int?
    let tmdbId: Int?
    let status: Int?
    let mediaType: String?
}

struct SeerrRequestUser: Codable {
    let id: Int?
    let displayName: String?
    let avatar: String?
}

struct SeerrRequestsResponse: Codable {
    let pageInfo: SeerrPageInfo
    let results: [SeerrMediaRequest]
}

struct SeerrPageInfo: Codable {
    let pages: Int
    let pageSize: Int
    let results: Int
    let page: Int
}
