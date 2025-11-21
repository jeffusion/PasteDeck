//
//  AppDelegate.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import Cocoa
import SwiftUI
import Combine
import KeyboardShortcuts

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var clipboardWindow: NSPanel!
    private var clipboardMonitor: ClipboardMonitor!
    private var clipboardViewModel: ClipboardViewModel!
    private var hotKeyManager: HotKeyManager!
    private var cancellables = Set<AnyCancellable>()
    private var isShowingWindow = false

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure app to be menu bar only
        NSApp.setActivationPolicy(.accessory)

        // Initialize services
        setupClipboardMonitor()
        setupViewModel()
        setupStatusBar()
        setupClipboardWindow()
        setupKeyboardShortcuts()

        print("🚀 PasteDeck launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stopMonitoring()
        print("👋 PasteDeck terminated")
    }

    // MARK: - Setup Methods

    private func setupClipboardMonitor() {
        clipboardMonitor = ClipboardMonitor()
        clipboardMonitor.startMonitoring()
    }

    private func setupViewModel() {
        clipboardViewModel = ClipboardViewModel(monitor: clipboardMonitor)
    }

    private func setupStatusBar() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Set icon - using SF Symbol
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            button.image = NSImage(
                systemSymbolName: "doc.on.clipboard",
                accessibilityDescription: "PasteDeck"
            )?.withSymbolConfiguration(config)

            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        setupStatusBarMenu()
    }

    private func setupStatusBarMenu() {
        let menu = NSMenu()

        // Quick actions
        menu.addItem(NSMenuItem(
            title: "Show Clipboard",
            action: #selector(showClipboardWindow),
            keyEquivalent: ""
        ))

        menu.addItem(.separator())

        // Statistics
        let statsItem = NSMenuItem(
            title: "0 items captured",
            action: nil,
            keyEquivalent: ""
        )
        statsItem.isEnabled = false
        menu.addItem(statsItem)

        menu.addItem(.separator())

        // Settings
        menu.addItem(NSMenuItem(
            title: "Settings...",
            action: #selector(showSettings),
            keyEquivalent: ","
        ))

        // About
        menu.addItem(NSMenuItem(
            title: "About PasteDeck",
            action: #selector(showAbout),
            keyEquivalent: ""
        ))

        menu.addItem(.separator())

        // Quit
        menu.addItem(NSMenuItem(
            title: "Quit PasteDeck",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        // Store reference for later updates
        statusItem.menu = menu
    }

    private func setupClipboardWindow() {
        // Create the SwiftUI content view
        let contentView = MainWindow()
            .environmentObject(clipboardViewModel)

        // Create hosting controller
        let hostingController = NSHostingController(rootView: contentView)

        // Calculate drawer size and position (bottom of screen)
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let drawerHeight: CGFloat = 220
        let windowSize = CGSize(width: screenFrame.width, height: drawerHeight)

        // Start off-screen (below visible area) for animation
        let windowOrigin = CGPoint(
            x: screenFrame.origin.x,
            y: screenFrame.origin.y - drawerHeight
        )
        let windowRect = CGRect(origin: windowOrigin, size: windowSize)

        // Create panel with borderless style for drawer appearance
        clipboardWindow = NSPanel(
            contentRect: windowRect,
            styleMask: [.borderless, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        // Configure panel for drawer behavior
        clipboardWindow.contentView = hostingController.view
        clipboardWindow.isFloatingPanel = true
        clipboardWindow.level = .popUpMenu
        clipboardWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        clipboardWindow.backgroundColor = NSColor(white: 0.15, alpha: 0.98)
        clipboardWindow.isOpaque = false
        clipboardWindow.hasShadow = true
        clipboardWindow.hidesOnDeactivate = false
        clipboardWindow.becomesKeyOnlyIfNeeded = false

        // Handle window close
        clipboardWindow.delegate = self

        // Set up close callback for ViewModel
        clipboardViewModel.onRequestClose = { [weak self] in
            self?.hideClipboardWindow()
        }
    }

    private func setupKeyboardShortcuts() {
        hotKeyManager = HotKeyManager()

        // Set up callbacks
        hotKeyManager.onShowClipboard = { [weak self] in
            self?.toggleClipboardWindow()
        }

        hotKeyManager.onClearHistory = { [weak self] in
            self?.clipboardViewModel.clearHistory()
        }

        hotKeyManager.onSearchClipboard = { [weak self] in
            self?.showClipboardWindow()
            // Focus search field after window appears
        }

        // Check accessibility permission
        if !hotKeyManager.hasAccessibilityPermission {
            hotKeyManager.requestAccessibilityPermission()
        }

        print("⌨️ Keyboard shortcuts setup completed")
    }

    // MARK: - Actions

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right click - show menu
            statusItem.menu = statusItem.menu
            statusItem.button?.performClick(nil)
        } else {
            // Left click - toggle window
            toggleClipboardWindow()
        }
    }

    @objc private func showClipboardWindow() {
        guard !clipboardWindow.isVisible else {
            clipboardWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        isShowingWindow = true

        // Use full screen frame for width, visibleFrame for height calculation
        let fullFrame = NSScreen.main?.frame ?? .zero
        let visibleFrame = NSScreen.main?.visibleFrame ?? .zero
        let drawerHeight: CGFloat = 220

        // Update window size to match full screen width
        let windowSize = CGSize(width: fullFrame.width, height: drawerHeight)
        clipboardWindow.setContentSize(windowSize)

        // Position window off-screen first (below visible area)
        clipboardWindow.setFrameOrigin(CGPoint(
            x: fullFrame.origin.x,
            y: visibleFrame.origin.y - drawerHeight
        ))

        // Show window and activate
        clipboardWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Animate slide up
        let targetFrame = CGRect(
            x: fullFrame.origin.x,
            y: visibleFrame.origin.y,
            width: fullFrame.width,
            height: drawerHeight
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true

            self.clipboardWindow.setFrame(targetFrame, display: true, animate: true)
        }, completionHandler: { [weak self] in
            self?.isShowingWindow = false
        })
    }

    private func hideClipboardWindow() {
        guard clipboardWindow.isVisible else { return }

        let fullFrame = NSScreen.main?.frame ?? .zero
        let visibleFrame = NSScreen.main?.visibleFrame ?? .zero
        let drawerHeight: CGFloat = 220

        // Animate slide down
        let targetFrame = CGRect(
            x: fullFrame.origin.x,
            y: visibleFrame.origin.y - drawerHeight,
            width: fullFrame.width,
            height: drawerHeight
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true

            self.clipboardWindow.setFrame(targetFrame, display: true, animate: true)
        }, completionHandler: { [weak self] in
            self?.clipboardWindow.orderOut(nil)
        })
    }

    @objc private func toggleClipboardWindow() {
        if clipboardWindow.isVisible {
            hideClipboardWindow()
        } else {
            showClipboardWindow()
        }
    }

    @objc private func showSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Helper Methods

    private func updateStatusBarMenu() {
        // Update statistics in menu
        if let menu = statusItem.menu,
           let statsItem = menu.items.first(where: { $0.title.contains("items") }) {
            let count = clipboardViewModel.items.count
            statsItem.title = "\(count) item\(count == 1 ? "" : "s") captured"
        }
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Hide the drawer with animation instead of terminating
        hideClipboardWindow()
    }

    func windowDidResignKey(_ notification: Notification) {
        // Don't auto-hide if we're in the middle of showing the window
        guard !isShowingWindow else { return }
        // Auto-hide drawer when it loses focus
        hideClipboardWindow()
    }
}
