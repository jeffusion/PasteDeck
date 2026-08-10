//
//  SettingsView.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI
import KeyboardShortcuts

// MARK: - Settings Navigation Item

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case privacy
    case shortcuts
    case about

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .privacy: return "hand.raised"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
        }
    }

    var title: String {
        switch self {
        case .general: return L10n.string("settings.tab.general")
        case .privacy: return L10n.string("settings.tab.privacy")
        case .shortcuts: return L10n.string("settings.tab.shortcuts")
        case .about: return L10n.string("settings.tab.about")
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            // Content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .privacy:
                    PrivacySettingsView()
                case .shortcuts:
                    ShortcutsSettingsView()
                case .about:
                    AboutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 650, height: 500)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("pasteMode") private var pasteMode = "activeApp"
    @AppStorage("alwaysPastePlainText") private var alwaysPastePlainText = false
    @AppStorage("historyRetentionDays") private var historyRetentionDays = 30

    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    // Retention time confirmation
    @State private var previousRetentionDays: Int = 30
    @State private var showRetentionConfirmation = false
    @State private var pendingRetentionDays: Int?
    @State private var showRetentionResult = false
    @State private var deletedItemsCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text(L10n.string("settings.general.title"))
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)

                // Basic Settings Group
                SettingsGroupBox {
                    SettingsToggleRow(
                        title: L10n.string("settings.general.launch_at_login"),
                        isOn: $launchAtLogin
                    )
                    Divider()
                    SettingsToggleRow(
                        title: L10n.string("settings.general.icloud_sync"),
                        isOn: $iCloudSyncEnabled,
                        subtitle: iCloudSyncEnabled ? L10n.string("settings.general.synced") : nil
                    )
                    Divider()
                    SettingsToggleRow(
                        title: L10n.string("settings.general.show_menu_bar"),
                        isOn: $showInMenuBar
                    )
                    Divider()
                    SettingsToggleRow(
                        title: L10n.string("settings.general.sound"),
                        isOn: $soundEnabled
                    )
                }

                // Paste Mode Group
                Text(L10n.string("settings.general.paste_items"))
                    .font(.headline)
                    .padding(.top, 8)

                SettingsGroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        // Paste to active app
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: pasteMode == "activeApp" ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(pasteMode == "activeApp" ? .accentColor : .secondary)
                                    .onTapGesture { pasteMode = "activeApp" }

                                Text(L10n.string("settings.general.paste_active_app"))
                                    .fontWeight(pasteMode == "activeApp" ? .medium : .regular)
                            }

                            Text(L10n.string("settings.general.paste_active_app.description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }

                        Divider()

                        // Paste to clipboard only
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: pasteMode == "clipboard" ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(pasteMode == "clipboard" ? .accentColor : .secondary)
                                    .onTapGesture { pasteMode = "clipboard" }

                                Text(L10n.string("settings.general.paste_clipboard"))
                                    .fontWeight(pasteMode == "clipboard" ? .medium : .regular)
                            }

                            Text(L10n.string("settings.general.paste_clipboard.description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }

                        Divider()

                        // Plain text option
                        HStack {
                            Image(systemName: alwaysPastePlainText ? "checkmark.square.fill" : "square")
                                .foregroundColor(alwaysPastePlainText ? .accentColor : .secondary)
                                .onTapGesture { alwaysPastePlainText.toggle() }

                            Text(L10n.string("settings.general.always_plain_text"))
                        }
                    }
                }

                // History Retention Group
                Text(L10n.string("settings.general.retention"))
                    .font(.headline)
                    .padding(.top, 8)

                SettingsGroupBox {
                    VStack(spacing: 16) {
                        // 自定义滑块组件（增加左右内边距）
                        RetentionSlider(retentionDays: $historyRetentionDays)
                            .padding(.horizontal, 20)

                        HStack {
                            Spacer()
                            Button(L10n.string("settings.general.delete_history")) {
                                // TODO: Show confirmation dialog
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
            .onAppear {
                // Sync @AppStorage with actual system state
                let actualState = LaunchAtLoginService.shared.isEnabled
                if launchAtLogin != actualState {
                    launchAtLogin = actualState
                }

                // Initialize previous retention days
                previousRetentionDays = historyRetentionDays
            }
            .onChange(of: launchAtLogin) { newValue in
                // Sync system state with user preference
                let actualState = LaunchAtLoginService.shared.sync(with: newValue)

                // If sync failed, revert the toggle
                if actualState != newValue {
                    launchAtLogin = actualState
                    errorMessage = L10n.string("settings.error.launch_at_login")
                    showErrorAlert = true
                }
            }
            .onChange(of: historyRetentionDays) { newValue in
                // Check if retention time is being shortened (and not set to permanent)
                if newValue < previousRetentionDays && newValue != -1 {
                    // Show confirmation dialog
                    pendingRetentionDays = newValue
                    showRetentionConfirmation = true
                    // Temporarily revert to old value
                    historyRetentionDays = previousRetentionDays
                } else {
                    // No confirmation needed for increasing retention or setting to permanent
                    previousRetentionDays = newValue

                    // Auto-cleanup when changing retention time (except permanent)
                    if newValue != -1 {
                        Task {
                            _ = viewModel.cleanupExpiredItems(retentionDays: newValue)
                        }
                    }
                }
            }
        }
        .alert(L10n.string("settings.error.title"), isPresented: $showErrorAlert) {
            Button(L10n.string("common.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert(L10n.string("settings.retention.shorten.title"), isPresented: $showRetentionConfirmation) {
            Button(L10n.string("common.cancel"), role: .cancel) {
                pendingRetentionDays = nil
            }
            Button(L10n.string("settings.retention.confirm_delete"), role: .destructive) {
                if let newDays = pendingRetentionDays {
                    // Execute cleanup
                    Task {
                        deletedItemsCount = viewModel.cleanupExpiredItems(retentionDays: newDays)
                        historyRetentionDays = newDays
                        previousRetentionDays = newDays
                        pendingRetentionDays = nil

                        // Show result if items were deleted
                        if deletedItemsCount > 0 {
                            showRetentionResult = true
                        }
                    }
                }
            }
        } message: {
            if let newDays = pendingRetentionDays {
                let daysText = L10n.plural("duration.days", count: newDays)
                Text(L10n.format("settings.retention.shorten.message", daysText))
            }
        }
        .alert(L10n.string("settings.retention.cleanup.title"), isPresented: $showRetentionResult) {
            Button(L10n.string("common.ok"), role: .cancel) {}
        } message: {
            Text(L10n.plural("count.deleted_history", count: deletedItemsCount))
        }
    }
}

// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    @State private var hasAccessibilityPermission = AccessibilityPermissionGuide.shared.hasPermission
    @State private var excludedApps: [String] = []
    @State private var permissionCheckTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(L10n.string("settings.privacy.title"))
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)

                // Accessibility Permission
                Text(L10n.string("settings.privacy.accessibility"))
                    .font(.headline)

                SettingsGroupBox {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(hasAccessibilityPermission ? .green : .orange)
                                Text(L10n.string(
                                    hasAccessibilityPermission ?
                                        "settings.privacy.authorized" : "settings.privacy.not_authorized"
                                ))
                                    .fontWeight(.medium)
                            }

                            Text(L10n.string("settings.privacy.accessibility.description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !hasAccessibilityPermission {
                            Button(L10n.string("settings.privacy.open_guide")) {
                                AccessibilityPermissionGuide.shared.showGuide()
                            }
                        }
                    }
                }

                // Excluded Apps
                Text(L10n.string("settings.privacy.excluded_apps"))
                    .font(.headline)
                    .padding(.top, 8)

                SettingsGroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.string("settings.privacy.excluded_apps.description"))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if excludedApps.isEmpty {
                            Text(L10n.string("settings.privacy.excluded_apps.empty"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(excludedApps, id: \.self) { app in
                                HStack {
                                    Image(systemName: "app")
                                    Text(app)
                                    Spacer()
                                    Button {
                                        excludedApps.removeAll { $0 == app }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(
                                        L10n.format("settings.privacy.remove_app", app)
                                    )
                                }
                            }
                        }

                        Divider()

                        Button(L10n.string("settings.privacy.add_app")) {
                            // TODO: Show app picker
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            hasAccessibilityPermission = AccessibilityPermissionGuide.shared.hasPermission
            startPermissionChecking()
        }
        .onDisappear {
            stopPermissionChecking()
        }
    }

    // MARK: - Helper Methods

    private func startPermissionChecking() {
        // Check permission status every 2 seconds
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                hasAccessibilityPermission = AccessibilityPermissionGuide.shared.hasPermission
            }
        }
    }

    private func stopPermissionChecking() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    @ObservedObject private var hotKeyManager = HotKeyManager.shared
    @State private var showModifierPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(L10n.string("settings.shortcuts.title"))
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)

                // 基础快捷键
                Text(L10n.string("settings.shortcuts.basic"))
                    .font(.headline)

                SettingsGroupBox {
                    VStack(spacing: 12) {
                        ShortcutRecorderRow(
                            title: L10n.string("settings.shortcuts.show_pastedeck"),
                            name: .showClipboard
                        )
                        Divider()
                        ShortcutRecorderRow(
                            title: L10n.string("settings.shortcuts.clear_history"),
                            name: .clearHistory
                        )
                    }
                }

                // 快速粘贴快捷键
                Text(L10n.string("settings.shortcuts.quick_paste"))
                    .font(.headline)
                    .padding(.top, 8)

                SettingsGroupBox {
                    VStack(spacing: 12) {
                        HStack {
                            Text(L10n.string("settings.shortcuts.quick_paste.description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        HStack {
                            Text(L10n.string("settings.shortcuts.quick_paste"))
                                .frame(width: 150, alignment: .leading)
                            Spacer()
                            Button(action: {
                                showModifierPicker = true
                            }) {
                                Text(L10n.format(
                                    "settings.shortcuts.quick_paste.preview",
                                    hotKeyManager.quickPasteModifiers.displayString
                                ))
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button(L10n.string("settings.shortcuts.reset")) {
                        resetAllShortcuts()
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .sheet(isPresented: $showModifierPicker) {
            ModifierPickerView(modifiers: $hotKeyManager.quickPasteModifiers)
        }
    }

    private func resetAllShortcuts() {
        KeyboardShortcuts.reset(.showClipboard)
        KeyboardShortcuts.reset(.clearHistory)
        hotKeyManager.quickPasteModifiers = .default
    }
}

// MARK: - Modifier Picker View

struct ModifierPickerView: View {
    @Binding var modifiers: QuickPasteModifiers
    @Environment(\.dismiss) var dismiss
    @State private var tempModifiers: QuickPasteModifiers

    init(modifiers: Binding<QuickPasteModifiers>) {
        self._modifiers = modifiers
        self._tempModifiers = State(initialValue: modifiers.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.string("settings.shortcuts.modifiers.title"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Toggle(L10n.string("settings.shortcuts.modifier.command"), isOn: $tempModifiers.command)
                Toggle(L10n.string("settings.shortcuts.modifier.control"), isOn: $tempModifiers.control)
                Toggle(L10n.string("settings.shortcuts.modifier.option"), isOn: $tempModifiers.option)
                Toggle(L10n.string("settings.shortcuts.modifier.shift"), isOn: $tempModifiers.shift)
            }
            .toggleStyle(.checkbox)

            Text(L10n.format("settings.shortcuts.modifiers.preview", tempModifiers.displayString))
                .font(.caption)
                .foregroundColor(.secondary)

            if !tempModifiers.isValid {
                Text(L10n.string("settings.shortcuts.modifiers.required"))
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button(L10n.string("common.cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(L10n.string("common.confirm")) {
                    modifiers = tempModifiers
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!tempModifiers.isValid)
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}

struct ShortcutRecorderRow: View {
    let title: String
    let name: KeyboardShortcuts.Name

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 150, alignment: .leading)
            Spacer()
            KeyboardShortcuts.Recorder(for: name)
        }
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("PasteDeck")
                .font(.title)
                .fontWeight(.bold)

            Text(L10n.format(
                "settings.about.version",
                appVersion,
                L10n.string("settings.about.beta")
            ))
                .foregroundColor(.secondary)

            Text(L10n.string("settings.about.tagline"))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/example/PasteDeck")!) {
                    Label(L10n.string("settings.about.github"), systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/example/PasteDeck/issues")!) {
                    Label(L10n.string("settings.about.report_issue"), systemImage: "exclamationmark.bubble")
                }
            }

            Spacer()

            VStack(spacing: 4) {
                Text("© 2025 PasteDeck Contributors")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(L10n.string("settings.about.license"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
}

// MARK: - Helper Components

struct SettingsGroupBox<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var subtitle: String? = nil

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
