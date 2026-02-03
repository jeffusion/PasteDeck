//
//  ScreenSelection.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors.
//

import CoreGraphics

enum ScreenSelection {
    static func preferredScreenIndex(
        frontmostAppScreenIndex: Int?,
        keyWindowScreenIndex: Int?,
        mouseScreenIndex: Int?,
        mainScreenIndex: Int?
    ) -> Int? {
        if let frontmostAppScreenIndex {
            return frontmostAppScreenIndex
        }
        if let keyWindowScreenIndex {
            return keyWindowScreenIndex
        }
        if let mouseScreenIndex {
            return mouseScreenIndex
        }
        return mainScreenIndex
    }

    static func screenIndexForWindowBounds(_ bounds: CGRect, in screenFrames: [CGRect]) -> Int? {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if let index = screenFrames.firstIndex(where: { $0.contains(center) }) {
            return index
        }
        if let index = screenFrames.firstIndex(where: { $0.intersects(bounds) }) {
            return index
        }
        return nil
    }
}
