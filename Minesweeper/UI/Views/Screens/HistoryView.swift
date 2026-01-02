//
//  HistoryView.swift (多语言版本)
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//
//  历史记录说真的不见得多实用，我只是想顺手做一个
//  不是我怎么越做越上头了，还加了回放功能
//  现在还支持多语言了，真是停不下来

import SwiftUI

// MARK: - 历史记录视图
// 这里存放着你的血泪史，每一条记录都是一次心跳加速的旅程
// 现在还能用五种语言回顾你的黑历史
struct HistoryView: View {
    @ObservedObject var localization = LocalizationManager.shared
    @ObservedObject var game: MinesweeperGame
    @StateObject private var cloudSync = CloudSyncManager.shared
    @Environment(\.dismiss) var dismiss
    
    // 用于控制回放弹窗
    @State private var selectedReplayRecord: GameRecord?
    
    // 日期格式化
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f  // 不再硬编码中文locale，让系统自动适配
    }()

    var body: some View {
        NavigationView {
            List {
                // 1. iCloud 同步状态栏
                // 看看你的数据有没有飞到云端去
                CloudSyncStatusView(cloudSync: cloudSync) {
                    game.loadHistory()
                }
                
                // 2. 列表内容
                if game.history.isEmpty {
                    EmptyHistoryView()
                } else {
                    Section(header: Text(localization.text(.history)).font(.caption)) {
                        ForEach(game.history) { record in
                            // 记录行视图
                            HistoryRowView(record: record, formatter: dateFormatter)
                                .contentShape(Rectangle()) // 扩大点击区域
                                .onTapGesture {
                                    handleRecordTap(record)
                                }
                                // 滑动操作：左滑置顶，右滑删除，人生要是也能这样就好了
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation { game.deleteRecord(record) }
                                    } label: {
                                        Label(localization.text(.delete), systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        withAnimation { game.togglePin(record) }
                                    } label: {
                                        Label(record.isPinned ? localization.text(.unpin) : localization.text(.pin),
                                              systemImage: record.isPinned ? "pin.slash" : "pin")
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                }
            }
            .navigationTitle(localization.text(.historyTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localization.text(.close)) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localization.text(.clearAll)) {
                        game.clearHistory()
                        HapticManager.shared.light()
                    }
                    .foregroundColor(.red)
                    .disabled(game.history.isEmpty)
                }
            }
            .onAppear {
                game.loadHistory()
                if cloudSync.isCloudAvailable {
                    cloudSync.downloadFromCloud()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        game.loadHistory()
                    }
                }
            }
            .fullScreenCover(item: $selectedReplayRecord) { record in
                ReplayView(viewModel: ReplayViewModel(record: record))
            }
        }
    }
    
    // 处理点击逻辑
    // 点击回放：公开处刑还是自我欣赏？
    private func handleRecordTap(_ record: GameRecord) {
        if record.moves != nil && !(record.moves!.isEmpty) {
            // 有录像数据，进入回放
            selectedReplayRecord = record
            HapticManager.shared.light()
        } else {
            // 旧数据或无录像，给予错误震动反馈：抱歉，这段记忆已模糊
            HapticManager.shared.failure()
        }
    }
}

// MARK: - 子视图：单行记录
// 每一行都是一段故事，有的惊心动魄，有的草草收场
struct HistoryRowView: View {
    @ObservedObject var localization = LocalizationManager.shared
    let record: GameRecord
    let formatter: DateFormatter
    
    var body: some View {
        HStack {
            // 胜利的绿色，还是失败的红色？
            Image(systemName: record.isWin ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(record.isWin ? .green : .red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.localizedDifficultyName(localization: localization))
                        .font(.headline)
                    if record.isPinned {
                        // 置顶：永远铭记
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .rotationEffect(.degrees(45))
                    }
                }
                
                // 【新增】显示种子信息
                // 命运的代码，如果你想再挑战一次命运
                if let seed = record.seed {
                    Text("#\(seed)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(.gray)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(3)
                }
                
                Text(formatter.string(from: record.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2).foregroundColor(.gray)
                    Text(formatTime(record.duration))
                        .font(.monospacedDigit(.body)())
                }
                
                if record.moves != nil {
                    HStack(spacing: 2) {
                        Image(systemName: "play.tv.fill")
                        Text(localization.text(.replay))
                    }
                    .font(.caption2)
                    .foregroundColor(.blue.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// MARK: - 子视图：iCloud 状态
// 云端连接状态：看老天爷赏不赏脸
struct CloudSyncStatusView: View {
    @ObservedObject var localization = LocalizationManager.shared
    @ObservedObject var cloudSync: CloudSyncManager
    let onReload: () -> Void
    
    var body: some View {
        Section {
            if cloudSync.isCloudAvailable {
                HStack {
                    Image(systemName: "icloud.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization.text(.iCloudReady))
                            .font(.headline)
                        
                        if let lastSync = cloudSync.lastSyncDate {
                            Text("\(localization.text(.lastSync)): \(lastSync, style: .relative)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text(localization.text(.waitingSync))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if cloudSync.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button(action: {
                            cloudSync.downloadFromCloud()
                            HapticManager.shared.light()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                onReload()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.body)
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.icloud")
                        .foregroundColor(.orange)
                    Text(localization.text(.iCloudUnavailable))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - 子视图：空状态
// 一片空白，就像你的大脑（划掉）就像新的开始
struct EmptyHistoryView: View {
    @ObservedObject var localization = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            Text(localization.text(.noHistory))
                .font(.headline)
                .foregroundColor(.gray)
            Text(localization.text(.noHistoryDesc))
                .font(.caption)
                .foregroundColor(.gray.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .listRowBackground(Color.clear)
    }
}

// MARK: - GameRecord扩展 (多语言支持)
// 让历史记录也能说多种语言
// 兼容旧的硬编码中文难度名称，新旧和谐共存
extension GameRecord {
    func localizedDifficultyName(localization: LocalizationManager) -> String {
        // 这里就像一个万能翻译官，不管数据库里存的是哪国语言的“简单”，
        // 都要把它翻译成当前用户设置语言的“简单”。
        switch difficultyName {
        case "简单", "簡單", "Easy", "簡単", "쉬움", "Легко", "Facile", "سهل":
            return localization.text(.difficultyEasy)
            
        case "普通", "Medium", "보통", "Средне", "Moyen", "متوسط":
            return localization.text(.difficultyMedium)
            
        case "困难", "困難", "Hard", "難しい", "어려움", "Сложно", "Difficile", "صعب":
            return localization.text(.difficultyHard)
            
        case "地狱", "地獄", "Hell", "지옥", "Ад", "Enfer", "جحيم":
            return localization.text(.difficultyHell)
            
        default:
            // 如果遇到实在不认识的（比如未来加了火星文），就原样显示
            return difficultyName
        }
    }
}
