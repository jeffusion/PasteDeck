//
//  ClipListView.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI

struct ClipListView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    @Binding var selectedItem: ClipItem?

    var body: some View {
        List(selection: $selectedItem) {
            ForEach(viewModel.filteredItems) { item in
                ClipItemRow(item: item)
                    .tag(item)
                    .contextMenu {
                        ClipItemContextMenu(item: item)
                    }
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Clip Item Row

struct ClipItemRow: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    let item: ClipItem

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: item.content.iconName)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(item.title)
                    .font(.body)
                    .lineLimit(2)

                // Preview
                Text(item.content.previewString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Metadata
                HStack(spacing: 8) {
                    // Source app
                    if let sourceApp = item.sourceApp {
                        Label(sourceApp, systemImage: "app")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Timestamp
                    Label(item.relativeTimestamp, systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    // Size
                    if item.content.estimatedSize > 1024 {
                        Label(item.sizeDescription, systemImage: "opticaldiscdrive")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Badges
            HStack(spacing: 4) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }

                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            viewModel.copyAndPaste(item)
        }
        .onTapGesture(count: 1) {
            viewModel.copyItem(item)
        }
    }
}

// MARK: - Context Menu

struct ClipItemContextMenu: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    let item: ClipItem

    var body: some View {
        Button("Copy") {
            viewModel.copyItem(item)
        }

        Button("Copy and Paste") {
            viewModel.copyAndPaste(item)
        }

        Divider()

        Button(item.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            viewModel.toggleFavorite(item)
        }

        Button(item.isPinned ? "Unpin" : "Pin to Top") {
            viewModel.togglePin(item)
        }

        Divider()

        Button("Delete", role: .destructive) {
            viewModel.deleteItem(item)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ClipListView_Previews: PreviewProvider {
    static var previews: some View {
        ClipListView(selectedItem: .constant(nil))
            .environmentObject(ClipboardViewModel.preview)
            .frame(width: 600, height: 500)
    }
}
#endif
