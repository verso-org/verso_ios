import Foundation

enum ImageURLBuilder {
    enum ImageType: String {
        case primary = "Primary"
        case backdrop = "Backdrop"
        case thumb = "Thumb"
        case logo = "Logo"
        case banner = "Banner"
    }

    static func jellyfinImageURL(
        baseURL: String,
        itemId: String,
        imageType: ImageType = .primary,
        maxWidth: Int = 400,
        quality: Int = 90
    ) -> URL? {
        URL(string: "\(baseURL)/Items/\(itemId)/Images/\(imageType.rawValue)?maxWidth=\(maxWidth)&quality=\(quality)")
    }

    static func tmdbPosterURL(path: String, size: String = "w342") -> URL? {
        guard !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }

    static func tmdbBackdropURL(path: String, size: String = "w780") -> URL? {
        guard !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}
