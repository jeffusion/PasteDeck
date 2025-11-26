//
//  ClipboardViewModel.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import Foundation
import Combine
import AppKit

/// View model for clipboard management UI
@MainActor
class ClipboardViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var items: [ClipItem] = []
    @Published var filteredItems: [ClipItem] = []
    @Published var searchText: String = ""
    @Published var contentFilter: ClipItem.ContentFilter = .all
    @Published var dateFilter: ClipItem.DateFilter = .all
    @Published var isSearching: Bool = false

    // MARK: - Callbacks

    /// Called when the view should be closed (e.g., after paste)
    var onRequestClose: (() -> Void)?

    /// Called immediately before paste to lower window level (allows instant paste)
    var onPrepareForPaste: (() -> Void)?

    // MARK: - Private Properties

    private let monitor: ClipboardMonitor
    private let storageService: StorageService
    private var cancellables = Set<AnyCancellable>()
    private let maxHistorySize: Int

    // MARK: - Constants

    private let defaultMaxHistorySize = 200

    // MARK: - Initialization

    init(monitor: ClipboardMonitor, storageService: StorageService = StorageService(), maxHistorySize: Int? = nil) {
        self.monitor = monitor
        self.storageService = storageService
        self.maxHistorySize = maxHistorySize ?? defaultMaxHistorySize

        setupSubscriptions()
        loadInitialData()
    }

    // MARK: - Setup

    private func setupSubscriptions() {
        // Subscribe to new clipboard items
        monitor.clipboardItemPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] clipItem in
                self?.handleNewClipItem(clipItem)
            }
            .store(in: &cancellables)

        // Subscribe to search text changes
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)

        // Subscribe to filter changes
        Publishers.CombineLatest($contentFilter, $dateFilter)
            .dropFirst() // Skip initial value
            .receive(on: RunLoop.main) // Ensure it runs after SwiftUI state update
            .sink { [weak self] _, _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }

    private func loadInitialData() {
        // Load persisted data from Core Data
        items = storageService.fetchAll()
        applyFilters()
        print("📋 ClipboardViewModel: Loaded \(items.count) items from storage")
    }

    // MARK: - Public Methods

    /// Copy an item to the clipboard and mark as used
    func copyItem(_ item: ClipItem) {
        // Write to pasteboard
        item.content.write(to: .general)

        // Update use statistics
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].markAsUsed()
            saveItems()
        }

        print("📋 Copied: \(item.title)")
    }

    /// Copy and paste an item (copy then simulate paste)
    func copyAndPaste(_ item: ClipItem) {
        // 1. Always copy to clipboard first
        copyItem(item)

        // 2. Read paste mode setting (default: activeApp)
        let pasteMode = UserDefaults.standard.string(forKey: "pasteMode") ?? "activeApp"

        // 3. Handle clipboard mode (copy only, no permission check)
        if pasteMode == "clipboard" {
            print("📋 剪贴板模式：项目已复制到剪贴板")
            // Close drawer and return (no permission check, no paste)
            onPrepareForPaste?()
            onRequestClose?()
            return
        }

        // 4. Handle activeApp mode (auto-paste with permission check)
        // Close drawer first (regardless of permission)
        onPrepareForPaste?()
        onRequestClose?()

        // Check accessibility permission
        let hasPermission = AccessibilityPermissionGuide.shared.hasPermission

        if !hasPermission {
            // Force show permission guide (ignores "don't show again")
            AccessibilityPermissionGuide.shared.showGuide()
            print("⚠️ 自动粘贴不可用：未授予辅助功能权限")
            print("💡 内容已复制到剪贴板，可手动使用 Cmd+V 粘贴")
            return
        }

        // Permission granted - auto-paste
        // Paste almost immediately (just a tiny delay to ensure window level is lowered)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            print("📋 模拟粘贴到活动应用...")
            self.simulatePaste()
        }
    }

    /// Toggle favorite status
    func toggleFavorite(_ item: ClipItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].toggleFavorite()
            saveItems()
            applyFilters()
        }
    }

    /// Toggle pinned status
    func togglePin(_ item: ClipItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].togglePinned()
            saveItems()
            applyFilters()
        }
    }

    /// Delete an item
    func deleteItem(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
        applyFilters()
    }

    /// Delete multiple items
    func deleteItems(_ itemsToDelete: [ClipItem]) {
        let idsToDelete = Set(itemsToDelete.map { $0.id })
        items.removeAll { idsToDelete.contains($0.id) }
        saveItems()
        applyFilters()
    }

    /// Clear all non-permanent items
    func clearHistory() {
        items.removeAll { !$0.isPermanent }
        saveItems()
        applyFilters()
    }

    /// Clear all items including favorites
    func clearAll() {
        items.removeAll()
        saveItems()
        applyFilters()
    }

    /// Add a tag to an item
    func addTag(_ tag: String, to item: ClipItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].addTag(tag)
            saveItems()
        }
    }

    /// Remove a tag from an item
    func removeTag(_ tag: String, from item: ClipItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].removeTag(tag)
            saveItems()
        }
    }

    // MARK: - Private Methods

    private func handleNewClipItem(_ clipItem: ClipItem) {
        // Check for duplicates (same content)
        if let existingIndex = items.firstIndex(where: { self.isSimilarContent($0.content, clipItem.content) }) {
            // Move existing item to top by updating its date
            var existing = items[existingIndex]
            existing.markAsUsed()
            items.remove(at: existingIndex)
            items.insert(existing, at: 0)
        } else {
            // Add new item
            items.insert(clipItem, at: 0)

            // Enforce max history size (keep favorites and pinned)
            if items.count > maxHistorySize {
                let itemsToRemove = items.drop(while: { $0.isPermanent }).dropFirst(maxHistorySize)
                let idsToRemove = Set(itemsToRemove.map { $0.id })
                items.removeAll { idsToRemove.contains($0.id) && !$0.isPermanent }
            }
        }

        saveItems()
        applyFilters()
    }

    private func isSimilarContent(_ content1: ClipContent, _ content2: ClipContent) -> Bool {
        switch (content1, content2) {
        case (.text(let text1, _), .text(let text2, _)):
            return text1 == text2
        case (.url(let url1), .url(let url2)):
            return url1 == url2
        case (.file(let file1), .file(let file2)):
            return file1 == file2
        case (.image(let data1, _), .image(let data2, _)):
            return data1 == data2
        case (.color(let color1), .color(let color2)):
            return color1 == color2
        default:
            return false
        }
    }

    private func applyFilters() {
        var filtered = items

        // Apply search filter
        if !searchText.isEmpty {
            isSearching = true
            filtered = filtered.filter { $0.matches(query: searchText) }
        } else {
            isSearching = false
        }

        // Apply content type filter
        if contentFilter != .all {
            filtered = filtered.filter { contentFilter.matches(content: $0.content) }
        }

        // Apply date filter
        if dateFilter != .all {
            filtered = filtered.filter { dateFilter.matches(date: $0.createdAt) }
        }

        // Sort (pinned and favorites first, then by date)
        filtered.sort()

        filteredItems = filtered
    }

    private func saveItems() {
        // Persist all items to Core Data
        // First, clear and re-save (simple approach for now)
        _ = storageService.deleteAll(keepFavorites: false)
        _ = storageService.save(items)

        // Enforce max history
        _ = storageService.enforceMaxHistory(maxItems: maxHistorySize)
    }

    private func simulatePaste() {
        // Create and post a Cmd+V keyboard event
        let source = CGEventSource(stateID: .hidSystemState)

        // Virtual key code 0x09 is 'V'
        let vKeyCode: CGKeyCode = 0x09

        // Create key down event
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else {
            print("⚠️ Failed to create key down event")
            return
        }

        // Set Command flag
        keyDown.flags = .maskCommand

        // Post key down
        keyDown.post(tap: .cghidEventTap)

        // Small delay between key down and key up
        usleep(10000) // 10ms delay

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            print("⚠️ Failed to create key up event")
            return
        }

        // Set Command flag
        keyUp.flags = .maskCommand

        // Post key up
        keyUp.post(tap: .cghidEventTap)

        print("✅ Paste event posted successfully")
    }

    // MARK: - Computed Properties

    var favoriteItems: [ClipItem] {
        items.filter { $0.isFavorite }
    }

    var pinnedItems: [ClipItem] {
        items.filter { $0.isPinned }
    }

    var recentItems: [ClipItem] {
        items.filter { !$0.isPinned && !$0.isFavorite }.prefix(20).map { $0 }
    }

    var totalSize: Int64 {
        Int64(items.reduce(0) { $0 + $1.content.estimatedSize })
    }

    var statistics: Statistics {
        Statistics(
            totalItems: items.count,
            favoriteItems: favoriteItems.count,
            pinnedItems: pinnedItems.count,
            totalSize: totalSize,
            oldestItem: items.last?.createdAt,
            newestItem: items.first?.createdAt
        )
    }

    struct Statistics {
        let totalItems: Int
        let favoriteItems: Int
        let pinnedItems: Int
        let totalSize: Int64
        let oldestItem: Date?
        let newestItem: Date?

        var totalSizeFormatted: String {
            ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension ClipboardViewModel {
    static var preview: ClipboardViewModel {
        let monitor = ClipboardMonitor()
        let viewModel = ClipboardViewModel(monitor: monitor)

        // Add sample data
        viewModel.items = [
            ClipItem(
                content: .text("Hello, World!", isRTF: false),
                sourceApp: "TextEdit",
                isFavorite: true
            ),
            ClipItem(
                content: .url(URL(string: "https://github.com")!),
                sourceApp: "Safari"
            ),
            ClipItem(
                content: .text("Lorem ipsum dolor sit amet, consectetur adipiscing elit.", isRTF: false),
                sourceApp: "Notes",
                isPinned: true
            ),
        ]

        viewModel.applyFilters()
        return viewModel
    }
}
#endif
