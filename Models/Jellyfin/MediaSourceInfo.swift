import Foundation

struct MediaStream: Codable {
    let index: Int
    let type: StreamType?
    let codec: String?
    let language: String?
    let title: String?
    let isDefault: Bool?
    let isExternal: Bool?
    let supportsExternalStream: Bool?
    let displayTitle: String?

    /// Bitmap subtitle formats that must be burned in (SubtitleMethod=Encode)
    private static let bitmapCodecs: Set<String> = ["pgssub", "pgs", "dvdsub", "dvbsub", "vobsub", "sub", "idx"]

    var isBitmapSubtitle: Bool {
        guard type == .subtitle, let codec = codec?.lowercased() else { return false }
        return Self.bitmapCodecs.contains(codec)
    }

    var isTextSubtitle: Bool {
        guard type == .subtitle else { return false }
        return !isBitmapSubtitle
    }

    /// Human-readable label for subtitle picker
    var displayLabel: String {
        if let displayTitle { return displayTitle }
        var parts: [String] = []
        if let language { parts.append(language.uppercased()) }
        if let title { parts.append(title) }
        if parts.isEmpty, let codec { parts.append(codec.uppercased()) }
        if isBitmapSubtitle { parts.append("(PGS)") }
        return parts.isEmpty ? "Track \(index)" : parts.joined(separator: " — ")
    }

    /// Human-readable label for audio picker (uses server's displayTitle, falls back to language + codec)
    var audioDisplayLabel: String {
        if let displayTitle { return displayTitle }
        var parts: [String] = []
        if let language { parts.append(language.uppercased()) }
        if let title { parts.append(title) }
        if parts.isEmpty, let codec { parts.append(codec.uppercased()) }
        return parts.isEmpty ? "Track \(index)" : parts.joined(separator: " — ")
    }

    enum StreamType: String, Codable {
        case video = "Video"
        case audio = "Audio"
        case subtitle = "Subtitle"
        case unknown

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            self = StreamType(rawValue: value) ?? .unknown
        }
    }

    enum CodingKeys: String, CodingKey {
        case index = "Index"
        case type = "Type"
        case codec = "Codec"
        case language = "Language"
        case title = "Title"
        case isDefault = "IsDefault"
        case isExternal = "IsExternal"
        case supportsExternalStream = "SupportsExternalStream"
        case displayTitle = "DisplayTitle"
    }
}

struct MediaSourceInfo: Codable {
    let id: String
    let name: String?
    let container: String?
    let supportsDirectPlay: Bool?
    let supportsDirectStream: Bool?
    let supportsTranscoding: Bool?
    let bitrate: Int?
    let size: Int64?
    let mediaStreams: [MediaStream]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case container = "Container"
        case supportsDirectPlay = "SupportsDirectPlay"
        case supportsDirectStream = "SupportsDirectStream"
        case supportsTranscoding = "SupportsTranscoding"
        case bitrate = "Bitrate"
        case size = "Size"
        case mediaStreams = "MediaStreams"
    }
}
