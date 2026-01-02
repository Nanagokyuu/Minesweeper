//
//  CellView.swift
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
    // 【新增】接收上帝模式状态
    let isGodMode: Bool
    // 【新增】接收皮肤主题，不然它怎么知道该长成地雷还是花朵
    let theme: GameTheme
    
    // 【优化点 1】:实现自定义比较函数
    // 告诉 SwiftUI:只有当这些影响外观的属性改变时,才认为这两个 View 不同,需要重绘
    static func == (lhs: CellView, rhs: CellView) -> Bool {
        return lhs.cell.isRevealed == rhs.cell.isRevealed &&
               lhs.cell.isFlagged == rhs.cell.isFlagged &&
               lhs.cell.isExploding == rhs.cell.isExploding &&
               lhs.cell.isMine == rhs.cell.isMine &&
               lhs.cell.neighborMines == rhs.cell.neighborMines &&
               // 【关键】必须比较 isGodMode，否则切换模式后格子不会刷新
               lhs.isGodMode == rhs.isGodMode &&
               // 【关键】皮肤变了当然也要重绘
               lhs.theme == rhs.theme
    }
    
    var body: some View {
        // 【回退】:原汁原味的 GeometryReader,确保布局比例完美
        GeometryReader { geometry in
            ZStack {
                // 背面 - 未翻开状态
                Group {
                    RoundedRectangle(cornerRadius: 6)
                        // 【核心修改】皮肤适配：如果是花圃模式，这里会是绿色；经典模式是蓝色
                        // 上帝模式下，地雷依然显示为橙色背景，这是绝对法则
                        .fill(isGodMode && cell.isMine ? Color.orange : theme.coveredColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(0.3), Color.clear]),
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                        )
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 2)
                    
                    if cell.isFlagged {
                        Image(systemName: theme.flagIcon)
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
                .zIndex(cell.isRevealed ? 0 : 1)
                
                // 正面 - 翻开后状态
                Group {
                    RoundedRectangle(cornerRadius: 6)
                        // 【核心修改】皮肤适配：爆炸时的背景色
                        // 地雷翻开时与数字格保持相同底色，深色模式下不再突兀
                        .foregroundColor(cell.isMine && cell.isTriggeredMine ? .red : Color.cellRevealed)
                        // 【新增】爆炸时的闪烁效果
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.explodedColor)
                                .opacity(cell.isExploding ? 0.8 : 0.0)
                                .animation(.easeInOut(duration: 0.15).repeatCount(2, autoreverses: true), value: cell.isExploding)
                        )
                    
                    if cell.isMine {
                        // 【关键修复】不再叠加显示，只显示爆炸结果
                        // 之前把炸弹和爆炸符叠在一起确实太蠢了，我的锅，现在只显示一个干净的图标
                        Text(theme.explosionIcon)
                            .font(.system(size: geometry.size.width * 0.7))
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
                .zIndex(cell.isRevealed ? 1 : 0)
                
                // 【新增】爆炸粒子效果 - 在格子爆炸时显示
                if cell.isExploding {
                    ExplosionParticles(color: theme.explodedColor)
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
    let color: Color // 接收主题颜色
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<4) { i in
                Circle()
                    .fill(Color.orange) // 火花还是保留橙色比较像样
                    .frame(width: 4, height: 4)
                    .offset(
                        x: isAnimating ? cos(Double(i) * .pi / 2) * 15 : 0,
                        y: isAnimating ? sin(Double(i) * .pi / 2) * 15 : 0
                    )
                    .opacity(isAnimating ? 0 : 1)
            }
            
            ForEach(0..<4) { i in
                Circle()
                    .fill(color) // 第二层粒子使用主题色（红色碎片 或 棕色泥土）
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
