//
//  MacGameSession.swift
//  MinesweeperMac
//
//  Owns the current game so the menu bar, toolbar and window content all drive
//  the same instance.
//

import Combine
import SwiftUI

@MainActor
final class MacGameSession: ObservableObject {
    enum Screen: Equatable {
        case home
        case game
    }

    @Published private(set) var screen: Screen = .home
    @Published var difficulty: Difficulty = .easy
    @Published private(set) var game: MinesweeperGame?
    @Published private(set) var isGodMode = false
    @Published private(set) var isNanagokyuuMode = false

    func start(
        difficulty: Difficulty? = nil,
        seed: Int? = nil,
        godMode: Bool = false,
        nanagokyuu: Bool = false
    ) {
        if let difficulty {
            self.difficulty = difficulty
        }
        if let existing = game {
            existing.stop()
        }
        let next = MinesweeperGame(
            difficulty: self.difficulty,
            theme: AppSettings.shared.currentTheme,
            seed: seed,
            isGodMode: godMode,
            isNanagokyuuMode: nanagokyuu
        )
        game = next
        isGodMode = godMode
        isNanagokyuuMode = nanagokyuu
        screen = .game
    }

    /// Menu / toolbar "New Game": keep the current difficulty and options.
    func newGame() {
        if let game {
            game.startNewGame()
        } else {
            start()
        }
    }

    func restart(seed: Int?) {
        game?.startNewGame(with: seed)
    }

    func backHome() {
        game?.stop()
        game = nil
        screen = .home
    }
}
