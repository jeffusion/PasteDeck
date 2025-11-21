//
//  PersistenceController.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import Foundation
import CoreData

/// Core Data stack controller using pure code model definition
class PersistenceController {
    // MARK: - Shared Instance

    static let shared = PersistenceController()

    // MARK: - Preview Support

    @MainActor
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)

        // Add sample data for preview
        let context = controller.container.viewContext

        for i in 0..<5 {
            let entity = ClipItemEntity(context: context)
            entity.id = UUID()
            entity.createdAt = Date().addingTimeInterval(TimeInterval(-i * 3600))
            entity.sourceApp = "Preview App"
            entity.isFavorite = i == 0
            entity.isPinned = i == 1
            entity.useCount = Int32(i)
            entity.contentType = "text"
            entity.textContent = "Sample text content \(i)"
        }

        do {
            try context.save()
        } catch {
            fatalError("Failed to save preview context: \(error)")
        }

        return controller
    }()

    // MARK: - Properties

    let container: NSPersistentContainer
    let inMemory: Bool

    /// Main view context for UI operations
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Background context for async operations
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    // MARK: - Initialization

    init(inMemory: Bool = false) {
        self.inMemory = inMemory

        // Create the managed object model programmatically
        let model = Self.createManagedObjectModel()

        // Create the container
        container = NSPersistentContainer(name: "PasteDeck", managedObjectModel: model)

        if inMemory {
            // Use proper in-memory store type
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        } else {
            // Set up store URL in Application Support
            let storeURL = Self.storeURL()
            container.persistentStoreDescriptions.first?.url = storeURL
        }

        // Configure container
        container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSPersistentHistoryTrackingKey
        )
        container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
        )

        // Load persistent stores
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // In production, handle this error appropriately
                fatalError("Failed to load persistent stores: \(error), \(error.userInfo)")
            }
            print("📦 Core Data store loaded: \(storeDescription.url?.absoluteString ?? "unknown")")
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.name = "viewContext"
    }

    // MARK: - Model Creation

    /// Creates the Core Data managed object model programmatically
    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Create ClipItemEntity
        let clipItemEntity = NSEntityDescription()
        clipItemEntity.name = "ClipItemEntity"
        clipItemEntity.managedObjectClassName = "PasteDeck.ClipItemEntity"

        // Define attributes
        var attributes: [NSAttributeDescription] = []

        // id: UUID
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false
        attributes.append(idAttr)

        // createdAt: Date
        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false
        attributes.append(createdAtAttr)

        // sourceApp: String?
        let sourceAppAttr = NSAttributeDescription()
        sourceAppAttr.name = "sourceApp"
        sourceAppAttr.attributeType = .stringAttributeType
        sourceAppAttr.isOptional = true
        attributes.append(sourceAppAttr)

        // isFavorite: Bool
        let isFavoriteAttr = NSAttributeDescription()
        isFavoriteAttr.name = "isFavorite"
        isFavoriteAttr.attributeType = .booleanAttributeType
        isFavoriteAttr.defaultValue = false
        attributes.append(isFavoriteAttr)

        // isPinned: Bool
        let isPinnedAttr = NSAttributeDescription()
        isPinnedAttr.name = "isPinned"
        isPinnedAttr.attributeType = .booleanAttributeType
        isPinnedAttr.defaultValue = false
        attributes.append(isPinnedAttr)

        // lastUsedAt: Date?
        let lastUsedAtAttr = NSAttributeDescription()
        lastUsedAtAttr.name = "lastUsedAt"
        lastUsedAtAttr.attributeType = .dateAttributeType
        lastUsedAtAttr.isOptional = true
        attributes.append(lastUsedAtAttr)

        // useCount: Int32
        let useCountAttr = NSAttributeDescription()
        useCountAttr.name = "useCount"
        useCountAttr.attributeType = .integer32AttributeType
        useCountAttr.defaultValue = 0
        attributes.append(useCountAttr)

        // tags: Transformable ([String])
        let tagsAttr = NSAttributeDescription()
        tagsAttr.name = "tags"
        tagsAttr.attributeType = .transformableAttributeType
        tagsAttr.valueTransformerName = NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue
        tagsAttr.isOptional = true
        attributes.append(tagsAttr)

        // note: String?
        let noteAttr = NSAttributeDescription()
        noteAttr.name = "note"
        noteAttr.attributeType = .stringAttributeType
        noteAttr.isOptional = true
        attributes.append(noteAttr)

        // cloudRecordID: String?
        let cloudRecordIDAttr = NSAttributeDescription()
        cloudRecordIDAttr.name = "cloudRecordID"
        cloudRecordIDAttr.attributeType = .stringAttributeType
        cloudRecordIDAttr.isOptional = true
        attributes.append(cloudRecordIDAttr)

        // excludeFromSync: Bool
        let excludeFromSyncAttr = NSAttributeDescription()
        excludeFromSyncAttr.name = "excludeFromSync"
        excludeFromSyncAttr.attributeType = .booleanAttributeType
        excludeFromSyncAttr.defaultValue = false
        attributes.append(excludeFromSyncAttr)

        // Content storage (simplified approach)
        // contentType: String (text, image, url, file, color)
        let contentTypeAttr = NSAttributeDescription()
        contentTypeAttr.name = "contentType"
        contentTypeAttr.attributeType = .stringAttributeType
        contentTypeAttr.isOptional = false
        attributes.append(contentTypeAttr)

        // textContent: String?
        let textContentAttr = NSAttributeDescription()
        textContentAttr.name = "textContent"
        textContentAttr.attributeType = .stringAttributeType
        textContentAttr.isOptional = true
        attributes.append(textContentAttr)

        // isRTF: Bool
        let isRTFAttr = NSAttributeDescription()
        isRTFAttr.name = "isRTF"
        isRTFAttr.attributeType = .booleanAttributeType
        isRTFAttr.defaultValue = false
        attributes.append(isRTFAttr)

        // imageData: Binary Data
        let imageDataAttr = NSAttributeDescription()
        imageDataAttr.name = "imageData"
        imageDataAttr.attributeType = .binaryDataAttributeType
        imageDataAttr.isOptional = true
        imageDataAttr.allowsExternalBinaryDataStorage = true
        attributes.append(imageDataAttr)

        // imageFormat: String?
        let imageFormatAttr = NSAttributeDescription()
        imageFormatAttr.name = "imageFormat"
        imageFormatAttr.attributeType = .stringAttributeType
        imageFormatAttr.isOptional = true
        attributes.append(imageFormatAttr)

        // urlString: String?
        let urlStringAttr = NSAttributeDescription()
        urlStringAttr.name = "urlString"
        urlStringAttr.attributeType = .stringAttributeType
        urlStringAttr.isOptional = true
        attributes.append(urlStringAttr)

        // filePaths: Transformable ([String])
        let filePathsAttr = NSAttributeDescription()
        filePathsAttr.name = "filePaths"
        filePathsAttr.attributeType = .transformableAttributeType
        filePathsAttr.valueTransformerName = NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue
        filePathsAttr.isOptional = true
        attributes.append(filePathsAttr)

        // colorRed, colorGreen, colorBlue, colorAlpha: Double
        let colorRedAttr = NSAttributeDescription()
        colorRedAttr.name = "colorRed"
        colorRedAttr.attributeType = .doubleAttributeType
        colorRedAttr.defaultValue = 0.0
        attributes.append(colorRedAttr)

        let colorGreenAttr = NSAttributeDescription()
        colorGreenAttr.name = "colorGreen"
        colorGreenAttr.attributeType = .doubleAttributeType
        colorGreenAttr.defaultValue = 0.0
        attributes.append(colorGreenAttr)

        let colorBlueAttr = NSAttributeDescription()
        colorBlueAttr.name = "colorBlue"
        colorBlueAttr.attributeType = .doubleAttributeType
        colorBlueAttr.defaultValue = 0.0
        attributes.append(colorBlueAttr)

        let colorAlphaAttr = NSAttributeDescription()
        colorAlphaAttr.name = "colorAlpha"
        colorAlphaAttr.attributeType = .doubleAttributeType
        colorAlphaAttr.defaultValue = 1.0
        attributes.append(colorAlphaAttr)

        clipItemEntity.properties = attributes

        model.entities = [clipItemEntity]

        return model
    }

    // MARK: - Store Location

    /// Returns the URL for the Core Data store
    private static func storeURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("PasteDeck", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        return directory.appendingPathComponent("PasteDeck.sqlite")
    }

    // MARK: - Save Operations

    /// Save the view context
    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
            print("📦 Core Data: Context saved successfully")
        } catch {
            print("📦 Core Data: Failed to save context - \(error.localizedDescription)")
        }
    }

    /// Save a specific context
    func save(context: NSManagedObjectContext) {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            print("📦 Core Data: Failed to save context - \(error.localizedDescription)")
        }
    }

    // MARK: - Batch Operations

    /// Delete all data (for testing or reset)
    func deleteAll() {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ClipItemEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(deleteRequest)
            try context.save()
            print("📦 Core Data: All data deleted")
        } catch {
            print("📦 Core Data: Failed to delete all data - \(error.localizedDescription)")
        }
    }
}
