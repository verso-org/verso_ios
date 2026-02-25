import SwiftUI

struct CachedAsyncImage: View {
    let url: URL?
    var cornerRadius: CGFloat = 14
    var displaySize: CGSize?

    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if loadFailed {
                errorPlaceholder
            } else {
                ShimmerView()
            }
        }
        .task(id: url) {
            image = nil
            loadFailed = false
            guard let url else {
                loadFailed = true
                return
            }
            if let loaded = await ImageCache.shared.image(for: url, displaySize: displaySize) {
                image = loaded
            } else {
                loadFailed = true
            }
        }
    }

    private var errorPlaceholder: some View {
        Rectangle()
            .fill(Color.versoCard)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(Color.versoSecondaryText)
            }
    }
}

// MARK: - Image Cache (memory + disk, with request deduplication)

actor ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 30 * 1024 * 1024,   // 30 MB URL cache in memory
            diskCapacity: 150 * 1024 * 1024      // 150 MB on disk
        )
        config.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration: config)
        memoryCache.countLimit = 150
        memoryCache.totalCostLimit = 80 * 1024 * 1024  // 80 MB max for decoded images
    }

    func image(for url: URL, displaySize: CGSize? = nil) async -> UIImage? {
        let cacheKey = cacheKey(url: url, displaySize: displaySize)

        // 1. Check memory cache
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }

        // 2. Deduplicate in-flight requests
        if let existing = inFlight[cacheKey] {
            return await existing.value
        }

        // 3. Fetch (URLCache provides disk-level caching)
        let task = Task<UIImage?, Never> {
            guard let (data, _) = try? await session.data(from: url) else {
                return nil
            }
            let img: UIImage?
            if let displaySize, displaySize.width > 0, displaySize.height > 0 {
                img = downsample(data: data, to: displaySize)
            } else {
                img = UIImage(data: data)
            }
            guard let img else { return nil }
            let cost = Int(img.size.width * img.size.height * img.scale * img.scale * 4)
            memoryCache.setObject(img, forKey: cacheKey as NSString, cost: cost)
            return img
        }

        inFlight[cacheKey] = task
        let result = await task.value
        inFlight.removeValue(forKey: cacheKey)  // guaranteed: Task<_, Never> always completes
        return result
    }

    private func cacheKey(url: URL, displaySize: CGSize?) -> String {
        if let displaySize, displaySize.width > 0, displaySize.height > 0 {
            return "\(url.absoluteString)_\(Int(displaySize.width))x\(Int(displaySize.height))"
        }
        return url.absoluteString
    }

    private func downsample(data: Data, to size: CGSize) -> UIImage? {
        let scale = UIScreen.main.scale
        let maxDimension = max(size.width, size.height) * scale

        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) {
            return UIImage(cgImage: cgImage)
        }
        // Thumbnail creation failed — decode at original size but constrain via UIKit
        // to avoid flooding GPU with massive textures
        guard let original = UIImage(data: data) else { return nil }
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        if original.size.width <= targetSize.width && original.size.height <= targetSize.height {
            return original
        }
        // Manual resize to target dimensions
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            original.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
