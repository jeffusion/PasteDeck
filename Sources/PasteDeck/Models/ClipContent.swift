//
//  ClipContent.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import Foundation
import AppKit

/// Represents the different types of content that can be stored in the clipboard
enum ClipContent: Codable, Equatable {
    case text(String, isRTF: Bool)
    case image(Data, format: ImageFormat)
    case url(URL)
    case file(URL)
    case multipleFiles([URL])
    case color(ColorInfo)

    // MARK: - Supporting Types

    enum ImageFormat: String, Codable {
        case png
        case jpeg
        case tiff
        case gif
        case heic
        case unknown

        var fileExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            case .tiff: return "tiff"
            case .gif: return "gif"
            case .heic: return "heic"
            case .unknown: return "dat"
            }
        }

        var mimeType: String {
            switch self {
            case .png: return "image/png"
            case .jpeg: return "image/jpeg"
            case .tiff: return "image/tiff"
            case .gif: return "image/gif"
            case .heic: return "image/heic"
            case .unknown: return "application/octet-stream"
            }
        }
    }

    struct ColorInfo: Codable, Equatable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        var hexString: String {
            String(format: "#%02X%02X%02X",
                   Int(red * 255),
                   Int(green * 255),
                   Int(blue * 255))
        }

        var rgbString: String {
            "rgb(\(Int(red * 255)), \(Int(green * 255)), \(Int(blue * 255)))"
        }

        var nsColor: NSColor {
            NSColor(red: red, green: green, blue: blue, alpha: alpha)
        }
    }

    // MARK: - Computed Properties

    /// Returns a display-friendly type name
    var typeName: String {
        switch self {
        case .text(_, let isRTF):
            return isRTF ? "Rich Text" : "Text"
        case .image:
            return "Image"
        case .url:
            return "URL"
        case .file:
            return "File"
        case .multipleFiles:
            return "Files"
        case .color:
            return "Color"
        }
    }

    /// Returns a preview string suitable for display
    var previewString: String {
        switch self {
        case .text(let string, _):
            // Return first 100 characters
            let preview = string.prefix(100)
            return preview.count < string.count ? "\(preview)..." : String(preview)

        case .image(_, let format):
            return "Image (\(format.rawValue.uppercased()))"

        case .url(let url):
            return url.absoluteString

        case .file(let url):
            return url.lastPathComponent

        case .multipleFiles(let urls):
            if urls.count == 1 {
                return urls[0].lastPathComponent
            } else {
                return "\(urls.count) files: \(urls.first?.lastPathComponent ?? "") ..."
            }

        case .color(let color):
            return color.hexString
        }
    }

    /// Estimated size in bytes for memory management
    var estimatedSize: Int {
        switch self {
        case .text(let string, _):
            return string.utf8.count
        case .image(let data, _):
            return data.count
        case .url(let url):
            return url.absoluteString.utf8.count
        case .file(let url):
            return url.path.utf8.count
        case .multipleFiles(let urls):
            return urls.reduce(0) { $0 + $1.path.utf8.count }
        case .color:
            return 32 // 4 doubles
        }
    }

    /// Icon name from SF Symbols for this content type
    var iconName: String {
        switch self {
        case .text(_, let isRTF):
            return isRTF ? "doc.richtext" : "doc.text"
        case .image:
            return "photo"
        case .url:
            return "link"
        case .file:
            return "doc"
        case .multipleFiles:
            return "doc.on.doc"
        case .color:
            return "paintpalette"
        }
    }

    /// Whether this content is an image
    var isImage: Bool {
        if case .image = self {
            return true
        }
        return false
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case type
        case textContent
        case isRTF
        case imageData
        case imageFormat
        case urlString
        case filePath
        case filePaths
        case colorInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .textContent)
            let isRTF = try container.decode(Bool.self, forKey: .isRTF)
            self = .text(text, isRTF: isRTF)

        case "image":
            let data = try container.decode(Data.self, forKey: .imageData)
            let format = try container.decode(ImageFormat.self, forKey: .imageFormat)
            self = .image(data, format: format)

        case "url":
            let urlString = try container.decode(String.self, forKey: .urlString)
            guard let url = URL(string: urlString) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .urlString,
                    in: container,
                    debugDescription: "Invalid URL string"
                )
            }
            self = .url(url)

        case "file":
            let filePath = try container.decode(String.self, forKey: .filePath)
            self = .file(URL(fileURLWithPath: filePath))

        case "multipleFiles":
            let filePaths = try container.decode([String].self, forKey: .filePaths)
            self = .multipleFiles(filePaths.map { URL(fileURLWithPath: $0) })

        case "color":
            let colorInfo = try container.decode(ColorInfo.self, forKey: .colorInfo)
            self = .color(colorInfo)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let string, let isRTF):
            try container.encode("text", forKey: .type)
            try container.encode(string, forKey: .textContent)
            try container.encode(isRTF, forKey: .isRTF)

        case .image(let data, let format):
            try container.encode("image", forKey: .type)
            try container.encode(data, forKey: .imageData)
            try container.encode(format, forKey: .imageFormat)

        case .url(let url):
            try container.encode("url", forKey: .type)
            try container.encode(url.absoluteString, forKey: .urlString)

        case .file(let url):
            try container.encode("file", forKey: .type)
            try container.encode(url.path, forKey: .filePath)

        case .multipleFiles(let urls):
            try container.encode("multipleFiles", forKey: .type)
            try container.encode(urls.map { $0.path }, forKey: .filePaths)

        case .color(let colorInfo):
            try container.encode("color", forKey: .type)
            try container.encode(colorInfo, forKey: .colorInfo)
        }
    }
}

