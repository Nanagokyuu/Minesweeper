//
//  ReplayView.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//

import SwiftUI

// 回放影院：坐好，爆米花准备，开始欣赏或复盘
struct ReplayView: View {
    @StateObject var viewModel: ReplayViewModel
    @Environment(\.dismiss) var dismiss
    
    // 复用 CellView 的尺寸
    private let baseCellSize: CGFloat = 35.0
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                // 关灯散场
                Button("关闭") { dismiss() }
                Spacer()
                Text("游戏回放").font(.headline)
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
                Color(UIColor.systemGroupedBackground) // 幕布背景，低调不抢戏
                
                ZoomableScrollView {
                    // 【回归本质】：使用 VStack + HStack
                    VStack(spacing: 2) {
                        ForEach(0..<viewModel.rows, id: \.self) { row in
                            HStack(spacing: 2) {
                                ForEach(0..<viewModel.cols, id: \.self) { col in
                                    let index = row * viewModel.cols + col
                                    if index < viewModel.grid.count {
                                        CellView(cell: viewModel.grid[index])
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
                        let step = Int(newVal * Double(viewModel.record.moves?.count ?? 0))
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
                
                Text("步数: \(viewModel.currentStepIndex) / \(viewModel.record.moves?.count ?? 0)") // 片长统计
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
        // 倍速循环：1x → 2x → 4x → 回到 1x
        if viewModel.playbackSpeed == 1.0 { viewModel.playbackSpeed = 2.0 }
        else if viewModel.playbackSpeed == 2.0 { viewModel.playbackSpeed = 4.0 }
        else { viewModel.playbackSpeed = 1.0 }
    }
}
