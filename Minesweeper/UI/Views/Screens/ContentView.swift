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
    
    // 是否开场：当它为 true，剧情正式开始
    @State private var isGameStarted = false
    // 选中的难度：从幼儿园到地狱，请谨慎选择
    @State private var selectedDifficulty: Difficulty = .easy
    
    // 【暴力修复核心】：每一局游戏的唯一身份证
    // 每次开始游戏，我们都换一张身份证，强制 SwiftUI 销毁旧游戏，创建新游戏
    @State private var gameID = UUID()
    
    // 弹窗控制
    // 历史回放面板：回顾你的高光与黑历史
    @State private var showHistory = false
    // 种子输入面板：命运的红线，握在你手里
    @State private var showSeedInput = false
    // 语言设置面板：选择用哪种语言被炸
    @State private var showLanguageSettings = false
    // 种子文本：数字越帅，命运越玄
    @State private var seedInputText = ""
    // 自定义种子：为 nil 则随机，交给上天
    @State private var customSeedToPlay: Int? = nil
    
    // 【新增】致敬 Cytimax：上帝模式开关
    @State private var triggerGodMode = false
    
    // 【新增】作者的自嘲：倒霉蛋模式开关
    @State private var triggerNanagokyuuMode = false
    
    // 大厅背景用的游戏实例，只负责撑场面和存历史
    @StateObject private var menuGame = MinesweeperGame()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.mainGradient.ignoresSafeArea() // 渐变是灵魂（虽然现在是五彩斑斓的白）
                
                // 【修改点 1】：全局间距从 30 压缩到 15
                VStack(spacing: 15) {
                    Spacer()
                    
                    // 标题
                    // 说实话如果不是看这里谁能知道这个地雷是可以按下去的
                    VStack(spacing: 8) {
                        Text("💣")
                            // 【修改点 2】：Emoji稍微改小一点，留出空间
                            .font(.system(size: 72))
                            .shadow(radius: 10)
                            // 长按 5 秒直通地狱难度：不作不死，作了更刺激
                            .onLongPressGesture(minimumDuration: 5.0) {
                                HapticManager.shared.heavy()
                                selectedDifficulty = .hell
                                customSeedToPlay = nil
                                triggerGodMode = false // 确保正常模式
                                triggerNanagokyuuMode = false // 确保不是自杀模式
                                // 即使是长按触发，也要刷新 ID
                                gameID = UUID()
                                isGameStarted = true
                            }
                        
                        Text(localization.text(.gameTitle))
                            // 【修改点 3】：标题文字稍微改小
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(.black)
                            .tracking(2)
                    }
                    
                    // 难度选择
                    VStack(alignment: .leading, spacing: 10) {
                        Text(localization.text(.selectDifficulty))
                            .font(.headline)
                            .foregroundColor(.black)
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
                    .colorMultiply(.black)
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
                            triggerGodMode = false // 正常开始
                            triggerNanagokyuuMode = false // 正常开始
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
                ToolbarItem(placement: .navigationBarLeading) {
                    // 语言切换按钮：国旗+下拉箭头，点击进入语言选择
                    Button(action: {
                        showLanguageSettings = true
                        HapticManager.shared.light()
                    }) {
                        HStack(spacing: 4) {
                            Text(localization.currentLanguage.flag)
                                .font(.title3)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial) // 玻璃质感：语言选择也要有仪式感
                        .clipShape(Capsule())
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showHistory = true
                        HapticManager.shared.light()
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundColor(.black)
                            .padding(8)
                            .background(.ultraThinMaterial) // 玻璃质感：历史也需要仪式感
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(game: menuGame)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showLanguageSettings) {
                LanguageSettingsView()
                    .presentationDetents([.medium])
            }
            .alert(localization.text(.inputSeedTitle), isPresented: $showSeedInput) {
                // 这里不再限制为 numberPad，为了能输入 Cytimax
                TextField(localization.text(.inputSeedPlaceholder), text: $seedInputText)
                
                Button(localization.text(.inputSeed), action: {
                    let lowerText = seedInputText.lowercased().trimmingCharacters(in: .whitespaces)
                    
                    // 【修改点】致敬 Cytimax 的彩蛋逻辑
                    if lowerText == "cytimax" {
                        triggerGodMode = true
                        triggerNanagokyuuMode = false
                        // 【核心修改】这里改成 nil，让游戏引擎去生成随机种子
                        // 这样每次输入 Cytimax，都会是一局全新的、但是透视的排雷局
                        customSeedToPlay = nil
                        gameID = UUID()
                        isGameStarted = true
                        HapticManager.shared.success()
                        
                    } else if lowerText == "nanagokyuu" {
                        // 【新增】作者模式逻辑
                        // 既然你输入了这个名字，那就要做好心理准备
                        triggerNanagokyuuMode = true
                        triggerGodMode = false
                        customSeedToPlay = nil // 这里的随机种子已经没有意义了，因为结局已注定
                        gameID = UUID()
                        isGameStarted = true
                        // 给个震动，让玩家以为触发了什么隐藏福利，其实是隐藏陷阱
                        HapticManager.shared.success()
                        
                    } else if let seed = Int(seedInputText) {
                        // 正常的数字种子逻辑
                        triggerGodMode = false
                        triggerNanagokyuuMode = false
                        customSeedToPlay = seed
                        gameID = UUID()
                        isGameStarted = true
                    }
                })
                Button(localization.text(.cancel), role: .cancel) { }
            } message: {
                Text(localization.text(.inputSeedMessage)) // 公平对决：没有借口，只有水平
            }
            .navigationDestination(isPresented: $isGameStarted) {
                // 这里我们传入 gameID 作为视图的身份标识
                // 当 gameID 变化时，SwiftUI 必须丢弃旧视图，重新执行 GameView.init()
                // 【修改】传入 isGodMode 和 isNanagokyuuMode 参数
                GameView(
                    difficulty: selectedDifficulty,
                    seed: customSeedToPlay,
                    isGodMode: triggerGodMode,
                    isNanagokyuuMode: triggerNanagokyuuMode
                )
                .id(gameID)
            }
        }
    }
}
