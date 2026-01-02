//
//  ReplayView.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//
//  玩地平线4的时候突发的灵感，就这么尝试实现了一下子
//  现在还能用五种语言看回放，国际化就是这么简单

import SwiftUI

// 回放影院：坐好，爆米花准备，开始欣赏或复盘
// 现在支持多语言字幕了（虽然没有真的字幕）
struct ReplayView: View {
    @ObservedObject var localization = LocalizationManager.shared
    @StateObject var viewModel: ReplayViewModel
    // 【新增】接收皮肤，回放也要有面子
    let theme: GameTheme
    @Environment(\.dismiss) var dismiss
    
    // 复用 CellView 的尺寸
    private let baseCellSize: CGFloat = 35.0
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                // 关灯散场
                Button(localization.text(.close)) { dismiss() }
                Spacer()
                Text(localization.text(.replayTitle)).font(.headline)
                Spacer()
                // 倍速切换：剧情快进，小心漏掉细节
                Button(action: {
                    cycleSpeed()
                }) {
                    Text("\(String(format: "%.1f", viewModel.playbackSpeed))x")
                        .font(.subheadline).bold()
                        .padding(6)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // 棋盘区域 (复用 ZoomableScrollView)
            ZStack {
                // 【修改】背景色跟随系统
                Color(UIColor.systemGroupedBackground)
                
                ZoomableScrollView {
                    VStack(spacing: 2) {
                        ForEach(0..<viewModel.rows, id: \.self) { row in
                            HStack(spacing: 2) {
                                ForEach(0..<viewModel.cols, id: \.self) { col in
                                    let index = row * viewModel.cols + col
                                    if index < viewModel.grid.count {
                                        // 【修复报错的关键点】在这里！
                                        // 补上了 theme 参数，让回放也支持皮肤
                                        CellView(
                                            cell: viewModel.grid[index],
                                            isGodMode: false,
                                            theme: theme // 传入皮肤
                                        )
                                        .equatable()
                                        .frame(width: baseCellSize, height: baseCellSize)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.clear)
                }
            }
            
            // 底部控制栏
            VStack(spacing: 15) {
                // 进度条
                Slider(value: Binding(
                    get: { viewModel.progress },
                    set: { newVal in
                        let step = Int(newVal * Double(viewModel.moves.count))
                        viewModel.seek(to: step)
                    }
                ))
                .tint(.blue)
                
                // 播放按钮
                Button(action: {
                    viewModel.togglePlay()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill") // 停还是播，由你掌控
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                        .symbolRenderingMode(.hierarchical)
                }
                
                Text("\(localization.text(.stepCount)): \(viewModel.currentStepIndex) / \(viewModel.moves.count)") // 片长统计
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationBarHidden(true)
    }
    
    private func cycleSpeed() {
        // 倍速循环：1x -> 2x -> 4x -> 回到 1x
        if viewModel.playbackSpeed == 1.0 { viewModel.playbackSpeed = 2.0 }
        else if viewModel.playbackSpeed == 2.0 { viewModel.playbackSpeed = 4.0 }
        else { viewModel.playbackSpeed = 1.0 }
        
        // 如果正在播放，重启计时器以应用新速度
        if viewModel.isPlaying {
            viewModel.togglePlay() // 先停
            viewModel.togglePlay() // 再开
        }
    }
}
