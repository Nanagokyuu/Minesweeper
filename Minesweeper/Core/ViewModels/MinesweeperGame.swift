//
//  MinesweeperGame.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/22.
//

import SwiftUI
import Combine

class MinesweeperGame: ObservableObject {
    // MARK: - Published 状态
    @Published var difficulty: Difficulty
    @Published var grid: [Cell] = []
    @Published var gameStatus: GameStatus = .playing
    @Published var showResult: Bool = false
    
    // MARK: - 皮肤系统
    // 既然有人想在雷区里种花，那就满足他
    // Update: 现在这个属性主要用于游戏内部显示，真正的开关在 AppSettings
    @Published var currentTheme: GameTheme = .classic
    
    // MARK: - 致敬 Cytimax
    // 上帝模式状态：开启后拥有全知全能的视角
    @Published var isGodMode: Bool = false
    
    // MARK: - 【新增】Nanagokyuu 模式
    // 也就是所谓的“落地成盒”模式，专门用来坑那些以为输入作者名字会有什么好果子吃的人
    @Published var isNanagokyuuMode: Bool = false
    
    // MARK: - 无猜模式逻辑 (No Guessing Mode)
    // 【修改】逻辑升级：
    // 1. 如果是地狱模式，强制关闭无猜（地狱就是用来受苦的，不需要公平）
    // 2. 如果不是地狱模式，则检查 AppSettings 里的总开关
    // 这样就把选择权交给了 SettingsView 里的开关
    var isNoGuessingMode: Bool {
        if difficulty == .hell { return false }
        return AppSettings.shared.isNoGuessingEnabled
    }
    
    // MARK: - 历史记录
    @Published var history: [GameRecord] = []
    
    // MARK: - 计时器
    // 总是有人希望我加这个功能,那就加上吧,看着时间的流逝,焦虑感倍增
    @Published var timeElapsed: Int = 0
    var timer: Timer? // 改为 internal 以便扩展访问
    
    // MARK: - 种子系统
    // 感谢Cytimax提出的灵感,不说我还真没想到这个玩法,这就是命运的红线
    @Published var currentSeed: Int = 0
    
    // MARK: - 录制相关属性
    // 记录你的每一次操作,无论是神之一手还是愚蠢的失误
    var recordedMoves: [GameMove] = [] // 改为 internal
    var gameStartTime: Date? // 改为 internal
    var actualMineIndices: [Int] = [] // 改为 internal
    
    var isFirstClick = true // 改为 internal
    
    // 计算属性
    var rows: Int { difficulty.rows }
    var cols: Int { difficulty.cols }
    var totalMines: Int { difficulty.totalMines }
    
    // 【修改】初始化方法增加 theme 参数
    // 这样从 SettingsView 修改完回来，新开的游戏就能拿到新皮肤
    init(difficulty: Difficulty = .easy, theme: GameTheme = .classic, isGodMode: Bool = false, isNanagokyuuMode: Bool = false) {
        self.difficulty = difficulty
        self.currentTheme = theme // 继承皮肤
        self.isGodMode = isGodMode // 设置上帝模式状态
        self.isNanagokyuuMode = isNanagokyuuMode // 注入霉运
        
        // 初始化时随机生成一个种子并开始,命运的齿轮开始转动
        startNewGame()
    }
    
    // MARK: - 基础生命周期
    
    // 切换皮肤：在 💣 和 🌼 之间反复横跳
    // 兼容旧代码的方法，现在实际由SettingsView控制
    func toggleTheme() {
        if currentTheme == .classic {
            currentTheme = .flower
        } else {
            currentTheme = .classic
        }
        // 切换皮肤给个震动反馈，让玩家知道变身了
        HapticManager.shared.light()
    }
    
    func changeDifficulty(_ newDifficulty: Difficulty) {
        self.difficulty = newDifficulty
        startNewGame() // 切换难度会自动随机种子,新的挑战
    }
    
    // 启动新游戏 (支持指定种子)
    func startNewGame(with seed: Int? = nil) {
        // 如果没有指定种子,就随机生成一个 -> 听天由命
        // 如果指定了,就用指定的 -> 我命由我不由天
        if let specificSeed = seed {
            self.currentSeed = specificSeed
        } else {
            // 这里换成了玄学算法,不仅看天,还要看你的手机电量和此刻的心情(时间)
            self.currentSeed = generateEnvironmentalSeed()
        }
        resetGame()
    }
    
    func resetGame() {
        stopTimer()
        timeElapsed = 0
        grid = Array(repeating: Cell(), count: rows * cols)
        gameStatus = .playing
        showResult = false
        isFirstClick = true
        
        // 重置录制数据
        recordedMoves = []
        actualMineIndices = []
        gameStartTime = nil
    }
}
