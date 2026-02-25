import Foundation

struct SeerrRequestBody: Encodable {
    let mediaType: String
    let mediaId: Int
    let seasons: [Int]?
    let profileId: Int?
    let rootFolder: String?
    let serverId: Int?

    init(
        mediaType: String,
        mediaId: Int,
        seasons: [Int]? = nil,
        profileId: Int? = nil,
        rootFolder: String? = nil,
        serverId: Int? = nil
    ) {
        self.mediaType = mediaType
        self.mediaId = mediaId
        self.seasons = seasons
        self.profileId = profileId
        self.rootFolder = rootFolder
        self.serverId = serverId
    }

    // Custom encoding: camelCase keys, skip nil fields
    // (the shared encoder uses convertToSnakeCase which Jellyseerr rejects)
    enum CodingKeys: String, CodingKey {
        case mediaType, mediaId, seasons, profileId, rootFolder, serverId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mediaType, forKey: .mediaType)
        try container.encode(mediaId, forKey: .mediaId)
        if let seasons { try container.encode(seasons, forKey: .seasons) }
        if let profileId { try container.encode(profileId, forKey: .profileId) }
        if let rootFolder { try container.encode(rootFolder, forKey: .rootFolder) }
        if let serverId { try container.encode(serverId, forKey: .serverId) }
    }
}
