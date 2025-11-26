//
//  AccessibilityPermissionGuide.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import AppKit
import ApplicationServices
import SwiftUI

/// Manages accessibility permission guidance
@MainActor
class AccessibilityPermissionGuide {

    // MARK: - Singleton

    static let shared = AccessibilityPermissionGuide()

    // MARK: - Properties

    /// Check if accessibility permission is granted
    var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Permission guide window
    private var permissionWindow: NSWindow?

    // MARK: - Public Methods

    /// Show permission guide if needed (returns true if guide was shown)
    @discardableResult
    func showGuideIfNeeded() -> Bool {
        // Don't show if permission already granted
        guard !hasPermission else { return false }

        showGuide()
        return true
    }

    /// Show permission guide window
    func showGuide() {
        // If window already exists, just bring it to front
        if let window = permissionWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create new permission guide window
        let view = PermissionGuideView(onClose: { [weak self] in
            self?.permissionWindow = nil
        })
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "辅助功能权限"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 500, height: 480))
        window.center()
        window.isReleasedWhenClosed = false

        permissionWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("🔒 AccessibilityPermissionGuide: 显示权限引导窗口")
    }
}
