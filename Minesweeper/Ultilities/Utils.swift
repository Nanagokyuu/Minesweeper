//
//  Utils.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/22.
//

import SwiftUI

// MARK: - 震动反馈工具
// 我不管，震动反馈必须要有，这是灵魂，没有震动的扫雷就像没有气泡的可乐
class HapticManager {
    static let shared = HapticManager()
    
    // 轻触：像是在小心翼翼地试探，生怕惊醒沉睡的巨龙
    func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    
    // 重击：当你确信这里有雷，或者只是单纯想发泄一下
    func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    
    // 成功：虽然只是震动了一下，但在你心里应该已经放起了烟花
    func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    
    // 失败：手机震动的同时，你的心也跟着碎了一地
    func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// MARK: - 颜色扩展
extension Color {
    // 真相大白时的颜色，通常意味着安全（或者你已经炸了）
    static let cellRevealed = Color.white
    
    // 虽然叫渐变，但其实就是白色，一种五彩斑斓的白，简约（陋）美学
    static let mainGradient = Color.white
}
