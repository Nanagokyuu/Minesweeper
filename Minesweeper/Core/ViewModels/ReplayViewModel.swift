//
//  ReplayViewModel.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//

import SwiftUI
import Combine

class ReplayViewModel: ObservableObject {
    // MARK: - 输出状态 (View 只需要知道这些)
    @Published var grid: [Cell] = []
    @Published var isPlaying: Bool = false
    @Published var playbackSpeed: Double = 1.0
    @Published var currentStepIndex: Int = 0
   
    // 进度条用的归一化进度 (0.0 - 1.0)
    var progress: Double {
        guard !moves.isEmpty else { return 0 }
        return Double(currentStepIndex) / Double(moves.count)
    }
   
    // MARK: - 内部数据
    let record: GameRecord
    var moves: [GameMove] { record.moves ?? [] }
    var rows: Int { record.rows ?? 9 }
    var cols: Int { record.cols ?? 9 }
   
    private var timer: Timer?
   
    // MARK: - 初始化
    init(record: GameRecord) {
        self.record = record
        // 初始化空棋盘
        // 如果记录里有雷的位置信息，也可以预埋进去（虽然回放主要是看操作）
        let totalCells = (record.rows ?? 9) * (record.cols ?? 9)
        self.grid = Array(repeating: Cell(), count: totalCells)
       
        // 如果记录包含雷的分布，把雷埋好（为了最后输的那一下能炸开）
        if let mineIndices = record.mineIndices {
            for index in mineIndices {
                if index < self.grid.count {
                    self.grid[index].isMine = true
                }
            }
        }
       
        // 初始化数字（为了回放时翻开能看到数字）
        // 这里为了简单，我们假设回放时不重新计算数字，或者如果你想更严谨，
        // 应该在这里复用 MinesweeperGame+Algorithms 的计算逻辑。
        // 为了演示方便，我们暂时只依赖 moves 里的操作。
        // 但为了视觉完美，最好还是算一下数字：
        recalculateNumbers()
    }
   
    // MARK: - 播放控制
   
