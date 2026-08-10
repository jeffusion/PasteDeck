//
//  CardGridView.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI

enum ClipCardAction {
    case select
    case copy
    case copyAndPaste
    case toggleFavorite
    case togglePin
    case delete
}

struct CardGridView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    @EnvironmentObject var focusManager: FocusManager
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Binding var selectedItem: ClipItem?

    private let cardSpacing: CGFloat = 12
    private let cardSize: CGFloat = 180
    private let contentPadding: CGFloat = 16

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                // The transparent margins provide both content padding and reveal padding.
                LazyHStack(spacing: cardSpacing - (contentPadding * 2)) {
                    ForEach(viewModel.filteredItems) { item in
                        HStack(spacing: 0) {
                            revealSpacer

                            ClipCardView(
                                item: item,
                                isSelected: selectedItem?.id == item.id,
                                onAction: { action in
                                    handle(action, for: item)
                                }
                            )
                            .equatable()

                            revealSpacer
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .id(item.id)
                    }
                }
                .padding(.vertical, contentPadding)
            }
            .frame(height: cardSize + (contentPadding * 2))
            .onChange(of: selectedItem) { newSelection in
                // A nil anchor scrolls only as far as needed to reveal the full card.
                if let item = newSelection {
                    reveal(item, using: proxy)
                }
            }
            .onChange(of: viewModel.filteredItems.map(\.id)) { _ in
                // Pinning reorders the list without necessarily changing the selection.
                DispatchQueue.main.async {
                    guard let item = selectedItem else { return }
                    reveal(item, using: proxy)
                }
            }
        }
    }

    private func reveal(_ item: ClipItem, using proxy: ScrollViewProxy) {
        if accessibilityReduceMotion {
            proxy.scrollTo(item.id)
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(item.id)
            }
        }
    }

    private func handle(_ action: ClipCardAction, for item: ClipItem) {
        switch action {
        case .select:
            focusManager.clearSearchFocus()
            selectedItem = item
        case .copy:
            viewModel.copyItem(item)
        case .copyAndPaste:
            focusManager.clearSearchFocus()
            viewModel.copyAndPaste(item)
        case .toggleFavorite:
            viewModel.toggleFavorite(item)
        case .togglePin:
            selectedItem = item
            viewModel.togglePin(item)
        case .delete:
            viewModel.deleteItem(item)
        }
    }

    private var revealSpacer: some View {
        Color.clear
            .frame(width: contentPadding)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Preview

#if DEBUG
struct CardGridView_Previews: PreviewProvider {
    static var previews: some View {
        CardGridView(selectedItem: .constant(nil))
            .environmentObject(ClipboardViewModel.preview)
            .environmentObject(FocusManager())
            .frame(height: 200)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}
#endif
