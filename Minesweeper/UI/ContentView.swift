//
//  ContentView.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/22.
//

import SwiftUI

// 欢迎大厅：在这里选择你的命运，或输入命运的代码
struct ContentView: View {
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
    // 种子文本：数字越帅，命运越玄
    @State private var seedInputText = ""
    // 自定义种子：为 nil 则随机，交给上天
    @State private var customSeedToPlay: Int? = nil
    
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
                    VStack(spacing: 8) { // 内部间距微调
                        Text("💣")
                            // 【修改点 2】：Emoji稍微改小一点，留出空间
                            .font(.system(size: 72))
                            .shadow(radius: 10)
                            // 长按 5 秒直通地狱难度：不作不死，作了更刺激
                            .onLongPressGesture(minimumDuration: 5.0) {
                                HapticManager.shared.heavy()
                                selectedDifficulty = .hell
                                customSeedToPlay = nil
                                // 即使是长按触发，也要刷新 ID
                                gameID = UUID()
                                isGameStarted = true
                            }
                        
                        Text("扫雷")
                            // 【修改点 3】：标题文字稍微改小
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(.black)
                            .tracking(2)
                    }
                    
                    // 难度选择
                    VStack(alignment: .leading, spacing: 10) { // 内部间距微调
                        Text("选择难度")
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
                    // 【修改点 4】：卡片内边距从 20 压缩到 16
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                    
                    // 规则说明
                    VStack(alignment: .leading, spacing: 12) { // 内部间距微调
                        // 战前动员：工具与规则，一目了然
                        RuleRow(icon: "hammer.fill", text: "切换至[挖雷]模式翻开格子")
                        RuleRow(icon: "flag.fill", text: "切换至[插旗]模式标记地雷")
                        RuleRow(icon: "number.square", text: "使用相同种子可进行公平对决")
                    }
                    .colorMultiply(.black)
                    // 【修改点 5】：卡片内边距从 25 压缩到 16
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // 底部按钮区域
                    VStack(spacing: 15) {
                        
                        // 1. 自定义种子入口
                        Button(action: {
                            seedInputText = ""
                            showSeedInput = true
                            HapticManager.shared.light()
                        }) {
                            HStack {
                                Image(systemName: "number.circle")
                                Text("输入种子挑战") // 命运的数字，让胜负更公平（也更残酷）
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .padding(.vertical, 5)
                        }
                        
                        // 2. 正常开始
                        Button(action: {
                            // 1. 清空旧种子，确保是随机新局
                            customSeedToPlay = nil
                            
                            // 2. 【暴力刷新】：生成新的 UUID
                            // 这告诉 SwiftUI："我要创建一个全新的 GameView，别给我复用旧的！"
                            gameID = UUID()
                            
                            isGameStarted = true
                            HapticManager.shared.light()
                        }) {
                            Text("开始游戏")
                                .font(.title3).fontWeight(.bold).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.blue)
                                .cornerRadius(15)
                                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
                        }
                    }
                    .padding(.horizontal, 40)
                    // 【修改点 6】：底部距离设为 50，既不贴底，也给顶部留足了空间
                    .padding(.bottom, 50)
                }
                // 确保顶部留有一点安全距离，防止极端的压缩情况
                .padding(.top, 10)
            }
            .toolbar {
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
            .alert("输入游戏种子", isPresented: $showSeedInput) {
                TextField("例如: 123456", text: $seedInputText)
                    .keyboardType(.numberPad)
                
                Button("开始", action: {
                    if let seed = Int(seedInputText) {
                        customSeedToPlay = seed
                        // 即使是自定义种子，也要刷新 ID
                        gameID = UUID()
                        isGameStarted = true
                    }
                })
                Button("取消", role: .cancel) { }
            } message: {
                Text("输入相同的数字将生成完全一样的雷区布局。") // 公平对决：没有借口，只有水平
            }
            .navigationDestination(isPresented: $isGameStarted) {
                // 这里我们传入 gameID 作为视图的身份标识
                // 当 gameID 变化时，SwiftUI 必须丢弃旧视图，重新执行 GameView.init()
                GameView(difficulty: selectedDifficulty, seed: customSeedToPlay)
                    .id(gameID)
            }
        }
    }
}
