//
//  ReplayView.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//

import SwiftUI

// 回放影院：坐好，爆米花准备，开始欣赏或复盘
struct ReplayView: View {
    @ObservedObject var localization = LocalizationManager.shared
    @StateObject var viewModel: ReplayViewModel
    // 接收皮肤
    let theme: GameTheme
    @Environment(\.dismiss) var dismiss
    
    // 复用 CellView 的尺寸
    private let baseCellSize: CGFloat = 35.0
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                // 关灯散场
                Button(action: { dismiss() }) {
                    Text(localization.text(.close))
                        .fontWeight(.medium)
                        // 【修改】明确指定为蓝色，防止看不清
                        .foregroundColor(.blue)
                }
                
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
                        // 给个小背景，防止和标题栏混在一起
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(8)
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // 棋盘区域 (复用 ZoomableScrollView)
            ZStack {
                // 背景色跟随系统
                Color(UIColor.systemGroupedBackground)
                
                ZoomableScrollView {
                    VStack(spacing: 2) {
                        ForEach(0..<viewModel.rows, id: \.self) { row in
                            HStack(spacing: 2) {
                                ForEach(0..<viewModel.cols, id: \.self) { col in
                                    let index = row * viewModel.cols + col
                                    if index < viewModel.grid.count {
                                        // 传入 theme
                                        CellView(
                                            cell: viewModel.grid[index],
                                            isGodMode: false,
                                            theme: theme
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
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                        .symbolRenderingMode(.hierarchical)
                }
                
                Text("\(localization.text(.stepCount)): \(viewModel.currentStepIndex) / \(viewModel.moves.count)")
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
        if viewModel.playbackSpeed == 1.0 { viewModel.playbackSpeed = 2.0 }
        else if viewModel.playbackSpeed == 2.0 { viewModel.playbackSpeed = 4.0 }
        else { viewModel.playbackSpeed = 1.0 }
        
        if viewModel.isPlaying {
            viewModel.togglePlay()
            viewModel.togglePlay()
        }
    }
}
