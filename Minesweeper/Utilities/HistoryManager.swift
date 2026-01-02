//
//  HistoryManager.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/24.
//
//  历史记录说真的不见得多实用，我只是想顺手做一个
//  不是我怎么越做越上头了，还加了回放功能
//  甚至支持了多语言，停不下来了属于是

import Foundation
import Combine

// MARK: - 管理器
class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    private let key = "minesweeper_history_v4"
    
    // 【新增】发布者属性
    // 界面直接读取这个数组，一旦变化，界面自动刷新
    // 避免了在 View 的 body 里频繁调用 load() 读取硬盘，性能更佳
    @Published var records: [GameRecord] = []
    
    private init() {
        // 初始化时从硬盘加载一次
        self.records = loadFromDisk()
    }
    
    // 保存单条
    // 记录下这一刻，虽然你可能很快就想删掉它
    func save(_ record: GameRecord) {
        var currentHistory = loadFromDisk()
        // 新记录插入到非置顶区域的最前面
        currentHistory.insert(record, at: 0)
        
        // 限制数量 (保留最近50条)
        // 太多了也记不住，50条足够你回味（或反思）了
        if currentHistory.count > 50 {
            currentHistory = Array(currentHistory.prefix(50))
        }
        
        saveToDisk(currentHistory)
        // 自动上传到 iCloud
        CloudSyncManager.shared.uploadToCloud()
    }
    
    // 删除单条
    // 毁尸灭迹，假装无事发生
    func delete(_ record: GameRecord) {
        var currentHistory = loadFromDisk()
        currentHistory.removeAll { $0.id == record.id }
        saveToDisk(currentHistory)
        // 同步删除
        CloudSyncManager.shared.uploadToCloud()
    }
    
    // 切换置顶状态
    // 把这场战斗钉在耻辱柱（或荣誉墙）上
    func togglePin(_ record: GameRecord) {
        var currentHistory = loadFromDisk()
        if let index = currentHistory.firstIndex(where: { $0.id == record.id }) {
            currentHistory[index].isPinned.toggle()
            saveToDisk(currentHistory) // 保存时会自动排序
            // 同步置顶状态
            CloudSyncManager.shared.uploadToCloud()
        }
    }
    
    // 清空所有
    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        self.records = [] // 更新内存数据
    }
    
    // 重新加载（供 CloudSyncManager 调用以刷新 UI）
    func reload() {
        self.records = loadFromDisk()
    }
    
    // MARK: - 内部私有方法
    
    // 从磁盘读取并排序
    private func loadFromDisk() -> [GameRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let history = try? JSONDecoder().decode([GameRecord].self, from: data) else {
            return []
        }
        
        // 排序逻辑：
        // 1. isPinned 为 true 的排在前面
        // 2. 如果置顶状态相同，则按 date 倒序 (新的在前)
        return history.sorted { (a, b) -> Bool in
            if a.isPinned != b.isPinned {
                return a.isPinned // true 排在 false 前面
            }
            return a.date > b.date
        }
    }
    
    // 保存到磁盘并更新内存
    private func saveToDisk(_ history: [GameRecord]) {
        // 保存前再排一次序，确保数据整洁
        let sortedHistory = history.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.date > $1.date
        }
        
        if let encoded = try? JSONEncoder().encode(sortedHistory) {
            UserDefaults.standard.set(encoded, forKey: key)
            UserDefaults.standard.synchronize()
            
            // 【关键】更新 @Published 属性，通知 UI 刷新
            self.records = sortedHistory
        }
    }
    
    // 为了兼容旧代码的 load() 接口（如果有其他地方用到），我们可以保留这个方法
    // 但建议 UI 层直接使用 .records
    func load() -> [GameRecord] {
        return records
    }
}
