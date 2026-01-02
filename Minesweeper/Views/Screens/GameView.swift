//
//  GameViews.swift (多语言版本)
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/22.
//

import SwiftUI

struct GameView: View {
    @ObservedObject var localization = LocalizationManager.shared
    // 游戏的大脑，掌控着雷区的生杀大权
    @StateObject var game: MinesweeperGame
    // 用于逃离战场的紧急出口
    @Environment(\.presentationMode) var presentationMode
    // 当前手中的工具：是铲子(dig)还是旗帜(flag)？
    @State private var inputMode: InputMode = .dig
    
    // 提示文本状态：告诉用户"种子已复制"，虽然他们可能只是手滑
    @State private var showCopyToast = false
    
    // MARK: - 缩放相关状态
    // 格子大小：太小了费眼睛，太大了费手指
    private let baseCellSize: CGFloat = 35.0
    
    // 【关键】：初始化逻辑
    // 上帝掷骰子的地方，或者你指定上帝掷出几点（如果有 seed）
    // 【修改】增加了 theme 参数，接收从主页传过来的皮肤设置
    init(difficulty: Difficulty, seed: Int? = nil, theme: GameTheme = .classic, isGodMode: Bool = false, isNanagokyuuMode: Bool = false) {
        // 将上帝模式和作者模式状态传递给 ViewModel
        let newGame = MinesweeperGame(
            difficulty: difficulty,
            theme: theme, // 传入皮肤
            isGodMode: isGodMode,
            isNanagokyuuMode: isNanagokyuuMode
        )
        // 如果有种子，就用种子重新开局，复刻那场经典的战役
        if let customSeed = seed {
            newGame.startNewGame(with: customSeed)
        }
        // 否则 newGame 已经在内部通过 generateEnvironmentalSeed() 初始化好了
        _game = StateObject(wrappedValue: newGame)
    }
    
