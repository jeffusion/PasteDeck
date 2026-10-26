import Foundation
import CoreData
import Combine

/// All application reads and writes use the main view context, serially.
@MainActor
class StorageService: ObservableObject {
    enum StorageError: Error {
        case duplicateIdentity
        case invalidLimit
        case unreadableIdentityConflict
    }

    struct RepairReport {
        var removedRecords = 0
        var reassignedRecords = 0
        var unreadableRecords = 0
        var backupURL: URL?
    }

    private let persistenceController: PersistenceController
    private let commit: (NSManagedObjectContext) throws -> Void
    private let backup: () throws -> URL?
    private var isPrepared = false
    private var context: NSManagedObjectContext { persistenceController.viewContext }
    private(set) var lastError: Error?
    private(set) var repairReport = RepairReport()
    private let itemsChangedSubject = PassthroughSubject<Void, Never>()
    var itemsChangedPublisher: AnyPublisher<Void, Never> { itemsChangedSubject.eraseToAnyPublisher() }

    init(persistenceController: PersistenceController = .shared,
         commit: @escaping (NSManagedObjectContext) throws -> Void = { try $0.save() },
         backup: (() throws -> URL?)? = nil) {
        self.persistenceController = persistenceController
        self.commit = commit
        self.backup = backup ?? { try persistenceController.backupStore() }
    }

    // MARK: - Startup repair

    /// Uses the unchanged legacy model. The repair and all ID assignments commit together.
    @discardableResult
    func prepareHistory() throws -> RepairReport {
        try persistenceController.retryLoadingStoreIfNeeded()
        if isPrepared { return repairReport }
        let entities = try context.fetch(ClipItemEntity.fetchRequest())
        let groups = Dictionary(grouping: entities, by: \.id)
        var report = RepairReport()
        report.unreadableRecords = entities.filter { $0.toClipItem() == nil }.count
        let duplicates = groups.values.filter { $0.count > 1 }
        guard !duplicates.isEmpty else {
            isPrepared = true
            repairReport = report
            return report
        }
        // A disk backup must succeed before any record is touched.
        report.backupURL = try backup()
        var allocatedIDs = Set(groups.keys)
        do {
            for group in duplicates {
                let ranked = group.sorted(by: Self.preferredRecord)
                var partitions: [[ClipItemEntity]] = []
                for entity in ranked {
                    if let content = entity.toClipItem()?.content,
                       let index = partitions.firstIndex(where: { $0[0].toClipItem()?.content == content }) {
                        partitions[index].append(entity)
                    } else {
                        // An unreadable record is retained as its own partition.
                        partitions.append([entity])
                    }
                }
                for (index, partition) in partitions.enumerated() {
                    let survivor = partition[0]
                    var id = survivor.id
                    if index > 0 {
                        repeat { id = UUID() } while allocatedIDs.contains(id)
                        allocatedIDs.insert(id)
                        report.reassignedRecords += 1
                    }
                    if let merged = Self.merge(partition, id: id) {
                        survivor.update(from: merged)
                        for redundant in partition.dropFirst() {
                            context.delete(redundant)
                            report.removedRecords += 1
                        }
                    } else if index > 0 {
                        survivor.id = id
                        survivor.cloudRecordID = nil
                    }
                }
            }
            try commit(context)
            isPrepared = true
            repairReport = report
            itemsChangedSubject.send()
            print("📦 History repair: removed=\(report.removedRecords), reassigned=\(report.reassignedRecords), unreadable=\(report.unreadableRecords)")
            return report
        } catch {
            context.rollback()
            lastError = error
            throw error
        }
    }

    private static func preferredRecord(_ lhs: ClipItemEntity, _ rhs: ClipItemEntity) -> Bool {
        let left = lhs.lastUsedAt ?? lhs.createdAt
        let right = rhs.lastUsedAt ?? rhs.createdAt
        if left != right { return left > right }
        return lhs.objectID.uriRepresentation().absoluteString < rhs.objectID.uriRepresentation().absoluteString
    }

