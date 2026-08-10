//
//  CardPreviewCacheTests.swift
//  PasteDeckTests
//

import XCTest
import AppKit
@testable import PasteDeck

final class CardPreviewCacheTests: XCTestCase {
    func testImagePreviewIsDownsampledAndCached() async throws {
        let cache = CardPreviewCache(countLimit: 10, totalCostLimit: 8 * 1024 * 1024)
        let imageData = try XCTUnwrap(makePNGData(width: 1_200, height: 600))
        let item = ClipItem(content: .image(imageData, format: .png))

        let first = await cache.preview(for: item)
        let second = await cache.preview(for: item)
        let firstImage = try XCTUnwrap(first.image)
        let secondImage = try XCTUnwrap(second.image)

        XCTAssertEqual(first.metadata, "1200 × 600")
        XCTAssertLessThanOrEqual(
            max(firstImage.width, firstImage.height),
            CardPreviewCache.maximumImagePixelSize
        )
        XCTAssertTrue(firstImage === secondImage)
    }

    func testFilePreviewIncludesExtension() async throws {
        let cache = CardPreviewCache(countLimit: 10, totalCostLimit: 8 * 1024 * 1024)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pastedeck-preview-\(UUID().uuidString).txt")
        try Data(repeating: 0, count: 2_048).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let preview = await cache.preview(for: ClipItem(content: .file(fileURL)))

        XCTAssertFalse(preview.metadata.isEmpty)
        XCTAssertTrue(preview.metadata.contains("TXT"))
    }

    private func makePNGData(width: Int, height: Int) -> Data? {
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        return representation.representation(using: .png, properties: [:])
    }
}
