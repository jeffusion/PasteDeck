//
//  ScreenSelectionTests.swift
//  PasteDeckTests
//
//  Created by PasteDeck Contributors.
//

import XCTest
@testable import PasteDeck

final class ScreenSelectionTests: XCTestCase {
    func testPreferredScreenIndexPrefersFrontmostApp() {
        let result = ScreenSelection.preferredScreenIndex(
            frontmostAppScreenIndex: 1,
            keyWindowScreenIndex: 0,
            mouseScreenIndex: 2,
            mainScreenIndex: 0
        )

        XCTAssertEqual(result, 1)
    }

    func testPreferredScreenIndexFallsBackToKeyWindow() {
        let result = ScreenSelection.preferredScreenIndex(
            frontmostAppScreenIndex: nil,
            keyWindowScreenIndex: 2,
            mouseScreenIndex: 1,
            mainScreenIndex: 0
        )

        XCTAssertEqual(result, 2)
    }

    func testPreferredScreenIndexFallsBackToMouse() {
        let result = ScreenSelection.preferredScreenIndex(
            frontmostAppScreenIndex: nil,
            keyWindowScreenIndex: nil,
            mouseScreenIndex: 1,
            mainScreenIndex: 0
        )

        XCTAssertEqual(result, 1)
    }

    func testPreferredScreenIndexFallsBackToMain() {
        let result = ScreenSelection.preferredScreenIndex(
            frontmostAppScreenIndex: nil,
            keyWindowScreenIndex: nil,
            mouseScreenIndex: nil,
            mainScreenIndex: 0
        )

        XCTAssertEqual(result, 0)
    }

    func testScreenIndexForWindowBoundsUsesCenter() {
        let screens = [
            CGRect(x: 0, y: 0, width: 100, height: 100),
            CGRect(x: 100, y: 0, width: 100, height: 100)
        ]
        let windowBounds = CGRect(x: 120, y: 10, width: 20, height: 20)

        let index = ScreenSelection.screenIndexForWindowBounds(windowBounds, in: screens)

        XCTAssertEqual(index, 1)
    }

    func testScreenIndexForWindowBoundsFallsBackToIntersection() {
        let screens = [
            CGRect(x: 0, y: 0, width: 100, height: 100),
            CGRect(x: 200, y: 0, width: 100, height: 100)
        ]
        let windowBounds = CGRect(x: 90, y: 10, width: 120, height: 20)

        let index = ScreenSelection.screenIndexForWindowBounds(windowBounds, in: screens)

        XCTAssertEqual(index, 0)
    }
}
