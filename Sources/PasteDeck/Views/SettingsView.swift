//
//  SettingsView.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI

// MARK: - Settings Navigation Item

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "通用"
    case privacy = "隐私"
    case shortcuts = "键盘快捷键"
    case about = "关于"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .privacy: return "hand.raised"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
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
                Label(tab.rawValue, systemImage: tab.icon)
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
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("pasteMode") private var pasteMode = "activeApp"
    @AppStorage("alwaysPastePlainText") private var alwaysPastePlainText = false
    @AppStorage("historyRetentionDays") private var historyRetentionDays = 30

    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private let retentionOptions: [(String, Int)] = [
        ("天", 1),
        ("周", 7),
        ("个月", 30),
        ("年", 365),
        ("永久", -1)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text("通用")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)

                // Basic Settings Group
                SettingsGroupBox {
                    SettingsToggleRow(title: "登录时打开", isOn: $launchAtLogin)
                    Divider()
                    SettingsToggleRow(title: "iCloud 同步", isOn: $iCloudSyncEnabled, subtitle: iCloudSyncEnabled ? "已同步" : nil)
                    Divider()
                    SettingsToggleRow(title: "显示在菜单栏上", isOn: $showInMenuBar)
                    Divider()
                    SettingsToggleRow(title: "音效", isOn: $soundEnabled)
                }

                // Paste Mode Group
                Text("粘贴项目")
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

                                Text("到当前活动应用")
                                    .fontWeight(pasteMode == "activeApp" ? .medium : .regular)
                            }

                            Text("将选定的项目直接粘贴到您当前正在使用的应用程序中。")
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

                                Text("到剪贴板")
                                    .fontWeight(pasteMode == "clipboard" ? .medium : .regular)
                            }

                            Text("将选定的项目复制到系统剪贴板，以便稍后手动粘贴。")
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

                            Text("始终以纯文本粘贴")
                        }
                    }
                }

                // History Retention Group
                Text("保留历史")
                    .font(.headline)
                    .padding(.top, 8)

                SettingsGroupBox {
                    VStack(spacing: 16) {
                        // Slider
                        HStack {
                            ForEach(retentionOptions, id: \.1) { option in
                                Text(option.0)
                                    .font(.caption)
                                    .foregroundColor(historyRetentionDays == option.1 ? .primary : .secondary)
                                    .fontWeight(historyRetentionDays == option.1 ? .medium : .regular)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        Slider(
                            value: Binding(
                                get: { Double(retentionOptions.firstIndex(where: { $0.1 == historyRetentionDays }) ?? 2) },
                                set: { historyRetentionDays = retentionOptions[Int($0)].1 }
                            ),
                            in: 0...Double(retentionOptions.count - 1),
                            step: 1
                        )

                        HStack {
                            Spacer()
                            Button("删除历史...") {
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
            }
            .onChange(of: launchAtLogin) { newValue in
                // Sync system state with user preference
                let actualState = LaunchAtLoginService.shared.sync(with: newValue)

                // If sync failed, revert the toggle
                if actualState != newValue {
                    launchAtLogin = actualState
                    errorMessage = "无法更改登录时打开设置，请检查系统权限。"
                    showErrorAlert = true
                }
            }
        }
        .alert("设置失败", isPresented: $showErrorAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(errorMessage)
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
                Text("隐私")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)

                // Accessibility Permission
                Text("辅助功能权限")
                    .font(.headline)

                SettingsGroupBox {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(hasAccessibilityPermission ? .green : .orange)
                                Text(hasAccessibilityPermission ? "已授权" : "未授权")
                                    .fontWeight(.medium)
                            }

                            Text("需要辅助功能权限才能使用自动粘贴功能")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !hasAccessibilityPermission {
                            Button("打开引导") {
                                AccessibilityPermissionGuide.shared.showGuide()
                            }
                        }
                    }
                }

                // Excluded Apps
                Text("排除的应用")
                    .font(.headline)
                    .padding(.top, 8)

                SettingsGroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("以下应用的剪贴板内容将不会被捕获：")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if excludedApps.isEmpty {
                            Text("暂无排除的应用")
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
                                }
                            }
                        }

                        Divider()

                        Button("添加应用...") {
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
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("键盘快捷键")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)

                SettingsGroupBox {
                    VStack(spacing: 12) {
                        ShortcutRow(title: "显示 PasteDeck", shortcut: "⌘⇧V")
                        Divider()
                        ShortcutRow(title: "清除历史", shortcut: "⌘⇧⌫")
                        Divider()
                        ShortcutRow(title: "搜索剪贴板", shortcut: "⌘⇧F")
                    }
                }

                Text("提示：点击快捷键可以自定义")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(24)
        }
    }
}

struct ShortcutRow: View {
    let title: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
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

            Text("Version 0.1.0 (Beta)")
                .foregroundColor(.secondary)

            Text("一款现代化的开源 macOS 剪贴板管理器")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/example/PasteDeck")!) {
                    Label("在 GitHub 上查看", systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/example/PasteDeck/issues")!) {
                    Label("报告问题", systemImage: "exclamationmark.bubble")
                }
            }

            Spacer()

            VStack(spacing: 4) {
                Text("© 2025 PasteDeck Contributors")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("MIT 许可证")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
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
