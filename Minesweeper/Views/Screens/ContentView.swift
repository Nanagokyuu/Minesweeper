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
    // 只剩一个设置弹窗了，清爽多了
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
   
    // 大厅背景用的游戏实例，只负责撑场面和存历史
    @StateObject private var menuGame = MinesweeperGame()
   
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色自适应：深色模式下变黑，浅色下变白
                Color.mainGradient.ignoresSafeArea()
               
                // 【修改点 1】：全局间距从 30 压缩到 15
                VStack(spacing: 15) {
                    Spacer()
                   
                    // 标题与 Logo
                    VStack(spacing: 8) {
                        // 直接读取设置里的当前皮肤
                        Text(settings.currentTheme.mainIcon)
                            .font(.system(size: 72))
                            .shadow(radius: 10)
                            // 【已移除】点击切换皮肤功能已删除
                            // 皮肤切换请前往右上角设置页面
                           
                            // 长按进地狱模式 (保留这个隐藏彩蛋)
                            .onLongPressGesture(minimumDuration: 5.0) {
                                HapticManager.shared.heavy()
                                selectedDifficulty = .hell
                                customSeedToPlay = nil
                                triggerGodMode = false
                                triggerNanagokyuuMode = false
                                gameID = UUID()
                                isGameStarted = true
                            }
                       
                        Text(localization.text(.gameTitle))
                            // 【修改点 3】：标题文字稍微改小
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            // 【修改】文字颜色自适应 (.primary)
                            .foregroundColor(.primary)
                            .tracking(2)
                    }
                   
                    // 难度选择
                    VStack(alignment: .leading, spacing: 10) {
                        Text(localization.text(.selectDifficulty))
                            .font(.headline)
                            // 【修改】文字颜色自适应 (.primary)
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
                    .padding(.horizontal, 20)
                   
                    // 规则说明
                    VStack(alignment: .leading, spacing: 12) {
                        RuleRow(icon: "hammer.fill", text: localization.text(.ruleDig))
                        RuleRow(icon: "flag.fill", text: localization.text(.ruleFlag))
                        RuleRow(icon: "number.square", text: localization.text(.ruleSeed))
                    }
                    // 【修改】移除了 .colorMultiply(.black)，让 RuleRow 内部的 .primary 生效
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                   
                    Spacer()
                   
                    // 底部按钮区域
                    VStack(spacing: 15) {
                       
                        // 自定义种子入口
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
                       
                        // 开始游戏
                        Button(action: {
                            customSeedToPlay = nil
                            triggerGodMode = false
                            triggerNanagokyuuMode = false
                            gameID = UUID()
                            isGameStarted = true
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
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                }
                .padding(.top, 10)
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
               
                Button(localization.text(.inputSeed), action: {
                    let lowerText = seedInputText.lowercased().trimmingCharacters(in: .whitespaces)
                   
                    // 【修改点】致敬 Cytimax 的彩蛋逻辑
                    if lowerText == "cytimax" {
                        // Cytimax 彩蛋：上帝模式
                        triggerGodMode = true
                        triggerNanagokyuuMode = false
                        // 上帝模式不需要无猜逻辑，上帝全知全能
                        customSeedToPlay = nil
                        gameID = UUID()
                        isGameStarted = true
                        HapticManager.shared.success()
                       
                    } else if lowerText == "nanagokyuu" {
                        // 作者彩蛋：倒霉蛋模式
                        triggerNanagokyuuMode = true
                        triggerGodMode = false
                        // 倒霉蛋模式下，逻辑救不了你
                        customSeedToPlay = nil
                        gameID = UUID()
                        isGameStarted = true
                        // 给个震动，让玩家以为触发了什么隐藏福利，其实是隐藏陷阱
                        HapticManager.shared.success()
                       
                    } else if let seed = Int(seedInputText) {
                        // 正常数字种子
                        triggerGodMode = false
                        triggerNanagokyuuMode = false
                        // 公平对决：没有借口，只有水平
                        customSeedToPlay = seed
                        gameID = UUID()
                        isGameStarted = true
                    }
                })
                Button(localization.text(.cancel), role: .cancel) { }
            } message: {
                Text(localization.text(.inputSeedMessage))
            }
            .navigationDestination(isPresented: $isGameStarted) {
                // 【修改】传入 settings.currentTheme
                GameView(
                    difficulty: selectedDifficulty,
                    seed: customSeedToPlay,
                    theme: settings.currentTheme, // 这里的改动最关键！
                    isGodMode: triggerGodMode,
                    isNanagokyuuMode: triggerNanagokyuuMode
                )
                .id(gameID)
            }
        }
    }
}
