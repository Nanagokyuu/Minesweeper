import XCTest
@testable import Minesweeper

final class HistorySyncPolicyTests: XCTestCase {
    private func record(id: String, date: Double) -> CoreRecord {
        CoreRecord(
            id: id,
            date: date,
            duration: 10,
            difficultyName: "easy",
            isWin: true,
            isPinned: false,
            seed: 1,
            rows: 9,
            cols: 9,
            mineIndices: [0],
            moves: []
        )
    }

    func testDeletedIDIsHidden() {
        XCTAssertTrue(
            HistorySyncPolicy.shouldHide(
                record: record(id: "deleted", date: 100),
                deletedIDs: ["deleted"],
                clearedAt: 0
            )
        )
    }

    func testRecordsAtOrBeforeClearAreHidden() {
        XCTAssertTrue(
            HistorySyncPolicy.shouldHide(
                record: record(id: "old", date: 50),
                deletedIDs: [],
                clearedAt: 50
            )
        )
    }

    func testNewerRecordSurvivesClear() {
        XCTAssertFalse(
            HistorySyncPolicy.shouldHide(
                record: record(id: "new", date: 51),
                deletedIDs: [],
                clearedAt: 50
            )
        )
    }
}

final class HistoryTombstoneTests: XCTestCase {
    func testMergeKeepsNewestDeletionTimestamp() {
        let merged = HistorySyncPolicy.mergeTombstones(
            ["a": 10, "b": 5],
            ["b": 20, "c": 30]
        )
        XCTAssertEqual(merged["a"], 10)
        XCTAssertEqual(merged["b"], 20)
        XCTAssertEqual(merged["c"], 30)
    }

    func testTombstonesExpireAfterRetention() {
        let now = 1_000_000_000.0
        let cutoff = now - HistorySyncPolicy.tombstoneRetention
        let tombstones = [
            "old": cutoff - 1,
            "edge": cutoff,
            "fresh": now,
        ]
        let pruned = HistorySyncPolicy.prunedTombstones(tombstones, now: now)
        XCTAssertNil(pruned["old"])
        XCTAssertNotNil(pruned["edge"])
        XCTAssertNotNil(pruned["fresh"])
    }
}
