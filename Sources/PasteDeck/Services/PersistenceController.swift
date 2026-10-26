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
    private(set) var loadError: Error?

    static var applicationDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PasteDeck", isDirectory: true)
    }

    /// Main view context for UI operations
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Background context for async operations
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    // MARK: - Initialization

    init(inMemory: Bool = false, storeURL: URL? = nil, readOnly: Bool = false) {
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
            let location = storeURL ?? Self.applicationDirectory.appendingPathComponent("PasteDeck.sqlite")
            container.persistentStoreDescriptions.first?.url = location
            do {
                if !readOnly {
                    try FileManager.default.createDirectory(at: location.deletingLastPathComponent(), withIntermediateDirectories: true)
                }
            } catch {
                loadError = error
            }
            container.persistentStoreDescriptions.first?.url = location
        }

        container.persistentStoreDescriptions.first?.shouldAddStoreAsynchronously = false
        if readOnly {
            container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSReadOnlyPersistentStoreOption)
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
        if loadError == nil {
            container.loadPersistentStores { [weak self] _, error in self?.loadError = error }
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.name = "viewContext"
    }

    /// Allows a startup Retry after a transient filesystem or store-opening failure.
    func retryLoadingStoreIfNeeded() throws {
        guard container.persistentStoreCoordinator.persistentStores.isEmpty else {
            if let loadError { throw loadError }
            return
        }
        if let description = container.persistentStoreDescriptions.first,
           let url = description.url,
           (description.options[NSReadOnlyPersistentStoreOption] as? NSNumber)?.boolValue != true,
           !inMemory {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        loadError = nil
        container.loadPersistentStores { [weak self] _, error in self?.loadError = error }
        if let loadError { throw loadError }
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
        // contentType: String (text, image, file, color)
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

    /// Core Data copies the SQLite store together with its external binary data.
    /// Call before changing any records, with the application's instance lock held.
    func backupStore() throws -> URL? {
        if let loadError { throw loadError }
        guard !inMemory, let source = container.persistentStoreDescriptions.first?.url else { return nil }
        let directory = source.deletingLastPathComponent()
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                              attributes: [.posixPermissions: 0o700])
        let destination = directory.appendingPathComponent("PasteDeck.sqlite")
        do {
            try container.persistentStoreCoordinator.replacePersistentStore(
                at: destination, destinationOptions: nil,
                withPersistentStoreFrom: source, sourceOptions: nil, ofType: NSSQLiteStoreType
            )
            return destination
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
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
