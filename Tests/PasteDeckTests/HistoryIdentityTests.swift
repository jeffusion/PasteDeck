import XCTest
import CoreData
import Combine
@testable import PasteDeck

@MainActor
final class HistoryIdentityTests: XCTestCase {
    private enum InjectedError: Error { case failed }
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("PasteDeckHistory-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: directory) }

    private func seed(_ items: [ClipItem], in controller: PersistenceController) throws {
        for item in items { _ = ClipItemEntity.create(from: item, in: controller.viewContext) }
        try controller.viewContext.save()
    }

    func testRepeatedSaveUpsertsAndDuplicateBatchIsRejectedWithoutChanges() throws {
        let controller = PersistenceController(inMemory: true)
        let store = StorageService(persistenceController: controller)
        var item = ClipItem(content: .text("synthetic", isRTF: false))
        XCTAssertTrue(store.save(item))
        item.isFavorite = true
        XCTAssertTrue(store.save(item))
        XCTAssertEqual(store.count(), 1)
        XCTAssertEqual(store.fetch(id: item.id)?.isFavorite, true)
        XCTAssertFalse(store.save([item, item]))
        XCTAssertEqual(store.count(), 1)
        XCTAssertThrowsError(try store.replaceAll(with: [item, item], maxItems: 20))
        XCTAssertEqual(store.count(), 1)
    }

    func testRepairMergesMetadataPreservesContentConflictsAndIsIdempotent() throws {
        let controller = PersistenceController(inMemory: true)
        let id = UUID()
        let early = Date(timeIntervalSince1970: 100)
        let late = Date(timeIntervalSince1970: 200)
        let first = ClipItem(id: id, content: .text("same", isRTF: false), createdAt: early,
                             sourceApp: "Older", isFavorite: true, lastUsedAt: early, useCount: 3,
                             tags: ["One"], note: "First", cloudRecordID: "cloud", excludeFromSync: true)
        let second = ClipItem(id: id, content: first.content, createdAt: late,
                              sourceApp: "Recent", isPinned: true, lastUsedAt: late, useCount: 7,
                              tags: ["one", "two"], note: "Second", cloudRecordID: "cloud")
        let conflict = ClipItem(id: id, content: .text("different", isRTF: false), createdAt: early,
                                cloudRecordID: "cloud")
        try seed([first, second, conflict], in: controller)
        let store = StorageService(persistenceController: controller)
        let loaded = try store.loadHistory()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(Set(loaded.map(\.id)).count, 2)
        let merged = try XCTUnwrap(loaded.first { $0.content == first.content })
        XCTAssertEqual(merged.id, id)
        XCTAssertTrue(merged.isFavorite && merged.isPinned && merged.excludeFromSync)
        XCTAssertEqual(merged.useCount, 7)
        XCTAssertEqual(merged.createdAt, early)
        XCTAssertEqual(merged.lastUsedAt, late)
        XCTAssertEqual(merged.sourceApp, "Recent")
        XCTAssertEqual(Set(merged.tags), Set(["one", "two"]))
        XCTAssertEqual(merged.note, "Second\n\nFirst")
        let preserved = try XCTUnwrap(loaded.first { $0.content == conflict.content })
        XCTAssertNotEqual(preserved.id, id)
        XCTAssertNil(preserved.cloudRecordID)
        XCTAssertEqual(store.repairReport.removedRecords, 1)
        XCTAssertEqual(store.repairReport.reassignedRecords, 1)
        let reloaded = try StorageService(persistenceController: controller).loadHistory()
        XCTAssertEqual(Set(reloaded.map(\.id)), Set(loaded.map(\.id)))
    }

    func testUnreadableRecordsSurviveRepairAndNormalSnapshotWrites() throws {
        let controller = PersistenceController(inMemory: true)
        let item = ClipItem(content: .text("valid", isRTF: false))
        try seed([item, item], in: controller)
        let entities = try controller.viewContext.fetch(ClipItemEntity.fetchRequest())
        entities[0].contentType = "unrecognized"
        try controller.viewContext.save()
        let store = StorageService(persistenceController: controller)
        let valid = try store.loadHistory()
        XCTAssertEqual(valid.count, 1)
        XCTAssertEqual(store.count(), 2)
        XCTAssertEqual(store.repairReport.unreadableRecords, 1)
        _ = try store.replaceAll(with: valid, maxItems: 1)
        XCTAssertEqual(store.count(), 2)
        let raw = try controller.viewContext.fetch(ClipItemEntity.fetchRequest())
        XCTAssertEqual(Set(raw.map(\.id)).count, 2)
        XCTAssertEqual(raw.filter { $0.contentType == "unrecognized" }.count, 1)
    }

    func testRepairFailureRollsBackAndBackupFailureDoesNotTouchRecords() throws {
        let controller = PersistenceController(inMemory: true)
        let item = ClipItem(content: .text("duplicate", isRTF: false))
        try seed([item, item], in: controller)
        let backupFailure = StorageService(persistenceController: controller, backup: { throw InjectedError.failed })
        XCTAssertThrowsError(try backupFailure.loadHistory())
        XCTAssertEqual(try controller.viewContext.count(for: ClipItemEntity.fetchRequest()), 2)
        let commitFailure = StorageService(persistenceController: controller, commit: { _ in throw InjectedError.failed })
        XCTAssertThrowsError(try commitFailure.loadHistory())
        let raw = try controller.viewContext.fetch(ClipItemEntity.fetchRequest())
        XCTAssertEqual(raw.count, 2)
        XCTAssertEqual(Set(raw.map(\.id)), Set([item.id]))
        XCTAssertFalse(controller.viewContext.hasChanges)
    }

    func testSnapshotFailureLeavesMemoryAndDiskUnchanged() throws {
        let url = directory.appendingPathComponent("Failure.sqlite")
        let controller = PersistenceController(storeURL: url)
        let original = ClipItem(content: .text("original", isRTF: false))
        try seed([original], in: controller)
        var fail = false
        let store = StorageService(persistenceController: controller, commit: { context in
            if fail { throw InjectedError.failed }
            try context.save()
        })
        let vm = ClipboardViewModel(monitor: ClipboardMonitor(), storageService: store)
        var publications = 0
        let token = vm.$items.dropFirst().sink { _ in publications += 1 }
        fail = true
        vm.toggleFavorite(original)
        XCTAssertEqual(publications, 0)
        XCTAssertEqual(vm.items.first?.isFavorite, false)
        XCTAssertEqual(vm.filteredItems.first?.isFavorite, false)
        XCTAssertNotNil(vm.storageError)
        XCTAssertThrowsError(try store.replaceAll(with: [ClipItem(content: .text("new", isRTF: false))], maxItems: 1))
        XCTAssertEqual(try store.loadHistory().map(\.id), [original.id])
        XCTAssertEqual(try store.loadHistory().first?.isFavorite, false)
        XCTAssertFalse(controller.viewContext.hasChanges)
        let reopened = StorageService(persistenceController: PersistenceController(storeURL: url))
        XCTAssertEqual(try reopened.loadHistory().map(\.id), [original.id])
        XCTAssertEqual(try reopened.loadHistory().first?.isFavorite, false)
        _ = token
    }

    func testStartupRepairFailurePublishesNoConflictingHistoryAndBlocksWrites() throws {
        let controller = PersistenceController(inMemory: true)
        let item = ClipItem(content: .text("duplicate", isRTF: false))
        try seed([item, item], in: controller)
        let store = StorageService(persistenceController: controller, backup: { throw InjectedError.failed })
        let vm = ClipboardViewModel(monitor: ClipboardMonitor(), storageService: store)
        XCTAssertFalse(vm.isStorageReady)
        XCTAssertTrue(vm.items.isEmpty && vm.filteredItems.isEmpty)
        vm.clearAll()
        XCTAssertEqual(try controller.viewContext.count(for: ClipItemEntity.fetchRequest()), 2)
    }

    func testLegacyDiskRepairBacksUpImagesAndSurvivesReopen() throws {
        let url = directory.appendingPathComponent("PasteDeck.sqlite")
        var controller: PersistenceController? = PersistenceController(storeURL: url)
        XCTAssertNil(controller!.loadError)
        let text = (0..<1200).map { ClipItem(content: .text("synthetic \($0)", isRTF: false)) }
        let unique = (0..<12).map { ClipItem(content: .text("unique \($0)", isRTF: false)) }
        let imageBytes = Data((0..<(2 * 1024 * 1024)).map { UInt8(truncatingIfNeeded: $0) })
        let image = ClipItem(id: text[0].id, content: .image(imageBytes, format: .png), createdAt: text[0].createdAt)
        var originals = text
        originals[0] = image
        try seed(originals + originals + unique, in: controller!)
        var store: StorageService? = StorageService(persistenceController: controller!)
        let repaired = try store!.loadHistory()
        XCTAssertEqual(repaired.count, 1212)
        XCTAssertEqual(Set(repaired.map(\.id)).count, 1212)
        XCTAssertEqual(store!.repairReport.removedRecords, 1200)
        let backup = try XCTUnwrap(store!.repairReport.backupURL)
        store = nil
        controller = nil
        do {
            let reopened = StorageService(persistenceController: PersistenceController(storeURL: url))
            let loaded = try reopened.loadHistory()
            XCTAssertEqual(Set(loaded.map(\.id)), Set(repaired.map(\.id)))
            XCTAssertEqual(loaded.first { $0.id == image.id }?.content, image.content)
            XCTAssertEqual(reopened.repairReport.removedRecords, 0)
            XCTAssertNil(reopened.repairReport.backupURL)
        }
        let allFiles = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])!
        let externalFiles = allFiles.compactMap { $0 as? URL }.filter {
            !$0.path.contains("/Backups/") && $0.path.contains("_EXTERNAL_DATA/") &&
                ((try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true)
        }
        XCTAssertFalse(externalFiles.isEmpty, "Fixture must exercise external binary storage")
        // Remove access to every original component. A backup must stand alone.
        let components = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let quarantine = directory.appendingPathComponent("OriginalStoreRemoved")
        try FileManager.default.createDirectory(at: quarantine, withIntermediateDirectories: true)
        for component in components where component.lastPathComponent != "Backups" {
            try FileManager.default.moveItem(at: component, to: quarantine.appendingPathComponent(component.lastPathComponent))
        }
        let backupController = PersistenceController(storeURL: backup, readOnly: true)
        XCTAssertNil(backupController.loadError)
        let backupEntities = try backupController.viewContext.fetch(ClipItemEntity.fetchRequest())
        XCTAssertEqual(backupEntities.count, 2412)
        XCTAssertEqual(backupEntities.first { $0.id == image.id }?.imageData, imageBytes)
    }
}
