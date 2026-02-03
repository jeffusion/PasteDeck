//
//  ClipContentTests.swift
//  PasteDeckTests
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import XCTest
@testable import PasteDeck

final class ClipContentTests: XCTestCase {
    func testTextContent() {
        let content = ClipContent.text("Hello", isRTF: false)

        XCTAssertEqual(content.typeName, "Text")
        XCTAssertEqual(content.previewString, "Hello")
        XCTAssertEqual(content.iconName, "doc.text")
    }

    func testRTFContent() {
        let content = ClipContent.text("Hello", isRTF: true)

        XCTAssertEqual(content.typeName, "Rich Text")
        XCTAssertEqual(content.iconName, "doc.richtext")
    }

    func testFileContent() {
        let url = URL(fileURLWithPath: "/Users/test/file.txt")
        let content = ClipContent.file(url)

        XCTAssertEqual(content.typeName, "File")
        XCTAssertEqual(content.previewString, "file.txt")
        XCTAssertEqual(content.iconName, "doc")
    }

    func testMultipleFilesContent() {
        let urls = [
            URL(fileURLWithPath: "/Users/test/file1.txt"),
            URL(fileURLWithPath: "/Users/test/file2.txt")
        ]
        let content = ClipContent.multipleFiles(urls)

        XCTAssertEqual(content.typeName, "Files")
        XCTAssertTrue(content.previewString.contains("2 files"))
        XCTAssertEqual(content.iconName, "doc.on.doc")
    }

    func testColorContent() {
        let colorInfo = ClipContent.ColorInfo(
            red: 1.0,
            green: 0.0,
            blue: 0.0,
            alpha: 1.0
        )
        let content = ClipContent.color(colorInfo)

        XCTAssertEqual(content.typeName, "Color")
        XCTAssertEqual(content.previewString, "#FF0000")
        XCTAssertEqual(content.iconName, "paintpalette")
    }

    func testColorHexConversion() {
        let colorInfo = ClipContent.ColorInfo(
            red: 0.5,
            green: 0.25,
            blue: 0.75,
            alpha: 1.0
        )

        XCTAssertEqual(colorInfo.hexString, "#7F3FBF")
    }

    func testColorRGBConversion() {
        let colorInfo = ClipContent.ColorInfo(
            red: 1.0,
            green: 0.5,
            blue: 0.0,
            alpha: 1.0
        )

        XCTAssertEqual(colorInfo.rgbString, "rgb(255, 127, 0)")
    }

    func testTextPreviewTruncation() {
        let longText = String(repeating: "A", count: 150)
        let content = ClipContent.text(longText, isRTF: false)

        XCTAssertTrue(content.previewString.hasSuffix("..."))
        XCTAssertLessThanOrEqual(content.previewString.count, 103) // 100 chars + "..."
    }

    func testEstimatedSize() {
        let textContent = ClipContent.text("Hello", isRTF: false)
        XCTAssertGreaterThan(textContent.estimatedSize, 0)

        let fileContent = ClipContent.file(URL(fileURLWithPath: "/Users/test/file.txt"))
        XCTAssertGreaterThan(fileContent.estimatedSize, 0)
    }

    func testContentEquality() {
        let content1 = ClipContent.text("Hello", isRTF: false)
        let content2 = ClipContent.text("Hello", isRTF: false)
        let content3 = ClipContent.text("Hello", isRTF: true)

        XCTAssertEqual(content1, content2)
        XCTAssertNotEqual(content1, content3)
    }

    func testImageFormatFileExtension() {
        XCTAssertEqual(ClipContent.ImageFormat.png.fileExtension, "png")
        XCTAssertEqual(ClipContent.ImageFormat.jpeg.fileExtension, "jpg")
        XCTAssertEqual(ClipContent.ImageFormat.tiff.fileExtension, "tiff")
    }

    func testImageFormatMimeType() {
        XCTAssertEqual(ClipContent.ImageFormat.png.mimeType, "image/png")
        XCTAssertEqual(ClipContent.ImageFormat.jpeg.mimeType, "image/jpeg")
    }
}
