//
//  GameModels.swift
//  Minesweeper
//
//  SwiftUI-facing value types.  Game logic lives in Rust; this file only
//  contains presentation models and mappings.
//

import SwiftUI

// MARK: - 难度枚举
enum Difficulty: String, CaseIterable {
    case easy
    case medium
    case hard
    case hell

    var rows: Int {
        switch self {
        case .easy: return 9
        case .medium: return 12
        case .hard: return 16
        case .hell: return 30
        }
    }

    var cols: Int {
        switch self {
        case .easy: return 9
        case .medium: return 12
        case .hard: return 16
        case .hell: return 24
        }
    }

    var totalMines: Int {
        switch self {
        case .easy: return 10
        case .medium: return 20
        case .hard: return 45
        case .hell: return 200
        }
    }

    var icon: String {
        switch self {
        case .easy: return "😊"
        case .medium: return "😐"
        case .hard: return "😰"
        case .hell: return "😈"
        }
    }

    var core: CoreDifficulty {
        switch self {
        case .easy: return .easy
        case .medium: return .medium
        case .hard: return .hard
        case .hell: return .hell
        }
    }

    init?(coreCode: String) {
        switch coreCode.lowercased() {
        case "easy", "简单", "簡單": self = .easy
        case "medium", "普通": self = .medium
        case "hard", "困难", "困難": self = .hard
        case "hell", "地狱", "地獄": self = .hell
        default: return nil
        }
    }
}

// MARK: - 格子视图模型
// 仅用于 SwiftUI 渲染，真实状态由 Rust 快照映射而来。
struct Cell: Equatable {
    var isMine: Bool = false
    var isRevealed: Bool = false
    var isFlagged: Bool = false
    var neighborMines: Int = 0
    /// 用于涟漪/连锁爆炸的视觉延迟（秒）。模型状态本身是同步的。
    var animationDelay: Double = 0
    var isExploding: Bool = false
    var isTriggeredMine: Bool = false
}

// MARK: - 游戏状态
enum GameStatus {
    case playing
    case won
    case lost
    case exploding
}

// 单一发布状态，避免一次操作触发多次 objectWillChange。
struct GameBoardState: Equatable {
    var cells: [Cell] = []
    var status: GameStatus = .playing
    var seed: Int = 0
    var remainingMines: Int = 0
    var started: Bool = false
    /// Board dimensions come from the Rust snapshot so a difficulty change in
    /// the core can never desynchronise the SwiftUI index math.
    var rows: Int = 0
    var cols: Int = 0
}

// MARK: - 操作模式
enum InputMode {
    case dig
    case flag
}

// MARK: - 皮肤主题
struct GameTheme: Equatable {
    let name: String

    let mainIcon: String
    let mineIcon: String
    let explosionIcon: String
    let flagIcon: String

    let coveredColor: Color
    let explodedColor: Color

    static let classic = GameTheme(
        name: "Classic",
        mainIcon: "💣",
        mineIcon: "💣",
        explosionIcon: "💥",
        flagIcon: "flag.fill",
        coveredColor: .blue,
        explodedColor: .white
    )

    static let flower = GameTheme(
        name: "Flower",
        mainIcon: "🌼",
        mineIcon: "🌼",
        explosionIcon: "🌼",
        flagIcon: "flag.fill",
        coveredColor: .green,
        explodedColor: .white
    )
}

// MARK: - Difficulty 本地化
extension Difficulty {
    func localizedName(localization: LocalizationManager) -> String {
        switch self {
        case .easy: return localization.text(.difficultyEasy)
        case .medium: return localization.text(.difficultyMedium)
        case .hard: return localization.text(.difficultyHard)
        case .hell: return localization.text(.difficultyHell)
        }
    }

    func localizedDescription(localization: LocalizationManager) -> String {
        "\(rows)×\(cols) · \(totalMines)\(localization.text(.minesSuffix))"
    }
}