// MARK: - Extensions

extension ClipContent {
    /// Determines the appropriate ClipContent from NSPasteboard types
    static func from(pasteboard: NSPasteboard) -> ClipContent? {
        // Priority order: Color → Image → File → URL → Text

        // Check for color
        if let colorData = pasteboard.data(forType: .color),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            let colorInfo = ColorInfo(
                red: Double(color.redComponent),
                green: Double(color.greenComponent),
                blue: Double(color.blueComponent),
                alpha: Double(color.alphaComponent)
            )
            return .color(colorInfo)
        }

        // Check for image
        if let image = NSImage(pasteboard: pasteboard) {
            if let data = image.tiffRepresentation {
                // Try to determine actual format
                let format = determineImageFormat(from: data)

                // Convert to more efficient format if needed
                if let pngData = convertToPNG(data: data) {
                    return .image(pngData, format: .png)
                }
                return .image(data, format: format)
            }
        }

        // Check for file URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            let fileURLs = urls.filter { $0.isFileURL }
            if !fileURLs.isEmpty {
                return fileURLs.count == 1 ? .file(fileURLs[0]) : .multipleFiles(fileURLs)
            }
        }

        // Check for URL
        if let urlString = pasteboard.string(forType: .URL),
           let url = URL(string: urlString) {
            return .url(url)
        }

        // Check for rich text
        if let rtfData = pasteboard.data(forType: .rtf),
           let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            return .text(attributedString.string, isRTF: true)
        }

        // Check for plain text
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            // Check if it's a URL that wasn't captured earlier
            if let url = URL(string: string), url.scheme != nil {
                return .url(url)
            }
            return .text(string, isRTF: false)
        }

        return nil
    }

    /// Write this content back to the pasteboard
    func write(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        switch self {
        case .text(let string, let isRTF):
            if isRTF, let rtfData = try? NSAttributedString(string: string).data(
                from: NSRange(location: 0, length: string.count),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ) {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            pasteboard.setString(string, forType: .string)

        case .image(let data, _):
            if let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }

        case .url(let url):
            pasteboard.setString(url.absoluteString, forType: .URL)
            pasteboard.setString(url.absoluteString, forType: .string)

        case .file(let url):
            pasteboard.writeObjects([url as NSURL])

        case .multipleFiles(let urls):
            pasteboard.writeObjects(urls.map { $0 as NSURL })

        case .color(let colorInfo):
            if let colorData = try? NSKeyedArchiver.archivedData(
                withRootObject: colorInfo.nsColor,
                requiringSecureCoding: true
            ) {
                pasteboard.setData(colorData, forType: .color)
            }
            // Also write as text for convenience
            pasteboard.setString(colorInfo.hexString, forType: .string)
        }
    }

    // MARK: - Helper Methods

    private static func determineImageFormat(from data: Data) -> ImageFormat {
        guard data.count > 4 else { return .unknown }

        let bytes = [UInt8](data.prefix(4))

        // PNG: 89 50 4E 47
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return .png
        }

        // JPEG: FF D8 FF
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return .jpeg
        }

        // TIFF: 49 49 or 4D 4D
        if (bytes[0] == 0x49 && bytes[1] == 0x49) || (bytes[0] == 0x4D && bytes[1] == 0x4D) {
            return .tiff
        }

        // GIF: 47 49 46
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
            return .gif
        }

        return .unknown
    }

    private static func convertToPNG(data: Data) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
