//
//  ClipItemTests.swift
//  PasteDeckTests
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import XCTest
@testable import PasteDeck

final class ClipItemTests: XCTestCase {
    func testClipItemCreation() {
        let content = ClipContent.text("Hello, World!", isRTF: false)
        let item = ClipItem(content: content, sourceApp: "TextEdit")

        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.sourceApp, "TextEdit")
        XCTAssertFalse(item.isFavorite)
        XCTAssertFalse(item.isPinned)
        XCTAssertEqual(item.useCount, 0)
    }

    func testMarkAsUsed() {
        var item = ClipItem(
            content: .text("Test", isRTF: false),
            sourceApp: "TestApp"
        )

        XCTAssertEqual(item.useCount, 0)
        XCTAssertNil(item.lastUsedAt)

        item.markAsUsed()

        XCTAssertEqual(item.useCount, 1)
        XCTAssertNotNil(item.lastUsedAt)
    }

    func testToggleFavorite() {
        var item = ClipItem(
            content: .text("Test", isRTF: false),
            sourceApp: "TestApp"
        )

        XCTAssertFalse(item.isFavorite)

        item.toggleFavorite()
        XCTAssertTrue(item.isFavorite)

        item.toggleFavorite()
        XCTAssertFalse(item.isFavorite)
    }

    func testTogglePin() {
        var item = ClipItem(
            content: .text("Test", isRTF: false),
            sourceApp: "TestApp"
        )

        XCTAssertFalse(item.isPinned)

        item.togglePinned()
        XCTAssertTrue(item.isPinned)

        item.togglePinned()
        XCTAssertFalse(item.isPinned)
    }

    func testAddTag() {
        var item = ClipItem(
            content: .text("Test", isRTF: false),
            sourceApp: "TestApp"
        )

        XCTAssertEqual(item.tags.count, 0)

        item.addTag("important")
        XCTAssertEqual(item.tags.count, 1)
        XCTAssertTrue(item.tags.contains("important"))

        // Adding duplicate shouldn't increase count
        item.addTag("important")
        XCTAssertEqual(item.tags.count, 1)

        // Case insensitive
        item.addTag("IMPORTANT")
        XCTAssertEqual(item.tags.count, 1)
    }

    func testRemoveTag() {
        var item = ClipItem(
            content: .text("Test", isRTF: false),
            sourceApp: "TestApp"
        )

        item.addTag("tag1")
        item.addTag("tag2")
        XCTAssertEqual(item.tags.count, 2)

        item.removeTag("tag1")
        XCTAssertEqual(item.tags.count, 1)
        XCTAssertFalse(item.tags.contains("tag1"))
        XCTAssertTrue(item.tags.contains("tag2"))
    }

    func testSearchMatches() {
        let item = ClipItem(
            content: .text("Hello, World!", isRTF: false),
            sourceApp: "TextEdit"
        )

        XCTAssertTrue(item.matches(query: "hello"))
        XCTAssertTrue(item.matches(query: "world"))
        XCTAssertTrue(item.matches(query: "Hello"))
        XCTAssertFalse(item.matches(query: "goodbye"))
    }

    func testIsPermanent() {
        var item = ClipItem(
            content: .text("Test", isRTF: false),
            sourceApp: "TestApp"
        )

        XCTAssertFalse(item.isPermanent)

        item.isFavorite = true
        XCTAssertTrue(item.isPermanent)

        item.isFavorite = false
        item.isPinned = true
        XCTAssertTrue(item.isPermanent)
    }

    func testEquality() {
        let id = UUID()
        let item1 = ClipItem(
            id: id,
            content: .text("Test", isRTF: false),
            sourceApp: "TestApp"
        )
        let item2 = ClipItem(
            id: id,
            content: .text("Different", isRTF: false),
            sourceApp: "OtherApp"
        )

        XCTAssertEqual(item1, item2) // Same ID means equal
    }

    func testHashable() {
        let id = UUID()
        let item1 = ClipItem(
            id: id,
            content: .text("Test", isRTF: false),
            sourceApp: "TestApp"
        )
        let item2 = ClipItem(
            id: id,
            content: .text("Different", isRTF: false),
            sourceApp: "OtherApp"
        )

        var set = Set<ClipItem>()
        set.insert(item1)
        set.insert(item2)

        XCTAssertEqual(set.count, 1) // Same ID, so only one item in set
    }

    func testComparable() {
        let pinnedItem = ClipItem(
            content: .text("Pinned", isRTF: false),
            isPinned: true
        )
        let favoriteItem = ClipItem(
            content: .text("Favorite", isRTF: false),
            isFavorite: true
        )
        let normalItem = ClipItem(
            content: .text("Normal", isRTF: false)
        )

        // Pinned should come before favorite
        XCTAssertTrue(pinnedItem < favoriteItem)

        // Favorite should come before normal
        XCTAssertTrue(favoriteItem < normalItem)

        // Pinned should come before normal
        XCTAssertTrue(pinnedItem < normalItem)
    }
}
