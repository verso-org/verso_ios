import Foundation

struct JellyfinAuthResponse: Codable {
    let user: JellyfinUser
    let accessToken: String
    let serverId: String

    enum CodingKeys: String, CodingKey {
        case user = "User"
        case accessToken = "AccessToken"
        case serverId = "ServerId"
    }
}

struct JellyfinUser: Codable, Identifiable {
    let id: String
    let name: String
    let serverId: String
    let hasPassword: Bool

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case serverId = "ServerId"
        case hasPassword = "HasPassword"
    }
}
