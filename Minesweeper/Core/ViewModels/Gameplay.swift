//
//  Gameplay.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//

import Foundation
import SwiftUI

// MARK: - 游戏核心交互逻辑
extension MinesweeperGame {
    
    func revealCell(at index: Int) {
        guard gameStatus == .playing else { return }
        guard !grid[index].isFlagged && !grid[index].isRevealed else { return }
        
        if isFirstClick {
            gameStartTime = Date()
            
            // 【新增】判断是否为 Nanagokyuu 模式
            if isNanagokyuuMode {
                // 惊喜不？意外不？
                // 既然你诚心诚意地输入了我的名字，那我就大发慈悲地送你上路
                // 强制把当前点击的格子变成雷，无视任何生成规则
                grid[index].isMine = true
                
                // 为了让场面更壮观，我们不妨把除了这个雷以外的很多地方也变成雷
                // 让玩家死得明明白白：你不是运气不好，你是被针对了
                for i in 0..<grid.count {
                    if i != index && Bool.random() { // 50%概率全图埋雷
                         grid[i].isMine = true
                    }
                }
                
                // 记录一下这短暂的一生
                actualMineIndices = grid.indices.filter { grid[$0].isMine }
                
            } else {
                // 正常的生成逻辑：第一次点击永远安全
                placeMines(excluding: index)
            }
            
            isFirstClick = false
            startTimer()
            
            // 如果不是恶作剧模式，我们才去记录雷的位置
            // 因为恶作剧模式上面已经强行记录过了
            if !isNanagokyuuMode {
                actualMineIndices = grid.indices.filter { grid[$0].isMine }
            }
        }
        
        recordMove(at: index, type: .reveal)
        
        if grid[index].isMine {
            // 【改进】先翻开第一个雷,再触发连锁爆炸
            grid[index].isTriggeredMine = true
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
        checkWinCondition()
    }
    
    // MARK: - 极速双击
    func quickReveal(at index: Int) {
        guard gameStatus == .playing else { return }
        let cell = grid[index]
        guard cell.isRevealed && cell.neighborMines > 0 else { return }
        
        let neighbors = getNeighbors(index: index)
        let flaggedCount = neighbors.filter { grid[$0].isFlagged }.count
        
        if flaggedCount == cell.neighborMines {
            var didReveal = false
            for neighborIndex in neighbors {
                if !grid[neighborIndex].isRevealed && !grid[neighborIndex].isFlagged {
                    revealCell(at: neighborIndex)
                    didReveal = true
                }
            }
            if didReveal { HapticManager.shared.light() }
        } else {
            HapticManager.shared.failure()
        }
    }
    
    // MARK: - 游戏结算
    func checkWinCondition() {
        let allSafeRevealed = grid.filter { $0.isRevealed }.count == (rows * cols) - totalMines
        
        // 新增判定：所有地雷都被正确插旗，且无误插的旗帜
        let allMinesFlagged = grid.filter { $0.isMine && $0.isFlagged }.count == totalMines
        let hasWrongFlag = grid.contains { !$0.isMine && $0.isFlagged }
        
        if allSafeRevealed || (allMinesFlagged && !hasWrongFlag) {
            gameOver(win: true)
            HapticManager.shared.success()
        }
    }
    
    func gameOver(win: Bool) {
        stopTimer()
        gameStatus = win ? .won : .lost
        if win { revealAllSafeCells() } // 胜利时自动翻开所有非雷格
        saveGameRecord(isWin: win)
        withAnimation(.spring()) { showResult = true }
        if win { HapticManager.shared.success() }
        else { HapticManager.shared.failure() }
    }
    
    // MARK: - 胜利后自动翻开所有安全格
    func revealAllSafeCells() {
        for i in 0..<grid.count where !grid[i].isMine {
            grid[i].isRevealed = true
        }
    }
}
