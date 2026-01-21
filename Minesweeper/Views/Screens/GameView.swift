//
//  GameViews.swift (多语言版本 + Mac 鼠标支持)
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/22.
//  Enhanced for Mac (iPad version) by Claude on 2026/01/16
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
    
    // 【新增】追踪当前鼠标悬停的格子索引，用于键盘操作
    @State private var hoveredIndex: Int? = nil
    
    // MARK: - 缩放相关状态
    // 格子大小：太小了费眼睛，太大了费手指
    private let baseCellSize: CGFloat = 35.0
    
    // 【新增】检测是否在 Mac 上运行（iPad 版本）
    // 这个判断在 Mac 上运行 iPad 应用时返回 true
    private var isRunningOnMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        // 在 Mac 上运行的 iPad 应用，进程名会包含 Mac 相关信息
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return true
        }
        return false
        #endif
    }
    
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
                // 【Mac 优化】在 Mac 上隐藏模式切换按钮或显示提示
                if isRunningOnMac {
                    macFooterView
                } else {
                    footerView
                }
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
            
            // 【新增】键盘事件响应器 (隐藏的按钮)
            // 利用 Button 的 keyboardShortcut 可以在整个 View 树中捕获按键
            // 只有在 Mac 上运行且没有弹窗时才生效
            if isRunningOnMac && !game.showResult {
                Group {
                    Button(action: { handleKeyZ() }) { Text("Z").opacity(0) }
                        .keyboardShortcut("z", modifiers: []) // 监听 Z 键，无修饰符
                    
                    Button(action: { handleKeyX() }) { Text("X").opacity(0) }
                        .keyboardShortcut("x", modifiers: []) // 监听 X 键，无修饰符
                        
                    // 【新增】ESC 键退出游戏，无修饰符
                    Button(action: {
                        // 爆炸时禁止退出，防止动画未结束导致状态异常（与退出按钮逻辑一致）
                        if game.gameStatus != .exploding {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) { Text("ESC").opacity(0) }
                        .keyboardShortcut(.escape, modifiers: [])
                }
                .frame(width: 0, height: 0) // 隐藏起来
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
                                // 【Mac 增强】在 Mac 上使用支持右键的视图
                                if isRunningOnMac {
                                    MouseAwareCellView(
                                        cell: game.grid[index],
                                        isGodMode: game.isGodMode,
                                        theme: game.currentTheme,
                                        onLeftClick: { handleSmartTap(at: index) },
                                        onRightClick: { game.toggleFlag(at: index) }
                                    )
                                    .frame(width: baseCellSize, height: baseCellSize)
                                    // 【新增】追踪鼠标悬停位置，为了让键盘 Z/X 知道该炸谁
                                    .onHover { isHovering in
                                        if isHovering {
                                            self.hoveredIndex = index
                                        } else if self.hoveredIndex == index {
                                            // 离开时如果当前记录还是自己，则置空
                                            self.hoveredIndex = nil
                                        }
                                    }
                                } else {
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
            }
            .padding(20)
            .background(Color.clear) // 明确背景透明
        }
        .background(Color.black.opacity(0.03))
        .cornerRadius(20)
        .padding(.horizontal, 10)
    }
    
    // 底部操作栏（iOS 和 Mac 触摸屏）：你的武器库
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
    
    // 【新增】Mac 底部操作栏：显示鼠标操作提示
    // 现在改为了键盘提示，Z和X是新的神
    private var macFooterView: some View {
        VStack(spacing: 10) {
            // 鼠标操作提示 (现在是键盘快捷键提示)
            HStack(spacing: 20) {
                HStack(spacing: 8) {
                    // 图标改为键盘，更直观
                    Image(systemName: "keyboard")
                        .foregroundColor(.blue)
                    // Z键: 挖雷
                    Text(localization.text(.keyZDig))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    // 图标改为键盘
                    Image(systemName: "keyboard")
                        .foregroundColor(.orange)
                    // X键: 插旗
                    Text(localization.text(.keyXFlag))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            // 退出按钮：留得青山在，不怕没柴烧
            Button(localization.text(.exitGame)) {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.gray).font(.caption).padding(.bottom, 5)
            .disabled(game.gameStatus == .exploding)
        }
    }
    
    // MARK: - 交互逻辑 (保持不变)
    
    // 【新增】处理 Z 键 (挖雷)
    private func handleKeyZ() {
        guard let index = hoveredIndex, game.gameStatus == .playing else { return }
        // 模拟智能点击（如果是未翻开则挖开，如果是已翻开则尝试双击）
        handleSmartTap(at: index)
    }
    
    // 【新增】处理 X 键 (插旗)
    private func handleKeyX() {
        guard let index = hoveredIndex, game.gameStatus == .playing else { return }
        // 直接插旗/取消插旗
        let cell = game.grid[index]
        if !cell.isRevealed {
            game.toggleFlag(at: index)
        }
    }
    
    private func handleSmartTap(at index: Int) {
        let cell = game.grid[index]
        if cell.isRevealed {
            game.quickReveal(at: index)
        } else {
            // 【Mac 优化】在 Mac 上左键直接挖雷
            if isRunningOnMac {
                if cell.isFlagged {
                    HapticManager.shared.light()
                } else {
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.6)) {
                        game.revealCell(at: index)
                    }
                }
            } else {
                // iOS 保持原有逻辑
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

// MARK: - 【新增】支持鼠标右键的格子视图（Mac iPad 应用专用）
struct MouseAwareCellView: UIViewRepresentable {
    let cell: Cell
    let isGodMode: Bool
    let theme: GameTheme
    let onLeftClick: () -> Void
    let onRightClick: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // 创建 SwiftUI 的 CellView 并嵌入
        let cellView = CellView(cell: cell, isGodMode: isGodMode, theme: theme)
            .equatable()
        
        let hostingController = UIHostingController(rootView: cellView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = containerView.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(hostingController.view)
        
        // 保存 hostingController 到 coordinator，以便后续更新
        context.coordinator.hostingController = hostingController
        
        // 添加手势识别器
        // 左键点击（主要按钮 = 0）
        let leftClickGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLeftClick))
        leftClickGesture.buttonMaskRequired = .primary // 主按钮（鼠标左键）
        containerView.addGestureRecognizer(leftClickGesture)
        
        // 右键点击（次要按钮 = 1）
        let rightClickGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRightClick))
        rightClickGesture.buttonMaskRequired = .secondary // 次要按钮（鼠标右键）
        containerView.addGestureRecognizer(rightClickGesture)
        
        // 保存回调到 coordinator
        context.coordinator.onLeftClick = onLeftClick
        context.coordinator.onRightClick = onRightClick
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 【修复】更新 CellView - 使用保存的 hostingController
        let cellView = CellView(cell: cell, isGodMode: isGodMode, theme: theme)
            .equatable()
        
        context.coordinator.hostingController?.rootView = cellView
        
        // 更新回调
        context.coordinator.onLeftClick = onLeftClick
        context.coordinator.onRightClick = onRightClick
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var onLeftClick: (() -> Void)?
        var onRightClick: (() -> Void)?
        // 【新增】保存 hostingController 引用
        var hostingController: UIHostingController<EquatableView<CellView>>?
        
        @objc func handleLeftClick() {
            onLeftClick?()
        }
        
        @objc func handleRightClick() {
            onRightClick?()
        }
    }
}
