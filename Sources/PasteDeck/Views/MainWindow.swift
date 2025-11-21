//
//  MainWindow.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI

struct MainWindow: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    @State private var selectedItem: ClipItem?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Compact header with search
            DrawerHeaderView(isSearchFocused: $isSearchFocused)

            // Main content - horizontal card grid
            if viewModel.filteredItems.isEmpty {
                DrawerEmptyStateView()
            } else {
                CardGridView(selectedItem: $selectedItem)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        .onAppear {
            // Select first item by default
            if selectedItem == nil && !viewModel.filteredItems.isEmpty {
                selectedItem = viewModel.filteredItems.first
            }
        }
        .onChange(of: viewModel.filteredItems) { newItems in
            // Keep selection valid
            if let selected = selectedItem, !newItems.contains(where: { $0.id == selected.id }) {
                selectedItem = newItems.first
            }
        }
        .background(
            KeyboardEventHandler(
                onLeftArrow: { moveSelection(by: -1) },
                onRightArrow: { moveSelection(by: 1) },
                onReturn: {
                    guard let item = selectedItem else { return }
                    viewModel.copyAndPaste(item)
                },
                onDelete: {
                    if let item = selectedItem {
                        viewModel.deleteItem(item)
                    }
                },
                onEscape: {
                    viewModel.onRequestClose?()
                }
            )
        )
    }

    private func moveSelection(by offset: Int) {
        guard !viewModel.filteredItems.isEmpty else { return }

        if let current = selectedItem,
           let currentIndex = viewModel.filteredItems.firstIndex(where: { $0.id == current.id }) {
            let newIndex = max(0, min(viewModel.filteredItems.count - 1, currentIndex + offset))
            selectedItem = viewModel.filteredItems[newIndex]
        } else {
            selectedItem = viewModel.filteredItems.first
        }
    }
}

// MARK: - Keyboard Event Handler

struct KeyboardEventHandler: NSViewRepresentable {
    var onLeftArrow: () -> Void
    var onRightArrow: () -> Void
    var onReturn: () -> Void
    var onDelete: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> KeyboardView {
        let view = KeyboardView()
        view.onLeftArrow = onLeftArrow
        view.onRightArrow = onRightArrow
        view.onReturn = onReturn
        view.onDelete = onDelete
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: KeyboardView, context: Context) {
        nsView.onLeftArrow = onLeftArrow
        nsView.onRightArrow = onRightArrow
        nsView.onReturn = onReturn
        nsView.onDelete = onDelete
        nsView.onEscape = onEscape
    }

    class KeyboardView: NSView {
        var onLeftArrow: (() -> Void)?
        var onRightArrow: (() -> Void)?
        var onReturn: (() -> Void)?
        var onDelete: (() -> Void)?
        var onEscape: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 123: // Left arrow
                onLeftArrow?()
            case 124: // Right arrow
                onRightArrow?()
            case 36: // Return
                onReturn?()
            case 51: // Delete
                onDelete?()
            case 53: // Escape
                onEscape?()
            default:
                super.keyDown(with: event)
            }
        }
    }
}

// MARK: - Drawer Header View

struct DrawerHeaderView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    var isSearchFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 12) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Search...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused(isSearchFocused)

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .frame(maxWidth: 200)

            // Content type filter (compact)
            Picker("", selection: $viewModel.contentFilter) {
                ForEach(ClipItem.ContentFilter.allCases, id: \.self) { filter in
                    Image(systemName: filter.iconName)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 180)

            Spacer()

            // Item count
            Text("\(viewModel.filteredItems.count) items")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
    }
}

// MARK: - Drawer Empty State View

struct DrawerEmptyStateView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.isSearching ? "magnifyingglass" : "doc.on.clipboard")
                .font(.system(size: 24))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.isSearching ? "No results found" : "No clipboard history")
                    .font(.headline)

                Text(viewModel.isSearching ?
                     "Try a different search term" :
                     "Copy something to get started")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
struct MainWindow_Previews: PreviewProvider {
    static var previews: some View {
        MainWindow()
            .environmentObject(ClipboardViewModel.preview)
            .frame(width: 800, height: 220)
    }
}
#endif
