//
//  Component.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/22.
//

import SwiftUI

// MARK: - 单个格子视图
// 【优化点 1】：添加 Equatable 协议
// 讲道理,演员一样的妆容就别重复化妆了(避免不必要重绘)
struct CellView: View, Equatable {
    let cell: Cell
    
    // 【优化点 1】:实现自定义比较函数
    // 告诉 SwiftUI:只有当这些影响外观的属性改变时,才认为这两个 View 不同,需要重绘
    static func == (lhs: CellView, rhs: CellView) -> Bool {
        return lhs.cell.isRevealed == rhs.cell.isRevealed &&
               lhs.cell.isFlagged == rhs.cell.isFlagged &&
               lhs.cell.isExploding == rhs.cell.isExploding &&
               // 以下属性只有在 revealed 为 true 时才影响外观,但比较它们开销很小,一并带上更安全
               lhs.cell.isMine == rhs.cell.isMine &&
               lhs.cell.neighborMines == rhs.cell.neighborMines
    }
    
    var body: some View {
        // 【回退】:原汁原味的 GeometryReader,确保布局比例完美
        GeometryReader { geometry in
            ZStack {
                // 背面 - 未翻开状态
                Group {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(0.3), Color.clear]),
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                        )
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 2)
                    
                    if cell.isFlagged {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: geometry.size.width * 0.5))
                            .shadow(radius: 1)
                            // 【新增】旗帜弹性动画
                            .scaleEffect(cell.isFlagged ? 1.0 : 0.1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: cell.isFlagged)
                            // 【关键修复】旗帜也反向旋转180度,抵消背面的镜像
                            .rotation3DEffect(
                                .degrees(180),
                                axis: (x: 0, y: 1, z: 0)
                            )
                    }
                }
                // 【关键修复】背面旋转180度,且在翻开时渐隐
                .rotation3DEffect(
                    .degrees(180),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(cell.isRevealed ? 0 : 1)
                .zIndex(cell.isRevealed ? 0 : 1) // 未翻开时在上层
                
                // 正面 - 翻开后状态
                Group {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(cell.isMine ? Color.red.opacity(0.2) : Color.cellRevealed)
                        // 【新增】爆炸时的闪烁效果
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.red)
                                .opacity(cell.isExploding ? 0.8 : 0.0)
                                .animation(.easeInOut(duration: 0.15).repeatCount(2, autoreverses: true), value: cell.isExploding)
                        )
                    
                    if cell.isMine {
                        // 【新增】显示双层图标：炸弹 + 💥
                        ZStack {
                            // 💥 emoji 在底层
                            Text("💥")
                                .font(.system(size: geometry.size.width * 0.65))
                                .opacity(0.9)
                            
                            // 炸弹图标在上层
                            Image(systemName: "bomb.fill") // 惊喜还是惊吓?翻开就知道
                                .foregroundColor(cell.isExploding ? .white : .red)
                                .font(.system(size: geometry.size.width * 0.5))
                        }
                        // 【改进】爆炸时的强烈动画效果
                        .scaleEffect(cell.isExploding ? 1.5 : (cell.isRevealed ? 1.0 : 0.1))
                        .rotationEffect(.degrees(cell.isExploding ? 360 : 0))
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: cell.isRevealed)
                        .animation(.easeOut(duration: 0.2), value: cell.isExploding)
                        // 【关键修复】正面内容反向旋转180度抵消镜像
                        .rotation3DEffect(
                            .degrees(180),
                            axis: (x: 0, y: 1, z: 0)
                        )
                    } else if cell.neighborMines > 0 {
                        Text("\(cell.neighborMines)")
                            .font(.system(size: geometry.size.width * 0.7, weight: .heavy, design: .rounded))
                            .foregroundColor(numberColor(cell.neighborMines))
                            // 【新增】数字渐显动画
                            .opacity(cell.isRevealed ? 1.0 : 0.0)
                            .scaleEffect(cell.isRevealed ? 1.0 : 0.5)
                            .animation(.easeOut(duration: 0.3), value: cell.isRevealed)
                            // 【关键修复】正面内容反向旋转180度抵消镜像
                            .rotation3DEffect(
                                .degrees(180),
                                axis: (x: 0, y: 1, z: 0)
                            )
                    }
                }
                .opacity(cell.isRevealed ? 1 : 0)
                .zIndex(cell.isRevealed ? 1 : 0) // 翻开后在上层
                
                // 【新增】爆炸粒子效果 - 在格子爆炸时显示
                if cell.isExploding {
                    ExplosionParticles()
                }
            }
            // 【修复】整体翻转效果 - 减速到0.6秒,阻尼改为0.75让动画更平滑
            .rotation3DEffect(
                .degrees(cell.isRevealed ? 180 : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            // 【改进】爆炸时的强烈震动效果
            .scaleEffect(cell.isExploding ? 1.15 : (cell.isRevealed ? 1.0 : 0.95))
            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: cell.isRevealed)
            .animation(.spring(response: 0.15, dampingFraction: 0.3), value: cell.isExploding)
        }
    }
    
    func numberColor(_ num: Int) -> Color {
        // 数字配色:让信息一目了然,也让界面更有活力
        [.blue, .green, .red, .purple, .orange, .cyan, .black, .gray][(num - 1) % 8]
    }
}

