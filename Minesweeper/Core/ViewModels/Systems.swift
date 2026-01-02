//
//  Systems.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//

import Foundation
import UIKit // 引入 UIKit 以获取电池状态

// MARK: - 系统功能 (历史、种子、计时、录制)
extension MinesweeperGame {
    
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
    
    func clearHistory() {
        HistoryManager.shared.clear()
        loadHistory()
    }
    
    func saveGameRecord(isWin: Bool) {
        // 上帝模式下的成绩不计入历史，保持排行榜的纯洁性
        if isGodMode { return }
        
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
    
    // MARK: - 计时器逻辑
    func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.timeElapsed += 1 }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - 种子生成
    // 生成基于环境的玄学种子
    // 既然是玄学,那就贯彻到底,把电量和纳秒都算进去
    func generateEnvironmentalSeed() -> Int {
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
    
    // MARK: - 录制辅助方法
    func recordMove(at index: Int, type: MoveType) {
        guard gameStatus == .playing || gameStatus == .exploding else { return }
        let time = Date().timeIntervalSince(gameStartTime ?? Date())
        let move = GameMove(timestamp: time, index: index, type: type)
        recordedMoves.append(move)
    }
}
