//
//  CloudSyncManager.swift
//  Minesweeper
//
//  iCloud Key-Value Store adapter.  The actual merge/JSON logic lives in Rust
//  (`CoreHistory`), so this file only moves (compressed) bytes, reports sync
//  state and surfaces quota/account failures.
//

import Foundation
import Combine

@MainActor
final class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published private(set) var lastError: String?

    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let localKey = "minesweeper_history_v4"
    private let cloudKey = "minesweeper_cloud_history_v4"
    private let cloudDeletedIDsKey = "minesweeper_cloud_history_v4_deleted_ids"
    private let cloudClearedAtKey = "minesweeper_cloud_history_v4_cleared_at"
    private var syncGeneration = 0

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudDataChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )
        ubiquitousStore.synchronize()
    }

    // MARK: - Upload
    /// Uploads the already-encoded history envelope.  Callers should pass the
    /// same bytes they just wrote locally so the cloud and disk cannot diverge.
    func uploadToCloud(payload: Data? = nil) {
        guard isCloudAvailable else {
            lastError = nil
            return
        }

        guard let data = payload ?? UserDefaults.standard.data(forKey: localKey) else { return }
        guard data.count <= HistoryCodec.maxCloudPayloadBytes else {
            lastError = LocalizationManager.shared.text(.iCloudHistoryTooLarge)
            return
        }

        isSyncing = true
        ubiquitousStore.set(data, forKey: cloudKey)
        let synchronized = ubiquitousStore.synchronize()
        finishSync(error: synchronized ? nil : LocalizationManager.shared.text(.iCloudSyncFailed))
    }

    // MARK: - Download
    func downloadFromCloud() {
        guard isCloudAvailable,
              let cloudData = ubiquitousStore.data(forKey: cloudKey) else {
            return
        }

        isSyncing = true
        HistoryManager.shared.mergeCloud(cloudData)
        finishSync(error: nil)
    }

    /// The raw payload (compressed envelope or legacy JSON) for merge-before-
    /// upload in HistoryManager.  Returning nil means "no cloud copy yet".
    func readCloudHistory() -> Data? {
        guard isCloudAvailable else { return nil }
        return ubiquitousStore.data(forKey: cloudKey)
    }

    func readCloudTombstones() -> [String: Double] {
        guard isCloudAvailable,
              let data = ubiquitousStore.data(forKey: cloudDeletedIDsKey) else {
            return [:]
        }
        if let map = try? JSONDecoder().decode([String: Double].self, from: data) {
            return map
        }
        // Backward compatibility: earlier builds stored a plain [String].
        if let ids = try? JSONDecoder().decode([String].self, from: data) {
            let now = Date().timeIntervalSinceReferenceDate
            return Dictionary(uniqueKeysWithValues: ids.map { ($0, now) })
        }
        return [:]
    }

    func readCloudClearedAt() -> Double {
        guard isCloudAvailable else { return 0 }
        return ubiquitousStore.double(forKey: cloudClearedAtKey)
    }

    /// Uploads tombstones/clear marker alongside the record payload.  Empty
    /// arrays are meaningful here (they clear the metadata on other devices).
    func uploadMetadata(deletedIDs: [String: Double], clearedAt: Double) {
        guard isCloudAvailable else { return }

        if let data = try? JSONEncoder().encode(deletedIDs) {
            ubiquitousStore.set(data, forKey: cloudDeletedIDsKey)
        }
        ubiquitousStore.set(clearedAt, forKey: cloudClearedAtKey)
    }

    @objc private func cloudDataChanged(_ notification: Notification) {
        let rawReasons = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? [Any] ?? []
        let reasons = rawReasons.compactMap {
            ($0 as? NSNumber)?.intValue ?? ($0 as? Int)
        }

        // The notification can arrive on any thread; all sync state is main-
        // actor isolated.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if reasons.contains(NSUbiquitousKeyValueStoreQuotaViolationChange) {
                self.lastError = LocalizationManager.shared.text(.iCloudQuotaExceeded)
                return
            }
            if reasons.contains(NSUbiquitousKeyValueStoreAccountChange) {
                self.lastError = LocalizationManager.shared.text(.iCloudAccountChanged)
            }
            self.downloadFromCloud()
        }
    }

    var isCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - State
    private func finishSync(error: String?) {
        syncGeneration += 1
        let generation = syncGeneration

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, generation == self.syncGeneration else { return }
            self.isSyncing = false
            if let error {
                self.lastError = error
            } else {
                self.lastError = nil
                self.lastSyncDate = Date()
            }
        }
    }
}
