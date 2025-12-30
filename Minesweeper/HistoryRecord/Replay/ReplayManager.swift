//
//  ReplayManager.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//
//  玩地平线4的时候突发的灵感，就这么尝试实现了一下子

import SwiftUI
import Combine

// 回放导演：在这里我们重现你的高光与黑历史
class ReplayViewModel: ObservableObject {
    // 棋盘状态
    // 舞台上的演员们（格子阵容），等待导演喊“开！”
    @Published var grid: [Cell] = []
    // 是否开拍：true 开始演，false 休息片刻
    @Published var isPlaying = false
    // 进度条：你的人生进度（不是），是回放进度 0.0 ~ 1.0
    @Published var progress: Double = 0.0 // 0.0 ~ 1.0
    // 当前走到第几步：剪辑时间轴上的位置
    @Published var currentStepIndex = 0
    
    // 倍速播放：1x, 2x, 4x —— 速度与激情
    // 【修改点】：添加 didSet 监听。一旦速度改变且正在播放，立即应用新速度。
    @Published var playbackSpeed: Double = 1.0 {
        didSet {
            if isPlaying {
                startTimer() // 立即重启计时器，应用新的时间间隔
            }
        }
    }
    
    // 元数据
    let record: GameRecord
    let rows: Int
    let cols: Int
    private let totalSteps: Int
    
    private var timer: Timer?
    
    init(record: GameRecord) {
        self.record = record
        self.rows = record.rows ?? 9
        self.cols = record.cols ?? 9
        self.totalSteps = record.moves?.count ?? 0
        
        // 初始化空棋盘：空镜头，静静等候剧情推动
        self.grid = Array(repeating: Cell(), count: rows * cols)
        
        // 埋雷 (如果有数据)：先把“剧情反转”埋好，等你来触发
        if let mines = record.mineIndices {
            for index in mines {
                if index < grid.count {
                    grid[index].isMine = true
                }
            }
            // 计算数字
            calculateNumbers()
        }
    }
    
    // 预计算数字（跟游戏逻辑一样）：把背景信息都标注好，演员更好发挥
    private func calculateNumbers() {
        for i in 0..<grid.count {
            if !grid[i].isMine {
                grid[i].neighborMines = countMinesAround(index: i)
            }
        }
    }
    
    // 播放控制：导演的“开拍/停！”
    func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            startTimer()
        } else {
            stopTimer()
        }
    }
    
    func seek(to step: Int) {
        stopTimer()
        isPlaying = false
        
        // 时光机倒退：如果目标步骤比当前小，需要重置棋盘重新跑
        if step < currentStepIndex {
            resetGridState()
            currentStepIndex = 0
        }
        
        // 快速执行到目标步骤：连播跳转，无需慢镜头
        while currentStepIndex < step {
            processNextMove(animated: false)
        }
        
        updateProgress()
    }
    
    // 核心：执行一步 —— 每个镜头都是故事推进
    private func processNextMove(animated: Bool) {
        guard let moves = record.moves, currentStepIndex < moves.count else {
            isPlaying = false
            stopTimer()
            return
        }
        
        let move = moves[currentStepIndex]
        let index = move.index
        
        // 执行操作：根据剧本来一段
        switch move.type {
        case .reveal:
            // 翻开一格：不做复杂戏法，FloodFill 由回放引擎代劳
            // 录制尽量只记录玩家点击，让文件更精瘦，播放更优雅
            if !grid[index].isRevealed {
                if grid[index].isMine {
                    grid[index].isRevealed = true // 炸了
                } else {
                    doFloodFill(index: index)
                }
            }
            if animated { HapticManager.shared.light() }
            
        case .flag:
            grid[index].isFlagged.toggle()
            if animated { HapticManager.shared.light() }
            
        case .chord:
            // 双击（chord）：高手的戏法，如果录制了就表演一次
            break
        }
        
        currentStepIndex += 1
        updateProgress()
        
        // 自动结束：字幕滚动，片尾到了
        if currentStepIndex >= moves.count {
            isPlaying = false
            stopTimer()
        }
    }
    
    private func startTimer() {
        // 先停止旧的，防止多重影分身
        stopTimer()
        // 基础间隔 0.5秒，除以倍速：节拍器开始打点
        let interval = 0.5 / playbackSpeed
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.processNextMove(animated: true)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func resetGridState() {
        // 保留地雷数据，重置状态：重置场景但不改剧情
        for i in 0..<grid.count {
            let isMine = grid[i].isMine
            grid[i] = Cell()
            grid[i].isMine = isMine
        }
        calculateNumbers()
    }
    
    private func updateProgress() {
        if totalSteps > 0 {
            progress = Double(currentStepIndex) / Double(totalSteps)
        } else {
            progress = 0
        }
    }
    
    // --- 复制过来的辅助逻辑 ---
    // 工具箱：邻居统计、邻居获取、洪水填充，缺一不可
    private func countMinesAround(index: Int) -> Int {
        getNeighbors(index: index).filter { grid[$0].isMine }.count
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
    
    private func doFloodFill(index: Int) {
        // 简单的 FloodFill：让空白如潮水般涌来
        // 必须完全复制 MinesweeperGame 的逻辑，否则回放结果会不一致
        var stack: [Int] = [index]
        while let currentIndex = stack.popLast() {
            guard !grid[currentIndex].isRevealed && !grid[currentIndex].isMine && !grid[currentIndex].isFlagged else { continue }
            grid[currentIndex].isRevealed = true
            if grid[currentIndex].neighborMines == 0 {
                let neighbors = getNeighbors(index: currentIndex)
                for neighborIndex in neighbors {
                    if !grid[neighborIndex].isRevealed {
                        stack.append(neighborIndex)
                    }
                }
            }
        }
    }
}
