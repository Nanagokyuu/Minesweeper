//
//  HistoryManager.swift
//  Minesweeper
//
//  Persistence adapter: `UserDefaults`/iCloud stay in Swift, while sorting,
//  pinning, de-duplication, the 50-record cap and JSON live in Rust.
//

import Foundation
import Combine

@MainActor
final class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    private let key = "minesweeper_history_v4"
    private let legacyKeys = [
        "minesweeper_history_v3",
        "minesweeper_history_v2",
        "minesweeper_history_v1",
        "minesweeper_history",
    ]
    private let backupKey = "minesweeper_history_v4_unreadable_backup"
    private let deletedIDsKey = "minesweeper_history_v4_deleted_ids"
    private let clearedAtKey = "minesweeper_history_v4_cleared_at"

    @Published private(set) var records: [CoreRecord] = []

    private let core = CoreHistory()
    /// True when the stored payload existed but could not be decoded.  In that
    /// case `persist()` must not silently replace it with `[]`; the raw bytes
    /// are copied to `backupKey` first.
    private var loadFailed = false
    /// Cross-device tombstones: record ID -> deletion date (Apple reference
    /// seconds).  They are re-applied after every cloud merge so a remote copy
    /// cannot resurrect a deleted game, and pruned after 90 days.
    private var tombstoneTimestamps: [String: Double] = [:]
    private var deletedIDs: Set<String> { Set(tombstoneTimestamps.keys) }
    /// Apple-reference seconds; records at or before this instant are hidden.
    private var clearedAt: Double = 0
    /// Compression/UserDefaults writes are serialized off the main actor;
    /// uploads are bounced back so CloudSyncManager stays main-actor isolated.
    private let persistenceQueue = DispatchQueue(
        label: "com.oakacorn.Minesweeper.history-persistence",
        qos: .userInitiated
    )
    private var persistenceGeneration = 0

    private init() {
        loadFromDisk()
    }

    // MARK: - Mutations
    func save(_ record: CoreRecord) {
        // Merge first so this save cannot clobber another device's games.
        mergeCloudInMemory()
        records = core.add(record: record)
        persist()
    }

    func delete(_ record: CoreRecord) {
        // Merge, then re-apply the deletion.  Without the second delete the
        // record would immediately come back from the cloud copy.
        records = core.delete(id: record.id)
        mergeCloudInMemory()
        tombstoneTimestamps[record.id] = Date().timeIntervalSinceReferenceDate
        records = core.delete(id: record.id)
        persist()
    }

    func togglePin(_ record: CoreRecord) {
        let targetPinned = !record.isPinned
        mergeCloudInMemory()

        if let current = core.records().first(where: { $0.id == record.id }) {
            if current.isPinned != targetPinned {
                records = core.togglePin(id: record.id)
            } else {
                records = core.records()
            }
        } else {
            records = core.records()
        }
        persist()
    }

    func clear() {
        loadFailed = false
        tombstoneTimestamps.removeAll()
        clearedAt = Date().timeIntervalSinceReferenceDate
        records = core.clear()
        // Do not merge the cloud copy back in here: the user explicitly asked
        // to clear.  The empty payload + clearedAt marker is uploaded so other
        // devices remove records older than this instant.
        persist()
    }

    // MARK: - Cloud
    /// Merge a downloaded cloud payload into the local list.
    func mergeCloud(_ data: Data) {
        mergeCloudInMemory(payload: data)
        persist(upload: false)
    }

    /// Two-way sync used by the "Sync Now" button: merge the remote copy first,
    /// then write the union back so one device cannot clobber another's games.
    func syncWithCloud() {
        mergeCloudInMemory()
        persist()
    }

    // MARK: - Loading
    func reload() {
        persistenceQueue.sync {}
        loadFromDisk()
    }


    private func loadFromDisk() {
        loadMetadataFromDisk()
        var sourceKey = key
        var data = UserDefaults.standard.data(forKey: key)

        if data == nil {
            for legacyKey in legacyKeys {
                if let legacyData = UserDefaults.standard.data(forKey: legacyKey) {
                    data = legacyData
                    sourceKey = legacyKey
                    break
                }
            }
        }

        guard let data, !data.isEmpty else {
            core.load(data: Data())
            records = core.records()
            loadFailed = false
            return
        }

        // The payload may be the compressed "MSH1" envelope or legacy raw JSON.
        guard let json = HistoryCodec.decode(data) else {
            UserDefaults.standard.set(data, forKey: backupKey)
            core.load(data: Data())
            records = core.records()
            loadFailed = true
            return
        }

        // Rust treats malformed JSON as an empty list.  Validate the container
        // first so a corrupt payload is preserved instead of being overwritten
        // on the next game result.
        guard (try? JSONSerialization.jsonObject(with: json)) is [Any] else {
            UserDefaults.standard.set(data, forKey: backupKey)
            core.load(data: Data())
            records = core.records()
            loadFailed = true
            return
        }

        core.load(data: json)
        applyTombstonesAndClear()
        loadFailed = false

        if sourceKey != key {
            // Migrate older keys to the current key using the compressed
            // envelope, but do not touch the cloud copy until the next save.
            writeLocalPayload()
        }
    }

    // MARK: - Storage
    /// Merge-before-upload: a local save must not overwrite records that
    /// another device added since our last download.  Empty/corrupt cloud
    /// payloads are ignored by Rust, so this cannot erase local history.
    private func mergeCloudInMemory(payload: Data? = nil) {
        let cloudTombstones = CloudSyncManager.shared.readCloudTombstones()
        tombstoneTimestamps = HistorySyncPolicy.mergeTombstones(
            tombstoneTimestamps,
            cloudTombstones
        )
        pruneTombstones()

        let cloudClearedAt = CloudSyncManager.shared.readCloudClearedAt()
        if cloudClearedAt > clearedAt {
            clearedAt = cloudClearedAt
        }

        if let cloud = payload ?? CloudSyncManager.shared.readCloudHistory(),
           let json = HistoryCodec.decode(cloud) {
            records = core.mergeCloud(data: json)
        }
        applyTombstonesAndClear()
    }

    private func applyTombstonesAndClear() {
        pruneTombstones()
        for record in core.records()
        where HistorySyncPolicy.shouldHide(
            record: record,
            deletedIDs: deletedIDs,
            clearedAt: clearedAt
        ) {
            _ = core.delete(id: record.id)
        }
        records = core.records()
    }

    private func loadMetadataFromDisk() {
        if let data = UserDefaults.standard.data(forKey: deletedIDsKey) {
            if let map = try? JSONDecoder().decode([String: Double].self, from: data) {
                tombstoneTimestamps = map
            } else if let ids = try? JSONDecoder().decode([String].self, from: data) {
                let now = Date().timeIntervalSinceReferenceDate
                tombstoneTimestamps = Dictionary(uniqueKeysWithValues: ids.map { ($0, now) })
            } else {
                tombstoneTimestamps = [:]
            }
        } else {
            tombstoneTimestamps = [:]
        }
        clearedAt = UserDefaults.standard.double(forKey: clearedAtKey)
        pruneTombstones()
    }

    private func pruneTombstones() {
        tombstoneTimestamps = HistorySyncPolicy.prunedTombstones(
            tombstoneTimestamps,
            now: Date().timeIntervalSinceReferenceDate
        )
    }

    private func persist(upload: Bool = true) {
        let json = core.encode()
        // Never replace real history with an empty payload on encode failure.
        guard !(json.isEmpty && !records.isEmpty) else { return }
        // Preserve an unreadable payload until the user explicitly clears it
        // or produces a new record.  Once new data is written, the backup key
        // remains as the recovery copy.
        guard !(loadFailed && records.isEmpty) else { return }
        loadFailed = false

        if upload {
            persistenceGeneration += 1
        }
        let generation = persistenceGeneration
        pruneTombstones()
        let deletedIDsSnapshot = tombstoneTimestamps
        let clearedAtValue = clearedAt
        let key = self.key
        let deletedIDsKey = self.deletedIDsKey
        let clearedAtKey = self.clearedAtKey
        let shouldUpload = upload

        // `core.encode()` is a copy; compression and the UserDefaults write are
        // the expensive parts for a large history, so keep them off the main
        // actor.  The serial queue preserves write order.
        persistenceQueue.async { [weak self] in
            let payload = HistoryCodec.encode(json) ?? json
            UserDefaults.standard.set(payload, forKey: key)
            if let idsData = try? JSONEncoder().encode(deletedIDsSnapshot) {
                UserDefaults.standard.set(idsData, forKey: deletedIDsKey)
            }
            UserDefaults.standard.set(clearedAtValue, forKey: clearedAtKey)

            guard shouldUpload else { return }
            DispatchQueue.main.async {
                self?.uploadPersisted(
                    payload: payload,
                    deletedIDs: deletedIDsSnapshot,
                    clearedAt: clearedAtValue,
                    generation: generation
                )
            }
        }
    }

    private func uploadPersisted(
        payload: Data,
        deletedIDs: [String: Double],
        clearedAt: Double,
        generation: Int
    ) {
        // A newer local save already queued its upload; skip this stale one.
        guard generation == persistenceGeneration else { return }
        CloudSyncManager.shared.uploadMetadata(
            deletedIDs: deletedIDs,
            clearedAt: clearedAt
        )
        CloudSyncManager.shared.uploadToCloud(payload: payload)
    }

    private func writeLocalPayload() {
        let json = core.encode()
        guard let payload = HistoryCodec.encode(json) else { return }
        UserDefaults.standard.set(payload, forKey: key)
    }
}
