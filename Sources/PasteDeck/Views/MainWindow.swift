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
            // Header with search and filters
            HeaderView(isSearchFocused: $isSearchFocused)

            Divider()

            // Main content
            if viewModel.filteredItems.isEmpty {
                EmptyStateView()
            } else {
                ClipListView(selectedItem: $selectedItem)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
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
                onUpArrow: { moveSelection(by: -1) },
                onDownArrow: { moveSelection(by: 1) },
                onReturn: {
                    guard let item = selectedItem else { return }
                    if NSEvent.modifierFlags.contains(.command) {
                        viewModel.copyAndPaste(item)
                    } else {
                        viewModel.copyItem(item)
                    }
                },
                onDelete: {
                    if let item = selectedItem {
                        viewModel.deleteItem(item)
                    }
                },
                onEscape: {
                    NSApp.keyWindow?.close()
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
    var onUpArrow: () -> Void
    var onDownArrow: () -> Void
    var onReturn: () -> Void
    var onDelete: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> KeyboardView {
        let view = KeyboardView()
        view.onUpArrow = onUpArrow
        view.onDownArrow = onDownArrow
        view.onReturn = onReturn
        view.onDelete = onDelete
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: KeyboardView, context: Context) {
        nsView.onUpArrow = onUpArrow
        nsView.onDownArrow = onDownArrow
        nsView.onReturn = onReturn
        nsView.onDelete = onDelete
        nsView.onEscape = onEscape
    }

    class KeyboardView: NSView {
        var onUpArrow: (() -> Void)?
        var onDownArrow: (() -> Void)?
        var onReturn: (() -> Void)?
        var onDelete: (() -> Void)?
        var onEscape: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 126: // Up arrow
                onUpArrow?()
            case 125: // Down arrow
                onDownArrow?()
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

// MARK: - Header View

struct HeaderView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    var isSearchFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search clipboard...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .focused(isSearchFocused)

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            // Filters
            HStack {
                // Content type filter
                Picker("Type", selection: $viewModel.contentFilter) {
                    ForEach(ClipItem.ContentFilter.allCases, id: \.self) { filter in
                        Label(filter.rawValue, systemImage: filter.iconName)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Spacer()

                // Date filter
                Menu {
                    ForEach(ClipItem.DateFilter.allCases, id: \.self) { filter in
                        Button(filter.rawValue) {
                            viewModel.dateFilter = filter
                        }
                    }
                } label: {
                    Label(viewModel.dateFilter.rawValue, systemImage: "calendar")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 120)
            }
        }
        .padding()
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.isSearching ? "magnifyingglass" : "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(viewModel.isSearching ? "No results found" : "No clipboard history")
                .font(.title2)
                .fontWeight(.medium)

            Text(viewModel.isSearching ?
                 "Try a different search term" :
                 "Copy something to get started")
                .foregroundColor(.secondary)
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
            .frame(width: 600, height: 500)
    }
}
#endif
