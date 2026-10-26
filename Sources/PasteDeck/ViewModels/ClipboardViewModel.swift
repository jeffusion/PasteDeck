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
    @Published private(set) var isStorageReady = false
    @Published private(set) var storageError: String?
    @Published var filteredItems: [ClipItem] = []
    @Published var searchText: String = ""
    @Published var contentFilter: ClipItem.ContentFilter = .all
    @Published var dateFilter: ClipItem.DateFilter = .all
    @Published var isSearching: Bool = false
    @Published var resetUITrigger: UUID? = nil
    @Published var selectFirstItemTrigger: UUID? = nil

    // MARK: - Callbacks

    /// Called when the view should be closed (e.g., after paste)
    var onRequestClose: (() -> Void)?

    /// Called immediately before paste to lower window level (allows instant paste)
    var onPrepareForPaste: (() -> Void)?

    // MARK: - Private Properties

    private let pasteboard: NSPasteboard
    private let monitor: ClipboardMonitor
    private let storageService: StorageService
    private var cancellables = Set<AnyCancellable>()
    private let maxHistorySize: Int

    // MARK: - Constants

    private let defaultMaxHistorySize = 20_000

    // MARK: - Initialization

    init(monitor: ClipboardMonitor, storageService: StorageService? = nil, maxHistorySize: Int? = nil, pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.monitor = monitor
        self.storageService = storageService ?? StorageService()
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
        do {
            let loaded = try storageService.loadHistory(maxItems: maxHistorySize)
            items = loaded
            storageError = nil
            isStorageReady = true
            applyFilters()
        } catch {
            isStorageReady = false
            storageError = L10n.string("storage.error.load")
        }
    }

    func retryLoadingHistory() { loadInitialData() }
    func dismissStorageError() { storageError = nil }
    func suspendForStorageFailure() { isStorageReady = false }

    // MARK: - Public Methods

    /// Copy an item to the clipboard and mark as used
    func copyItem(_ item: ClipItem) {
        guard isStorageReady else { return }
        item.content.write(to: pasteboard)
        var candidate = items
        if let index = candidate.firstIndex(where: { $0.id == item.id }) {
            candidate[index].markAsUsed()
            _ = persist(candidate)
        }
    }

    /// Copy and paste an item (copy then simulate paste)
    func copyAndPaste(_ item: ClipItem) {
        guard isStorageReady else { return }
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

    /// Publish history changes only after the complete transaction succeeds.
    func toggleFavorite(_ item: ClipItem) {
        var candidate = items
        guard let index = candidate.firstIndex(where: { $0.id == item.id }) else { return }
        candidate[index].toggleFavorite()
        _ = persist(candidate)
    }

    func togglePin(_ item: ClipItem) {
        var candidate = items
        guard let index = candidate.firstIndex(where: { $0.id == item.id }) else { return }
        candidate[index].togglePinned()
        _ = persist(candidate)
    }

    func deleteItem(_ item: ClipItem) { deleteItems([item]) }

    func deleteItems(_ itemsToDelete: [ClipItem]) {
        let ids = Set(itemsToDelete.map(\.id))
        if persist(items.filter { !ids.contains($0.id) }) {
            SoundManager.shared.playSound(for: .deleted)
        }
    }

    func clearHistory() {
        if persist(items.filter(\.isPermanent)) { SoundManager.shared.playSound(for: .cleared) }
    }

    func clearAll() {
        if persist([]) { SoundManager.shared.playSound(for: .cleared) }
    }

    @discardableResult
    func cleanupExpiredItems(retentionDays: Int) -> Int {
        guard retentionDays > 0,
              let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else { return 0 }
        let candidate = items.filter { $0.isPermanent || $0.createdAt >= cutoff }
        let deleted = items.count - candidate.count
        return persist(candidate) ? deleted : 0
    }

    func addTag(_ tag: String, to item: ClipItem) {
        var candidate = items
        guard let index = candidate.firstIndex(where: { $0.id == item.id }) else { return }
        candidate[index].addTag(tag)
        _ = persist(candidate)
    }

    func removeTag(_ tag: String, from item: ClipItem) {
        var candidate = items
        guard let index = candidate.firstIndex(where: { $0.id == item.id }) else { return }
        candidate[index].removeTag(tag)
        _ = persist(candidate)
    }

    /// Reset UI-related state to initial values
    /// Called when drawer is closed to ensure clean state on next open
    func resetUIState() {
        searchText = ""
        contentFilter = .all
        dateFilter = .all
        resetUITrigger = UUID()
        print("🔄 ClipboardViewModel: UI state reset")
    }

    /// Prepare view for display (select first item)
    /// Called when drawer is about to be shown
    func prepareForDisplay() {
        selectFirstItemTrigger = UUID()
        print("👁️ ClipboardViewModel: Prepare for display")
    }

    // MARK: - Private Methods

    private func handleNewClipItem(_ clipItem: ClipItem) {
        guard isStorageReady else { return }
        var candidate = items
        if let existingIndex = candidate.firstIndex(where: { self.isSimilarContent($0.content, clipItem.content) }) {
            var existing = candidate.remove(at: existingIndex)
            existing.markAsUsed()
            candidate.insert(existing, at: 0)
        } else {
            candidate.insert(clipItem, at: 0)
        }
        if persist(candidate) { SoundManager.shared.playSound(for: .captured) }
    }

    private func isSimilarContent(_ content1: ClipContent, _ content2: ClipContent) -> Bool {
        switch (content1, content2) {
        case (.text(let text1, _), .text(let text2, _)):
            return text1 == text2
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

    @discardableResult
    private func persist(_ candidate: [ClipItem]) -> Bool {
        guard isStorageReady else { return false }
        do {
            let saved = try storageService.replaceAll(with: candidate, maxItems: maxHistorySize)
            items = saved
            storageError = nil
            applyFilters()
            return true
        } catch {
            storageError = L10n.string("storage.error.save")
            return false
        }
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
        let viewModel = ClipboardViewModel(monitor: monitor, storageService: StorageService(persistenceController: PersistenceController(inMemory: true)), pasteboard: .withUniqueName())

        // Add sample data
        viewModel.items = [
            ClipItem(
                content: .text("Hello, World!", isRTF: false),
                sourceApp: "TextEdit",
                isFavorite: true
            ),
            ClipItem(
                content: .text("https://github.com", isRTF: false),
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
