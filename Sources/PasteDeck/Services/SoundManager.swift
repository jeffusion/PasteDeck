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

protocol SoundPlayback: AnyObject {
    var currentTime: TimeInterval { get set }
    var isPlaying: Bool { get }

    @discardableResult
    func play() -> Bool

    @discardableResult
    func stop() -> Bool
}

extension NSSound: SoundPlayback {}

/// Manages sound effects for clipboard operations
@MainActor
class SoundManager {
    // MARK: - Singleton

    static let shared = SoundManager()

    // MARK: - Properties

    private let sounds: [ClipboardAction: any SoundPlayback]
    private let isSoundEnabled: () -> Bool

    // MARK: - Initialization

    private convenience init() {
        self.init(
            sounds: [
                .captured: NSSound(named: "Funk"),
                .deleted: NSSound(named: "Bottle"),
                .cleared: NSSound(named: "Submarine")
            ].compactMapValues { $0 },
            isSoundEnabled: {
                UserDefaults.standard.bool(forKey: "soundEnabled")
            }
        )
    }

    init(
        sounds: [ClipboardAction: any SoundPlayback],
        isSoundEnabled: @escaping () -> Bool
    ) {
        self.sounds = sounds
        self.isSoundEnabled = isSoundEnabled
    }

    // MARK: - Public Methods

    /// Play sound for a clipboard action
    /// - Parameter action: The type of clipboard action
    func playSound(for action: ClipboardAction) {
        guard isSoundEnabled(), let sound = sounds[action] else {
            return
        }

        if sound.isPlaying {
            sound.stop()
        }
        sound.currentTime = 0
        sound.play()
    }
}
