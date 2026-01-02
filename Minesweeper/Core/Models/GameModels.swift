//
//  GameModels.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/22.
//

import Foundation
import SwiftUI

// MARK: - 难度枚举
enum Difficulty: String, CaseIterable {
    case easy = "简单"   // 幼儿园水平,适合热身
    case medium = "普通" // 正常人水平,适合打发时间
    case hard = "困难"   // 只有受虐狂才会选这个,或者你是大神
    case hell = "地狱"   // 不看这里你能知道还有地狱难度吗?这是给外星人准备的
    
    var rows: Int {
        switch self {
        case .easy: return 9
        case .medium: return 12
        case .hard: return 16
        case .hell: return 30 // 屏幕都要装不下了
        }
    }
    
    var cols: Int {
        switch self {
        case .easy: return 9
        case .medium: return 12
        case .hard: return 16
        case .hell: return 24 // 密密麻麻的格子,看着就头晕
        }
    }
    
    var totalMines: Int {
        switch self {
        case .easy: return 10
        case .medium: return 20
        case .hard: return 45
        case .hell: return 200 // 基本上走两步就是一个雷
        }
    }
    
    var icon: String {
        switch self {
        case .easy: return "😊" // 笑得像个孩子
        case .medium: return "😐" // 面无表情,内心毫无波澜
        case .hard: return "😰" // 汗流浃背了吧,老弟
        case .hell: return "😈" // 欢迎来到地狱
        }
    }
    
    var description: String {
        return "\(rows)×\(cols) · \(totalMines)个雷"
    }
}

// MARK: - 格子模型
struct Cell: Identifiable {
    let id = UUID()
    var isMine: Bool = false      // 是惊喜还是惊吓?
    var isRevealed: Bool = false  // 薛定谔的猫,打开之前你永远不知道
    var isFlagged: Bool = false   // 我觉得这里有雷,虽然我经常觉得错
    var neighborMines: Int = 0    // 死亡倒计时数字,或者说是生存指南
    // 【新增】涟漪动画延迟 - 让翻开效果更有层次感
    var animationDelay: Double = 0.0
    // 【新增】爆炸动画状态 - 让炸弹更有冲击力
    var isExploding: Bool = false
    // 【新增】标记玩家点中的那颗雷
    var isTriggeredMine: Bool = false
}

// MARK: - 游戏状态
enum GameStatus {
    case playing
    case won
    case lost
    case exploding
}

// MARK: - 操作模式
enum InputMode {
    case dig
    case flag
}

// MARK: - 回放相关模型

enum MoveType: String, Codable {
    case reveal
    case flag
    case chord
}

struct GameMove: Codable {
    let timestamp: TimeInterval
    let index: Int
    let type: MoveType
}

// MARK: - 游戏记录模型
// 统一放在这里,其他地方不要再定义了
struct GameRecord: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let duration: Int
    let difficultyName: String
    let isWin: Bool
    var isPinned: Bool = false
    
    // 种子信息 (新增)
    var seed: Int?
    
    // 回放数据
    var rows: Int?
    var cols: Int?
    var mineIndices: [Int]?
    var moves: [GameMove]?
}

// MARK: - Difficulty 扩展 (多语言支持)
// 把这段加在文件最后面，专门负责翻译
extension Difficulty {
    func localizedName(localization: LocalizationManager) -> String {
        switch self {
        case .easy: return localization.text(.difficultyEasy)
        case .medium: return localization.text(.difficultyMedium)
        case .hard: return localization.text(.difficultyHard)
        case .hell: return localization.text(.difficultyHell)
        }
    }
    
    // 动态生成的难度描述
    // 比如：9x9 · 10个雷
    func localizedDescription(localization: LocalizationManager) -> String {
        return "\(rows)×\(cols) · \(totalMines)\(localization.text(.minesSuffix))"
    }
}

// MARK: - 【新增】皮肤主题系统
// 既然要换肤，那就换个彻底，从图标到颜色全部参数化
struct GameTheme: Equatable {
    let name: String
    
    // 图标篇
    let mainIcon: String      // 主页那个大大的图标
    let mineIcon: String      // 还没炸的时候显示啥
    let explosionIcon: String // 炸开那一瞬间显示啥
    let flagIcon: String      // 插旗的图标
    
    // 颜色篇
    let coveredColor: Color   // 没翻开时的颜色 (经典蓝 vs 草地绿)
    let explodedColor: Color  // 炸开时的背景色 (经典红 vs 泥土褐)
    
    // 经典皮肤：原汁原味的 Windows 风格
    static let classic = GameTheme(
        name: "Classic",
        mainIcon: "💣",
        mineIcon: "💣",
        explosionIcon: "💥",   // Emoji
        flagIcon: "flag.fill",
        coveredColor: .blue,
        explodedColor: .white
    )
    
    // 花圃皮肤：致敬 Vista，把地雷变成花，把爆炸变成挖到土
    static let flower = GameTheme(
        name: "Flower",
        mainIcon: "🌼",
        // 【关键修复】：这里不能用 "flower.fill"，因为 iOS 没有这个图标
        // 直接改成 Emoji "🌼"，这样显示绝对不会错！
        mineIcon: "🌼",
        // 爆炸也显示花朵，或者也可以换成 "🌸"
        explosionIcon: "🌼",
        flagIcon: "flag.fill",   // 旗子保持原样
        coveredColor: .green,    // 绿油油的草地
        explodedColor: .white
    )
}
