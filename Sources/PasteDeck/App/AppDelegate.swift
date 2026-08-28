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
import CoreGraphics

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var clipboardWindow: NSPanel!
    private var clipboardMonitor: ClipboardMonitor!
    private var clipboardViewModel: ClipboardViewModel!
    private lazy var hotKeyManager = HotKeyManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var drawerAnimationGeneration = 0
    private var globalKeyEventMonitor: Any?
    private var globalMouseEventMonitor: Any?
    private var settingsWindow: NSWindow?
    private weak var drawerVisualEffectView: NSVisualEffectView?

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }

    private var isUnitTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isUnitTesting else { return }

        // Register default settings before any initialization
        registerDefaultSettings()

        // Configure app to be menu bar only
        NSApp.setActivationPolicy(.accessory)

        // Initialize services
        setupClipboardMonitor()
        setupViewModel()
        setupStatusBar()
        setupClipboardWindow()
        setupKeyboardShortcuts()
        setupNotifications()
        handleUITestingLaunchArguments()
        if !isUITesting {
            setupLaunchAtLogin()
        }

        // Perform startup cleanup based on retention settings
        if !isUITesting {
            performStartupCleanup()
        }

        print("🚀 PasteDeck launched successfully")
    }

    private func handleUITestingLaunchArguments() {
        let arguments = Set(ProcessInfo.processInfo.arguments)
        guard arguments.contains("--ui-testing") else { return }

        print("🌐 UI testing language: \(L10n.language.rawValue)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            if arguments.contains("--show-settings") {
                self.showSettings()
            }
            if arguments.contains("--show-drawer") {
                self.showClipboardWindow()
            }
            if arguments.contains("--show-permission-guide") {
                AccessibilityPermissionGuide.shared.showGuide()
            }
        }
    }

    private func registerDefaultSettings() {
        // Register default values for all user preferences
        // This ensures consistent behavior on first launch and when using UserDefaults directly
        let defaults: [String: Any] = [
            "launchAtLogin": false,
            "iCloudSyncEnabled": true,
            "showInMenuBar": true,          // Menu bar icon visible by default
            "soundEnabled": true,
            "pasteMode": "activeApp",
            MotionStyle.preferenceKey: MotionStyle.nativeSnappy.rawValue,
            MotionSpeed.preferenceKey: MotionSpeed.normal.rawValue,
            "alwaysPastePlainText": false,
            "historyRetentionDays": 30
        ]
        UserDefaults.standard.register(defaults: defaults)
        print("⚙️ Default settings registered")
    }

    private func setupNotifications() {
        // Listen for settings window request
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettings),
            name: NSNotification.Name("ShowSettingsWindow"),
            object: nil
        )

        // Listen for UserDefaults changes to update status bar visibility
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func userDefaultsDidChange() {
        // Update status bar visibility when showInMenuBar setting changes
        updateStatusBarVisibility()
    }

    private func setupLaunchAtLogin() {
        // Sync launch at login state with user preference
        let userPreference = UserDefaults.standard.bool(forKey: "launchAtLogin")
        _ = LaunchAtLoginService.shared.sync(with: userPreference)
    }

    private func performStartupCleanup() {
        // Read retention setting
        let retentionDays = UserDefaults.standard.integer(forKey: "historyRetentionDays")

        // Skip cleanup if set to permanent (-1) or invalid value
        guard retentionDays > 0 else {
            print("🧹 Startup cleanup skipped (retention: \(retentionDays == -1 ? "permanent" : "invalid"))")
            return
        }

        // Perform cleanup in background
        Task {
            let deletedCount = clipboardViewModel.cleanupExpiredItems(retentionDays: retentionDays)
            if deletedCount > 0 {
                print("🧹 Startup cleanup: Deleted \(deletedCount) expired items (retention: \(retentionDays) days)")
            } else {
                print("🧹 Startup cleanup: No expired items to delete")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stopMonitoring()
        print("👋 PasteDeck terminated")
    }

    // MARK: - Setup Methods

    private func setupClipboardMonitor() {
        clipboardMonitor = ClipboardMonitor()
        if !isUITesting {
            clipboardMonitor.startMonitoring()
        }
    }

    private func setupViewModel() {
        clipboardViewModel = ClipboardViewModel(monitor: clipboardMonitor)
    }

    private func setupStatusBar() {
        // Check user preference for showing in menu bar
        // Default value (true) is registered in registerDefaultSettings()
        let showInMenuBar = UserDefaults.standard.bool(forKey: "showInMenuBar")

        guard showInMenuBar else {
            print("⚠️ Status bar icon hidden by user preference")
            return
        }

        createStatusBarItem()
    }

    private func createStatusBarItem() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = StatusBarIconProvider.image()
            button.imageScaling = .scaleProportionallyDown

            // Both left and right click toggle the drawer
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Note: Menu has been moved to the drawer header
        print("✅ Status bar icon created")
    }

    private func removeStatusBarItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
            print("✅ Status bar icon removed")
        }
    }

    private func updateStatusBarVisibility() {
        let showInMenuBar = UserDefaults.standard.bool(forKey: "showInMenuBar")

        if showInMenuBar {
            // Show status bar icon if not already visible
            if statusItem == nil {
                createStatusBarItem()
            }
        } else {
            // Hide status bar icon if visible
            removeStatusBarItem()
        }
    }

    private func setupClipboardWindow() {
        // Create the SwiftUI content view
        let contentView = MainWindow()
            .environmentObject(clipboardViewModel)

        // Create hosting controller
        let hostingController = NSHostingController(rootView: contentView)

        // Calculate drawer size and position (bottom of screen)
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let drawerHeight: CGFloat = 280

        // Window positioned at visible area (not off-screen)
        let windowRect = CGRect(
            x: screenFrame.origin.x,
            y: screenFrame.origin.y,
            width: screenFrame.width,
            height: drawerHeight
        )

        // Create panel with borderless style for drawer appearance
        clipboardWindow = KeyablePanel(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Create clipping container view
        let clippingContainer = ClippingContainerView(frame: NSRect(
            x: 0,
            y: 0,
            width: screenFrame.width,
            height: drawerHeight
        ))
        clippingContainer.autoresizingMask = [.width, .height]

        // Create visual effect view for frosted glass effect
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .popover
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true

        // Position visual effect view off-screen initially (within the clipping container)
        visualEffectView.frame = NSRect(
            x: 0,
            y: -drawerHeight,
            width: screenFrame.width,
            height: drawerHeight
        )
        visualEffectView.autoresizingMask = [.width]

        // Add SwiftUI view on top of visual effect
        hostingController.view.frame = visualEffectView.bounds
        hostingController.view.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(hostingController.view)

        clippingContainer.addSubview(visualEffectView)
        drawerVisualEffectView = visualEffectView

        // Set clipping container as window content
        clipboardWindow.contentView = clippingContainer

        // Configure panel for drawer behavior
        clipboardWindow.isFloatingPanel = true
        clipboardWindow.level = .popUpMenu
        clipboardWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        clipboardWindow.backgroundColor = .clear
        clipboardWindow.isOpaque = false
        clipboardWindow.hasShadow = true
        clipboardWindow.hidesOnDeactivate = false
        clipboardWindow.isMovable = false

        // Handle window close
        clipboardWindow.delegate = self

        // Set up callbacks for ViewModel
        clipboardViewModel.onRequestClose = { [weak self] in
            self?.hideClipboardWindow()
        }

        clipboardViewModel.onPrepareForPaste = { [weak self] in
            guard let self = self else { return }
            // Immediately lower window level so keyboard events can reach the original app
            // This allows paste to work instantly without waiting for drawer to close
            self.clipboardWindow.level = .normal
            self.clipboardWindow.resignKey()
        }
    }

    private func setupKeyboardShortcuts() {
        // Set up callbacks
        hotKeyManager.onShowClipboard = { [weak self] in
            self?.toggleClipboardWindow()
        }

        hotKeyManager.onClearHistory = { [weak self] in
            self?.clipboardViewModel.clearHistory()
        }

        hotKeyManager.onQuickPaste = { [weak self] position in
            guard let self = self else { return }

            // Get item at position (1-indexed)
            let items = self.clipboardViewModel.filteredItems
            guard position > 0 && position <= items.count else {
                print("⚠️ Quick paste: No item at position \(position) (total: \(items.count))")
                return
            }

            let item = items[position - 1]
            print("⚡ Quick paste: Position \(position) - \(item.title)")
            self.clipboardViewModel.copyAndPaste(item)
        }

        print("⌨️ Keyboard shortcuts setup completed")
    }

    // MARK: - Actions

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        // Both left and right click toggle the drawer
        // Menu is now in the drawer header
        toggleClipboardWindow()
    }

    @objc private func showClipboardWindow() {
        guard !clipboardWindow.isVisible else {
            clipboardWindow.orderFront(nil)
            return
        }

        // Prepare view for display (select first item)
        clipboardViewModel.prepareForDisplay()

        drawerAnimationGeneration += 1
        let animationGeneration = drawerAnimationGeneration

        // Use full screen frame for width, visibleFrame for height calculation
        let fullFrame = NSScreen.main?.frame ?? .zero
        let screenVisibleFrame = NSScreen.main?.visibleFrame ?? .zero
        let drawerHeight: CGFloat = 280

        // Position window at visible area (stays in place)
        let windowRect = CGRect(
            x: fullFrame.origin.x,
            y: screenVisibleFrame.origin.y,
            width: fullFrame.width,
            height: drawerHeight
        )
        clipboardWindow.setFrame(windowRect, display: false)

        guard let visualEffectView = drawerVisualEffectView else {
            return
        }

        let motionStyle = MotionStyle.current()
        let durationMultiplier = MotionSpeed.current().durationMultiplier
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let visibleFrame = NSRect(x: 0, y: 0, width: fullFrame.width, height: drawerHeight)
        let hiddenFrame = NSRect(
            x: 0,
            y: motionStyle == .softMaterial ? -40 : -drawerHeight,
            width: fullFrame.width,
            height: drawerHeight
        )

        visualEffectView.frame = reduceMotion ? visibleFrame : hiddenFrame
        visualEffectView.alphaValue = reduceMotion || motionStyle == .softMaterial ? 0 : 1

        // Show window and make it key (but don't activate app, preserving original app focus)
        // This allows clicks to work immediately without needing a first click to focus
        clipboardWindow.makeKeyAndOrderFront(nil)

        // Add global event monitor for ESC key (works even when focus is in other app)
        globalKeyEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                DispatchQueue.main.async {
                    self?.hideClipboardWindow()
                }
            }
        }

        // Add global event monitor for clicks outside drawer
        globalMouseEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            guard self.clipboardWindow.isVisible else { return }

            // Check if click is outside the drawer window
            let windowFrame = self.clipboardWindow.frame
            let screenPoint = NSEvent.mouseLocation

            if !windowFrame.contains(screenPoint) {
                DispatchQueue.main.async {
                    self.hideClipboardWindow()
                }
            }
        }

        // Let AppKit commit the hidden state before starting the entrance animation.
        DispatchQueue.main.async { [weak self, weak visualEffectView] in
            guard let self, let visualEffectView else { return }
            guard self.drawerAnimationGeneration == animationGeneration,
                  self.clipboardWindow.isVisible else { return }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = MotionTiming.drawerEnter * durationMultiplier
                switch motionStyle {
                case .nativeSnappy:
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                case .spatialSpring:
                    context.timingFunction = CAMediaTimingFunction(
                        controlPoints: 0.34, 1.0, 0.64, 1.0
                    )
                case .softMaterial:
                    context.timingFunction = CAMediaTimingFunction(
                        controlPoints: 0.215, 0.61, 0.355, 1.0
                    )
                }
                if reduceMotion {
                    context.duration = 0.05
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                }
                context.allowsImplicitAnimation = true

                if !reduceMotion {
                    visualEffectView.animator().frame = visibleFrame
                }
                if reduceMotion || motionStyle == .softMaterial {
                    visualEffectView.animator().alphaValue = 1
                }
            }, completionHandler: { [weak self] in
                guard let self,
                      self.drawerAnimationGeneration == animationGeneration else { return }

                visualEffectView.frame = visibleFrame
                visualEffectView.alphaValue = 1
            })
        }
    }

    private func hideClipboardWindow(completion: (() -> Void)? = nil) {
        guard clipboardWindow.isVisible else {
            completion?()
            return
        }

        drawerAnimationGeneration += 1
        let animationGeneration = drawerAnimationGeneration

        let restoreSettingsFocus = shouldRestoreSettingsFocusAfterDrawerClose()

        // Remove event monitors
        if let monitor = globalKeyEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyEventMonitor = nil
        }
        if let monitor = globalMouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseEventMonitor = nil
        }

        let fullFrame = NSScreen.main?.frame ?? .zero
        let drawerHeight: CGFloat = 280

        clipboardWindow.resignKey()

        guard let visualEffectView = drawerVisualEffectView else {
            finishHidingClipboardWindow(
                restoreSettingsFocus: restoreSettingsFocus,
                completion: completion
            )
            return
        }

        let motionStyle = MotionStyle.current()
        let durationMultiplier = MotionSpeed.current().durationMultiplier
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let visibleFrame = NSRect(x: 0, y: 0, width: fullFrame.width, height: drawerHeight)
        let hiddenFrame = NSRect(
            x: 0,
            y: motionStyle == .softMaterial ? -20 : -drawerHeight,
            width: fullFrame.width,
            height: drawerHeight
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = MotionTiming.drawerExit * durationMultiplier
            switch motionStyle {
            case .nativeSnappy:
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            case .spatialSpring:
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.36, 0.0, 0.66, 1.0
                )
            case .softMaterial:
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.55, 0.055, 0.675, 0.19
                )
            }
            if reduceMotion {
                context.duration = 0.05
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            }
            context.allowsImplicitAnimation = true

            if !reduceMotion {
                visualEffectView.animator().frame = hiddenFrame
            }
            if reduceMotion || motionStyle == .softMaterial {
                visualEffectView.animator().alphaValue = 0
            }
        }, completionHandler: { [weak self] in
            guard let self,
                  self.drawerAnimationGeneration == animationGeneration else { return }
            self.finishHidingClipboardWindow(
                restoreSettingsFocus: restoreSettingsFocus,
                completion: completion
            )
            visualEffectView.frame = visibleFrame
            visualEffectView.alphaValue = 1
        })
    }

    private func finishHidingClipboardWindow(
        restoreSettingsFocus: Bool,
        completion: (() -> Void)?
    ) {
        clipboardWindow.orderOut(nil)
        clipboardWindow.level = .popUpMenu
        clipboardViewModel.resetUIState()

        if let completion {
            completion()
        } else if restoreSettingsFocus {
            settingsWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func shouldRestoreSettingsFocusAfterDrawerClose() -> Bool {
        guard let settingsWindow, settingsWindow.isVisible else { return false }
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return true
        }
        return NSApp.isActive
    }

    @objc private func toggleClipboardWindow() {
        if clipboardWindow.isVisible {
            hideClipboardWindow()
        } else {
            showClipboardWindow()
        }
    }

    @objc func showSettings() {
        if clipboardWindow.isVisible {
            hideClipboardWindow { [weak self] in
                self?.presentSettingsWindow()
            }
            return
        }

        presentSettingsWindow()
    }

    private func presentSettingsWindow() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(clipboardViewModel)
            let hostingController = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = L10n.string("window.settings.title")
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.tabbingMode = .disallowed
            window.setContentSize(NSSize(width: 760, height: 560))
            window.minSize = NSSize(width: 720, height: 520)
            window.maxSize = NSSize(width: 980, height: 760)
            window.level = .floating
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        guard let window = settingsWindow else { return }

        positionSettingsWindow(window)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func positionSettingsWindow(_ window: NSWindow) {
        guard let targetScreen = preferredSettingsScreen() else { return }

        let visibleFrame = targetScreen.visibleFrame
        let windowSize = window.frame.size
        let origin = NSPoint(
            x: visibleFrame.origin.x + (visibleFrame.width - windowSize.width) / 2,
            y: visibleFrame.origin.y + (visibleFrame.height - windowSize.height) / 2
        )
        window.setFrameOrigin(origin)
    }

    private func preferredSettingsScreen() -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        let frontmostAppScreenIndex = frontmostApplicationScreenIndex(in: screens)
        let keyWindowScreenIndex = screenIndex(
            for: NSApp.keyWindow?.screen ?? NSApp.mainWindow?.screen,
            in: screens
        )
        let mouseScreenIndex = screenIndexForMouseLocation(in: screens)
        let mainScreenIndex = screenIndex(for: NSScreen.main, in: screens) ?? 0

        guard let preferredIndex = ScreenSelection.preferredScreenIndex(
            frontmostAppScreenIndex: frontmostAppScreenIndex,
            keyWindowScreenIndex: keyWindowScreenIndex,
            mouseScreenIndex: mouseScreenIndex,
            mainScreenIndex: mainScreenIndex
        ) else {
            return nil
        }

        guard screens.indices.contains(preferredIndex) else { return nil }
        return screens[preferredIndex]
    }

    private func frontmostApplicationScreenIndex(in screens: [NSScreen]) -> Int? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        if frontApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return nil
        }
        return screenIndexForRunningApplication(frontApp, in: screens)
    }

    private func screenIndexForRunningApplication(_ app: NSRunningApplication, in screens: [NSScreen]) -> Int? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let screenFrames = screens.map { $0.frame }
        let targetPID = app.processIdentifier

        for info in windowInfoList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == targetPID else {
                continue
            }

            let layer = intValue(info[kCGWindowLayer as String]) ?? 0
            if layer != 0 {
                continue
            }

            if let isOnscreenValue = info[kCGWindowIsOnscreen as String],
               let isOnscreen = boolValue(isOnscreenValue),
               !isOnscreen {
                continue
            }

            guard let bounds = boundsRect(info[kCGWindowBounds as String]) else {
                continue
            }

            if let index = ScreenSelection.screenIndexForWindowBounds(bounds, in: screenFrames) {
                return index
            }
        }

        return nil
    }

    private func screenIndexForMouseLocation(in screens: [NSScreen]) -> Int? {
        let mousePoint = NSEvent.mouseLocation
        return screens.firstIndex(where: { $0.frame.contains(mousePoint) })
    }

    private func screenIndex(for screen: NSScreen?, in screens: [NSScreen]) -> Int? {
        guard let screen else { return nil }
        return screens.firstIndex(where: { $0 === screen })
    }

    private func boundsRect(_ value: Any?) -> CGRect? {
        guard let dict = value as? [String: Any],
              let x = cgFloatValue(dict["X"]),
              let y = cgFloatValue(dict["Y"]),
              let width = cgFloatValue(dict["Width"]),
              let height = cgFloatValue(dict["Height"]) else {
            return nil
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func cgFloatValue(_ value: Any?) -> CGFloat? {
        if let value = value as? CGFloat {
            return value
        }
        if let value = value as? Double {
            return CGFloat(value)
        }
        if let value = value as? Int {
            return CGFloat(value)
        }
        if let value = value as? NSNumber {
            return CGFloat(truncating: value)
        }
        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool? {
        if let value = value as? Bool {
            return value
        }
        if let value = value as? NSNumber {
            return value.boolValue
        }
        return nil
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Hide the drawer with animation instead of terminating
        hideClipboardWindow()
    }

    func windowDidResignKey(_ notification: Notification) {
        // Not used - we use global event monitor instead to detect clicks outside
        // This preserves focus in the original application
    }
}

// MARK: - Custom Panel

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

// MARK: - Clipping Container View

class ClippingContainerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupClipping()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupClipping()
    }

    private func setupClipping() {
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.backgroundColor = .clear
    }
}
