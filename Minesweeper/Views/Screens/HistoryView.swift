//
//  HistoryView.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var localization = LocalizationManager.shared
    // 现在 HistoryManager 已经是 ObservableObject 了，这里不会报错了
    @ObservedObject var historyManager = HistoryManager.shared
    @ObservedObject var settings = AppSettings.shared // 引入设置以获取当前皮肤
    
    // 这里保留 game 仅仅是为了以后可能需要的数据引用
    var game: MinesweeperGame
    
    // 选中的记录，用于弹起回放
    @State private var selectedRecord: GameRecord?
    
    var body: some View {
        Group {
            // 【修改】直接使用 .records 属性
            if historyManager.records.isEmpty {
                // 空状态：一片荒芜
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(localization.text(.noHistory))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Text(localization.text(.noHistoryDesc))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                // 列表状态
                List {
                    // 【修改】直接使用 .records 属性
                    ForEach(historyManager.records) { record in
                        Button(action: {
                            selectedRecord = record
                            HapticManager.shared.light()
                        }) {
                            HistoryRow(record: record)
                        }
                        // 列表项的滑动操作：只保留置顶和删除
                        .swipeActions(edge: .leading) {
                            Button {
                                historyManager.togglePin(record)
                            } label: {
                                Label(record.isPinned ? localization.text(.unpin) : localization.text(.pin),
                                      systemImage: record.isPinned ? "pin.slash" : "pin")
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation {
                                    historyManager.delete(record)
                                }
                            } label: {
                                Label(localization.text(.delete), systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(localization.text(.historyTitle))
        .navigationBarTitleDisplayMode(.inline)
        // 弹出的回放页面
        .fullScreenCover(item: $selectedRecord) { record in
            // 初始化回放 ViewModel
            let replayVM = ReplayViewModel(record: record)
            // 将设置里的当前皮肤传进去
            ReplayView(viewModel: replayVM, theme: settings.currentTheme)
        }
        .onAppear {
            // 确保数据是最新的 (虽然 .records 应该是同步的，但如果是刚从云端同步下来可能需要刷新)
            historyManager.reload()
        }
    }
}

// 单行记录视图保持不变
struct HistoryRow: View {
    let record: GameRecord
    @ObservedObject var localization = LocalizationManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    if record.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .rotationEffect(.degrees(45))
                    }
                    Text(record.isWin ? "WIN" : "LOSE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(record.isWin ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .foregroundColor(record.isWin ? .green : .red)
                        .cornerRadius(4)
                    
                    Text(record.difficultyName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("\(record.duration)s")
                }
                .font(.subheadline)
                .monospacedDigit()
                
                if let seed = record.seed {
                    Text("#\(seed)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
