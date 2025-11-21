//
//  ClipboardMonitor.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import Foundation
import AppKit
import Combine

/// Service responsible for monitoring the system clipboard and detecting changes
@MainActor
class ClipboardMonitor: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var isMonitoring = false
    @Published private(set) var lastCapturedItem: ClipItem?

    // MARK: - Private Properties

    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard: NSPasteboard
    private var excludedBundleIdentifiers: Set<String>
    private let pollingInterval: TimeInterval

    /// Publisher for new clipboard items
    private let clipboardItemSubject = PassthroughSubject<ClipItem, Never>()

    /// Public publisher for new clipboard items
    var clipboardItemPublisher: AnyPublisher<ClipItem, Never> {
        clipboardItemSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init(
        pasteboard: NSPasteboard = .general,
        pollingInterval: TimeInterval = 0.5,
        excludedApps: Set<String>? = nil
    ) {
        self.pasteboard = pasteboard
        self.pollingInterval = pollingInterval
        self.lastChangeCount = pasteboard.changeCount
        self.excludedBundleIdentifiers = excludedApps ?? Self.defaultExcludedApps
    }

    // MARK: - Public Methods

    /// Start monitoring the clipboard
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        lastChangeCount = pasteboard.changeCount

        timer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }

        // Add timer to common run loop modes to ensure it fires during modal windows
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }

        print("📋 ClipboardMonitor: Started monitoring")
    }

    /// Stop monitoring the clipboard
    func stopMonitoring() {
        guard isMonitoring else { return }

        timer?.invalidate()
        timer = nil
        isMonitoring = false

        print("📋 ClipboardMonitor: Stopped monitoring")
    }

    /// Update the list of excluded apps
    func updateExcludedApps(_ bundleIdentifiers: Set<String>) {
        self.excludedBundleIdentifiers = bundleIdentifiers
        print("📋 ClipboardMonitor: Updated excluded apps: \(bundleIdentifiers.count) apps")
    }

    /// Add an app to the exclusion list
    func addExcludedApp(_ bundleIdentifier: String) {
        excludedBundleIdentifiers.insert(bundleIdentifier)
    }

    /// Remove an app from the exclusion list
    func removeExcludedApp(_ bundleIdentifier: String) {
        excludedBundleIdentifiers.remove(bundleIdentifier)
    }

    // MARK: - Private Methods

    private func checkClipboard() {
        let currentChangeCount = pasteboard.changeCount

        // No change detected
        guard currentChangeCount != lastChangeCount else {
            return
        }

        lastChangeCount = currentChangeCount

        // Check if we should ignore this based on active app
        if shouldIgnoreCurrentApp() {
            print("📋 ClipboardMonitor: Ignoring clipboard from excluded app")
            return
        }

        // Capture the clipboard content
        captureClipboard()
    }

    private func captureClipboard() {
        // Get content from pasteboard
        guard let content = ClipContent.from(pasteboard: pasteboard) else {
            print("📋 ClipboardMonitor: Unable to capture clipboard content")
            return
        }

        // Get source app info
        let sourceApp = getActiveApplicationName()

        // Create clip item
        let clipItem = ClipItem(
            content: content,
            sourceApp: sourceApp
        )

        // Publish the new item
        clipboardItemSubject.send(clipItem)
        lastCapturedItem = clipItem

        print("📋 ClipboardMonitor: Captured \(content.typeName) from \(sourceApp ?? "unknown")")
    }

    private func shouldIgnoreCurrentApp() -> Bool {
        guard let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }

        return excludedBundleIdentifiers.contains(bundleIdentifier)
    }

    private func getActiveApplicationName() -> String? {
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }

    // MARK: - Default Excluded Apps

    /// Default list of apps to exclude from clipboard monitoring
    static let defaultExcludedApps: Set<String> = [
        // Password Managers
        "com.agilebits.onepassword7",           // 1Password 7
        "com.agilebits.onepassword-osx",        // 1Password
        "com.lastpass.LastPass",                // LastPass
        "com.dashlane.Dashlane",                // Dashlane
        "app.keeper.KeeperDesktop",             // Keeper
        "com.bitwarden.desktop",                // Bitwarden

        // System
        "com.apple.keychainaccess",             // Keychain Access
        "com.apple.Authentication",             // Authentication prompts

        // Crypto Wallets
        "com.coinbase.wallet",                  // Coinbase Wallet
        "io.metamask.MetaMask",                 // MetaMask

        // Banking
        // Add common banking apps if needed
    ]
}

// MARK: - Application Info Extension

extension ClipboardMonitor {
    /// Get detailed information about the frontmost application
    struct ApplicationInfo {
        let name: String
        let bundleIdentifier: String
        let isExcluded: Bool
        let icon: NSImage?

        init(app: NSRunningApplication, isExcluded: Bool) {
            self.name = app.localizedName ?? "Unknown"
            self.bundleIdentifier = app.bundleIdentifier ?? ""
            self.isExcluded = isExcluded
            self.icon = app.icon
        }
    }

    /// Get information about the currently active application
    func getCurrentApplicationInfo() -> ApplicationInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else {
            return nil
        }

        return ApplicationInfo(
            app: app,
            isExcluded: excludedBundleIdentifiers.contains(bundleID)
        )
    }

    /// Get list of all running applications
    func getRunningApplications() -> [ApplicationInfo] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier else { return nil }
                return ApplicationInfo(
                    app: app,
                    isExcluded: excludedBundleIdentifiers.contains(bundleID)
                )
            }
            .sorted { $0.name < $1.name }
    }
}

// MARK: - Statistics

extension ClipboardMonitor {
    /// Statistics about clipboard monitoring
    struct Statistics {
        var totalCaptured: Int = 0
        var ignoredCount: Int = 0
        var lastCaptureTime: Date?
        var monitoringStartTime: Date?

        var uptimeSeconds: TimeInterval? {
            guard let startTime = monitoringStartTime else { return nil }
            return Date().timeIntervalSince(startTime)
        }

        var captureRate: Double? {
            guard let uptime = uptimeSeconds, uptime > 0 else { return nil }
            return Double(totalCaptured) / uptime
        }
    }

    /// Get monitoring statistics (if tracking is enabled)
    var statistics: Statistics {
        // This could be expanded with actual tracking
        Statistics(
            totalCaptured: 0,
            ignoredCount: 0,
            lastCaptureTime: lastCapturedItem?.createdAt
        )
    }
}

// MARK: - Debug Support

#if DEBUG
extension ClipboardMonitor {
    /// Simulate a clipboard change for testing
    func simulateClipboardChange(content: ClipContent) {
        let clipItem = ClipItem(
            content: content,
            sourceApp: "Simulator"
        )
        clipboardItemSubject.send(clipItem)
        lastCapturedItem = clipItem
    }

    /// Force a clipboard check (for testing)
    func forceCheck() {
        lastChangeCount = pasteboard.changeCount - 1
        checkClipboard()
    }
}
#endif
