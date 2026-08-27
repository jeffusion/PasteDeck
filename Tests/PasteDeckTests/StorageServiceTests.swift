//
//  StorageServiceTests.swift
//  PasteDeckTests
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import XCTest
@testable import PasteDeck

final class StorageServiceTests: XCTestCase {
    var storageService: StorageService!
    var persistenceController: PersistenceController!

    override func setUp() async throws {
        try await super.setUp()
        // Use in-memory store for testing
        persistenceController = PersistenceController(inMemory: true)
        storageService = StorageService(persistenceController: persistenceController)
    }

    override func tearDown() async throws {
        storageService = nil
        persistenceController = nil
        try await super.tearDown()
    }

    // MARK: - Save Tests

    func testSaveSingleItem() {
        let item = ClipItem(
            content: .text("Test content", isRTF: false),
            sourceApp: "TestApp"
        )

        let result = storageService.save(item)

        XCTAssertTrue(result)
        XCTAssertEqual(storageService.count(), 1)
    }

    func testSaveMultipleItems() {
        let items = [
            ClipItem(content: .text("Item 1", isRTF: false)),
            ClipItem(content: .text("Item 2", isRTF: false)),
            ClipItem(content: .text("Item 3", isRTF: false))
        ]

        let result = storageService.save(items)

        XCTAssertTrue(result)
        XCTAssertEqual(storageService.count(), 3)
    }

    func testSaveFileContent() {
        let fileURL = URL(fileURLWithPath: "/Users/test/file.txt")
        let item = ClipItem(content: .file(fileURL))

        let result = storageService.save(item)
        let fetched = storageService.fetch(id: item.id)

        XCTAssertTrue(result)
        XCTAssertNotNil(fetched)

        if case .file(let fetchedURL) = fetched?.content {
            XCTAssertEqual(fetchedURL, fileURL)
        } else {
            XCTFail("Content type mismatch")
        }
    }

    // MARK: - Fetch Tests

    func testFetchAll() {
        // Save some items
        for i in 1...5 {
            storageService.save(ClipItem(content: .text("Item \(i)", isRTF: false)))
        }

        let items = storageService.fetchAll()

        XCTAssertEqual(items.count, 5)
    }

    func testFetchWithLimit() {
        // Save 10 items
        for i in 1...10 {
            storageService.save(ClipItem(content: .text("Item \(i)", isRTF: false)))
        }

        let items = storageService.fetch(limit: 5)

        XCTAssertEqual(items.count, 5)
    }

