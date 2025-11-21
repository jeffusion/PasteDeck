//
//  SettingsView.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ExclusionsSettingsView()
                .tabItem {
                    Label("Exclusions", systemImage: "eye.slash")
                }

            SyncSettingsView()
                .tabItem {
                    Label("Sync", systemImage: "icloud")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("maxHistorySize") private var maxHistorySize = 200
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Form {
            Section {
                LabeledContent("History Size") {
                    Stepper("\(maxHistorySize) items", value: $maxHistorySize, in: 50...1000, step: 50)
                }

                Toggle("Launch at Login", isOn: $launchAtLogin)
            } header: {
                Text("General")
            }

            Section {
                LabeledContent("Keyboard Shortcut") {
                    Text("⌘⇧V")
                        .font(.system(.body, design: .monospaced))
                }
            } header: {
                Text("Shortcuts")
            } footer: {
                Text("Global keyboard shortcut to show PasteDeck")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Exclusions Settings

struct ExclusionsSettingsView: View {
    @State private var excludedApps: [String] = []

    var body: some View {
        VStack {
            Text("Excluded Applications")
                .font(.headline)

            Text("Clipboard content from these apps will not be captured")
                .font(.caption)
                .foregroundColor(.secondary)

            List {
                ForEach(excludedApps, id: \.self) { app in
                    HStack {
                        Image(systemName: "app")
                        Text(app)
                        Spacer()
                        Button(action: {
                            excludedApps.removeAll { $0 == app }
                        }) {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button("Add Application...") {
                // TODO: Show app picker
            }
        }
        .padding()
    }
}

// MARK: - Sync Settings

struct SyncSettingsView: View {
    @AppStorage("iCloudSyncEnabled") private var syncEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("Enable iCloud Sync", isOn: $syncEnabled)

                if syncEnabled {
                    LabeledContent("Status") {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Syncing")
                        }
                    }

                    LabeledContent("Last Sync") {
                        Text("Just now")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("iCloud")
            } footer: {
                Text("Sync clipboard history across your Mac devices using iCloud")
            }
        }
        .formStyle(.grouped)
        .padding()
        .disabled(!syncEnabled)
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("PasteDeck")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 0.1.0 (Beta)")
                .foregroundColor(.secondary)

            Text("A modern, open-source clipboard manager for macOS")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/yourusername/PasteDeck")!) {
                    Label("View on GitHub", systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/yourusername/PasteDeck/issues")!) {
                    Label("Report an Issue", systemImage: "exclamationmark.bubble")
                }
            }

            Spacer()

            Text("© 2025 PasteDeck Contributors")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Licensed under MIT License")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
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
