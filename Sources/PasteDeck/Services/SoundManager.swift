//
//  SoundManager.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import AppKit
import Foundation

/// Types of clipboard actions that can trigger sounds
enum ClipboardAction {
    case captured  // New clipboard content captured
    case deleted   // Item(s) deleted
    case cleared   // History cleared
}

/// Manages sound effects for clipboard operations
@MainActor
class SoundManager {
    // MARK: - Singleton

    static let shared = SoundManager()

    // MARK: - Properties

    private var lastPlayTime: Date?
    private let debounceInterval: TimeInterval = 0.5

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Play sound for a clipboard action
    /// - Parameter action: The type of clipboard action
    func playSound(for action: ClipboardAction) {
        // Check if sound is enabled in settings
        guard UserDefaults.standard.bool(forKey: "soundEnabled") else {
            return
        }

        // Debounce: Prevent playing sounds too frequently
        if let lastTime = lastPlayTime,
           Date().timeIntervalSince(lastTime) < debounceInterval {
            return
        }

        // Select and play appropriate sound
        switch action {
        case .captured:
            // Distinctive funky sound for clipboard capture
            NSSound(named: "Funk")?.play()

        case .deleted:
            // Bottle sound for deletion
            NSSound(named: "Bottle")?.play()

        case .cleared:
            // Submarine sound for clearing action
            NSSound(named: "Submarine")?.play()
        }

        // Update last play time
        lastPlayTime = Date()
    }
}
