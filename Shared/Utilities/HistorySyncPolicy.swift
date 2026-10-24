//
//  HistorySyncPolicy.swift
//  Minesweeper
//
//  Pure cross-device filtering rules, kept separate from CoreHistory so they
//  can be unit tested without UserDefaults or iCloud.
//

import Foundation

enum HistorySyncPolicy {
    /// Tombstones are kept for 90 days.  The cloud history itself is capped at
    /// 50 records, so this is far longer than a resurrected record can survive
    /// in a normal sync.
    static let tombstoneRetention: TimeInterval = 90 * 24 * 60 * 60

    /// A record is hidden when its ID was deleted on any device, or when it was
    /// created at/before the latest "clear all" timestamp.
    static func shouldHide(
        record: CoreRecord,
        deletedIDs: Set<String>,
        clearedAt: Double
    ) -> Bool {
        if deletedIDs.contains(record.id) {
            return true
        }
        return clearedAt > 0 && record.date <= clearedAt
    }

    static func mergeTombstones(
        _ local: [String: Double],
        _ cloud: [String: Double]
    ) -> [String: Double] {
        var merged = local
        for (id, deletedAt) in cloud {
            merged[id] = max(merged[id] ?? 0, deletedAt)
        }
        return merged
    }

    static func prunedTombstones(
        _ tombstones: [String: Double],
        now: Double
    ) -> [String: Double] {
        let cutoff = now - tombstoneRetention
        return tombstones.filter { $0.value >= cutoff }
    }
}
