import Foundation

struct SeerrSearchResponse: Codable {
    let page: Int
    let totalPages: Int
    let totalResults: Int
    let results: [SeerrSearchResult]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decode(Int.self, forKey: .page)
        totalPages = try container.decode(Int.self, forKey: .totalPages)
        totalResults = try container.decode(Int.self, forKey: .totalResults)
        // Decode each result individually, skipping unsupported media types (e.g. "person")
        var resultsContainer = try container.nestedUnkeyedContainer(forKey: .results)
        var decoded: [SeerrSearchResult] = []
        while !resultsContainer.isAtEnd {
            if let result = try? resultsContainer.decode(SeerrSearchResult.self) {
                decoded.append(result)
            } else {
                // Skip the element that failed — decode as generic dict to advance the cursor
                _ = try? resultsContainer.decode([String: AnyCodableValue].self)
            }
        }
        results = decoded
    }
}

enum SeerrSearchResult: Codable, Identifiable {
    case movie(SeerrMovieResult)
    case tv(SeerrTvResult)

    var id: String {
        switch self {
        case .movie(let m): return "movie-\(m.id)"
        case .tv(let t): return "tv-\(t.id)"
        }
    }

    var tmdbId: Int {
        switch self {
        case .movie(let m): return m.id
        case .tv(let t): return t.id
        }
    }

    var title: String {
        switch self {
        case .movie(let m): return m.title
        case .tv(let t): return t.name
        }
    }

    var overview: String? {
        switch self {
        case .movie(let m): return m.overview
        case .tv(let t): return t.overview
        }
    }

    var posterPath: String? {
        switch self {
        case .movie(let m): return m.posterPath
        case .tv(let t): return t.posterPath
        }
    }

    var year: String? {
        switch self {
        case .movie(let m): return m.year
        case .tv(let t): return t.year
        }
    }

    var mediaType: String {
        switch self {
        case .movie: return "movie"
        case .tv: return "tv"
        }
    }

    var mediaInfo: SeerrMediaInfo? {
        switch self {
        case .movie(let m): return m.mediaInfo
        case .tv(let t): return t.mediaInfo
        }
    }

    var backdropPath: String? {
        switch self {
        case .movie(let m): return m.backdropPath
        case .tv(let t): return t.backdropPath
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Try to determine media type from the raw JSON
        let raw = try decoder.singleValueContainer()
        let dict = try raw.decode([String: AnyCodableValue].self)
        let mediaType = dict["mediaType"]?.stringValue

        if mediaType == "tv" {
            let tv = try container.decode(SeerrTvResult.self)
            self = .tv(tv)
        } else {
            let movie = try container.decode(SeerrMovieResult.self)
            self = .movie(movie)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .movie(let m): try container.encode(m)
        case .tv(let t): try container.encode(t)
        }
    }
}

// Helper for peeking at JSON values during decoding
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { self = .string(s) }
        else if let i = try? container.decode(Int.self) { self = .int(i) }
        else if let d = try? container.decode(Double.self) { self = .double(d) }
        else if let b = try? container.decode(Bool.self) { self = .bool(b) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }
}
