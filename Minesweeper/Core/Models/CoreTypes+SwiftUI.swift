//
//  CoreTypes+SwiftUI.swift
//  Minesweeper
//
//  Mapping between UniFFI snapshot records and the small SwiftUI-facing
//  value types.  This is deliberately the only place that knows the bit
//  layout of `CoreSnapshot.cellFlags`.
//

import Foundation

extension CoreSnapshot {
    /// Flat snapshot arrays -> view models.  One allocation per action and no
    /// per-cell FFI calls.
    func makeCells() -> [Cell] {
        let total = Int(rows) * Int(cols)
        guard total > 0,
              cellFlags.count >= total,
              neighborCounts.count >= total else {
            return []
        }
        var result = [Cell]()
        result.reserveCapacity(total)

        cellFlags.withUnsafeBytes { rawFlags in
            let flags = rawFlags.bindMemory(to: UInt8.self)
            neighborCounts.withUnsafeBytes { rawNeighbours in
                let neighbours = rawNeighbours.bindMemory(to: UInt8.self)
                for index in 0..<total {
                    let bits = flags[index]
                    let delay = index < revealDelaysMs.count
                        ? Double(revealDelaysMs[index]) / 1000.0
                        : 0
                    result.append(
                        Cell(
                            isMine: bits & 1 != 0,
                            isRevealed: bits & 2 != 0,
                            isFlagged: bits & 4 != 0,
                            neighborMines: Int(neighbours[index]),
                            animationDelay: delay,
                            isExploding: false,
                            isTriggeredMine: bits & 8 != 0
                        )
                    )
                }
            }
        }
        return result
    }
}

extension CoreRecord: Identifiable {}

extension CoreRecord {
    var dateValue: Date {
        Date(timeIntervalSinceReferenceDate: date)
    }

    var difficulty: Difficulty {
        Difficulty(coreCode: difficultyName) ?? .easy
    }

    var localizedDifficultyName: String {
        difficulty.localizedName(localization: LocalizationManager.shared)
    }

    var durationSeconds: Int {
        Int(duration)
    }
}
