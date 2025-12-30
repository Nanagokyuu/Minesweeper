//
//  MinesweeperGames.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/22.
//

import SwiftUI
import Combine
import UIKit // 引入 UIKit 以获取电池状态,玄学需要硬件支持

class MinesweeperGame: ObservableObject {
    @Published var difficulty: Difficulty
    @Published var grid: [Cell] = []
    @Published var gameStatus: GameStatus = .playing
    @Published var showResult: Bool = false
    
    // MARK: - 历史记录
    @Published var history: [GameRecord] = []
    
    // MARK: - 计时器
    // 总是有人希望我加这个功能,那就加上吧,看着时间的流逝,焦虑感倍增
    @Published var timeElapsed: Int = 0
    private var timer: Timer?
    
    // MARK: - 种子系统
    // 感谢Cytimax提出的灵感,不说我还真没想到这个玩法,这就是命运的红线
    @Published var currentSeed: Int = 0
    
    // MARK: - 录制相关属性
    // 记录你的每一次操作,无论是神之一手还是愚蠢的失误
    private var recordedMoves: [GameMove] = []
    private var gameStartTime: Date?
    private var actualMineIndices: [Int] = []
    
    private var isFirstClick = true
    
    var rows: Int { difficulty.rows }
    var cols: Int { difficulty.cols }
    var totalMines: Int { difficulty.totalMines }
    
    init(difficulty: Difficulty = .easy) {
        self.difficulty = difficulty
        // 初始化时随机生成一个种子并开始,命运的齿轮开始转动
        startNewGame()
    }
    
    // MARK: - 历史记录操作
    func loadHistory() {
        self.history = HistoryManager.shared.load()
    }
    
    func deleteRecord(_ record: GameRecord) {
        HistoryManager.shared.delete(record)
        loadHistory()
        // 删掉黑历史,假装无事发生
        HapticManager.shared.light()
    }
    
    func togglePin(_ record: GameRecord) {
        HistoryManager.shared.togglePin(record)
        loadHistory()
        HapticManager.shared.light()
    }
    
    // MARK: - 游戏基础控制
    
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
    
