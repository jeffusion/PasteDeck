//
//  CardPreviewCache.swift
//  PasteDeck
//

import Foundation
import CoreGraphics
import ImageIO

actor CardPreviewCache {
    struct Preview: @unchecked Sendable {
        let image: CGImage?
        let metadata: String
    }

    static let shared = CardPreviewCache()
    static let maximumImagePixelSize = 360

    private final class CacheEntry: NSObject {
        let preview: Preview

        init(preview: Preview) {
            self.preview = preview
        }
    }

    private let cache: NSCache<NSUUID, CacheEntry>

    init(countLimit: Int = 100, totalCostLimit: Int = 32 * 1024 * 1024) {
        cache = NSCache<NSUUID, CacheEntry>()
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }

    func preview(for item: ClipItem) -> Preview {
        let key = item.id as NSUUID
        if let cached = cache.object(forKey: key) {
            return cached.preview
        }

        let preview = Self.makePreview(for: item.content)
        let imageCost = preview.image.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(CacheEntry(preview: preview), forKey: key, cost: imageCost)
        return preview
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    private static func makePreview(for content: ClipContent) -> Preview {
        switch content {
        case .text(let string, _):
            return Preview(
                image: nil,
                metadata: L10n.plural("count.characters", count: string.count)
            )

        case .image(let data, _):
            return makeImagePreview(from: data)

        case .file(let url):
            return Preview(image: nil, metadata: fileMetadata(for: [url]))

        case .multipleFiles(let urls):
            return Preview(image: nil, metadata: fileMetadata(for: urls))

        case .color(let colorInfo):
            return Preview(image: nil, metadata: colorInfo.hexString)
        }
    }

    private static func makeImagePreview(from data: Data) -> Preview {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return Preview(image: nil, metadata: "")
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int
        let height = properties?[kCGImagePropertyPixelHeight] as? Int

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumImagePixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        )

        let resolvedWidth = width ?? image?.width
        let resolvedHeight = height ?? image?.height
        let metadata: String
        if let resolvedWidth, let resolvedHeight {
            metadata = "\(L10n.integer(resolvedWidth)) × \(L10n.integer(resolvedHeight))"
        } else {
            metadata = ""
        }

        return Preview(image: image, metadata: metadata)
    }

    private static func fileMetadata(for urls: [URL]) -> String {
        let totalSize = urls.compactMap { url -> Int64? in
            try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
        }.reduce(0, +)

        var parts: [String] = []
        if totalSize > 0 {
            parts.append(L10n.byteCount(totalSize))
        }

        if urls.count == 1 {
            let fileExtension = urls[0].pathExtension
            if !fileExtension.isEmpty {
                parts.append(fileExtension.uppercased())
            }
        } else if !urls.isEmpty {
            parts.append(L10n.plural("count.files", count: urls.count))
        }

        return parts.joined(separator: " · ")
    }
}