// MARK: - 【新增】爆炸粒子效果
// 让爆炸更有视觉冲击力
struct ExplosionParticles: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 4个方向的爆炸粒子
            ForEach(0..<4) { i in
                Circle()
                    .fill(Color.orange)
                    .frame(width: 4, height: 4)
                    .offset(
                        x: isAnimating ? cos(Double(i) * .pi / 2) * 15 : 0,
                        y: isAnimating ? sin(Double(i) * .pi / 2) * 15 : 0
                    )
                    .opacity(isAnimating ? 0 : 1)
            }
            
            // 对角线方向的粒子
            ForEach(0..<4) { i in
                Circle()
                    .fill(Color.red)
                    .frame(width: 3, height: 3)
                    .offset(
                        x: isAnimating ? cos(Double(i) * .pi / 2 + .pi / 4) * 12 : 0,
                        y: isAnimating ? sin(Double(i) * .pi / 2 + .pi / 4) * 12 : 0
                    )
                    .opacity(isAnimating ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - 模式切换按钮 (挖雷/插旗)
// 其实本来是长按插旗的,但是在手机上你用手长按的话就直接把格子盖住了,所以把长按换成了按键切换
// 工具箱:选择你的武器,锤子或旗帜,战术与艺术并存
struct ModeButton: View {
    let title: String, icon: String, isSelected: Bool, color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 24))
                Text(title).font(.caption).fontWeight(.bold)
            }
            .frame(maxWidth: .infinity).frame(height: 70)
            .background(isSelected ? color : Color.white)
            .foregroundColor(isSelected ? .white : .gray)
            .cornerRadius(15)
            .shadow(color: isSelected ? color.opacity(0.4) : Color.black.opacity(0.05),
                    radius: isSelected ? 8 : 2, x: 0, y: 4)
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1))
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
    }
}

// MARK: - 难度选择按钮
// 难度卡片:表情包代表心情,文字说明代表现实
struct DifficultyButton: View {
    let difficulty: Difficulty
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Text(difficulty.icon).font(.system(size: 30))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.rawValue).font(.headline).fontWeight(.bold)
                    Text(difficulty.description).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green).font(.title3)
                }
            }
            .padding()
            .background(isSelected ? Color.white : Color.white.opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 规则行组件
// 规则说明:简明扼要,战前动员
struct RuleRow: View {
    let icon: String, text: String
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon).foregroundColor(.white).frame(width: 24)
            Text(text).font(.subheadline).fontWeight(.medium).foregroundColor(.white.opacity(0.9))
        }
    }
}

// MARK: - 结果弹窗
// 战报发布:是捧杯时刻,还是复盘提升
struct ResultPopup: View {
    let isWin: Bool
    let timeElapsed: Int
    let onRetry: () -> Void
    let onReview: () -> Void
    let onExit: () -> Void
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: isWin ? "trophy.fill" : "xmark.octagon.fill")
                .font(.system(size: 60))
                .foregroundColor(isWin ? .yellow : .red)
                .padding(.top).shadow(radius: 5)
            
            VStack(spacing: 5) {
                Text(isWin ? "恭喜通关!" : "游戏结束")
                    .font(.title).fontWeight(.heavy).foregroundColor(isWin ? .green : .red)
                
                if isWin {
                    Text("耗时: \(formatTime(timeElapsed))")
                        .font(.headline).foregroundColor(.secondary)
                } else {
                    Text("下次好运.").font(.subheadline).foregroundColor(.gray)
                }
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 15) {
                    Button(action: onRetry) {
                        Text("再试一次").fontWeight(.bold).frame(maxWidth: .infinity).padding()
                            .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                    }
                    Button(action: onExit) {
                        Text("退出").fontWeight(.semibold).frame(maxWidth: .infinity).padding()
                            .background(Color.gray.opacity(0.2)).foregroundColor(.primary).cornerRadius(12)
                    }
                }
                
                Button(action: onReview) {
                    Text("👀 查看雷区")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(.blue.opacity(0.8)).padding(.vertical, 5)
                }
            }
            .padding(.horizontal)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)  // 磨砂玻璃效果
                // 别问,我就是喜欢磨砂玻璃
                .opacity(0.95)  // 增加不透明度
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)  // 玻璃边缘高光
        )
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
        .padding(40)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
