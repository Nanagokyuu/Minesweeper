//
//  HistoryManager.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/24.
//
//  历史记录说真的不见得多实用，我只是想顺手做一个
//  不是我怎么越做越上头了，还加了回放功能

import Foundation

// MARK: - 管理器
class HistoryManager {
    static let shared = HistoryManager()
    private let key = "minesweeper_history_v4"
    
    private init() {}
    
    // 保存单条
    // 记录下这一刻，虽然你可能很快就想删掉它
    func save(_ record: GameRecord) {
        var history = load()
        // 新记录插入到非置顶区域的最前面
        history.insert(record, at: 0)
        
        // 限制数量 (保留最近50条)
        // 太多了也记不住，50条足够你回味（或反思）了
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        
        saveToDisk(history)
        // 自动上传到 iCloud
        CloudSyncManager.shared.uploadToCloud()
    }
    
    // 删除单条
    // 毁尸灭迹，假装无事发生
    func delete(_ record: GameRecord) {
        var history = load()
        history.removeAll { $0.id == record.id }
        saveToDisk(history)
        // 同步删除
        CloudSyncManager.shared.uploadToCloud()
    }
    
    // 切换置顶状态
    // 把这场战斗钉在耻辱柱（或荣誉墙）上
    func togglePin(_ record: GameRecord) {
        var history = load()
        if let index = history.firstIndex(where: { $0.id == record.id }) {
            history[index].isPinned.toggle()
            saveToDisk(history) // 保存时会自动排序
            // 同步置顶状态
            CloudSyncManager.shared.uploadToCloud()
        }
    }
    
    // 读取 (带排序逻辑：置顶的在前，然后按时间倒序)
    // 翻开尘封的档案，看看你过去都干了些什么
    func load() -> [GameRecord] {
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
    
    // 内部保存辅助函数
    private func saveToDisk(_ history: [GameRecord]) {
        // 保存前再排一次序，确保数据整洁
        let sortedHistory = history.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.date > $1.date
        }
        
        if let encoded = try? JSONEncoder().encode(sortedHistory) {
            UserDefaults.standard.set(encoded, forKey: key)
            UserDefaults.standard.synchronize()
        }
    }
    
    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
