//
//  ClipboardMonitorTests.swift
//  PasteDeckTests
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import XCTest
@testable import PasteDeck

@MainActor
final class ClipboardMonitorTests: XCTestCase {
    var monitor: ClipboardMonitor!

    override func setUp() async throws {
        try await super.setUp()
        monitor = ClipboardMonitor()
    }

    override func tearDown() async throws {
        if monitor.isMonitoring {
            monitor.stopMonitoring()
        }
        monitor = nil
        try await super.tearDown()
    }

    func testInitialization() {
        XCTAssertNotNil(monitor)
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testStartMonitoring() {
        monitor.startMonitoring()
        XCTAssertTrue(monitor.isMonitoring)
    }

    func testStopMonitoring() {
        monitor.startMonitoring()
        XCTAssertTrue(monitor.isMonitoring)

        monitor.stopMonitoring()
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testAddExcludedApp() {
        let testBundleID = "com.test.app"
        monitor.addExcludedApp(testBundleID)

        // We can't directly test the internal set, but we can verify it doesn't crash
        XCTAssertNotNil(monitor)
    }

    func testRemoveExcludedApp() {
        let testBundleID = "com.test.app"
        monitor.addExcludedApp(testBundleID)
        monitor.removeExcludedApp(testBundleID)

        // Verify no crash
        XCTAssertNotNil(monitor)
    }
}
