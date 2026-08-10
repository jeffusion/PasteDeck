//
//  LaunchAtLoginService.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import Foundation
import ServiceManagement

/// Service for managing launch at login functionality
@MainActor
class LaunchAtLoginService {
    // MARK: - Singleton

    static let shared = LaunchAtLoginService()

    private init() {}

    // MARK: - Public Properties

    /// Check if launch at login is currently enabled
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    // MARK: - Public Methods

    /// Enable launch at login
    /// - Throws: Error if registration fails
    func enable() throws {
        guard !isEnabled else { return }

        do {
            try SMAppService.mainApp.register()
        } catch {
            throw LaunchAtLoginError.registrationFailed(error)
        }
    }

    /// Disable launch at login
    /// - Throws: Error if unregistration fails
    func disable() throws {
        guard isEnabled else { return }

        do {
            try SMAppService.mainApp.unregister()
        } catch {
            throw LaunchAtLoginError.unregistrationFailed(error)
        }
    }

    /// Sync system state with user preference
    /// - Parameter userPreference: The desired state from user settings
    /// - Returns: The actual state after sync (may differ if operation failed)
    @discardableResult
    func sync(with userPreference: Bool) -> Bool {
        do {
            if userPreference {
                try enable()
            } else {
                try disable()
            }
            return isEnabled
        } catch {
            return isEnabled
        }
    }
}

// MARK: - Error Types

enum LaunchAtLoginError: LocalizedError {
    case registrationFailed(Error)
    case unregistrationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let error):
            return L10n.format("service.launch_at_login.enable_error", error.localizedDescription)
        case .unregistrationFailed(let error):
            return L10n.format("service.launch_at_login.disable_error", error.localizedDescription)
        }
    }
}
