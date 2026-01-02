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
        checkWinCondition()
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
        saveGameRecord(isWin: win)
        withAnimation(.spring()) { showResult = true }
        if win { HapticManager.shared.success() }
        else { HapticManager.shared.failure() }
    }
}
