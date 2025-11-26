//
//  FocusManager.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI
import Combine

@MainActor
class FocusManager: ObservableObject {
    @Published var focusClearRequest: UUID?

    func clearSearchFocus() {
        focusClearRequest = UUID()
    }
}