    private static func merge(_ records: [ClipItemEntity], id: UUID) -> ClipItem? {
        guard let first = records[0].toClipItem() else { return nil }
        var tags: [String] = []
        var notes: [String] = []
        for record in records {
            for tag in record.tags ?? [] {
                let tag = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !tag.isEmpty && !tags.contains(tag) { tags.append(tag) }
            }
            if let note = record.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !notes.contains(note) { notes.append(note) }
        }
        func nonempty(_ value: String?) -> String? {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }
        return ClipItem(
            id: id, content: first.content,
            createdAt: records.map(\.createdAt).min()!,
            sourceApp: records.compactMap { nonempty($0.sourceApp) }.first,
            isFavorite: records.contains { $0.isFavorite },
            isPinned: records.contains { $0.isPinned },
            lastUsedAt: records.compactMap(\.lastUsedAt).max(),
            useCount: records.map { Int($0.useCount) }.max() ?? 0,
            tags: tags, note: notes.isEmpty ? nil : notes.joined(separator: "\n\n"),
            cloudRecordID: id == first.id ? records.compactMap { nonempty($0.cloudRecordID) }.first : nil,
            excludeFromSync: records.contains { $0.excludeFromSync }
        )
    }

    // MARK: - Transactions

    private func validate(_ items: [ClipItem]) throws {
        guard Set(items.map(\.id)).count == items.count else { throw StorageError.duplicateIdentity }
    }

    private func transaction<T>(_ body: () throws -> T) throws -> T {
        try prepareHistory()
        do {
            let result = try body()
            if context.hasChanges { try commit(context) }
            lastError = nil
            itemsChangedSubject.send()
            return result
        } catch {
            context.rollback()
            lastError = error
            throw error
        }
    }

    private func checkedItems(_ request: NSFetchRequest<ClipItemEntity>) throws -> [ClipItem] {
        let entities = try context.fetch(request)
        // Validate raw identities as well, including records the UI cannot decode.
        guard Set(entities.map(\.id)).count == entities.count else { throw StorageError.duplicateIdentity }
        return entities.compactMap { $0.toClipItem() }
    }

    func loadHistory(maxItems: Int? = nil) throws -> [ClipItem] {
        try prepareHistory()
        if let maxItems {
            return try transaction {
                _ = try trimHistory(maxItems: maxItems)
                return try checkedItems(ClipItemEntity.allItemsFetchRequest())
            }
        }
        return try checkedItems(ClipItemEntity.allItemsFetchRequest())
    }

    /// Reconciles the complete UI snapshot in a single commit, preserving unreadable records.
    func replaceAll(with items: [ClipItem], maxItems: Int) throws -> [ClipItem] {
        try validate(items)
        guard maxItems >= 0 else { throw StorageError.invalidLimit }
        return try transaction {
            let entities = try context.fetch(ClipItemEntity.fetchRequest())
            guard Set(entities.map(\.id)).count == entities.count else { throw StorageError.duplicateIdentity }
            let byID = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
            let incomingIDs = Set(items.map(\.id))
            for entity in entities where !incomingIDs.contains(entity.id) && entity.toClipItem() != nil {
                context.delete(entity)
            }
            try upsert(items, existing: byID)
            _ = try trimHistory(maxItems: maxItems)
            return try checkedItems(ClipItemEntity.allItemsFetchRequest())
        }
    }

    private func upsert(_ items: [ClipItem], existing: [UUID: ClipItemEntity]) throws {
        for item in items {
            if let entity = existing[item.id] {
                guard entity.toClipItem() != nil else { throw StorageError.unreadableIdentityConflict }
                entity.update(from: item)
            } else {
                _ = ClipItemEntity.create(from: item, in: context)
            }
        }
    }

    @discardableResult
    func save(_ item: ClipItem) -> Bool { save([item]) }

