//
//  HotKeyManager.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import Foundation
import KeyboardShortcuts
import AppKit

// MARK: - Shortcut Name Definitions

extension KeyboardShortcuts.Name {
    /// Show/hide the PasteDeck clipboard window
    static let showClipboard = Self("showClipboard", default: .init(.v, modifiers: [.command, .shift]))

    /// Clear clipboard history
    static let clearHistory = Self("clearHistory")

    /// Search in clipboard
    static let searchClipboard = Self("searchClipboard")
}

// MARK: - HotKeyManager

/// Manager for global keyboard shortcuts
class HotKeyManager: ObservableObject {
    // MARK: - Properties

    /// Callback when show clipboard shortcut is triggered
    var onShowClipboard: (() -> Void)?

    /// Callback when clear history shortcut is triggered
    var onClearHistory: (() -> Void)?

    /// Callback when search shortcut is triggered
    var onSearchClipboard: (() -> Void)?

    /// Whether accessibility permissions are granted
    @Published private(set) var hasAccessibilityPermission: Bool = false

    // MARK: - Initialization

    init() {
        setupShortcuts()
        checkAccessibilityPermission()
    }

    // MARK: - Setup

    private func setupShortcuts() {
        // Show clipboard window
        KeyboardShortcuts.onKeyUp(for: .showClipboard) { [weak self] in
            self?.onShowClipboard?()
        }

        // Clear history
        KeyboardShortcuts.onKeyUp(for: .clearHistory) { [weak self] in
            self?.onClearHistory?()
        }

        // Search clipboard
        KeyboardShortcuts.onKeyUp(for: .searchClipboard) { [weak self] in
            self?.onSearchClipboard?()
        }

        print("⌨️ HotKeyManager: Shortcuts registered")
    }

    // MARK: - Shortcut Management

    /// Get the current shortcut for showing clipboard
    func getShowClipboardShortcut() -> KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: .showClipboard)
    }

    /// Reset all shortcuts to defaults
    func resetToDefaults() {
        KeyboardShortcuts.reset(.showClipboard)
        KeyboardShortcuts.reset(.clearHistory)
        KeyboardShortcuts.reset(.searchClipboard)
        print("⌨️ HotKeyManager: Reset to defaults")
    }

    /// Enable or disable all shortcuts
    func setEnabled(_ enabled: Bool) {
        if enabled {
            KeyboardShortcuts.enable(.showClipboard)
            KeyboardShortcuts.enable(.clearHistory)
            KeyboardShortcuts.enable(.searchClipboard)
        } else {
            KeyboardShortcuts.disable(.showClipboard)
            KeyboardShortcuts.disable(.clearHistory)
            KeyboardShortcuts.disable(.searchClipboard)
        }
        print("⌨️ HotKeyManager: Shortcuts \(enabled ? "enabled" : "disabled")")
    }

    // MARK: - Accessibility Permission

    /// Check if accessibility permission is granted
    func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        hasAccessibilityPermission = trusted

        if !trusted {
            print("⌨️ HotKeyManager: Accessibility permission not granted")
        }
    }

    /// Request accessibility permission
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("⌨️ HotKeyManager: Requested accessibility permission")

        // Check again after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }

    /// Open System Preferences to Accessibility settings
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Shortcut Description Helper

extension HotKeyManager {
    /// Get a human-readable description of a shortcut
    @MainActor
    static func shortcutDescription(for name: KeyboardShortcuts.Name) -> String {
        if let shortcut = KeyboardShortcuts.getShortcut(for: name) {
            return shortcut.description
        }
        return "Not set"
    }

    /// Get all shortcut descriptions
    @MainActor
    func allShortcutDescriptions() -> [String: String] {
        return [
            "Show Clipboard": Self.shortcutDescription(for: .showClipboard),
            "Clear History": Self.shortcutDescription(for: .clearHistory),
            "Search": Self.shortcutDescription(for: .searchClipboard)
        ]
    }
}
