//
//  StorageService.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import Foundation
import CoreData
import Combine

/// Service for persisting and retrieving clipboard items using Core Data
class StorageService: ObservableObject {
    // MARK: - Properties

    private let persistenceController: PersistenceController
    private var context: NSManagedObjectContext {
        persistenceController.viewContext
    }

    /// Publisher for storage changes
    private let itemsChangedSubject = PassthroughSubject<Void, Never>()
    var itemsChangedPublisher: AnyPublisher<Void, Never> {
        itemsChangedSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController

        // Listen for context save notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave),
            name: .NSManagedObjectContextDidSave,
            object: context
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func contextDidSave(_ notification: Notification) {
        itemsChangedSubject.send()
    }

    // MARK: - CRUD Operations

    /// Save a new clipboard item
    @discardableResult
    func save(_ item: ClipItem) -> Bool {
        _ = ClipItemEntity.create(from: item, in: context)

        do {
            try context.save()
            print("📦 StorageService: Saved item \(item.id)")
            return true
        } catch {
            print("📦 StorageService: Failed to save - \(error.localizedDescription)")
            return false
        }
    }

    /// Save multiple items in a batch
    @discardableResult
    func save(_ items: [ClipItem]) -> Bool {
        for item in items {
            _ = ClipItemEntity.create(from: item, in: context)
        }

        do {
            try context.save()
            print("📦 StorageService: Saved \(items.count) items")
            return true
        } catch {
            print("📦 StorageService: Failed to save batch - \(error.localizedDescription)")
            return false
        }
    }

    /// Fetch all items
    func fetchAll() -> [ClipItem] {
        let request = ClipItemEntity.allItemsFetchRequest()

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toClipItem() }
        } catch {
            print("📦 StorageService: Failed to fetch - \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch items with a limit
    func fetch(limit: Int) -> [ClipItem] {
        let request = ClipItemEntity.recentItemsFetchRequest(limit: limit)

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toClipItem() }
        } catch {
            print("📦 StorageService: Failed to fetch - \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch a specific item by ID
    func fetch(id: UUID) -> ClipItem? {
        let request = ClipItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            let entities = try context.fetch(request)
            return entities.first?.toClipItem()
        } catch {
            print("📦 StorageService: Failed to fetch by ID - \(error.localizedDescription)")
            return nil
        }
    }

    /// Update an existing item
    @discardableResult
    func update(_ item: ClipItem) -> Bool {
        let request = ClipItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
        request.fetchLimit = 1

        do {
            if let entity = try context.fetch(request).first {
                entity.update(from: item)
                try context.save()
                print("📦 StorageService: Updated item \(item.id)")
                return true
            } else {
                // Item doesn't exist, create it
                return save(item)
            }
        } catch {
            print("📦 StorageService: Failed to update - \(error.localizedDescription)")
            return false
        }
    }

    /// Delete an item by ID
    @discardableResult
    func delete(id: UUID) -> Bool {
        let request = ClipItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            try context.save()
            print("📦 StorageService: Deleted item \(id)")
            return true
        } catch {
            print("📦 StorageService: Failed to delete - \(error.localizedDescription)")
            return false
        }
    }

    /// Delete multiple items
    @discardableResult
    func delete(ids: [UUID]) -> Bool {
        let request = ClipItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids)

        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            try context.save()
            print("📦 StorageService: Deleted \(ids.count) items")
            return true
        } catch {
            print("📦 StorageService: Failed to delete batch - \(error.localizedDescription)")
            return false
        }
    }

    /// Delete all items (except favorites if specified)
    @discardableResult
    func deleteAll(keepFavorites: Bool = true) -> Bool {
        let request = ClipItemEntity.fetchRequest()
        if keepFavorites {
            request.predicate = NSPredicate(format: "isFavorite == NO AND isPinned == NO")
        }

        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            try context.save()
            print("📦 StorageService: Deleted all items (keepFavorites: \(keepFavorites))")
            return true
        } catch {
            print("📦 StorageService: Failed to delete all - \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Query Operations

    /// Search items by query string
    func search(query: String) -> [ClipItem] {
        let request = ClipItemEntity.searchFetchRequest(query: query)

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toClipItem() }
        } catch {
            print("📦 StorageService: Search failed - \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch items by content type
    func fetch(contentType: String) -> [ClipItem] {
        let request = ClipItemEntity.allItemsFetchRequest()
        request.predicate = NSPredicate(format: "contentType == %@", contentType)

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toClipItem() }
        } catch {
            print("📦 StorageService: Failed to fetch by type - \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch favorite items
    func fetchFavorites() -> [ClipItem] {
        let request = ClipItemEntity.allItemsFetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == YES")

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toClipItem() }
        } catch {
            print("📦 StorageService: Failed to fetch favorites - \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch pinned items
    func fetchPinned() -> [ClipItem] {
        let request = ClipItemEntity.allItemsFetchRequest()
        request.predicate = NSPredicate(format: "isPinned == YES")

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toClipItem() }
        } catch {
            print("📦 StorageService: Failed to fetch pinned - \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Maintenance Operations

    /// Get total item count
    func count() -> Int {
        let request = ClipItemEntity.fetchRequest()

        do {
            return try context.count(for: request)
        } catch {
            print("📦 StorageService: Failed to count - \(error.localizedDescription)")
            return 0
        }
    }

    /// Enforce maximum history size by deleting oldest non-permanent items
    @discardableResult
    func enforceMaxHistory(maxItems: Int) -> Int {
        // Count total items
        let totalCount = count()

        guard totalCount > maxItems else { return 0 }

        // Fetch items to delete (oldest first, excluding favorites and pinned)
        let request = ClipItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == NO AND isPinned == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipItemEntity.createdAt, ascending: true)]

        let toDeleteCount = totalCount - maxItems
        request.fetchLimit = toDeleteCount

        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            try context.save()
            print("📦 StorageService: Deleted \(entities.count) old items to enforce max history")
            return entities.count
        } catch {
            print("📦 StorageService: Failed to enforce max history - \(error.localizedDescription)")
            return 0
        }
    }

    /// Check if an item with the same content already exists
    func exists(content: ClipContent) -> UUID? {
        let request = ClipItemEntity.fetchRequest()

        // Build predicate based on content type
        switch content {
        case .text(let text, _):
            request.predicate = NSPredicate(format: "contentType == 'text' AND textContent == %@", text)
        case .url(let url):
            request.predicate = NSPredicate(format: "contentType == 'url' AND urlString == %@", url.absoluteString)
        default:
            // For other types, we don't deduplicate by default
            return nil
        }

        request.fetchLimit = 1

        do {
            if let entity = try context.fetch(request).first {
                return entity.id
            }
        } catch {
            print("📦 StorageService: Failed to check existence - \(error.localizedDescription)")
        }

        return nil
    }
}

// MARK: - Statistics

extension StorageService {
    /// Storage statistics
    struct Statistics {
        let totalItems: Int
        let favoriteItems: Int
        let pinnedItems: Int
        let textItems: Int
        let imageItems: Int
        let urlItems: Int
        let fileItems: Int
        let colorItems: Int
    }

    /// Get storage statistics
    func getStatistics() -> Statistics {
        let total = count()

        let favoriteRequest = ClipItemEntity.fetchRequest()
        favoriteRequest.predicate = NSPredicate(format: "isFavorite == YES")

        let pinnedRequest = ClipItemEntity.fetchRequest()
        pinnedRequest.predicate = NSPredicate(format: "isPinned == YES")

        let textRequest = ClipItemEntity.fetchRequest()
        textRequest.predicate = NSPredicate(format: "contentType == 'text'")

        let imageRequest = ClipItemEntity.fetchRequest()
        imageRequest.predicate = NSPredicate(format: "contentType == 'image'")

        let urlRequest = ClipItemEntity.fetchRequest()
        urlRequest.predicate = NSPredicate(format: "contentType == 'url'")

        let fileRequest = ClipItemEntity.fetchRequest()
        fileRequest.predicate = NSPredicate(format: "contentType == 'file'")

        let colorRequest = ClipItemEntity.fetchRequest()
        colorRequest.predicate = NSPredicate(format: "contentType == 'color'")

        do {
            return Statistics(
                totalItems: total,
                favoriteItems: try context.count(for: favoriteRequest),
                pinnedItems: try context.count(for: pinnedRequest),
                textItems: try context.count(for: textRequest),
                imageItems: try context.count(for: imageRequest),
                urlItems: try context.count(for: urlRequest),
                fileItems: try context.count(for: fileRequest),
                colorItems: try context.count(for: colorRequest)
            )
        } catch {
            return Statistics(
                totalItems: total,
                favoriteItems: 0,
                pinnedItems: 0,
                textItems: 0,
                imageItems: 0,
                urlItems: 0,
                fileItems: 0,
                colorItems: 0
            )
        }
    }
}
