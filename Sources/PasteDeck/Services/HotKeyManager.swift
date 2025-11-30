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

// MARK: - Quick Paste Modifiers Configuration

struct QuickPasteModifiers: Codable, Equatable {
    var command: Bool
    var control: Bool
    var option: Bool
    var shift: Bool

    static let `default` = QuickPasteModifiers(command: true, control: false, option: false, shift: true)

    var eventFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if command { flags.insert(.command) }
        if control { flags.insert(.control) }
        if option { flags.insert(.option) }
        if shift { flags.insert(.shift) }
        return flags
    }

    var displayString: String {
        var result = ""
        if control { result += "⌃" }
        if option { result += "⌥" }
        if shift { result += "⇧" }
        if command { result += "⌘" }
        return result
    }

    var isValid: Bool {
        command || control || option || shift
    }
}

// MARK: - Shortcut Name Definitions

extension KeyboardShortcuts.Name {
    /// Show/hide the PasteDeck clipboard window
    static let showClipboard = Self("showClipboard", default: .init(.v, modifiers: [.command, .shift]))

    /// Clear clipboard history
    static let clearHistory = Self("clearHistory", default: .init(.delete, modifiers: [.command, .shift]))
}

// MARK: - HotKeyManager

/// Manager for global keyboard shortcuts
class HotKeyManager: ObservableObject {
    // MARK: - Singleton

    static let shared = HotKeyManager()

    // MARK: - Properties

    /// Callback when show clipboard shortcut is triggered
    var onShowClipboard: (() -> Void)?

    /// Callback when clear history shortcut is triggered
    var onClearHistory: (() -> Void)?

    /// Callback when quick paste shortcut is triggered (position 1-9)
    var onQuickPaste: ((Int) -> Void)?

    /// Whether accessibility permissions are granted
    @Published private(set) var hasAccessibilityPermission: Bool = false

    /// Quick paste modifiers configuration
    @Published var quickPasteModifiers: QuickPasteModifiers {
        didSet {
            saveQuickPasteModifiers()
            setupQuickPasteMonitor()
        }
    }

    /// Global event monitor for quick paste
    private var quickPasteMonitor: Any?

    // MARK: - Initialization

    private init() {
        self.quickPasteModifiers = Self.loadQuickPasteModifiers()
        setupShortcuts()
        setupQuickPasteMonitor()
        checkAccessibilityPermission()
    }

    deinit {
        if let monitor = quickPasteMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Setup

    private func setupShortcuts() {
        // Show clipboard window - use onKeyDown for instant response
        KeyboardShortcuts.onKeyDown(for: .showClipboard) { [weak self] in
            self?.onShowClipboard?()
        }

        // Clear history - use onKeyDown for instant response
        KeyboardShortcuts.onKeyDown(for: .clearHistory) { [weak self] in
            self?.onClearHistory?()
        }

        print("⌨️ HotKeyManager: Basic shortcuts registered")
    }

    private func setupQuickPasteMonitor() {
        // Remove existing monitor
        if let monitor = quickPasteMonitor {
            NSEvent.removeMonitor(monitor)
            quickPasteMonitor = nil
        }

        // Setup new monitor with current modifiers
        let modifiers = quickPasteModifiers
        quickPasteMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }

            // Check if modifiers match
            let eventModifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard eventModifiers == modifiers.eventFlags else { return }

            // Map key codes to positions (1-9)
            let position: Int?
            switch event.keyCode {
            case 18: position = 1  // 1
            case 19: position = 2  // 2
            case 20: position = 3  // 3
            case 21: position = 4  // 4
            case 23: position = 5  // 5
            case 22: position = 6  // 6
            case 26: position = 7  // 7
            case 28: position = 8  // 8
            case 25: position = 9  // 9
            default: position = nil
            }

            if let position = position {
                self.onQuickPaste?(position)
            }
        }

        print("⌨️ HotKeyManager: Quick paste monitor setup with modifiers: \(modifiers.displayString)")
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
        quickPasteModifiers = .default
        print("⌨️ HotKeyManager: Reset to defaults")
    }

    /// Enable or disable all shortcuts
    func setEnabled(_ enabled: Bool) {
        if enabled {
            KeyboardShortcuts.enable(.showClipboard)
            KeyboardShortcuts.enable(.clearHistory)
            setupQuickPasteMonitor()
        } else {
            KeyboardShortcuts.disable(.showClipboard)
            KeyboardShortcuts.disable(.clearHistory)
            if let monitor = quickPasteMonitor {
                NSEvent.removeMonitor(monitor)
                quickPasteMonitor = nil
            }
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
            "Quick Paste": "\(quickPasteModifiers.displayString) + 1...9"
        ]
    }

    // MARK: - Quick Paste Configuration Persistence

    private static let quickPasteModifiersKey = "quickPasteModifiers"

    private static func loadQuickPasteModifiers() -> QuickPasteModifiers {
        guard let data = UserDefaults.standard.data(forKey: quickPasteModifiersKey),
              let modifiers = try? JSONDecoder().decode(QuickPasteModifiers.self, from: data) else {
            return .default
        }
        return modifiers
    }

    private func saveQuickPasteModifiers() {
        guard let data = try? JSONEncoder().encode(quickPasteModifiers) else { return }
        UserDefaults.standard.set(data, forKey: Self.quickPasteModifiersKey)
    }
}
