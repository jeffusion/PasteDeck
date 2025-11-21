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

    var body: some View {
        VStack(spacing: 0) {
            // Header with search and filters
            HeaderView()

            Divider()

            // Main content
            if viewModel.filteredItems.isEmpty {
                EmptyStateView()
            } else {
                ClipListView(selectedItem: $selectedItem)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - Header View

struct HeaderView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search clipboard...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)

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
