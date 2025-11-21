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

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var clipboardWindow: NSPanel!
    private var clipboardMonitor: ClipboardMonitor!
    private var clipboardViewModel: ClipboardViewModel!
    private var cancellables = Set<AnyCancellable>()

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

        // Calculate window size and position (centered on screen)
        let windowSize = CGSize(width: 600, height: 500)
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let windowOrigin = CGPoint(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY - windowSize.height / 2
        )
        let windowRect = CGRect(origin: windowOrigin, size: windowSize)

        // Create panel (special kind of window)
        clipboardWindow = NSPanel(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel
        clipboardWindow.title = "PasteDeck"
        clipboardWindow.contentView = hostingController.view
        clipboardWindow.isFloatingPanel = true
        clipboardWindow.level = .floating
        clipboardWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        clipboardWindow.titlebarAppearsTransparent = true
        clipboardWindow.isMovableByWindowBackground = true
        clipboardWindow.styleMask.insert(.fullSizeContentView)

        // Handle window close
        clipboardWindow.delegate = self
    }

    private func setupKeyboardShortcuts() {
        // TODO: Implement global keyboard shortcuts using KeyboardShortcuts package
        // For now, users can use the menu bar to access the window

        // Example shortcut: Cmd+Shift+V
        // KeyboardShortcuts.onKeyUp(for: .showClipboard) { [weak self] in
        //     self?.toggleClipboardWindow()
        // }

        print("⌨️ Keyboard shortcuts setup (placeholder)")
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
        if clipboardWindow.isVisible {
            clipboardWindow.orderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            clipboardWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func toggleClipboardWindow() {
        if clipboardWindow.isVisible {
            clipboardWindow.orderOut(nil)
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
        // Just hide the window instead of terminating the app
        clipboardWindow.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Optionally hide window when it loses focus
        // Uncomment if you want auto-hide behavior
        // clipboardWindow.orderOut(nil)
    }
}