    func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            startTimer()
        } else {
            stopTimer()
        }
    }
   
    private func startTimer() {
        stopTimer()
        // 基础间隔 0.5秒，除以倍速
        let interval = 0.5 / playbackSpeed
       
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
           
            if self.currentStepIndex < self.moves.count {
                // 执行一步
                self.applyMove(at: self.currentStepIndex)
                // 必须在主线程更新 UI 相关的计数
                DispatchQueue.main.async {
                    self.currentStepIndex += 1
                }
            } else {
                // 剧终
                self.stopTimer()
                DispatchQueue.main.async { self.isPlaying = false }
            }
        }
    }
   
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
   
    // MARK: - 进度控制
   
    // 拖拽进度条时的逻辑：这是回放系统最麻烦的地方
    // 因为第 N 步的状态依赖于前 N-1 步，所以不能直接跳转，必须从头重跑
    func seek(to step: Int) {
        stopTimer()
        isPlaying = false
       
        let targetStep = max(0, min(step, moves.count))
       
        // 重置棋盘
        resetGridState()
       
        // 快速快进到目标步数
        // 这里不需要动画，直接修改数据模型
        for i in 0..<targetStep {
            applyMove(at: i, shouldAnimate: false)
        }
       
        currentStepIndex = targetStep
    }
   
    // 重置棋盘状态（不包括雷的分布，只重置翻开/插旗状态）
    private func resetGridState() {
        for i in 0..<grid.count {
            grid[i].isRevealed = false
            grid[i].isFlagged = false
            grid[i].isExploding = false
        }
    }
   
    // MARK: - 核心逻辑：执行一步操作
        // 【修改】将参数名从 withAnimation 改为 shouldAnimate，避免和 SwiftUI 的函数重名
        private func applyMove(at index: Int, shouldAnimate: Bool = true) {
            let move = moves[index]
            let cellIndex = move.index
           
            guard cellIndex < grid.count else { return }
           
            // 必须在主线程更新 UI
            DispatchQueue.main.async {
                switch move.type {
                case .reveal:
                    // 如果需要动画
                    if shouldAnimate {
                        // 现在这里的 withAnimation 指的是 SwiftUI 的全局函数，不会报错了
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            // 【修复】模拟原游戏的reveal逻辑：如果不是雷，则进行洪水填充扩散
                            if !self.grid[cellIndex].isMine {
                                self.floodFillWithRipple(startIndex: cellIndex)
                            } else {
                                self.grid[cellIndex].isRevealed = true
                            }
                        }
                    } else {
                        // 【修复】无动画时也模拟扩散
                        if !self.grid[cellIndex].isMine {
                            self.floodFillWithRipple(startIndex: cellIndex)
                        } else {
                            self.grid[cellIndex].isRevealed = true
                        }
                    }
                   
                    // 简单的震动反馈（仅在播放时）
                    if shouldAnimate { HapticManager.shared.light() }
                   
                case .flag:
                    if shouldAnimate {
                        withAnimation { self.grid[cellIndex].isFlagged.toggle() }
                    } else {
                        self.grid[cellIndex].isFlagged.toggle()
                    }
                    // 【修复】添加插旗震动反馈，与原游戏一致
                    if shouldAnimate { HapticManager.shared.heavy() }
                   
                case .chord:
                    break
                }
            }
        }
   
    // 辅助：计算周围雷数（为了回放显示正常）
    private func recalculateNumbers() {
        for i in 0..<grid.count {
            if !grid[i].isMine {
                let neighbors = getNeighbors(index: i)
                grid[i].neighborMines = neighbors.filter { grid[$0].isMine }.count
            }
        }
    }
   
    private func getNeighbors(index: Int) -> [Int] {
        var neighbors: [Int] = []
        let r = index / cols, c = index % cols
        for i in -1...1 {
            for j in -1...1 {
                if i == 0 && j == 0 { continue }
                let newR = r + i, newC = c + j
                if newR >= 0 && newR < rows && newC >= 0 && newC < cols {
                    neighbors.append(newR * cols + newC)
                }
            }
        }
        return neighbors
    }
    
    // MARK: - 【新增】涟漪式 FloodFill（从原游戏复制并调整为回放专用）
    // 从点击中心向外扩散,像水波一样优雅
    func floodFillWithRipple(startIndex: Int) {
        // 1. 先计算所有应该被揭示的格子(使用传统 BFS)
        var toReveal: Set<Int> = []
        var queue: [Int] = [startIndex]
        var visited: Set<Int> = [startIndex]
       
        while !queue.isEmpty {
            let currentIndex = queue.removeFirst()
           
            guard !grid[currentIndex].isMine && !grid[currentIndex].isFlagged else { continue }
           
            toReveal.insert(currentIndex)
           
            // 只有当前格子是 0 时才继续扩展
            if grid[currentIndex].neighborMines == 0 {
                let neighbors = getNeighbors(index: currentIndex)
                for neighborIndex in neighbors {
                    if !visited.contains(neighborIndex) {
                        visited.insert(neighborIndex)
                        queue.append(neighborIndex)
                    }
                }
            }
        }
       
        // 2. 计算每个格子到起点的距离,用于设置动画延迟
        let startR = startIndex / cols
        let startC = startIndex % cols
       
        for index in toReveal {
            let r = index / cols
            let c = index % cols
           
            // 曼哈顿距离:越远的格子,动画延迟越大
            let distance = abs(r - startR) + abs(c - startC)
           
            // 【关键修复】延迟时间从0.03改为0.05秒,让涟漪更从容
            grid[index].animationDelay = Double(distance) * 0.05
           
            // 3. 使用延迟执行来实现涟漪效果
            DispatchQueue.main.asyncAfter(deadline: .now() + grid[index].animationDelay) { [weak self] in
                guard let self = self else { return }
                self.grid[index].isRevealed = true
            }
        }
    }
}
