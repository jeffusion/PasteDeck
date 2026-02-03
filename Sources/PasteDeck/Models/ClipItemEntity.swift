//
//  ClipItemEntity.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import Foundation
import CoreData

/// Core Data entity for persisting clipboard items
@objc(ClipItemEntity)
public class ClipItemEntity: NSManagedObject {
    // MARK: - Core Properties

    @NSManaged public var id: UUID
    @NSManaged public var createdAt: Date
    @NSManaged public var sourceApp: String?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var isPinned: Bool
    @NSManaged public var lastUsedAt: Date?
    @NSManaged public var useCount: Int32
    @NSManaged public var tags: [String]?
    @NSManaged public var note: String?
    @NSManaged public var cloudRecordID: String?
    @NSManaged public var excludeFromSync: Bool

    // MARK: - Content Properties

    @NSManaged public var contentType: String
    @NSManaged public var textContent: String?
    @NSManaged public var isRTF: Bool
    @NSManaged public var imageData: Data?
    @NSManaged public var imageFormat: String?
    @NSManaged public var filePaths: [String]?
    @NSManaged public var colorRed: Double
    @NSManaged public var colorGreen: Double
    @NSManaged public var colorBlue: Double
    @NSManaged public var colorAlpha: Double
}

// MARK: - Fetch Request

extension ClipItemEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ClipItemEntity> {
        return NSFetchRequest<ClipItemEntity>(entityName: "ClipItemEntity")
    }

    /// Fetch all items sorted by date (newest first), with pinned items at top
    @nonobjc public class func allItemsFetchRequest() -> NSFetchRequest<ClipItemEntity> {
        let request = fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipItemEntity.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \ClipItemEntity.isFavorite, ascending: false),
            NSSortDescriptor(keyPath: \ClipItemEntity.createdAt, ascending: false)
        ]
        return request
    }

    /// Fetch items with a limit
    @nonobjc public class func recentItemsFetchRequest(limit: Int) -> NSFetchRequest<ClipItemEntity> {
        let request = allItemsFetchRequest()
        request.fetchLimit = limit
        return request
    }

    /// Search items by content
    @nonobjc public class func searchFetchRequest(query: String) -> NSFetchRequest<ClipItemEntity> {
        let request = allItemsFetchRequest()
        request.predicate = NSPredicate(
            format: "textContent CONTAINS[cd] %@ OR note CONTAINS[cd] %@",
            query, query
        )
        return request
    }
}

// MARK: - Conversion to ClipItem

extension ClipItemEntity {
    /// Convert entity to ClipItem value type
    func toClipItem() -> ClipItem? {
        guard let content = toClipContent() else { return nil }

        return ClipItem(
            id: id,
            content: content,
            createdAt: createdAt,
            sourceApp: sourceApp,
            isFavorite: isFavorite,
            isPinned: isPinned,
            lastUsedAt: lastUsedAt,
            useCount: Int(useCount),
            tags: tags ?? [],
            note: note,
            cloudRecordID: cloudRecordID,
            excludeFromSync: excludeFromSync
        )
    }

    /// Convert content properties to ClipContent
    private func toClipContent() -> ClipContent? {
        switch contentType {
        case "text":
            guard let text = textContent else { return nil }
            return .text(text, isRTF: isRTF)

        case "image":
            guard let data = imageData else { return nil }
            let format = ClipContent.ImageFormat(rawValue: imageFormat ?? "unknown") ?? .unknown
            return .image(data, format: format)

        case "file":
            guard let paths = filePaths, let firstPath = paths.first else { return nil }
            if paths.count == 1 {
                return .file(URL(fileURLWithPath: firstPath))
            } else {
                return .multipleFiles(paths.map { URL(fileURLWithPath: $0) })
            }

        case "color":
            let colorInfo = ClipContent.ColorInfo(
                red: colorRed,
                green: colorGreen,
                blue: colorBlue,
                alpha: colorAlpha
            )
            return .color(colorInfo)

        default:
            return nil
        }
    }
}

// MARK: - Update from ClipItem

extension ClipItemEntity {
    /// Update entity from ClipItem value type
    func update(from item: ClipItem) {
        id = item.id
        createdAt = item.createdAt
        sourceApp = item.sourceApp
        isFavorite = item.isFavorite
        isPinned = item.isPinned
        lastUsedAt = item.lastUsedAt
        useCount = Int32(item.useCount)
        tags = item.tags
        note = item.note
        cloudRecordID = item.cloudRecordID
        excludeFromSync = item.excludeFromSync

        // Update content
        updateContent(from: item.content)
    }

    /// Update content properties from ClipContent
    private func updateContent(from content: ClipContent) {
        // Clear all content fields first
        textContent = nil
        isRTF = false
        imageData = nil
        imageFormat = nil
        filePaths = nil
        colorRed = 0
        colorGreen = 0
        colorBlue = 0
        colorAlpha = 1

        switch content {
        case .text(let text, let rtf):
            contentType = "text"
            textContent = text
            isRTF = rtf

        case .image(let data, let format):
            contentType = "image"
            imageData = data
            imageFormat = format.rawValue

        case .file(let url):
            contentType = "file"
            filePaths = [url.path]

        case .multipleFiles(let urls):
            contentType = "file"
            filePaths = urls.map { $0.path }

        case .color(let colorInfo):
            contentType = "color"
            colorRed = colorInfo.red
            colorGreen = colorInfo.green
            colorBlue = colorInfo.blue
            colorAlpha = colorInfo.alpha
        }
    }
}

// MARK: - Factory Method

extension ClipItemEntity {
    /// Create a new entity from a ClipItem
    static func create(from item: ClipItem, in context: NSManagedObjectContext) -> ClipItemEntity {
        let entity = NSEntityDescription.insertNewObject(forEntityName: "ClipItemEntity", into: context) as! ClipItemEntity
        entity.update(from: item)
        return entity
    }
}
