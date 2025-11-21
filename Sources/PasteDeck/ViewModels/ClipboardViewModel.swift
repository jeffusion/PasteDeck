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
        copyItem(item)

        // Simulate Cmd+V after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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

        // Key down
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }

        // Key up
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
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
