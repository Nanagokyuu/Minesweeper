//
//  Algorithms.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//

import Foundation
import SwiftUI

// MARK: - 算法与特效 (生成、扩散、爆炸、求解)
extension MinesweeperGame {
    
    // MARK: - 生成地雷逻辑 (包含种子支持 + 无猜模式支持)
    func placeMines(excluding safeIndex: Int) {
        // 1. 初始化伪随机生成器,使用当前种子
        var rng = SeededGenerator(seed: currentSeed)
        
        // 如果开启了无猜模式，我们可能需要尝试好几次才能生成一个完美的局
        // 就像是在找对象，合适的总是很难遇到
        let maxAttempts = isNoGuessingMode ? 2000 : 1
        var attempts = 0
        var isValidBoard = false
        
        // 备份初始空状态
        let initialGrid = grid
        
        while !isValidBoard && attempts < maxAttempts {
            attempts += 1
            
            // 如果不是第一次，先清理一下战场
            if attempts > 1 {
                grid = initialGrid
            }
            
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
            
            // 4. 审判时刻：如果是无猜模式，让AI先替你跑一遍
            if isNoGuessingMode {
                // 实例化求解器
                // 【修复点】：现在 BoardSolver 有了明确的 init，不会报错了
                var solver = BoardSolver(rows: rows, cols: cols, grid: grid)
                
                // 从你点击的第一个格子开始推演
                if solver.isSolvable(startIndex: safeIndex) {
                    isValidBoard = true // 完美，这个盘可以通过
                    // print("无猜局生成成功！耗费了 \(attempts) 次尝试")
                } else {
                    // 还要猜？那就重来，CPU多跑几圈就是为了让你少掉几根头发
                    // 这里的 rng 不需要重置，继续往下生成就会得到不一样的序列
                }
            } else {
                // 普通模式，管杀不管埋
                isValidBoard = true
            }
        }
        
        // 最后的最后，如果实在是运气太背生成不出来
        if isNoGuessingMode && !isValidBoard {
            print("Failed to generate NG board after \(maxAttempts) attempts.")
            // 这里就不弹窗了，反正玩家玩的时候也感觉不出来，等他卡住了再默默吐槽吧
        }
    }
    
    func countMinesAround(index: Int) -> Int {
        let neighbors = getNeighbors(index: index)
        return neighbors.filter { grid[$0].isMine }.count
    }
    
    func getNeighbors(index: Int) -> [Int] {
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

    // MARK: - 【改进】爆炸动画
    // 不再是简单的波纹扩散,而是更有冲击力的连锁爆炸
    func triggerChainExplosion(centerIndex: Int) {
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
    func explodeByWaves(distances: [Int], minesByDistance: [Int: [Int]], currentWaveIndex: Int) {
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
}

// MARK: - 求解器 (专门用来检测是不是无猜局)
// 也就是让电脑先替你试毒，如果电脑都得靠猜，那这局就重开
struct BoardSolver {
    let rows: Int
    let cols: Int
    let grid: [Cell] // 这里存的是上帝视角的全图
    
    // 模拟玩家视角的棋盘状态
    private var knownMines: Set<Int> = []
    private var knownSafe: Set<Int> = []
    
    // 【关键修复】：显式添加初始化器
    // 因为属性有 private，系统自动生成的 init 可能会变成 private 或包含私有参数导致外部无法调用
    init(rows: Int, cols: Int, grid: [Cell]) {
        self.rows = rows
        self.cols = cols
        self.grid = grid
        // knownMines 和 knownSafe 使用默认值 [] 初始化
    }
    
    // 检查这个盘是不是纯逻辑可解
    // 也就是“拒绝赌狗，从我做起”
    mutating func isSolvable(startIndex: Int) -> Bool {
        // 第一步永远是安全的，先把它加入已知安全列表
        knownSafe.insert(startIndex)
        
        var progressMade = true
        
        // 只要还在取得进展，就继续循环
        while progressMade {
            progressMade = false
            
            // 遍历所有我们已经确认为安全（且未完全处理完）的格子
            for index in knownSafe {
                // 如果这个格子周围的雷已经找齐了，或者格子本身就是0，那周围没开的都是安全的
                // 如果这个格子周围的未知格子数量 == 剩余雷数，那周围未知的都是雷
                
                let neighbors = getNeighbors(index: index)
                // 筛选出周围未被揭示（且不在已知雷列表里）的邻居
                let unrevealedNeighbors = neighbors.filter { !knownSafe.contains($0) && !knownMines.contains($0) }
                
                if unrevealedNeighbors.isEmpty { continue } // 这个格子已经处理完了，跳过
                
                let neighborMinesCount = grid[index].neighborMines
                
                // 找出已经被标记为雷的邻居数量
                let foundMinesCount = neighbors.filter { knownMines.contains($0) }.count
                
                // 逻辑 A: 剩余未知格子 == 剩余需要找的雷 -> 剩下的全是雷
                // 比如：数字是3，已经标了1个雷，还剩2个雷，正好周围只剩2个没开的格子 -> 全是雷！
                if unrevealedNeighbors.count == (neighborMinesCount - foundMinesCount) {
                    for mineIndex in unrevealedNeighbors {
                        if !knownMines.contains(mineIndex) {
                            knownMines.insert(mineIndex)
                            progressMade = true
                        }
                    }
                }
                
                // 逻辑 B: 已经找齐了雷 -> 剩下的全是安全
                // 比如：数字是1，周围已经标了1个雷 -> 剩下没开的都是安全的，放心点
                if foundMinesCount == neighborMinesCount {
                    for safeIndex in unrevealedNeighbors {
                        if !knownSafe.contains(safeIndex) {
                            knownSafe.insert(safeIndex)
                            progressMade = true
                        }
                    }
                }
            }
        }
        
        // 循环结束后，看看是不是所有非雷的格子都被我们推导出来了
        // 如果还有没推导出来的，说明这局需要猜，那就是不合格的盘
        let totalCells = rows * cols
        let totalMines = grid.filter { $0.isMine }.count
        
        // 如果失败了，在这里留下一句吐槽
        // if (knownSafe.count + knownMines.count) != totalCells { print("Computer: I gave up.") }
        
        return (knownSafe.count + knownMines.count) == totalCells || knownSafe.count == (totalCells - totalMines)
    }
    
    // 辅助方法：获取邻居 (跟主逻辑里的一样，复用代码是美德)
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
}