    // 生成基于环境的玄学种子
    // 既然是玄学,那就贯彻到底,把电量和纳秒都算进去
    private func generateEnvironmentalSeed() -> Int {
        // 开启电池监控,虽然有点耗电,但为了命运是值得的
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.nanosecond, .second], from: now)
        
        // 获取时间戳的整数部分
        let timeStamp = Int(now.timeIntervalSince1970)
        
        // 获取纳秒,增加随机性,毕竟没人能在同一纳秒点两次
        let nano = components.nanosecond ?? 0
        
        // 获取电量,范围 0.0 - 1.0,如果获取失败就是 -1,那就当满电算吧
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryFactor = batteryLevel >= 0 ? Int(batteryLevel * 100) : 100
        
        // 核心玄学公式:时间异或纳秒,加上电量因子的加成
        // 野兽先辈也会喜欢的数字
        let seed = (timeStamp ^ nano) &+ (batteryFactor * 1145)
        
        // 保持正数,看着舒服点
        return abs(seed)
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
    
    // MARK: - 计时器逻辑
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.timeElapsed += 1 }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - 录制辅助方法
    private func recordMove(at index: Int, type: MoveType) {
        guard gameStatus == .playing || gameStatus == .exploding else { return }
        let time = Date().timeIntervalSince(gameStartTime ?? Date())
        let move = GameMove(timestamp: time, index: index, type: type)
        recordedMoves.append(move)
    }
    
    // MARK: - 游戏核心逻辑
    
    func revealCell(at index: Int) {
        guard gameStatus == .playing else { return }
        guard !grid[index].isFlagged && !grid[index].isRevealed else { return }
        
        if isFirstClick {
            gameStartTime = Date()
            placeMines(excluding: index)
            isFirstClick = false
            startTimer()
            actualMineIndices = grid.indices.filter { grid[$0].isMine }
        }
        
        recordMove(at: index, type: .reveal)
        
        if grid[index].isMine {
            // 【改进】先翻开第一个雷,再触发连锁爆炸
            grid[index].isRevealed = true
            HapticManager.shared.heavy()
            
            // 延迟一点点,让玩家看清第一个炸弹
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.triggerChainExplosion(centerIndex: index)
            }
            return
        }
        
        HapticManager.shared.light()
        // 【修改】使用带涟漪动画的 FloodFill
        floodFillWithRipple(startIndex: index)
        checkWinCondition()
    }
    
    func toggleFlag(at index: Int) {
        guard gameStatus == .playing && !grid[index].isRevealed else { return }
        
        if isFirstClick { gameStartTime = Date() }
        
        grid[index].isFlagged.toggle()
        HapticManager.shared.heavy()
        
        recordMove(at: index, type: .flag)
        
        // 每次插旗后检查是否获胜，不然你把所有雷都标完了还得再点一下才能结算
        checkWinCondition()  // ← 就是这一行！
    }
    
    // MARK: - 极速双击
    // 是有人提过一嘴,当时我还没什么概念,这是我后来看别人玩扫雷的时候才知道的
    // 高端玩家的必备技能,手残党的噩梦
    func quickReveal(at index: Int) {
        guard gameStatus == .playing else { return }
        let cell = grid[index]
        // 只有"已揭示"且"是数字(大于0)"的格子才响应此操作
        guard cell.isRevealed && cell.neighborMines > 0 else { return }
        
        let neighbors = getNeighbors(index: index)
        let flaggedCount = neighbors.filter { grid[$0].isFlagged }.count
        
        // 判定:只有旗帜数量等于数字时才触发
        if flaggedCount == cell.neighborMines {
            var didReveal = false
            for neighborIndex in neighbors {
                // 只处理没开过且没插旗的格子
                if !grid[neighborIndex].isRevealed && !grid[neighborIndex].isFlagged {
                    // 直接复用 revealCell
                    // 注意:revealCell 内部会自动执行 recordMove(.reveal),
                    // 所以不需要单独记录 chord 动作,回放时看起来就像快速连续点击
                    revealCell(at: neighborIndex)
                    didReveal = true
                }
            }
            if didReveal { HapticManager.shared.light() }
        } else {
            // 旗子不够或者多了,给个震动提示:你算错了
            HapticManager.shared.failure()
        }
    }
    
    // MARK: - 生成地雷逻辑 (包含种子支持)
    private func placeMines(excluding safeIndex: Int) {
        // 1. 初始化伪随机生成器,使用当前种子
        var rng = SeededGenerator(seed: currentSeed)
        
        var minesPlaced = 0
        
        // 2. 获取安全区 (防止报错部分)
        let neighbors = getNeighbors(index: safeIndex)
        var safeZone = Set(neighbors)
        safeZone.insert(safeIndex)
        
        let availableCells = grid.count - safeZone.count
        if totalMines > availableCells {
            safeZone = [safeIndex]
        }
        
        while minesPlaced < totalMines {
            // 3. 使用 rng 生成随机数
            let randomIndex = Int.random(in: 0..<grid.count, using: &rng)
            
            if !safeZone.contains(randomIndex) && !grid[randomIndex].isMine {
                grid[randomIndex].isMine = true
                minesPlaced += 1
            }
        }
        
        // 计算数字
        for i in 0..<grid.count {
            if !grid[i].isMine { grid[i].neighborMines = countMinesAround(index: i) }
        }
    }
    
    private func countMinesAround(index: Int) -> Int {
        let neighbors = getNeighbors(index: index)
        return neighbors.filter { grid[$0].isMine }.count
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
    
    // MARK: - 【新增】涟漪式 FloodFill
    // 从点击中心向外扩散,像水波一样优雅
    // 也是Cytimax提出来的，其实我也想做，当时懒得搞了，被他这么一提醒还是加回来的
    private func floodFillWithRipple(startIndex: Int) {
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

    // MARK: - 【改进】爆炸动画
    // 不再是简单的波纹扩散,而是更有冲击力的连锁爆炸
    private func triggerChainExplosion(centerIndex: Int) {
        stopTimer()
        gameStatus = .exploding
        
        let centerR = centerIndex / cols
        let centerC = centerIndex % cols
        
        // 收集所有地雷,按距离分组
        var minesByDistance: [Int: [Int]] = [:]
        
        for i in 0..<grid.count {
            if grid[i].isMine && !grid[i].isRevealed {
                let r = i / cols
                let c = i % cols
                // 使用切比雪夫距离(棋盘距离),更符合视觉效果
                let distance = max(abs(r - centerR), abs(c - centerC))
                
                if minesByDistance[distance] == nil {
                    minesByDistance[distance] = []
                }
                minesByDistance[distance]?.append(i)
            }
        }
        
        // 按距离排序
        let sortedDistances = minesByDistance.keys.sorted()
        
        // 依次引爆每一圈的地雷
        explodeByWaves(distances: sortedDistances, minesByDistance: minesByDistance, currentWaveIndex: 0)
    }
    
    // 分波次爆炸
    private func explodeByWaves(distances: [Int], minesByDistance: [Int: [Int]], currentWaveIndex: Int) {
        // 所有波次都爆完了,游戏结束
        guard currentWaveIndex < distances.count else {
            // 延迟一点再显示结果,让玩家看完最后的烟花
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.gameOver(win: false)
            }
            return
        }
        
        let distance = distances[currentWaveIndex]
        guard let mines = minesByDistance[distance] else {
            // 这一圈没有雷,跳到下一圈
            explodeByWaves(distances: distances, minesByDistance: minesByDistance, currentWaveIndex: currentWaveIndex + 1)
            return
        }
        
        // 【改进】同一圈的雷添加随机偏移,制造不整齐的爆炸效果
        for index in mines {
            // 随机延迟 0~0.08秒,让爆炸更自然
            let randomDelay = Double.random(in: 0.0...0.08)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) { [weak self] in
                guard let self = self else { return }
                
                // 【新增】设置爆炸状态
                self.grid[index].isExploding = true
                self.grid[index].isRevealed = true
                
                // 【强化】每个雷都震动！要的就是这种强烈的手感
                HapticManager.shared.heavy()
                
                // 爆炸效果持续0.25秒后消失
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.grid[index].isExploding = false
                }
            }
        }
        
        // 【改进】根据雷的数量动态调整下一波的延迟
        // 雷少 = 延迟短,雷多 = 延迟长,让节奏更合理
        let baseDelay = 0.12
        let additionalDelay = min(Double(mines.count) * 0.01, 0.08)
        let nextWaveDelay = baseDelay + additionalDelay
        
        // 继续下一波爆炸
        DispatchQueue.main.asyncAfter(deadline: .now() + nextWaveDelay) { [weak self] in
            self?.explodeByWaves(distances: distances, minesByDistance: minesByDistance, currentWaveIndex: currentWaveIndex + 1)
        }
    }
    
    // MARK: - 游戏结算
    private func checkWinCondition() {
        let allSafeRevealed = grid.filter { $0.isRevealed }.count == (rows * cols) - totalMines
        
        // 新增判定：所有地雷都被正确插旗，且无误插的旗帜
        let allMinesFlagged = grid.filter { $0.isMine && $0.isFlagged }.count == totalMines
        let hasWrongFlag = grid.contains { !$0.isMine && $0.isFlagged }
        
        if allSafeRevealed || (allMinesFlagged && !hasWrongFlag) {
            gameOver(win: true)
            HapticManager.shared.success()
        }
    }
    
    private func gameOver(win: Bool) {
        stopTimer()
        gameStatus = win ? .won : .lost
        saveGameRecord(isWin: win)
        withAnimation(.spring()) { showResult = true }
        if win { HapticManager.shared.success() }
        else { HapticManager.shared.failure() }
    }
    
    // MARK: - 保存与辅助
    private func saveGameRecord(isWin: Bool) {
        let diffName = getDifficultyName(difficulty)
        let newRecord = GameRecord(
            date: Date(),
            duration: timeElapsed,
            difficultyName: diffName,
            isWin: isWin,
            isPinned: false,
            // 保存种子
            seed: currentSeed,
            // 保存回放数据
            rows: rows,
            cols: cols,
            mineIndices: actualMineIndices,
            moves: recordedMoves
        )
        HistoryManager.shared.save(newRecord)
        loadHistory()
    }
    
    private func getDifficultyName(_ diff: Difficulty) -> String {
        switch diff {
        case .easy: return "简单"
        case .medium: return "普通"
        case .hard: return "困难"
        case .hell: return "地狱" // 没想到吧,这里还有一个难度
        }
    }
    
    func clearHistory() {
        HistoryManager.shared.clear()
        loadHistory()
    }
}
