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

            // Keep the content region stable when filters switch between results and empty state.
            Group {
                if viewModel.filteredItems.isEmpty {
                    DrawerEmptyStateView()
                } else {
                    CardGridView(selectedItem: $selectedItem)
                }
            }
            .frame(height: 212)
        }
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isSearchFocused = false
                }
        }
        .environmentObject(focusManager)
        .onChange(of: focusManager.focusClearRequest) { request in
            if request != nil {
                isSearchFocused = false
            }
        }
        .onChange(of: isSearchFocused) { focused in
            if !focused {
                reclaimKeyboardFocus()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
        .onAppear {
            // Select first item by default
            if selectedItem == nil && !viewModel.filteredItems.isEmpty {
                selectedItem = viewModel.filteredItems.first
            }
            reclaimKeyboardFocus()
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
            if trigger != nil {
                if !viewModel.filteredItems.isEmpty {
                    selectedItem = viewModel.filteredItems.first
                }
                reclaimKeyboardFocus()
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
                onSearch: {
                    isSearchFocused = true
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

    private func reclaimKeyboardFocus() {
        shouldReclaimKeyboardFocus = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            shouldReclaimKeyboardFocus = false
        }
    }
}

// MARK: - Keyboard Event Handler

struct KeyboardEventHandler: NSViewRepresentable {
    var onLeftArrow: () -> Void
    var onRightArrow: () -> Void
    var onReturn: () -> Void
    var onDelete: () -> Void
    var onSearch: () -> Void
    var onEscape: () -> Void
    var shouldReclaimFocus: Bool

    func makeNSView(context: Context) -> KeyboardView {
        let view = KeyboardView()
        view.onLeftArrow = onLeftArrow
        view.onRightArrow = onRightArrow
        view.onReturn = onReturn
        view.onDelete = onDelete
        view.onSearch = onSearch
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: KeyboardView, context: Context) {
        nsView.onLeftArrow = onLeftArrow
        nsView.onRightArrow = onRightArrow
        nsView.onReturn = onReturn
        nsView.onDelete = onDelete
        nsView.onSearch = onSearch
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
        var onSearch: (() -> Void)?
        var onEscape: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "f" {
                onSearch?()
                return
            }

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
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    var isSearchFocused: FocusState<Bool>.Binding
    @State private var isSearchHovered = false
    @State private var isSearchExpanded = false
    @State private var collapsedControlsWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: controlsLeadingOffset(containerWidth: geometry.size.width))

                HStack(spacing: 10) {
                    // The search keeps the centered group's original leading edge.
                    ZStack(alignment: .leading) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField(L10n.string("drawer.search.placeholder"), text: $viewModel.searchText)
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
                                .help(L10n.string("drawer.search.clear"))
                                .accessibilityLabel(L10n.string("drawer.search.clear"))
                            }
                        }
                        .padding(.horizontal, 12)
                        .opacity(isSearchExpanded ? 1 : 0)
                        .allowsHitTesting(isSearchExpanded)
                        .accessibilityHidden(!isSearchExpanded)

                        if !isSearchExpanded {
                            Button(action: expandSearch) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .frame(width: 34, height: 34)
                                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .help(L10n.string("drawer.search.history"))
                            .accessibilityLabel(L10n.string("drawer.search.history"))
                        }
                    }
                    .frame(width: isSearchExpanded ? 210 : 34, height: 34, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSearchHovered ? controlHoverColor : controlSurfaceColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                isSearchFocused.wrappedValue ? Color.accentColor :
                                    Color.primary.opacity(0.12),
                                lineWidth: isSearchFocused.wrappedValue ? 1.5 : 0.5
                            )
                            .allowsHitTesting(false)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
                    .animation(searchAnimation, value: isSearchExpanded)
                    .onHover { hovering in
                        isSearchHovered = hovering
                    }

                    // Content type filter (Paste style)
                    HStack(spacing: 2) {
                        ForEach(ClipItem.ContentFilter.allCases, id: \.self) { filter in
                            FilterButton(
                                filter: filter,
                                isSelected: viewModel.contentFilter == filter,
                                action: {
                                    focusManager.clearSearchFocus()
                                    withAnimation(filterSelectionAnimation) {
                                        viewModel.contentFilter = filter
                                    }
                                }
                            )
                        }
                    }
                    .fixedSize()
                    .backgroundPreferenceValue(FilterButtonBoundsPreferenceKey.self) { bounds in
                        GeometryReader { proxy in
                            if let anchor = bounds[viewModel.contentFilter.rawValue] {
                                let frame = proxy[anchor]

                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.accentColor)
                                    .frame(width: frame.width, height: frame.height)
                                    .position(x: frame.midX, y: frame.midY)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                                    .animation(
                                        filterSelectionAnimation,
                                        value: viewModel.contentFilter
                                    )
                            }
                        }
                    }
                    .padding(3)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(controlSurfaceColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
                            .allowsHitTesting(false)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 5, y: 2)

                    Text(L10n.integer(viewModel.filteredItems.count))
                    .monospacedDigit()
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .center)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        L10n.format(
                            "drawer.count.accessibility",
                            L10n.plural("count.items", count: viewModel.filteredItems.count)
                        )
                    )
                }
                .fixedSize()
                .background(
                    GeometryReader { controlsGeometry in
                        Color.clear.preference(
                            key: CollapsedControlsWidthPreferenceKey.self,
                            value: isSearchExpanded ? 0 : controlsGeometry.size.width
                        )
                    }
                )

                Spacer(minLength: 0)
            }
            .frame(height: 44)
        }
        .frame(height: 44)
        .onPreferenceChange(CollapsedControlsWidthPreferenceKey.self) { width in
            guard width > 0, !isSearchExpanded else { return }
            collapsedControlsWidth = width
        }
        .onChange(of: isSearchFocused.wrappedValue) { focused in
            if focused && !isSearchExpanded {
                withAnimation(searchAnimation) {
                    isSearchExpanded = true
                }
            } else if !focused && viewModel.searchText.isEmpty {
                withAnimation(searchAnimation) {
                    isSearchExpanded = false
                }
            }
        }
        .onChange(of: viewModel.searchText) { newText in
            // Expand search if user starts typing (edge case: direct text input)
            if !newText.isEmpty && !isSearchExpanded {
                withAnimation(searchAnimation) {
                    isSearchExpanded = true
                }
            }
            // Collapse search if text is cleared while not focused
            if newText.isEmpty && !isSearchFocused.wrappedValue && isSearchExpanded {
                withAnimation(searchAnimation) {
                    isSearchExpanded = false
                }
            }
        }
        .overlay(alignment: .trailing) {
            DrawerMenuButton(itemCount: viewModel.items.count)
                .padding(.trailing, 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func controlsLeadingOffset(containerWidth: CGFloat) -> CGFloat? {
        guard collapsedControlsWidth > 0 else { return nil }
        return max(0, (containerWidth - collapsedControlsWidth) / 2)
    }

    private var searchAnimation: Animation? {
        accessibilityReduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    private var filterSelectionAnimation: Animation? {
        accessibilityReduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86)
    }

    private var controlSurfaceColor: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    private var controlHoverColor: Color {
        Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    }

    private func expandSearch() {
        withAnimation(searchAnimation) {
            isSearchExpanded = true
        }

        DispatchQueue.main.async {
            guard isSearchExpanded else { return }
            isSearchFocused.wrappedValue = true
        }
    }
}

private struct CollapsedControlsWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct FilterButtonBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [String: Anchor<CGRect>],
        nextValue: () -> [String: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

// MARK: - Drawer Menu Button

struct DrawerMenuButton: View {
    let itemCount: Int
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var isHovered = false

    var body: some View {
        Menu {
            Button(L10n.string("drawer.menu.settings")) {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Button(L10n.string("drawer.menu.about")) {
                openAbout()
            }

            Divider()

            Text(L10n.plural("count.captured", count: itemCount))

            Divider()

            Button(L10n.string("drawer.menu.quit")) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        Color(nsColor: isHovered ?
                            .unemphasizedSelectedContentBackgroundColor : .controlBackgroundColor)
                    )

                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(width: 34, height: 34)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .menuIndicator(.hidden)
        .onHover { hovering in
            withAnimation(accessibilityReduceMotion ? nil : .easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(L10n.string("drawer.menu.more"))
        .accessibilityLabel(L10n.string("drawer.menu.more"))
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
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.iconName)
                    .font(.system(size: 12))

                ZStack {
                    Text(filter.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .opacity(isSelected ? 0 : 1)

                    Text(filter.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(isSelected ? 1 : 0)
                }
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .unemphasizedSelectedContentBackgroundColor))
                    .opacity(isHovered && !isSelected ? 1 : 0)
                    .allowsHitTesting(false)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .help(filter.displayName)
        .accessibilityLabel(filter.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .anchorPreference(key: FilterButtonBoundsPreferenceKey.self, value: .bounds) {
            [filter.rawValue: $0]
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .pointingHandCursor()
    }
}

private extension View {
    @ViewBuilder
    func pointingHandCursor() -> some View {
        if #available(macOS 15.0, *) {
            pointerStyle(.link)
        } else {
            background(PointingHandCursorRect())
        }
    }
}

private struct PointingHandCursorRect: NSViewRepresentable {
    func makeNSView(context: Context) -> PointingHandCursorRectView {
        PointingHandCursorRectView()
    }

    func updateNSView(_ nsView: PointingHandCursorRectView, context: Context) {
        nsView.invalidateCursorRect()
    }
}

private final class PointingHandCursorRectView: NSView {
    override func resetCursorRects() {
        super.resetCursorRects()

        let cursorRect = bounds.intersection(visibleRect)
        guard !cursorRect.isEmpty else { return }
        addCursorRect(cursorRect, cursor: .pointingHand)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        invalidateCursorRect()
    }

    override func setFrameSize(_ newSize: NSSize) {
        let sizeChanged = frame.size != newSize
        super.setFrameSize(newSize)

        if sizeChanged {
            invalidateCursorRect()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func invalidateCursorRect() {
        window?.invalidateCursorRects(for: self)
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
                Text(L10n.string(
                    viewModel.isSearching ?
                        "drawer.empty.search.title" : "drawer.empty.history.title"
                ))
                    .font(.headline)

                Text(L10n.string(
                    viewModel.isSearching ?
                        "drawer.empty.search.message" : "drawer.empty.history.message"
                ))
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
