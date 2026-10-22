//
//  GameClock.swift
//  Minesweeper
//
//  Timer ticks live outside MinesweeperGame so the board does not get
//  invalidated once per second.
//

import SwiftUI
import Combine

@MainActor
final class GameClock: ObservableObject {
    @Published private(set) var elapsed: Int = 0

    func reset() {
        if elapsed != 0 {
            elapsed = 0
        }
    }

    func set(_ value: Int) {
        let clamped = max(0, value)
        if elapsed != clamped {
            elapsed = clamped
        }
    }
}
