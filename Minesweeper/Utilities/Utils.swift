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
    
    // 【修改】这里不能用 @ObservedObject，因为 HapticManager 不是 View
    // 直接访问单例即可，反正我们只需要读取当前的值
    private var settings: AppSettings {
        return AppSettings.shared
    }
    
    // 轻触：像是在小心翼翼地试探，生怕惊醒沉睡的巨龙
    func light() {
        guard settings.isHapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // 重击：当你确信这里有雷，或者只是单纯想发泄一下
    func heavy() {
        guard settings.isHapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    // 成功：虽然只是震动了一下，但在你心里应该已经放起了烟花
    func success() {
        guard settings.isHapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    // 失败：手机震动的同时，你的心也跟着碎了一地
    func failure() {
        guard settings.isHapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - 颜色扩展
extension Color {
    // 真相大白时的颜色
    // 为了保证数字颜色的可读性（比如深蓝色在黑色背景上看不清），
    // 翻开的格子我们依然保持亮色（或者稍微灰一点），这样经典的数字配色才不会瞎眼
    // 如果你希望翻开也是黑的，那整套数字颜色都得重写，工程量巨大且容易丑
    // 这里使用 systemBackground 可以让它在深色模式下变成黑色，但为了数字清晰，我们暂时保持 .white
    // 或者你可以换成 Color(UIColor.secondarySystemGroupedBackground) 试试效果
    static let cellRevealed = Color(UIColor.secondarySystemGroupedBackground)
    
    // 背景色改为系统自适应背景
    // 浅色模式是白，深色模式是黑
    static let mainGradient = Color(UIColor.systemBackground)
}
