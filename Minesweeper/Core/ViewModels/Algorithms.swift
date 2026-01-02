//
//  Algorithms.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//

import Foundation
import SwiftUI

// MARK: - 算法与特效 (生成、扩散、爆炸)
extension MinesweeperGame {
    
    // MARK: - 生成地雷逻辑 (包含种子支持)
    func placeMines(excluding safeIndex: Int) {
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
