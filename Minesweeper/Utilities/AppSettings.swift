//
// AppSettings.swift
// Minesweeper
//
// Created by Nanagokyuu on 2026/1/2.
//

import SwiftUI
import Combine

// MARK: - 外观模式枚举
// 强迫症患者的福音，不管是白天还是黑夜，我想黑就黑
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
   
    var id: String { rawValue }
}
// MARK: - 全局设置管理器
// 这里存放着用户的所有偏好，哪怕删了 App...哦不对，删了 App 这里也会没的
// 但是杀掉进程再进来，它还能记得你的癖好
class AppSettings: ObservableObject {
    static let shared = AppSettings()
   
    // MARK: - 震动开关
    // 有些人即使是在手机上也不喜欢震动，虽然我觉得这是灵魂
    @Published var isHapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(isHapticsEnabled, forKey: "isHapticsEnabled") }
    }
   
    // MARK: - 无猜模式开关
    // 是否开启智能防猜。默认开启，毕竟谁也不想玩到最后二选一被炸死
    // 但如果你是受虐狂，可以关掉它
    @Published var isNoGuessingEnabled: Bool {
        didSet { UserDefaults.standard.set(isNoGuessingEnabled, forKey: "isNoGuessingEnabled") }
    }
   
    // MARK: - 主题名称
    // 默认经典，毕竟经典永不过时
    @Published var selectedThemeName: String {
        didSet { UserDefaults.standard.set(selectedThemeName, forKey: "selectedThemeName") }
    }
   
    // MARK: - 初始化
    // 从 UserDefaults 加载“记忆”，如果失忆了就用默认值
    private init() {
        self.isHapticsEnabled = UserDefaults.standard.object(forKey: "isHapticsEnabled") as? Bool ?? true
        self.isNoGuessingEnabled = UserDefaults.standard.object(forKey: "isNoGuessingEnabled") as? Bool ?? true
        self.selectedThemeName = UserDefaults.standard.string(forKey: "selectedThemeName") ?? "Classic"
    }
   
    // MARK: - 辅助属性
    // 把存储的字符串变成实实在在的皮肤配置
    var currentTheme: GameTheme {
        if selectedThemeName == "Flower" {
            return .flower
        }
        return .classic
    }
   
    // 切换主题
    // 换个心情，换个手气
    func updateTheme(_ theme: GameTheme) {
        selectedThemeName = theme.name
        // @Published 会自动通知界面更新，不需要手动发通知了
    }
}