    var body: some View {
        ZStack {
            // 背景色：平平无奇的灰色，衬托出雷区的惊心动魄
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 16) {
                // 1. 顶部状态栏：你的生命体征监视器
                headerView
                
                // 【新增】：种子显示栏 (点击可复制)
                // 命运的代码，复制它，分享给朋友，让他们也感受同样的绝望
                seedDisplayView
                
                Spacer()
                
                // 2. 棋盘区域：每一步都可能是最后一步
                boardView
                
                Spacer()
                
                // 3. 底部模式切换栏：工欲善其事，必先利其器
                footerView
            }
            // 游戏结束时模糊背景，让你的注意力集中在那个残酷的结果上
            .blur(radius: game.showResult ? 10 : 0)
            
            // 复制提示 Toast：一个小小的反馈，证明你确实点到了
            if showCopyToast {
                VStack {
                    Spacer()
                    Text(localization.text(.seedCopied))
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                        .padding(.bottom, 100)
                }
                .transition(.opacity)
                .zIndex(100)
            }
            
            // 结算弹窗：审判时刻
            if game.showResult {
                ResultPopup(
                    isWin: game.gameStatus == .won,
                    timeElapsed: game.timeElapsed,
                    onRetry: { game.startNewGame() }, // 重试时随机新种子，开启新的轮回
                    onReview: { withAnimation { game.showResult = false } }, // 复盘：看看你是怎么死的
                    onExit: { presentationMode.wrappedValue.dismiss() } // 逃跑：虽然可耻但有用
                )
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - 子视图
    
    private var headerView: some View {
        HStack {
            // 剩余雷数：你的 KPI，不归零就别想下班
            HStack(spacing: 4) {
                // 【修改】图标跟随皮肤变化：是炸弹还是花朵？
                if UIImage(systemName: game.currentTheme.mineIcon) != nil {
                    Image(systemName: game.currentTheme.mineIcon)
                        .foregroundColor(game.gameStatus == .lost ? .gray : game.currentTheme.explodedColor)
                } else {
                    Text(game.currentTheme.mineIcon)
                }
                
                let remaining = game.totalMines - game.grid.filter { $0.isFlagged }.count
                Text("\(remaining)")
                    .foregroundColor(.primary)
                    .monospacedDigit().fontWeight(.bold)
                    .frame(minWidth: 25, alignment: .leading)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2)
            
            Spacer()
            
            // 重置按钮：那个嘲讽你的笑脸
            // 点击它，意味着你不服气，要重来一局（全新种子）
            Button(action: {
                // 保持当前种子重置：哪里跌倒，就在哪里再跌倒一次
                withAnimation { game.startNewGame() }
                HapticManager.shared.light()
            }) {
                ZStack {
                    VStack(spacing: 0) {
                        // 如果是上帝模式，显示一个特殊的图标
                        // 如果是倒霉蛋模式，显示一个哭脸
                        if game.isNanagokyuuMode {
                            Text("🤡").font(.headline)
                        } else if game.isGodMode {
                            Text("👁️").font(.headline)
                        } else {
                            Text(game.difficulty.icon).font(.headline)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(Circle())
                    .shadow(color: .black.opacity(0.05), radius: 2)
                }
            }
            // 长按笑脸 = 随机新种子：这局太背了，换个风水
            .onLongPressGesture {
                withAnimation { game.startNewGame() } // 随机
                HapticManager.shared.heavy()
            }
            
            Spacer()
            
            // 计时器：记录你浪费了多少人生
            HStack(spacing: 4) {
                Image(systemName: "clock.fill").foregroundColor(.blue)
                Text(formatTime(game.timeElapsed))
                    .foregroundColor(.primary)
                    .monospacedDigit().fontWeight(.bold)
                    .frame(minWidth: 45, alignment: .trailing)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2)
        }
        .padding(.horizontal).padding(.top)
    }
    
    // 【新增】：种子显示条
    private var seedDisplayView: some View {
        Button(action: {
            UIPasteboard.general.string = String(game.currentSeed)
            HapticManager.shared.light()
            withAnimation { showCopyToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showCopyToast = false }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "number.square")
                    .font(.caption)
                Text("\(localization.text(.seed)): \(game.currentSeed)")
                    .font(.caption).monospacedDigit()
                Image(systemName: "doc.on.doc")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
        }
    }
    
    // 棋盘区域：这里埋葬了无数英雄的梦想
    private var boardView: some View {
        ZoomableScrollView {
            VStack(spacing: 2) {
                ForEach(0..<game.rows, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<game.cols, id: \.self) { col in
                            let index = row * game.cols + col
                            if index < game.grid.count {
                                // 【修改】将当前皮肤 (game.currentTheme) 传递给格子
                                CellView(cell: game.grid[index], isGodMode: game.isGodMode, theme: game.currentTheme)
                                    .equatable()
                                    .frame(width: baseCellSize, height: baseCellSize)
                                    // 点击：可能是惊喜，也可能是惊吓
                                    .onTapGesture { handleSmartTap(at: index) }
                                    // 长按：深思熟虑后的标记
                                    .onLongPressGesture(minimumDuration: 0.25) { handleSmartLongPress(at: index) }
                            }
                        }
                    }
                }
            }
            .padding(20)
            .background(Color.clear) // 明确背景透明
        }
        .background(Color.black.opacity(0.03))
        .cornerRadius(20)
        .padding(.horizontal, 10)
    }
    
    // 底部操作栏：你的武器库
    private var footerView: some View {
        VStack {
            HStack(spacing: 20) {
                // 挖雷模式：莽夫的选择
                ModeButton(
                    title: localization.text(.modeDigging),
                    icon: "hammer.fill",
                    isSelected: inputMode == .dig,
                    color: .blue
                ) {
                    inputMode = .dig
                    HapticManager.shared.light()
                }
                
                // 插旗模式：智者的选择
                ModeButton(
                    title: localization.text(.modeFlagging),
                    icon: "flag.fill",
                    isSelected: inputMode == .flag,
                    color: .orange
                ) {
                    inputMode = .flag
                    HapticManager.shared.light()
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 10)
            .disabled(game.gameStatus != .playing)
            .opacity(game.gameStatus == .playing ? 1 : 0.6)
            
            // 退出按钮：留得青山在，不怕没柴烧
            Button(localization.text(.exitGame)) {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.gray).font(.caption).padding(.bottom, 5)
            .disabled(game.gameStatus == .exploding)
        }
    }
    
    // MARK: - 交互逻辑 (保持不变)
    
    private func handleSmartTap(at index: Int) {
        let cell = game.grid[index]
        if cell.isRevealed {
            game.quickReveal(at: index)
        } else {
            switch inputMode {
            case .dig:
                if cell.isFlagged {
                    HapticManager.shared.light()
                } else {
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.6)) {
                        game.revealCell(at: index)
                    }
                }
            case .flag:
                game.toggleFlag(at: index)
            }
        }
    }

    private func handleSmartLongPress(at index: Int) {
        let cell = game.grid[index]
        guard !cell.isRevealed else { return }
        if inputMode == .dig {
            game.toggleFlag(at: index)
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
