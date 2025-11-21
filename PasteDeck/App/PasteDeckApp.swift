//
//  PasteDeckApp.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI

@main
struct PasteDeckApp: App {
    // MARK: - Properties

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Scene

    var body: some Scene {
        // We don't use a regular window scene because this is a menu bar app
        // The main window will be shown/hidden via AppDelegate
        Settings {
            SettingsView()
        }
    }
}
