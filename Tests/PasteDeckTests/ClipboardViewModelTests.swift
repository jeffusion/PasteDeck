//
//  ClipboardViewModelTests.swift
//  PasteDeckTests
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import XCTest
import Combine
@testable import PasteDeck

@MainActor
final class ClipboardViewModelTests: XCTestCase {
    var viewModel: ClipboardViewModel!
    var monitor: ClipboardMonitor!
    var storageService: StorageService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        monitor = ClipboardMonitor()
        // Use in-memory storage for test isolation
        let persistenceController = PersistenceController(inMemory: true)
        storageService = StorageService(persistenceController: persistenceController)
        viewModel = ClipboardViewModel(monitor: monitor, storageService: storageService, maxHistorySize: 10)
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        cancellables.removeAll()
        viewModel = nil
        storageService = nil
        monitor.stopMonitoring()
        monitor = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(viewModel)
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertTrue(viewModel.filteredItems.isEmpty)
        XCTAssertEqual(viewModel.searchText, "")
    }

    func testInitializationEnforcesMaxHistory() {
        let now = Date()
        let favorite = ClipItem(content: .text("Favorite", isRTF: false), createdAt: now.addingTimeInterval(-40), isFavorite: true)
        let oldestOrdinary = ClipItem(content: .text("Oldest", isRTF: false), createdAt: now.addingTimeInterval(-30))
        let middleOrdinary = ClipItem(content: .text("Middle", isRTF: false), createdAt: now.addingTimeInterval(-20))
        let newestOrdinary = ClipItem(content: .text("Newest", isRTF: false), createdAt: now.addingTimeInterval(-10))
        storageService.save([favorite, oldestOrdinary, middleOrdinary, newestOrdinary])

        viewModel = ClipboardViewModel(monitor: monitor, storageService: storageService, maxHistorySize: 3)
        let itemIDs = Set(viewModel.items.map(\.id))

        XCTAssertEqual(storageService.count(), 3)
        XCTAssertEqual(itemIDs, Set([favorite.id, middleOrdinary.id, newestOrdinary.id]))
    }

    func testSaveItemsKeepsViewModelAndStorageSynchronizedAfterCapDeletion() {
        let now = Date()
        let favorite = ClipItem(content: .text("Favorite", isRTF: false), createdAt: now.addingTimeInterval(-40), isFavorite: true)
        let oldestOrdinary = ClipItem(content: .text("Oldest", isRTF: false), createdAt: now.addingTimeInterval(-30))
        let middleOrdinary = ClipItem(content: .text("Middle", isRTF: false), createdAt: now.addingTimeInterval(-20))
        let newestOrdinary = ClipItem(content: .text("Newest", isRTF: false), createdAt: now.addingTimeInterval(-10))
        viewModel = ClipboardViewModel(monitor: monitor, storageService: storageService, maxHistorySize: 3)
        viewModel.items = [favorite, oldestOrdinary, middleOrdinary, newestOrdinary]

        viewModel.addTag("saved", to: newestOrdinary)

        let viewModelIDs = Set(viewModel.items.map(\.id))
        let storedIDs = Set(storageService.fetchAll().map(\.id))
        XCTAssertEqual(viewModel.items.count, 3)
        XCTAssertEqual(viewModelIDs, storedIDs)
        XCTAssertEqual(viewModelIDs, Set([favorite.id, middleOrdinary.id, newestOrdinary.id]))
    }

    // MARK: - Copy Operations Tests

    func testCopyItem() {
        // Add an item
        let item = ClipItem(content: .text("Test copy", isRTF: false))
        viewModel.items.append(item)

        // Copy it
        viewModel.copyItem(item)

        // Check use count increased
        let updatedItem = viewModel.items.first { $0.id == item.id }
        XCTAssertEqual(updatedItem?.useCount, 1)
    }

    // MARK: - Favorite Tests

    func testToggleFavorite() {
        var item = ClipItem(content: .text("Test favorite", isRTF: false))
        item.isFavorite = false
        viewModel.items.append(item)

        XCTAssertFalse(viewModel.items[0].isFavorite)

        viewModel.toggleFavorite(item)

        XCTAssertTrue(viewModel.items[0].isFavorite)
    }

    // MARK: - Pin Tests

    func testTogglePin() {
        var item = ClipItem(content: .text("Test pin", isRTF: false))
        item.isPinned = false
        viewModel.items.append(item)

        XCTAssertFalse(viewModel.items[0].isPinned)

        viewModel.togglePin(item)

        XCTAssertTrue(viewModel.items[0].isPinned)
    }

    // MARK: - Delete Tests

    func testDeleteItem() {
        let item = ClipItem(content: .text("To delete", isRTF: false))
        viewModel.items.append(item)

        XCTAssertEqual(viewModel.items.count, 1)

        viewModel.deleteItem(item)

        XCTAssertEqual(viewModel.items.count, 0)
    }

    func testDeleteMultipleItems() {
        let items = [
            ClipItem(content: .text("Item 1", isRTF: false)),
            ClipItem(content: .text("Item 2", isRTF: false)),
            ClipItem(content: .text("Item 3", isRTF: false))
        ]
        viewModel.items = items

        viewModel.deleteItems([items[0], items[2]])

        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items[0].id, items[1].id)
    }

    func testClearHistory() {
        var favoriteItem = ClipItem(content: .text("Favorite", isRTF: false))
        favoriteItem.isFavorite = true

        let normalItem = ClipItem(content: .text("Normal", isRTF: false))

        viewModel.items = [favoriteItem, normalItem]

        viewModel.clearHistory()

        // Should keep favorite
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertTrue(viewModel.items[0].isFavorite)
    }

    func testClearAll() {
        var favoriteItem = ClipItem(content: .text("Favorite", isRTF: false))
        favoriteItem.isFavorite = true

        let normalItem = ClipItem(content: .text("Normal", isRTF: false))

        viewModel.items = [favoriteItem, normalItem]

        viewModel.clearAll()

        XCTAssertEqual(viewModel.items.count, 0)
    }

    // MARK: - Tag Tests

    func testAddTag() {
        let item = ClipItem(content: .text("Test tag", isRTF: false))
        viewModel.items.append(item)

        viewModel.addTag("important", to: item)

        XCTAssertTrue(viewModel.items[0].tags.contains("important"))
    }

    func testRemoveTag() {
        var item = ClipItem(content: .text("Test tag", isRTF: false))
        item.tags = ["tag1", "tag2"]
        viewModel.items.append(item)

        viewModel.removeTag("tag1", from: item)

        XCTAssertFalse(viewModel.items[0].tags.contains("tag1"))
        XCTAssertTrue(viewModel.items[0].tags.contains("tag2"))
    }

    // MARK: - Computed Properties Tests

    func testFavoriteItems() {
        var favoriteItem = ClipItem(content: .text("Favorite", isRTF: false))
        favoriteItem.isFavorite = true

        let normalItem = ClipItem(content: .text("Normal", isRTF: false))

        viewModel.items = [favoriteItem, normalItem]

        XCTAssertEqual(viewModel.favoriteItems.count, 1)
        XCTAssertTrue(viewModel.favoriteItems[0].isFavorite)
    }

    func testPinnedItems() {
        var pinnedItem = ClipItem(content: .text("Pinned", isRTF: false))
        pinnedItem.isPinned = true

        let normalItem = ClipItem(content: .text("Normal", isRTF: false))

        viewModel.items = [pinnedItem, normalItem]

        XCTAssertEqual(viewModel.pinnedItems.count, 1)
        XCTAssertTrue(viewModel.pinnedItems[0].isPinned)
    }

    func testStatistics() {
        var favoriteItem = ClipItem(content: .text("Favorite", isRTF: false))
        favoriteItem.isFavorite = true

        var pinnedItem = ClipItem(content: .text("Pinned", isRTF: false))
        pinnedItem.isPinned = true

        let normalItem = ClipItem(content: .text("Normal", isRTF: false))

        viewModel.items = [favoriteItem, pinnedItem, normalItem]

        let stats = viewModel.statistics

        XCTAssertEqual(stats.totalItems, 3)
        XCTAssertEqual(stats.favoriteItems, 1)
        XCTAssertEqual(stats.pinnedItems, 1)
    }

    // MARK: - Filter Tests

    func testContentFilter() {
        let textItem = ClipItem(content: .text("Text", isRTF: false))
        let fileItem = ClipItem(content: .file(URL(fileURLWithPath: "/Users/test/file.txt")))

        viewModel.items = [textItem, fileItem]
        viewModel.contentFilter = .text

        // Give time for debounce
        let expectation = expectation(description: "Filter applied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(viewModel.filteredItems.count, 1)
    }
}
