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
            
            // 棋盘区域：复用游戏棋盘，地狱回放会自动走 Canvas，
            // 拖拽进度时不再重建 720 个 CellView。
            ZStack {
                Color(UIColor.systemGroupedBackground)

                GameBoardView(
                    cells: viewModel.grid,
                    rows: viewModel.rows,
                    cols: viewModel.cols,
                    theme: theme,
                    isGodMode: false,
                    isRunningOnMac: false,
                    inputMode: .dig,
                    hoveredIndex: .constant(nil),
                    onTap: { _ in },
                    onLongPress: { _ in },
                    onRightClick: { _ in }
                )
                .equatable()
            }

            // 底部控制栏
            VStack(spacing: 15) {
                // 进度条
                Slider(value: Binding(
                    get: { viewModel.progress },
                    set: { newVal in
                        let step = Int(newVal * Double(viewModel.movesCount))
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
                
                Text("\(localization.text(.stepCount)): \(viewModel.currentStepIndex) / \(viewModel.movesCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationBarHidden(true)
        .onDisappear {
            viewModel.stop()
        }
    }
    
    private func cycleSpeed() {
        viewModel.cycleSpeed()
    }
}
