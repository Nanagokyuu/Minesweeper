//
//  CloudSyncManager.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//

import Foundation
import Combine

class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()
    
    // 正在努力搬运数据，请勿打扰
    @Published var isSyncing = false
    // 上次和云端通话的时间，如果太久远，可能云端已经把你忘了
    @Published var lastSyncDate: Date?
    
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let localKey = "minesweeper_history_v4"
    private let cloudKey = "minesweeper_cloud_history_v4"
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 监听 iCloud 变化：时刻准备着接收来自云端的指令
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudDataChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )
        
        // 启动时同步一次：先打个招呼
        ubiquitousStore.synchronize()
    }
    
    // MARK: - 上传到 iCloud
    // 把你的光辉战绩（或丢人时刻）上传到云端，让苹果服务器替你保管
    func uploadToCloud() {
        guard let localData = UserDefaults.standard.data(forKey: localKey) else { return }
        
        isSyncing = true
        ubiquitousStore.set(localData, forKey: cloudKey)
        ubiquitousStore.synchronize()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isSyncing = false
            self?.lastSyncDate = Date()
        }
    }
    
    // MARK: - 从 iCloud 下载
    // 从云端取回记忆，希望能找回那些丢失的美好（如果有的话）
    func downloadFromCloud() {
        guard let cloudData = ubiquitousStore.data(forKey: cloudKey) else { return }
        
        isSyncing = true
        
        // 合并逻辑：取两边的记录，去重后保存
        // 就像合并两个平行宇宙的时间线
        let cloudRecords = (try? JSONDecoder().decode([GameRecord].self, from: cloudData)) ?? []
        let localRecords = HistoryManager.shared.load()
        
        // 去重：以 id 为准，优先保留云端的
        var merged: [GameRecord] = cloudRecords
        for local in localRecords {
            if !merged.contains(where: { $0.id == local.id }) {
                merged.append(local)
            }
        }
        
        // 排序并保存
        let sorted = merged.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.date > $1.date
        }
        
        if let encoded = try? JSONEncoder().encode(sorted) {
            UserDefaults.standard.set(encoded, forKey: localKey)
            UserDefaults.standard.synchronize()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isSyncing = false
            self?.lastSyncDate = Date()
        }
    }
    
    // MARK: - iCloud 数据变化回调
    // 云端有动静了！可能是你在另一台设备上又输了一局
    @objc private func cloudDataChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.downloadFromCloud()
        }
    }
    
    // MARK: - 检查 iCloud 是否可用
    // 看看老天爷（iCloud）赏不赏脸
    var isCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}