    func testFetchById() {
        let item = ClipItem(
            content: .text("Specific item", isRTF: false),
            sourceApp: "TestApp"
        )
        storageService.save(item)

        let fetched = storageService.fetch(id: item.id)

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, item.id)
    }

    func testFetchNonExistentId() {
        let fetched = storageService.fetch(id: UUID())

        XCTAssertNil(fetched)
    }

    // MARK: - Update Tests

    func testUpdateItem() {
        var item = ClipItem(
            content: .text("Original", isRTF: false),
            sourceApp: "TestApp"
        )
        storageService.save(item)

        // Update the item
        item.isFavorite = true
        item.useCount = 5

        let result = storageService.update(item)
        let fetched = storageService.fetch(id: item.id)

        XCTAssertTrue(result)
        XCTAssertEqual(fetched?.isFavorite, true)
        XCTAssertEqual(fetched?.useCount, 5)
    }

    func testUpdateNonExistentItem() {
        let item = ClipItem(content: .text("New item", isRTF: false))

        // Update should create the item if it doesn't exist
        let result = storageService.update(item)

        XCTAssertTrue(result)
        XCTAssertEqual(storageService.count(), 1)
    }

    // MARK: - Delete Tests

    func testDeleteById() {
        let item = ClipItem(content: .text("To delete", isRTF: false))
        storageService.save(item)
        XCTAssertEqual(storageService.count(), 1)

        let result = storageService.delete(id: item.id)

        XCTAssertTrue(result)
        XCTAssertEqual(storageService.count(), 0)
    }

    func testDeleteMultiple() {
        let items = [
            ClipItem(content: .text("Item 1", isRTF: false)),
            ClipItem(content: .text("Item 2", isRTF: false)),
            ClipItem(content: .text("Item 3", isRTF: false))
        ]
        storageService.save(items)

        let idsToDelete = [items[0].id, items[1].id]
        let result = storageService.delete(ids: idsToDelete)

        XCTAssertTrue(result)
        XCTAssertEqual(storageService.count(), 1)
    }

    func testDeleteAllKeepingFavorites() {
        // Create items with one favorite
        let normalItem = ClipItem(content: .text("Normal", isRTF: false))
        var favoriteItem = ClipItem(content: .text("Favorite", isRTF: false))
        favoriteItem.isFavorite = true

        storageService.save(normalItem)
        storageService.save(favoriteItem)

        let result = storageService.deleteAll(keepFavorites: true)

        XCTAssertTrue(result)
        XCTAssertEqual(storageService.count(), 1)

        let remaining = storageService.fetchAll()
        XCTAssertEqual(remaining.first?.isFavorite, true)
    }

    // MARK: - Query Tests

    func testFetchFavorites() {
        var favoriteItem = ClipItem(content: .text("Favorite", isRTF: false))
        favoriteItem.isFavorite = true

        let normalItem = ClipItem(content: .text("Normal", isRTF: false))

        storageService.save(favoriteItem)
        storageService.save(normalItem)

        let favorites = storageService.fetchFavorites()

        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites.first?.isFavorite, true)
    }

    func testFetchPinned() {
        var pinnedItem = ClipItem(content: .text("Pinned", isRTF: false))
        pinnedItem.isPinned = true

        let normalItem = ClipItem(content: .text("Normal", isRTF: false))

        storageService.save(pinnedItem)
        storageService.save(normalItem)

        let pinned = storageService.fetchPinned()

        XCTAssertEqual(pinned.count, 1)
        XCTAssertEqual(pinned.first?.isPinned, true)
    }

    // MARK: - Maintenance Tests

    func testEnforceMaxHistory() {
        // Create 10 items
        for i in 1...10 {
            storageService.save(ClipItem(content: .text("Item \(i)", isRTF: false)))
        }

        XCTAssertEqual(storageService.count(), 10)

        // Enforce max of 5
        let deleted = storageService.enforceMaxHistory(maxItems: 5)

        XCTAssertEqual(deleted, 5)
        XCTAssertEqual(storageService.count(), 5)
    }

    func testEnforceMaxHistoryDeletesOldestOrdinaryItemsFirst() {
        let now = Date()
        let favorite = ClipItem(content: .text("Favorite", isRTF: false), createdAt: now.addingTimeInterval(-500), isFavorite: true)
        let pinned = ClipItem(content: .text("Pinned", isRTF: false), createdAt: now.addingTimeInterval(-400), isPinned: true)
        let oldestOrdinary = ClipItem(content: .text("Oldest ordinary", isRTF: false), createdAt: now.addingTimeInterval(-300))
        let middleOrdinary = ClipItem(content: .text("Middle ordinary", isRTF: false), createdAt: now.addingTimeInterval(-200))
        let newestOrdinary = ClipItem(content: .text("Newest ordinary", isRTF: false), createdAt: now.addingTimeInterval(-100))
        storageService.save([favorite, pinned, oldestOrdinary, middleOrdinary, newestOrdinary])

        let deleted = storageService.enforceMaxHistory(maxItems: 3)
        let remainingIDs = Set(storageService.fetchAll().map(\.id))

        XCTAssertEqual(deleted, 2)
        XCTAssertEqual(remainingIDs, Set([favorite.id, pinned.id, newestOrdinary.id]))
    }

    func testEnforceMaxHistoryDeletesOldestPermanentItemsWhenNeeded() {
        let now = Date()
        let items = (0..<4).map { index in
            ClipItem(
                content: .text("Permanent \(index)", isRTF: false),
                createdAt: now.addingTimeInterval(TimeInterval(index - 4)),
                isFavorite: index.isMultiple(of: 2),
                isPinned: !index.isMultiple(of: 2)
            )
        }
        storageService.save(items)

        let deleted = storageService.enforceMaxHistory(maxItems: 2)
        let remainingIDs = Set(storageService.fetchAll().map(\.id))

        XCTAssertEqual(deleted, 2)
        XCTAssertEqual(storageService.count(), 2)
        XCTAssertEqual(remainingIDs, Set(items.suffix(2).map(\.id)))
    }

    func testDeleteItemsOlderThanPreservesFavoriteAndPinnedItems() {
        let oldDate = Date().addingTimeInterval(-60 * 24 * 60 * 60)
        let ordinary = ClipItem(content: .text("Ordinary", isRTF: false), createdAt: oldDate)
        let favorite = ClipItem(content: .text("Favorite", isRTF: false), createdAt: oldDate, isFavorite: true)
        let pinned = ClipItem(content: .text("Pinned", isRTF: false), createdAt: oldDate, isPinned: true)
        let recent = ClipItem(content: .text("Recent", isRTF: false))
        storageService.save([ordinary, favorite, pinned, recent])

        let deleted = storageService.deleteItemsOlderThan(days: 30, keepPermanent: true)
        let remainingIDs = Set(storageService.fetchAll().map(\.id))

        XCTAssertEqual(deleted, 1)
        XCTAssertEqual(remainingIDs, Set([favorite.id, pinned.id, recent.id]))
    }

    func testDeleteItemsOlderThanForeverDeletesNothing() {
        let oldItem = ClipItem(
            content: .text("Old", isRTF: false),
            createdAt: Date().addingTimeInterval(-365 * 24 * 60 * 60)
        )
        storageService.save(oldItem)

        let deleted = storageService.deleteItemsOlderThan(days: -1, keepPermanent: true)

        XCTAssertEqual(deleted, 0)
        XCTAssertEqual(storageService.count(), 1)
    }

    // MARK: - Statistics Tests

    func testGetStatistics() {
        // Create diverse items
        storageService.save(ClipItem(content: .text("Text", isRTF: false)))
        storageService.save(ClipItem(content: .file(URL(fileURLWithPath: "/Users/test/file.txt"))))

        var favorite = ClipItem(content: .text("Favorite", isRTF: false))
        favorite.isFavorite = true
        storageService.save(favorite)

        let stats = storageService.getStatistics()

        XCTAssertEqual(stats.totalItems, 3)
        XCTAssertEqual(stats.favoriteItems, 1)
        XCTAssertEqual(stats.textItems, 2)
        XCTAssertEqual(stats.fileItems, 1)
    }
}
