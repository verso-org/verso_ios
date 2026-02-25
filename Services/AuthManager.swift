import Foundation
import SwiftUI

@MainActor
final class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var user: JellyfinUser?

    private(set) var jellyfinClient: JellyfinClient
    private(set) var jellyseerrClient: JellyseerrClient
    private(set) var prograrClient: PrograrClient

    private enum Keys {
        static let serverURL = "serverURL"
        static let accessToken = "accessToken"
        static let userId = "userId"
        static let seerrURL = "seerrURL"
        static let seerrApiKey = "seerrApiKey"
        static let prograrURL = "prograrURL"
        static let prograrApiKey = "prograrApiKey"
    }

    init() {
        jellyfinClient = JellyfinClient()
        jellyseerrClient = JellyseerrClient()
        prograrClient = PrograrClient()
    }

    func restoreSession() async {
        guard let serverURL = KeychainService.get(key: Keys.serverURL),
              let accessToken = KeychainService.get(key: Keys.accessToken),
              let userId = KeychainService.get(key: Keys.userId) else {
            isLoading = false
            return
        }

        jellyfinClient = JellyfinClient(baseURL: serverURL, accessToken: accessToken, userId: userId)

        if let seerrURL = KeychainService.get(key: Keys.seerrURL),
           let seerrApiKey = KeychainService.get(key: Keys.seerrApiKey) {
            jellyseerrClient = JellyseerrClient(baseURL: seerrURL, apiKey: seerrApiKey)
        }

        if let prograrURL = KeychainService.get(key: Keys.prograrURL) {
            let prograrApiKey = KeychainService.get(key: Keys.prograrApiKey)
            prograrClient = PrograrClient(baseURL: prograrURL, apiKey: prograrApiKey)
        }

        isAuthenticated = true
        isLoading = false
    }

    func login(
        serverURL: String,
        username: String,
        password: String,
        seerrURL: String?,
        seerrApiKey: String?,
        prograrURL: String? = nil,
        prograrApiKey: String? = nil
    ) async throws {
        let trimmedURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let parsed = URL(string: trimmedURL),
              let scheme = parsed.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              parsed.host != nil else {
            throw NetworkError.invalidURL
        }
        let client = JellyfinClient(baseURL: trimmedURL)
        let authResponse = try await client.authenticate(username: username, password: password)

        // Store credentials
        KeychainService.set(trimmedURL, forKey: Keys.serverURL)
        KeychainService.set(authResponse.accessToken, forKey: Keys.accessToken)
        KeychainService.set(authResponse.user.id, forKey: Keys.userId)

        jellyfinClient = JellyfinClient(
            baseURL: trimmedURL,
            accessToken: authResponse.accessToken,
            userId: authResponse.user.id
        )

        // Jellyseerr (optional)
        if let seerrURL, !seerrURL.isEmpty, let seerrApiKey, !seerrApiKey.isEmpty {
            let trimmedSeerrURL = seerrURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            guard let parsedSeerr = URL(string: trimmedSeerrURL),
                  let scheme = parsedSeerr.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  parsedSeerr.host != nil else {
                throw NetworkError.invalidURL
            }
            KeychainService.set(trimmedSeerrURL, forKey: Keys.seerrURL)
            KeychainService.set(seerrApiKey, forKey: Keys.seerrApiKey)
            jellyseerrClient = JellyseerrClient(baseURL: trimmedSeerrURL, apiKey: seerrApiKey)
        }

        // Prograrr (optional)
        if let prograrURL, !prograrURL.isEmpty {
            let trimmedPrograrURL = prograrURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            guard let parsedPrograr = URL(string: trimmedPrograrURL),
                  let scheme = parsedPrograr.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  parsedPrograr.host != nil else {
                throw NetworkError.invalidURL
            }
            KeychainService.set(trimmedPrograrURL, forKey: Keys.prograrURL)
            if let prograrApiKey, !prograrApiKey.isEmpty {
                KeychainService.set(prograrApiKey, forKey: Keys.prograrApiKey)
            }
            prograrClient = PrograrClient(baseURL: trimmedPrograrURL, apiKey: prograrApiKey)
        }

        user = authResponse.user
        isAuthenticated = true
    }

    func logout() {
        KeychainService.clear()
        jellyfinClient = JellyfinClient()
        jellyseerrClient = JellyseerrClient()
        prograrClient = PrograrClient()
        user = nil
        isAuthenticated = false
    }
}
