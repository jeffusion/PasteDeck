//
//  SettingsView.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI
import KeyboardShortcuts

// MARK: - Settings Navigation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case privacy
    case shortcuts
    case about

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
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

struct SettingsView: View {
    @State private var selectedTab = SettingsTab.general

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SettingsSidebarHeader()

                List(SettingsTab.allCases, selection: $selectedTab) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .labelStyle(SettingsSidebarLabelStyle())
                        .tag(tab)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            .navigationSplitViewColumnWidth(min: 176, ideal: 188, max: 208)
        } detail: {
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
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 720, idealWidth: 760, minHeight: 520, idealHeight: 560)
    }
}

private struct SettingsSidebarHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor)

                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            .shadow(color: .black.opacity(0.10), radius: 3, y: 1)

            VStack(alignment: .leading, spacing: 1) {
                Text("PasteDeck")
                    .font(.system(size: 13, weight: .semibold))
                Text(L10n.string("window.settings.title"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

private struct SettingsSidebarLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 9) {
            configuration.icon
                .font(.system(size: 13))
                .frame(width: 18)
            configuration.title
                .font(.system(size: 13))
        }
        .padding(.vertical, 2)
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
    @State private var previousRetentionDays = 30
    @State private var showRetentionConfirmation = false
    @State private var pendingRetentionDays: Int?
    @State private var showRetentionResult = false
    @State private var deletedItemsCount = 0
    @State private var showClearHistoryConfirmation = false

    var body: some View {
        SettingsPage(title: L10n.string("settings.general.title"), icon: SettingsTab.general.icon) {
            SettingsSection {
                SettingsToggleRow(
                    icon: "power",
                    title: L10n.string("settings.general.launch_at_login"),
                    isOn: $launchAtLogin
                )
                SettingsRowDivider()
                SettingsToggleRow(
                    icon: "icloud",
                    title: L10n.string("settings.general.icloud_sync"),
                    subtitle: iCloudSyncEnabled ? L10n.string("settings.general.synced") : nil,
                    isOn: $iCloudSyncEnabled
                )
                SettingsRowDivider()
                SettingsToggleRow(
                    icon: "menubar.rectangle",
                    title: L10n.string("settings.general.show_menu_bar"),
                    isOn: $showInMenuBar
                )
                SettingsRowDivider()
                SettingsToggleRow(
                    icon: "speaker.wave.2",
                    title: L10n.string("settings.general.sound"),
                    isOn: $soundEnabled
                )
            }

            SettingsSection(title: L10n.string("settings.general.paste_items")) {
                VStack(alignment: .leading, spacing: 10) {
                    PasteModeSelector(selection: $pasteMode)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(pasteModeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 13)

                SettingsRowDivider(leadingInset: 0)

                SettingsToggleRow(
                    icon: "textformat",
                    title: L10n.string("settings.general.always_plain_text"),
                    isOn: $alwaysPastePlainText
                )
            }

            SettingsSection(title: L10n.string("settings.general.retention")) {
                VStack(spacing: 14) {
                    RetentionSlider(retentionDays: $historyRetentionDays)

                    Divider()

                    HStack {
                        Spacer()
                        Button {
                            showClearHistoryConfirmation = true
                        } label: {
                            Label(L10n.string("settings.general.delete_history"), systemImage: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 14)
            }
        }
        .onAppear {
            let actualState = LaunchAtLoginService.shared.isEnabled
            if launchAtLogin != actualState {
                launchAtLogin = actualState
            }
            previousRetentionDays = historyRetentionDays
        }
        .onChange(of: launchAtLogin) { newValue in
            let actualState = LaunchAtLoginService.shared.sync(with: newValue)
            if actualState != newValue {
                launchAtLogin = actualState
                errorMessage = L10n.string("settings.error.launch_at_login")
                showErrorAlert = true
            }
        }
        .onChange(of: historyRetentionDays) { newValue in
            if newValue < previousRetentionDays && newValue != -1 {
                pendingRetentionDays = newValue
                showRetentionConfirmation = true
                historyRetentionDays = previousRetentionDays
            } else {
                previousRetentionDays = newValue
                if newValue != -1 {
                    Task {
                        _ = viewModel.cleanupExpiredItems(retentionDays: newValue)
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
                guard let newDays = pendingRetentionDays else { return }
                deletedItemsCount = viewModel.cleanupExpiredItems(retentionDays: newDays)
                historyRetentionDays = newDays
                previousRetentionDays = newDays
                pendingRetentionDays = nil
                showRetentionResult = deletedItemsCount > 0
            }
        } message: {
            if let newDays = pendingRetentionDays {
                Text(L10n.format(
                    "settings.retention.shorten.message",
                    L10n.plural("duration.days", count: newDays)
                ))
            }
        }
        .alert(L10n.string("settings.retention.cleanup.title"), isPresented: $showRetentionResult) {
            Button(L10n.string("common.ok"), role: .cancel) {}
        } message: {
            Text(L10n.plural("count.deleted_history", count: deletedItemsCount))
        }
        .alert(L10n.string("settings.history.clear.title"), isPresented: $showClearHistoryConfirmation) {
            Button(L10n.string("common.cancel"), role: .cancel) {}
            Button(L10n.string("settings.history.clear.confirm"), role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text(L10n.string("settings.history.clear.message"))
        }
    }

    private var pasteModeDescription: String {
        L10n.string(
            pasteMode == "activeApp" ?
                "settings.general.paste_active_app.description" :
                "settings.general.paste_clipboard.description"
        )
    }
}

// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    @State private var hasAccessibilityPermission = AccessibilityPermissionGuide.shared.hasPermission
    @State private var excludedApps: [String] = []
    @State private var permissionCheckTimer: Timer?

    var body: some View {
        SettingsPage(title: L10n.string("settings.privacy.title"), icon: SettingsTab.privacy.icon) {
            SettingsSection(title: L10n.string("settings.privacy.accessibility")) {
                HStack(spacing: 12) {
                    Image(systemName: hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(hasAccessibilityPermission ? .green : .orange)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.string(
                            hasAccessibilityPermission ?
                                "settings.privacy.authorized" :
                                "settings.privacy.not_authorized"
                        ))
                        .font(.system(size: 13, weight: .medium))

                        Text(L10n.string("settings.privacy.accessibility.description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 16)

                    if !hasAccessibilityPermission {
                        Button(L10n.string("settings.privacy.open_guide")) {
                            AccessibilityPermissionGuide.shared.showGuide()
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 14)
            }

            SettingsSection(title: L10n.string("settings.privacy.excluded_apps")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.string("settings.privacy.excluded_apps.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if excludedApps.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "app")
                                .font(.system(size: 24))
                                .foregroundStyle(.tertiary)
                            Text(L10n.string("settings.privacy.excluded_apps.empty"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(excludedApps.enumerated()), id: \.element) { index, app in
                                HStack(spacing: 10) {
                                    Image(systemName: "app")
                                        .foregroundStyle(.secondary)
                                    Text(app)
                                    Spacer()
                                    Button {
                                        excludedApps.removeAll { $0 == app }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.red)
                                    .help(L10n.format("settings.privacy.remove_app", app))
                                    .accessibilityLabel(L10n.format("settings.privacy.remove_app", app))
                                }
                                .padding(.vertical, 9)

                                if index < excludedApps.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        // App selection and persistence are intentionally handled separately.
                    } label: {
                        Label(L10n.string("settings.privacy.add_app"), systemImage: "plus")
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 14)
            }
        }
        .onAppear {
            hasAccessibilityPermission = AccessibilityPermissionGuide.shared.hasPermission
            startPermissionChecking()
        }
        .onDisappear {
            stopPermissionChecking()
        }
    }

    private func startPermissionChecking() {
        permissionCheckTimer?.invalidate()
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
    @ObservedObject private var hotKeyManager = HotKeyManager.shared
    @State private var showModifierPicker = false

    var body: some View {
        SettingsPage(title: L10n.string("settings.shortcuts.title"), icon: SettingsTab.shortcuts.icon) {
            SettingsSection(title: L10n.string("settings.shortcuts.basic")) {
                ShortcutRecorderRow(
                    icon: "rectangle.on.rectangle",
                    title: L10n.string("settings.shortcuts.show_pastedeck"),
                    name: .showClipboard
                )
                SettingsRowDivider()
                ShortcutRecorderRow(
                    icon: "trash",
                    title: L10n.string("settings.shortcuts.clear_history"),
                    name: .clearHistory
                )
            }

            SettingsSection(title: L10n.string("settings.shortcuts.quick_paste")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.string("settings.shortcuts.quick_paste.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    HStack(spacing: 12) {
                        SettingsRowIcon(systemName: "number")
                        Text(L10n.string("settings.shortcuts.quick_paste"))
                        Spacer()
                        Button {
                            showModifierPicker = true
                        } label: {
                            Text(L10n.format(
                                "settings.shortcuts.quick_paste.preview",
                                hotKeyManager.quickPasteModifiers.displayString
                            ))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 14)
            }

            HStack {
                Spacer()
                Button {
                    resetAllShortcuts()
                } label: {
                    Label(L10n.string("settings.shortcuts.reset"), systemImage: "arrow.counterclockwise")
                }
                .controlSize(.small)
            }
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

struct ModifierPickerView: View {
    @Binding var modifiers: QuickPasteModifiers
    @Environment(\.dismiss) private var dismiss
    @State private var tempModifiers: QuickPasteModifiers

    init(modifiers: Binding<QuickPasteModifiers>) {
        _modifiers = modifiers
        _tempModifiers = State(initialValue: modifiers.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                SettingsPageIcon(systemName: "keyboard")
                Text(L10n.string("settings.shortcuts.modifiers.title"))
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle(L10n.string("settings.shortcuts.modifier.command"), isOn: $tempModifiers.command)
                Toggle(L10n.string("settings.shortcuts.modifier.control"), isOn: $tempModifiers.control)
                Toggle(L10n.string("settings.shortcuts.modifier.option"), isOn: $tempModifiers.option)
                Toggle(L10n.string("settings.shortcuts.modifier.shift"), isOn: $tempModifiers.shift)
            }
            .toggleStyle(.checkbox)

            Text(L10n.format("settings.shortcuts.modifiers.preview", tempModifiers.displayString))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            if !tempModifiers.isValid {
                Label(L10n.string("settings.shortcuts.modifiers.required"), systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

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
        .padding(22)
        .frame(width: 340)
    }
}

struct ShortcutRecorderRow: View {
    let icon: String
    let title: String
    let name: KeyboardShortcuts.Name

    var body: some View {
        HStack(spacing: 12) {
            SettingsRowIcon(systemName: icon)
            Text(title)
            Spacer(minLength: 16)
            KeyboardShortcuts.Recorder(for: name)
        }
        .padding(.vertical, 11)
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 36)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor)
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 76, height: 76)
            .shadow(color: .black.opacity(0.16), radius: 10, y: 4)

            Text("PasteDeck")
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 16)

            Text(L10n.format(
                "settings.about.version",
                appVersion,
                L10n.string("settings.about.beta")
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 3)

            Text(L10n.string("settings.about.tagline"))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            HStack(spacing: 10) {
                Link(destination: URL(string: "https://github.com/example/PasteDeck")!) {
                    Label(L10n.string("settings.about.github"), systemImage: "link")
                }
                .buttonStyle(.bordered)

                Link(destination: URL(string: "https://github.com/example/PasteDeck/issues")!) {
                    Label(L10n.string("settings.about.report_issue"), systemImage: "exclamationmark.bubble")
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)
            .padding(.top, 18)

            Spacer()

            VStack(spacing: 3) {
                Text("© 2025 PasteDeck Contributors")
                Text(L10n.string("settings.about.license"))
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
}

// MARK: - Shared Components

private struct PasteModeSelector: View {
    @Binding var selection: String
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        HStack(spacing: 3) {
            PasteModeSegment(
                title: L10n.string("settings.general.paste_active_app"),
                icon: "cursorarrow.click.2",
                isSelected: selection == "activeApp"
            ) {
                select("activeApp")
            }

            PasteModeSegment(
                title: L10n.string("settings.general.paste_clipboard"),
                icon: "clipboard",
                isSelected: selection == "clipboard"
            ) {
                select("clipboard")
            }
        }
        .padding(3)
        .frame(width: 390)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.string("settings.general.paste_items"))
    }

    private func select(_ mode: String) {
        withAnimation(accessibilityReduceMotion ? nil : .easeInOut(duration: 0.15)) {
            selection = mode
        }
    }
}

private struct PasteModeSegment: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(segmentBackground)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var segmentBackground: Color {
        if isSelected {
            return .accentColor
        }
        if isHovered {
            return Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
        }
        return .clear
    }
}

private struct SettingsPage<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 11) {
                    SettingsPageIcon(systemName: icon)
                    Text(title)
                        .font(.system(size: 22, weight: .semibold))
                }
                .padding(.bottom, 2)

                content
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.35))
    }
}

private struct SettingsPageIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.11), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.07), radius: 4, y: 2)
    }
}

private struct SettingsSection<Content: View>: View {
    var title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 15)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.045), radius: 4, y: 1)
        }
    }
}

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    init(icon: String, title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        _isOn = isOn
    }

    var body: some View {
        HStack(spacing: 12) {
            SettingsRowIcon(systemName: icon)

            Text(title)
                .lineLimit(2)

            Spacer(minLength: 12)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 10)
    }
}

private struct SettingsRowIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(width: 18)
            .accessibilityHidden(true)
    }
}

private struct SettingsRowDivider: View {
    var leadingInset: CGFloat = 30

    var body: some View {
        Divider()
            .padding(.leading, leadingInset)
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ClipboardViewModel(monitor: ClipboardMonitor()))
    }
}
#endif
