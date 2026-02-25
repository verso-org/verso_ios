import Foundation

struct SeerrServiceProfile: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
}

struct SeerrServiceServer: Codable, Identifiable {
    let id: Int
    let name: String
    let is4k: Bool
    let isDefault: Bool
    let activeProfileId: Int
    let activeDirectory: String
}

struct SeerrServiceDetail: Codable {
    let server: SeerrServiceServer
    let profiles: [SeerrServiceProfile]
}
