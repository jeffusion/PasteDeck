//
//  MainWindow.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI
import AppKit

struct MainWindow: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    @State private var selectedItem: ClipItem?
    @FocusState private var isSearchFocused: Bool
    @StateObject private var focusManager = FocusManager()
    @State private var shouldReclaimKeyboardFocus = false

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
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss search focus when tapping outside
            isSearchFocused = false
        }
        .environmentObject(focusManager)
        .onChange(of: focusManager.focusClearRequest) { request in
            if request != nil {
                isSearchFocused = false
            }
        }
        .onChange(of: isSearchFocused) { focused in
            if !focused {
                // Reclaim keyboard focus for navigation when search loses focus
                shouldReclaimKeyboardFocus = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    shouldReclaimKeyboardFocus = false
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
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
        .onChange(of: viewModel.resetUITrigger) { trigger in
            // Reset local UI state when drawer is closed
            if trigger != nil {
                selectedItem = nil
                isSearchFocused = false
            }
        }
        .onChange(of: viewModel.selectFirstItemTrigger) { trigger in
            // Select first item when drawer is opened
            if trigger != nil && !viewModel.filteredItems.isEmpty {
                selectedItem = viewModel.filteredItems.first
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
                },
                shouldReclaimFocus: shouldReclaimKeyboardFocus
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
    var shouldReclaimFocus: Bool

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

        // Reclaim focus when requested (to fix keyboard navigation after search unfocus)
        if shouldReclaimFocus {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
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
    @EnvironmentObject var focusManager: FocusManager
    var isSearchFocused: FocusState<Bool>.Binding
    @State private var isSearchHovered = false
    @State private var isSearchExpanded = false
    @Namespace private var searchAnimation

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 12) {
                Spacer()
                    .frame(width: isSearchExpanded ? leadingSpacerWidth(containerWidth: geometry.size.width) : nil)

                    // Search component (single view with smooth transitions)
                    HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(isSearchExpanded ? .caption : .system(size: 14))
                        .foregroundColor(.secondary)

                    if isSearchExpanded {
                        TextField("Search...", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .focused(isSearchFocused)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))

                        if !viewModel.searchText.isEmpty {
                            Button(action: { viewModel.searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                    }
                }
                .padding(.horizontal, isSearchExpanded ? 12 : 0)
                .padding(.vertical, isSearchExpanded ? 6 : 0)
                .frame(
                    width: isSearchExpanded ? 200 : 32,
                    height: 32
                )
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSearchFocused.wrappedValue ? Color.accentColor :
                            (isSearchHovered ? Color.secondary.opacity(0.5) : Color.secondary.opacity(0.3)),
                            lineWidth: isSearchFocused.wrappedValue ? 1.5 : 1
                        )
                )
                .matchedGeometryEffect(id: "searchBox", in: searchAnimation)
                .onTapGesture {
                    if !isSearchExpanded {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearchExpanded = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isSearchFocused.wrappedValue = true
                        }
                    }
                }
                .onHover { hovering in
                    isSearchHovered = hovering
                }

                // Content type filter (Paste style)
                HStack(spacing: isSearchExpanded ? 6 : 8) {
                    ForEach(ClipItem.ContentFilter.allCases, id: \.self) { filter in
                        FilterButton(
                            filter: filter,
                            isSelected: viewModel.contentFilter == filter,
                            isCompact: isSearchExpanded,
                            action: {
                                // Clear search focus and collapse when filter is clicked
                                focusManager.clearSearchFocus()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.searchText = ""
                                    isSearchExpanded = false
                                    viewModel.contentFilter = filter
                                }
                            }
                        )
                    }
                }
                .fixedSize()

                // Item count
                Text("\(viewModel.filteredItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize()

                Spacer()
                    .frame(width: isSearchExpanded ? 0 : nil)
            }
            .frame(height: 44)
        }
        .frame(height: 44)
        .onChange(of: isSearchFocused.wrappedValue) { focused in
            // Collapse search if lost focus and no content
            if !focused && viewModel.searchText.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearchExpanded = false
                }
            }
        }
        .onChange(of: viewModel.searchText) { newText in
            // Expand search if user starts typing (edge case: direct text input)
            if !newText.isEmpty && !isSearchExpanded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearchExpanded = true
                }
            }
            // Collapse search if text is cleared while not focused
            if newText.isEmpty && !isSearchFocused.wrappedValue && isSearchExpanded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearchExpanded = false
                }
            }
        }
        .overlay(alignment: .trailing) {
            // Menu button - overlaid at trailing edge
            DrawerMenuButton(itemCount: viewModel.items.count)
                .padding(.trailing, 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func leadingSpacerWidth(containerWidth: CGFloat) -> CGFloat {
        let searchWidth: CGFloat = 200 // 展开后的搜索框宽度
        let horizontalPadding: CGFloat = 16 * 2 // 左右各 16 padding
        let spacing: CGFloat = 12 // HStack spacing

        // 搜索框中心应该在容器中心
        // leadingSpace + spacing + searchWidth/2 = (containerWidth - horizontalPadding) / 2
        let availableWidth = containerWidth - horizontalPadding
        let idealLeadingSpace = (availableWidth - searchWidth) / 2 - spacing

        return max(0, idealLeadingSpace)
    }
}

// MARK: - Drawer Menu Button

struct DrawerMenuButton: View {
    let itemCount: Int
    @State private var isHovered = false

    var body: some View {
        Menu {
            Button("设置...") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("关于 PasteDeck") {
                openAbout()
            }

            Divider()

            Text("\(itemCount) 项已捕获")

            Divider()

            Button("退出 PasteDeck") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isHovered ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.secondary.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .menuIndicator(.hidden)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func openSettings() {
        NotificationCenter.default.post(name: NSNotification.Name("ShowSettingsWindow"), object: nil)
    }

    private func openAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let filter: ClipItem.ContentFilter
    let isSelected: Bool
    let isCompact: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: isCompact ? 0 : 6) {
                Image(systemName: filter.iconName)
                    .font(.system(size: 12))

                if !isCompact {
                    Text(filter.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(.horizontal, isCompact ? 0 : 12)
            .padding(.vertical, isCompact ? 0 : 6)
            .frame(
                width: isCompact ? 28 : nil,
                height: 28
            )
            .background(
                Capsule()
                    .fill(isSelected ?
                          Color.accentColor.opacity(0.15) :  // 选中：品牌色背景
                          (isHovered ?
                           Color.secondary.opacity(0.08) :  // 悬停：轻微灰色背景
                           Color.clear))  // 默认：透明背景
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ?
                            Color.accentColor.opacity(0.6) :  // 选中：品牌色边框
                            (isHovered ?
                             Color.secondary.opacity(0.4) :  // 悬停：中等灰色边框
                             Color.secondary.opacity(0.2)),   // 默认：淡灰色边框
                     lineWidth: isSelected ? 1.5 : 1)  // 选中状态更粗的边框
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
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
