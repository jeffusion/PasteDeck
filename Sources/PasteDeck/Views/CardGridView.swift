//
//  CardGridView.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI

struct CardGridView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    @Binding var selectedItem: ClipItem?

    private let cardSpacing: CGFloat = 12
    private let cardSize: CGFloat = 180

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(spacing: cardSpacing) {
                    ForEach(viewModel.filteredItems) { item in
                        ClipCardView(
                            item: item,
                            isSelected: selectedItem?.id == item.id,
                            onSelect: {
                                selectedItem = item
                            }
                        )
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: selectedItem) { newSelection in
                // Scroll to selected item
                if let item = newSelection {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(item.id, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CardGridView_Previews: PreviewProvider {
    static var previews: some View {
        CardGridView(selectedItem: .constant(nil))
            .environmentObject(ClipboardViewModel.preview)
            .frame(height: 200)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}
#endif
