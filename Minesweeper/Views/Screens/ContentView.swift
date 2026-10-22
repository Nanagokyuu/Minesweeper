//
//  ContentView.swift (多语言版本)
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/22.
//

import SwiftUI

// 欢迎大厅：在这里选择你的命运，或输入命运的代码
// 现在还能选择用什么语言来接受命运的审判
struct ContentView: View {
    @ObservedObject var localization = LocalizationManager.shared
    // 引入设置管理器
    @ObservedObject var settings = AppSettings.shared

    // 是否开场：当它为 true，剧情正式开始
    @State private var isGameStarted = false
    // 选中的难度：从幼儿园到地狱，请谨慎选择
    @State private var selectedDifficulty: Difficulty = .easy

    // 【暴力修复核心】：每一局游戏的唯一身份证
    // 每次开始游戏，我们都换一张身份证，强制 SwiftUI 销毁旧游戏，创建新游戏
    @State private var gameID = UUID()

    // 弹窗控制
    @State private var showSettings = false
    // 种子输入面板
    @State private var showSeedInput = false
    // 种子文本
    @State private var seedInputText = ""
    // 自定义种子
    @State private var customSeedToPlay: Int? = nil

    // 模式开关
    @State private var triggerGodMode = false
    @State private var triggerNanagokyuuMode = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                // iPhone Duo unfolded is 669x951pt and iPad is even wider, so
                // use two columns there.  The Duo cover display is only 678pt
                // tall, so the compact layout scrolls instead of clipping the
                // start button like the old fixed VStack did.
                let isWide = proxy.size.width >= 620 && proxy.size.height >= 560

                ZStack {
                    Color.mainGradient.ignoresSafeArea()

                    ScrollView(.vertical, showsIndicators: false) {
                        Group {
                            if isWide {
                                wideLayout
                            } else {
                                compactLayout
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(
                            minHeight: max(0, proxy.size.height - 40),
                            alignment: .center
                        )
                        .padding(.horizontal, isWide ? 28 : 20)
                        .padding(.vertical, 20)
                    }
                    // Keep "Start Game" reachable on the 678pt-tall Duo cover
                    // display and on small phones instead of hiding it below
                    // the scroll fold.
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if !isWide {
                            compactActionBar
                        }
                    }
                }
            }
            .toolbar {
                // MARK: - 极简工具栏
                // 只有一个“更多”按钮，包罗万象
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings = true
                        HapticManager.shared.light()
                    }) {
                        // 使用省略号圆圈图标，代表“更多”
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            // 种子输入逻辑
            .alert(localization.text(.inputSeedTitle), isPresented: $showSeedInput) {
                // 这里不再限制为 numberPad，为了能输入 Cytimax
                TextField(localization.text(.inputSeedPlaceholder), text: $seedInputText)

                Button(localization.text(.inputSeed), action: handleSeedInput)
                Button(localization.text(.cancel), role: .cancel) { }
            } message: {
                Text(localization.text(.inputSeedMessage))
            }
            .navigationDestination(isPresented: $isGameStarted) {
                GameView(
                    difficulty: selectedDifficulty,
                    seed: customSeedToPlay,
                    theme: settings.currentTheme,
                    isGodMode: triggerGodMode,
                    isNanagokyuuMode: triggerNanagokyuuMode
                )
                .id(gameID)
            }
        }
    }

    // MARK: - Layouts

    private var wideLayout: some View {
        HStack(alignment: .center, spacing: 28) {
            VStack(spacing: 22) {
                heroSection
                rulesSection
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 22) {
                difficultySection
                actionSection
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 860)
    }

    private var compactLayout: some View {
        VStack(spacing: 18) {
            heroSection
            difficultySection
            rulesSection
        }
        .frame(maxWidth: 560)
    }

    private var compactActionBar: some View {
        actionSection
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: 8) {
            // 直接读取设置里的当前皮肤
            Text(settings.currentTheme.mainIcon)
                .font(.system(size: 72))
                .shadow(radius: 10)
                // 长按进地狱模式 (保留这个隐藏彩蛋)
                .onLongPressGesture(minimumDuration: 5.0) {
                    startGame(difficulty: .hell, seed: nil, godMode: false, nanagokyuu: false)
                    HapticManager.shared.heavy()
                }

            Text(localization.text(.gameTitle))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localization.text(.selectDifficulty))
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 2)

            ForEach(Difficulty.allCases.filter { $0 != .hell }, id: \.self) { difficulty in
                DifficultyButton(
                    difficulty: difficulty,
                    isSelected: selectedDifficulty == difficulty
                ) {
                    selectedDifficulty = difficulty
                    HapticManager.shared.light()
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RuleRow(icon: "hammer.fill", text: localization.text(.ruleDig))
            RuleRow(icon: "flag.fill", text: localization.text(.ruleFlag))
            RuleRow(icon: "number.square", text: localization.text(.ruleSeed))
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    private var actionSection: some View {
        VStack(spacing: 14) {
            Button(action: {
                seedInputText = ""
                showSeedInput = true
                HapticManager.shared.light()
            }) {
                HStack {
                    Image(systemName: "number.circle")
                    Text(localization.text(.customSeedChallenge))
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .padding(.vertical, 5)
            }

            Button(action: {
                startGame(
                    difficulty: selectedDifficulty,
                    seed: nil,
                    godMode: false,
                    nanagokyuu: false
                )
                HapticManager.shared.light()
            }) {
                Text(localization.text(.startGame))
                    .font(.title3).fontWeight(.bold).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.blue)
                    .cornerRadius(15)
                    .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Actions

    private func startGame(
        difficulty: Difficulty,
        seed: Int?,
        godMode: Bool,
        nanagokyuu: Bool
    ) {
        selectedDifficulty = difficulty
        customSeedToPlay = seed
        triggerGodMode = godMode
        triggerNanagokyuuMode = nanagokyuu
        gameID = UUID()
        isGameStarted = true
    }

    private func handleSeedInput() {
        let trimmed = seedInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerText = trimmed.lowercased()

        // 【修改点】致敬 Cytimax 的彩蛋逻辑
        if lowerText == "cytimax" {
            // Cytimax 彩蛋：上帝模式
            startGame(difficulty: selectedDifficulty, seed: nil, godMode: true, nanagokyuu: false)
            HapticManager.shared.success()
        } else if lowerText == "nanagokyuu" {
            // 作者彩蛋：倒霉蛋模式
            startGame(difficulty: selectedDifficulty, seed: nil, godMode: false, nanagokyuu: true)
            // 给个震动，让玩家以为触发了什么隐藏福利，其实是隐藏陷阱
            HapticManager.shared.success()
        } else if let seed = Int(trimmed) {
            // 正常数字种子
            startGame(difficulty: selectedDifficulty, seed: seed, godMode: false, nanagokyuu: false)
        } else {
            // 非法输入不再静默失败：重新打开输入框并给出触感反馈
            HapticManager.shared.failure()
            showSeedInput = true
        }
    }
}