    @discardableResult
    func save(_ items: [ClipItem]) -> Bool {
        attempt(false) {
            try validate(items)
            return try transaction {
                let entities = try context.fetch(ClipItemEntity.fetchRequest())
                guard Set(entities.map(\.id)).count == entities.count else { throw StorageError.duplicateIdentity }
                try upsert(items, existing: Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) }))
                return true
            }
        }
    }

    @discardableResult
    func update(_ item: ClipItem) -> Bool { save(item) }

    @discardableResult
    func delete(id: UUID) -> Bool { delete(ids: [id]) }

    @discardableResult
    func delete(ids: [UUID]) -> Bool {
        attempt(false) {
            try transaction {
                let request = ClipItemEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id IN %@", ids)
                for entity in try context.fetch(request) { context.delete(entity) }
                return true
            }
        }
    }

    @discardableResult
    func deleteAll(keepFavorites: Bool = true) -> Bool {
        attempt(false) {
            try transaction {
                for entity in try context.fetch(ClipItemEntity.fetchRequest()) {
                    if !keepFavorites || (!entity.isFavorite && !entity.isPinned && entity.toClipItem() != nil) {
                        context.delete(entity)
                    }
                }
                return true
            }
        }
    }

    // MARK: - Queries

    private func attempt<T>(_ fallback: T, _ body: () throws -> T) -> T {
        do {
            let result = try body()
            lastError = nil
            return result
        } catch {
            lastError = error
            // Never log validation errors or values from the clipboard.
            print("📦 Storage operation failed")
            return fallback
        }
    }

    private func read(_ request: NSFetchRequest<ClipItemEntity>) -> [ClipItem] {
        attempt([]) {
            try prepareHistory()
            return try checkedItems(request)
        }
    }

    func fetchAll() -> [ClipItem] { attempt([]) { try loadHistory() } }
    func fetch(limit: Int) -> [ClipItem] { Array(fetchAll().prefix(max(0, limit))) }
    func fetch(id: UUID) -> ClipItem? { fetchAll().first { $0.id == id } }
    func search(query: String) -> [ClipItem] { read(ClipItemEntity.searchFetchRequest(query: query)) }
    func fetch(contentType: String) -> [ClipItem] {
        let request = ClipItemEntity.allItemsFetchRequest()
        request.predicate = NSPredicate(format: "contentType == %@", contentType)
        return read(request)
    }
    func fetchFavorites() -> [ClipItem] { fetchAll().filter(\.isFavorite) }
    func fetchPinned() -> [ClipItem] { fetchAll().filter(\.isPinned) }
    func count() -> Int {
        attempt(0) {
            try prepareHistory()
            return try context.count(for: ClipItemEntity.fetchRequest())
        }
    }
    func exists(content: ClipContent) -> UUID? {
        guard case .text(let text, _) = content else { return nil }
        return fetchAll().first {
            if case .text(let candidate, _) = $0.content { return text == candidate }
            return false
        }?.id
    }

    // MARK: - Retention

    /// Unreadable records are retained for recovery, rather than silently removed.
    private func trimHistory(maxItems: Int) throws -> Int {
        guard maxItems >= 0 else { throw StorageError.invalidLimit }
        let entities = try context.fetch(ClipItemEntity.fetchRequest()).filter { $0.toClipItem() != nil }
        let ordered = entities.sorted {
            let leftPermanent = $0.isPinned || $0.isFavorite
            let rightPermanent = $1.isPinned || $1.isFavorite
            if leftPermanent != rightPermanent { return !leftPermanent }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        let deleted = max(0, ordered.count - maxItems)
        for entity in ordered.prefix(deleted) { context.delete(entity) }
        return deleted
    }

    @discardableResult
    func enforceMaxHistory(maxItems: Int) -> Int {
        attempt(0) { try transaction { try trimHistory(maxItems: maxItems) } }
    }

    @discardableResult
    func deleteItemsOlderThan(days: Int, keepPermanent: Bool = true) -> Int {
        attempt(0) {
            guard days > 0 else { return 0 }
            guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return 0 }
            return try transaction {
                let entities = try context.fetch(ClipItemEntity.fetchRequest()).filter {
                    $0.toClipItem() != nil && $0.createdAt < cutoff && (!keepPermanent || (!$0.isPinned && !$0.isFavorite))
                }
                for entity in entities { context.delete(entity) }
                return entities.count
            }
        }
    }

    struct Statistics {
        let totalItems: Int
        let favoriteItems: Int
        let pinnedItems: Int
        let textItems: Int
        let imageItems: Int
        let fileItems: Int
        let colorItems: Int
    }

    func getStatistics() -> Statistics {
        let items = fetchAll()
        return Statistics(totalItems: items.count, favoriteItems: items.filter(\.isFavorite).count,
                          pinnedItems: items.filter(\.isPinned).count,
                          textItems: items.filter { if case .text = $0.content { return true }; return false }.count,
                          imageItems: items.filter { if case .image = $0.content { return true }; return false }.count,
                          fileItems: items.filter { if case .file = $0.content { return true }; if case .multipleFiles = $0.content { return true }; return false }.count,
                          colorItems: items.filter { if case .color = $0.content { return true }; return false }.count)
    }
}
