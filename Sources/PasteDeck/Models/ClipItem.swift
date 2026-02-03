//
//  ClipItem.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import Foundation
import CloudKit
import SwiftUI

/// Represents a single clipboard item with metadata
struct ClipItem: Identifiable, Codable, Equatable, Hashable {
    // MARK: - Properties

    /// Unique identifier
    let id: UUID

    /// The actual content of the clipboard item
    let content: ClipContent

    /// When this item was created/captured
    let createdAt: Date

    /// The application that was active when this was copied (if available)
    let sourceApp: String?

    /// Whether this item is marked as favorite
    var isFavorite: Bool

    /// Whether this item is pinned to the top
    var isPinned: Bool

    /// Last time this item was used/accessed
    var lastUsedAt: Date?

    /// Number of times this item has been used
    var useCount: Int

    /// Optional user-added tags
    var tags: [String]

    /// Optional user note
    var note: String?

    /// CloudKit record ID (nil if not synced)
    var cloudRecordID: String?

    /// Indicates if this item should be excluded from sync
    var excludeFromSync: Bool

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        content: ClipContent,
        createdAt: Date = Date(),
        sourceApp: String? = nil,
        isFavorite: Bool = false,
        isPinned: Bool = false,
        lastUsedAt: Date? = nil,
        useCount: Int = 0,
        tags: [String] = [],
        note: String? = nil,
        cloudRecordID: String? = nil,
        excludeFromSync: Bool = false
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.sourceApp = sourceApp
        self.isFavorite = isFavorite
        self.isPinned = isPinned
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
        self.tags = tags
        self.note = note
        self.cloudRecordID = cloudRecordID
        self.excludeFromSync = excludeFromSync
    }

    // MARK: - Computed Properties

    /// Display title based on content type
    var title: String {
        switch content {
        case .text(let string, _):
            // Use first line or first 50 characters
            let firstLine = string.components(separatedBy: .newlines).first ?? string
            let preview = firstLine.prefix(50)
            return preview.count < firstLine.count ? "\(preview)..." : String(preview)

        case .image:
            return "Image"

        case .file(let url):
            return url.lastPathComponent

        case .multipleFiles(let urls):
            return "\(urls.count) files"

        case .color(let colorInfo):
            return colorInfo.hexString
        }
    }

    /// Human-readable timestamp
    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    /// Size-friendly description of content size
    var sizeDescription: String {
        let bytes = content.estimatedSize
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    /// Whether this item should be kept permanently (favorites or pinned)
    var isPermanent: Bool {
        return isFavorite || isPinned
    }

    // MARK: - Methods

    /// Mark this item as used (updates useCount and lastUsedAt)
    mutating func markAsUsed() {
        useCount += 1
        lastUsedAt = Date()
    }

    /// Toggle favorite status
    mutating func toggleFavorite() {
        isFavorite.toggle()
    }

    /// Toggle pinned status
    mutating func togglePinned() {
        isPinned.toggle()
    }

    /// Add a tag
    mutating func addTag(_ tag: String) {
        let normalizedTag = tag.trimmingCharacters(in: .whitespaces).lowercased()
        if !normalizedTag.isEmpty && !tags.contains(normalizedTag) {
            tags.append(normalizedTag)
        }
    }

    /// Remove a tag
    mutating func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag.lowercased() }
    }

    // MARK: - Equatable

    static func == (lhs: ClipItem, rhs: ClipItem) -> Bool {
        return lhs.id == rhs.id
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - CloudKit Extensions

extension ClipItem {
    /// CloudKit record type
    static let recordType = "ClipItem"

    /// Convert to CloudKit record
    func toCKRecord(zoneID: CKRecordZone.ID? = nil) throws -> CKRecord {
        let recordID: CKRecord.ID
        if let cloudRecordID = cloudRecordID {
            if let zoneID = zoneID {
                recordID = CKRecord.ID(recordName: cloudRecordID, zoneID: zoneID)
            } else {
                recordID = CKRecord.ID(recordName: cloudRecordID)
            }
        } else {
            if let zoneID = zoneID {
                recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
            } else {
                recordID = CKRecord.ID(recordName: id.uuidString)
            }
        }

        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        // Encode content as JSON
        let contentData = try JSONEncoder().encode(content)
        record["content"] = contentData

        // Store metadata
        record["createdAt"] = createdAt as CKRecordValue
        record["sourceApp"] = (sourceApp ?? "") as CKRecordValue
        record["isFavorite"] = isFavorite as CKRecordValue
        record["isPinned"] = isPinned as CKRecordValue
        record["useCount"] = useCount as CKRecordValue
        record["tags"] = tags as CKRecordValue
        record["note"] = (note ?? "") as CKRecordValue

        if let lastUsedAt = lastUsedAt {
            record["lastUsedAt"] = lastUsedAt as CKRecordValue
        }

        return record
    }

    /// Create from CloudKit record
    static func from(record: CKRecord) throws -> ClipItem {
        guard let contentData = record["content"] as? Data else {
            throw NSError(
                domain: "ClipItem",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing content data"]
            )
        }

        let content = try JSONDecoder().decode(ClipContent.self, from: contentData)

        guard let createdAt = record["createdAt"] as? Date else {
            throw NSError(
                domain: "ClipItem",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Missing createdAt"]
            )
        }

        let sourceApp = record["sourceApp"] as? String
        let isFavorite = record["isFavorite"] as? Bool ?? false
        let isPinned = record["isPinned"] as? Bool ?? false
        let useCount = record["useCount"] as? Int ?? 0
        let tags = record["tags"] as? [String] ?? []
        let note = record["note"] as? String
        let lastUsedAt = record["lastUsedAt"] as? Date

        // Parse UUID from record name
        guard let id = UUID(uuidString: record.recordID.recordName) else {
            throw NSError(
                domain: "ClipItem",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Invalid UUID in record name"]
            )
        }

        return ClipItem(
            id: id,
            content: content,
            createdAt: createdAt,
            sourceApp: sourceApp,
            isFavorite: isFavorite,
            isPinned: isPinned,
            lastUsedAt: lastUsedAt,
            useCount: useCount,
            tags: tags,
            note: note,
            cloudRecordID: record.recordID.recordName,
            excludeFromSync: false
        )
    }
}

// MARK: - Search Support

extension ClipItem {
    /// Check if this item matches a search query
    func matches(query: String) -> Bool {
        let lowercaseQuery = query.lowercased()

        // Check content
        switch content {
        case .text(let string, _):
            if string.lowercased().contains(lowercaseQuery) {
                return true
            }

        case .file(let url):
            if url.lastPathComponent.lowercased().contains(lowercaseQuery) {
                return true
            }

        case .multipleFiles(let urls):
            if urls.contains(where: { $0.lastPathComponent.lowercased().contains(lowercaseQuery) }) {
                return true
            }

        case .color(let colorInfo):
            if colorInfo.hexString.lowercased().contains(lowercaseQuery) {
                return true
            }

        case .image:
            // Can't search inside images
            break
        }

        // Check tags
        if tags.contains(where: { $0.contains(lowercaseQuery) }) {
            return true
        }

        // Check note
        if let note = note, note.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Check source app
        if let sourceApp = sourceApp, sourceApp.lowercased().contains(lowercaseQuery) {
            return true
        }

        return false
    }

    /// Filter type for content
    enum ContentFilter: String, CaseIterable {
        case all = "All"
        case text = "Text"
        case images = "Images"
        case files = "Files"
        case colors = "Colors"

        var iconName: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .text: return "doc.text"
            case .images: return "photo"
            case .files: return "doc"
            case .colors: return "paintpalette"
            }
        }

        var displayName: String {
            switch self {
            case .all: return "全部"
            case .text: return "文本"
            case .images: return "图片"
            case .files: return "文件"
            case .colors: return "颜色"
            }
        }

        var dotColor: Color {
            switch self {
            case .all: return .gray
            case .text: return .blue
            case .images: return .purple
            case .files: return .orange
            case .colors: return .pink
            }
        }

        func matches(content: ClipContent) -> Bool {
            switch (self, content) {
            case (.all, _):
                return true
            case (.text, .text):
                return true
            case (.images, .image):
                return true
            case (.files, .file), (.files, .multipleFiles):
                return true
            case (.colors, .color):
                return true
            default:
                return false
            }
        }
    }

    /// Date filter for items
    enum DateFilter: String, CaseIterable {
        case all = "All Time"
        case today = "Today"
        case yesterday = "Yesterday"
        case thisWeek = "This Week"
        case thisMonth = "This Month"

        func matches(date: Date) -> Bool {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .all:
                return true

            case .today:
                return calendar.isDateInToday(date)

            case .yesterday:
                return calendar.isDateInYesterday(date)

            case .thisWeek:
                guard let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) else {
                    return false
                }
                return date > weekAgo

            case .thisMonth:
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
            }
        }
    }
}

// MARK: - Comparable for Sorting

extension ClipItem: Comparable {
    static func < (lhs: ClipItem, rhs: ClipItem) -> Bool {
        // Pinned items always come first
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned
        }

        // Then favorites
        if lhs.isFavorite != rhs.isFavorite {
            return lhs.isFavorite
        }

        // Then by most recent
        return lhs.createdAt > rhs.createdAt
    }
}
