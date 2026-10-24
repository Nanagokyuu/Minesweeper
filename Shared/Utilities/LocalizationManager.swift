//
//  LocalizationManager.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2026/1/1.
//

import SwiftUI
import Combine

// MARK: - 支持的语言
enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }
    
    var flag: String {
        switch self {
        case .simplifiedChinese: return "🇨🇳"
        case .traditionalChinese: return "🇭🇰"
        case .english: return "🇺🇸"
        case .japanese: return "🇯🇵"
        }
    }
}

// MARK: - 本地化管理器
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
        }
    }
    
    private init() {
        // 1. 优先读取用户之前在这个 App 里手动选过的语言
        if let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // 2. 如果没选过，就偷看一眼系统的首选语言列表
            let preferredLanguages = Locale.preferredLanguages
            let firstLang = preferredLanguages.first ?? "en"
            
            // 简单的字符串匹配，粗暴但有效
            if firstLang.hasPrefix("zh-Hans") {
                self.currentLanguage = .simplifiedChinese
            } else if firstLang.hasPrefix("zh-Hant") || firstLang.hasPrefix("zh-HK") || firstLang.hasPrefix("zh-TW") {
                self.currentLanguage = .traditionalChinese
            } else if firstLang.hasPrefix("ja") {
                self.currentLanguage = .japanese
            } else {
                // 实在认不出来你是哪国人，那就讲英语吧，国际通用
                self.currentLanguage = .english
            }
        }
    }
    
    func text(_ key: LocalizedKey) -> String {
        return key.localized(for: currentLanguage)
    }
}

// MARK: - 本地化键值
enum LocalizedKey: CaseIterable {
    // 通用
    case close
    case cancel
    case delete
    case clearAll
    case exit
    
    // 游戏相关
    case gameTitle
    case selectDifficulty
    case startGame
    case exitGame
    case gameOver
    case congratulations
    case playAgain
    case reviewBoard
    case timeElapsed
    case remainingMines
    
    // 难度
    case difficultyEasy
    case difficultyMedium
    case difficultyHard
    case difficultyHell
    
    // 地雷数量后缀
    case minesSuffix
    
    // 模式
    case modeDigging
    case modeFlagging
    
    // 无猜模式相关
    
    // 规则说明
    case ruleDig
    case ruleFlag
    case ruleSeed
    
    // 历史记录
    case historyTitle
    case noHistory
    case noHistoryDesc
    case win
    case lose
    case accessibilityCovered
    case accessibilityFlagged
    case accessibilityMine
    case accessibilityEmpty
    case accessibilityNeighbors
    case accessibilityBoard
    case iCloudSync
    case iCloudQuotaExceeded
    case iCloudAccountChanged
    case iCloudSyncFailed
    case iCloudHistoryTooLarge
    case pin
    case unpin
    
    // 种子相关
    case seed
    case seedCopied
    case inputSeed
    case inputSeedTitle
    case inputSeedMessage
    case inputSeedPlaceholder
    case customSeedChallenge
    
    // iCloud
    case iCloudUnavailable
    case lastSync
    case waitingSync
    case syncNow
    
    // 回放
    case replayTitle
    case stepCount
    case playbackSpeed
    
    // 设置界面 (新增)
    case settings
    case general
    case language
    case gameplay
    case theme
    case themeClassic
    case themeFlower
    case haptics
    case hapticsDesc
    case noGuessingOption
    case noGuessingDesc
    case dataManagement
    case clearHistoryConfirm
    case about
    case version
    
    // 其他
    case betterLuckNextTime
    case keyZDig
    case keyXFlag

    // 输入 / 键位
    case inputSettings
    case inputSettingsDesc
    case inputActionDig
    case inputActionFlag
    case inputActionChord
    case inputActionNewGame
    case inputAdd
    case inputPressPrompt
    case inputReset
    case inputMouseLeft
    case inputMouseRight
    case inputMouseMiddle
    case inputMouseSideBack
    case inputMouseSideForward
    case inputMouseButton
    case backToHome
    case newGame
    case inputHint
    case inputConflictFormat
    case gameMenu
    case howToPlay
    case ruleDigDesktop
    case ruleFlagDesktop
    
    func localized(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: return localizedSimplifiedChinese
        case .traditionalChinese: return localizedTraditionalChinese
        case .english: return localizedEnglish
        case .japanese: return localizedJapanese
        }
    }
    
    // MARK: - 简体中文
    private var localizedSimplifiedChinese: String {
        switch self {
        case .close: return "关闭"
        case .cancel: return "取消"
        case .delete: return "删除"
        case .clearAll: return "清除全部"
        case .exit: return "退出"
            
        case .gameTitle: return "扫雷"
        case .selectDifficulty: return "选择难度"
        case .startGame: return "开始游戏"
        case .exitGame: return "退出游戏"
        case .gameOver: return "游戏结束"
        case .congratulations: return "恭喜通关!"
        case .playAgain: return "再试一次"
        case .reviewBoard: return "👀 查看雷区"
        case .timeElapsed: return "耗时"
        case .remainingMines: return "剩余地雷"
            
        case .difficultyEasy: return "简单"
        case .difficultyMedium: return "普通"
        case .difficultyHard: return "困难"
        case .difficultyHell: return "地狱"
        case .minesSuffix: return "个雷"
            
        case .modeDigging: return "挖雷"
        case .modeFlagging: return "插旗"
            
        case .ruleDig: return "切换至[挖雷]模式翻开格子"
        case .ruleFlag: return "切换至[插旗]模式标记地雷"
        case .ruleSeed: return "使用相同种子可进行公平对决"
        case .historyTitle: return "历史记录"
        case .noHistory: return "暂无游戏记录"
        case .noHistoryDesc: return "完成一局游戏后，可在此查看回放"
        case .win: return "胜利"
        case .lose: return "失败"
        case .accessibilityCovered: return "未翻开"
        case .accessibilityFlagged: return "已插旗"
        case .accessibilityMine: return "地雷"
        case .accessibilityEmpty: return "空白"
        case .accessibilityNeighbors: return "周围 %d 个雷"
        case .accessibilityBoard: return "扫雷棋盘，%d 行 %d 列"
        case .iCloudSync: return "iCloud 同步"
        case .iCloudQuotaExceeded: return "iCloud 存储配额已满"
        case .iCloudAccountChanged: return "iCloud 账号已变更"
        case .iCloudSyncFailed: return "iCloud 同步失败"
        case .iCloudHistoryTooLarge: return "历史记录过大，无法上传到 iCloud"
        case .pin: return "置顶"
        case .unpin: return "取消置顶"
            
        case .seed: return "种子"
        case .seedCopied: return "种子已复制"
        case .inputSeed: return "开始"
        case .inputSeedTitle: return "输入游戏种子"
        case .inputSeedMessage: return "输入相同的种子，并在相同的首发位置落子，才会生成完全一样的雷区布局。"
        case .inputSeedPlaceholder: return "例如: 123456"
        case .customSeedChallenge: return "输入种子挑战"
        case .iCloudUnavailable: return "iCloud 未登录或不可用"
        case .lastSync: return "上次同步"
        case .waitingSync: return "等待同步..."
        case .syncNow: return "立即同步"
            
        case .replayTitle: return "游戏回放"
        case .stepCount: return "步数"
        case .playbackSpeed: return "倍速"
            
        case .settings: return "设置"
        case .general: return "通用"
        case .language: return "多语言 (Language)"
        case .gameplay: return "游戏体验"
        case .theme: return "游戏皮肤"
        case .themeClassic: return "经典 (💣)"
        case .themeFlower: return "花圃 (🌼)"
        case .haptics: return "震动反馈"
        case .hapticsDesc: return "开启后，挖雷和爆炸时会有触感反馈"
        case .noGuessingOption: return "无猜模式"
        case .noGuessingDesc: return "保证所有局面都可逻辑推导，无需瞎猜 (地狱难度除外)"
        case .dataManagement: return "数据管理"
        case .clearHistoryConfirm: return "确定要删除所有历史记录吗？此操作不可撤销。"
        case .about: return "关于"
        case .version: return "版本"
        case .keyZDig: return "Z键: 挖雷"
        case .keyXFlag: return "X键: 插旗"
        case .inputSettings: return "按键与鼠标"
        case .inputSettingsDesc: return "同一个操作可以绑定多个键盘按键或鼠标按键；鼠标侧键也支持。"
        case .inputActionDig: return "挖开"
        case .inputActionFlag: return "插旗"
        case .inputActionChord: return "快速展开"
        case .inputActionNewGame: return "新游戏"
        case .inputAdd: return "添加按键"
        case .inputPressPrompt: return "请按下键盘按键，或点击鼠标按键…（Esc 取消）"
        case .inputReset: return "恢复默认键位"
        case .inputMouseLeft: return "鼠标左键"
        case .inputMouseRight: return "鼠标右键"
        case .inputMouseMiddle: return "鼠标中键"
        case .inputMouseSideBack: return "鼠标侧键 1"
        case .inputMouseSideForward: return "鼠标侧键 2"
        case .inputMouseButton: return "鼠标按键 %d"
        case .backToHome: return "返回主页"
        case .newGame: return "新游戏"
        case .inputHint: return "左键/右键或自定义键位均可操作；双击已翻开的数字可快速展开。"
        case .inputConflictFormat: return "「%@」原本绑定在「%@」，已自动移到这里。"
        case .gameMenu: return "游戏"
        case .howToPlay: return "玩法"
        case .ruleDigDesktop: return "左键或自定义键位翻开格子"
        case .ruleFlagDesktop: return "右键或自定义键位标记地雷"
        case .betterLuckNextTime: return "下次好运."
        }
    }
    
    // MARK: - English
    private var localizedEnglish: String {
        switch self {
        case .close: return "Close"
        case .cancel: return "Cancel"
        case .delete: return "Delete"
        case .clearAll: return "Clear All"
        case .exit: return "Exit"
            
        case .gameTitle: return "Minesweeper"
        case .selectDifficulty: return "Select Difficulty"
        case .startGame: return "Start Game"
        case .exitGame: return "Exit Game"
        case .gameOver: return "Game Over"
        case .congratulations: return "Congratulations!"
        case .playAgain: return "Play Again"
        case .reviewBoard: return "👀 Review Board"
        case .timeElapsed: return "Time"
        case .remainingMines: return "Mines Left"
            
        case .difficultyEasy: return "Easy"
        case .difficultyMedium: return "Medium"
        case .difficultyHard: return "Hard"
        case .difficultyHell: return "Hell"
        case .minesSuffix: return " Mines"
            
        case .modeDigging: return "Dig"
        case .modeFlagging: return "Flag"
            
        case .ruleDig: return "Switch to [Dig] mode to reveal cells"
        case .ruleFlag: return "Switch to [Flag] mode to mark mines"
        case .ruleSeed: return "Use the same seed for fair competition"
        case .historyTitle: return "Game History"
        case .noHistory: return "No Game Records"
        case .noHistoryDesc: return "Complete a game to view replays here"
        case .win: return "WIN"
        case .lose: return "LOSE"
        case .accessibilityCovered: return "Covered"
        case .accessibilityFlagged: return "Flagged"
        case .accessibilityMine: return "Mine"
        case .accessibilityEmpty: return "Empty"
        case .accessibilityNeighbors: return "%d adjacent mines"
        case .accessibilityBoard: return "Minesweeper board, %d rows by %d columns"
        case .iCloudSync: return "iCloud Sync"
        case .iCloudQuotaExceeded: return "iCloud storage quota exceeded"
        case .iCloudAccountChanged: return "iCloud account changed"
        case .iCloudSyncFailed: return "iCloud synchronization failed"
        case .iCloudHistoryTooLarge: return "History is too large for iCloud"
        case .pin: return "Pin"
        case .unpin: return "Unpin"
            
        case .seed: return "Seed"
        case .seedCopied: return "Seed Copied"
        case .inputSeed: return "Start"
        case .inputSeedTitle: return "Enter Game Seed"
        case .inputSeedMessage: return "The same seed reproduces the same board only when your first tap is on the same cell."
        case .inputSeedPlaceholder: return "e.g., 123456"
        case .customSeedChallenge: return "Custom Seed Challenge"
        case .iCloudUnavailable: return "iCloud Unavailable"
        case .lastSync: return "Last Sync"
        case .waitingSync: return "Waiting to sync..."
        case .syncNow: return "Sync Now"
            
        case .replayTitle: return "Game Replay"
        case .stepCount: return "Steps"
        case .playbackSpeed: return "Speed"
        
        case .settings: return "Settings"
        case .general: return "General"
        case .language: return "Language"
        case .gameplay: return "Gameplay"
        case .theme: return "Theme"
        case .themeClassic: return "Classic (💣)"
        case .themeFlower: return "Flower (🌼)"
        case .haptics: return "Haptics"
        case .hapticsDesc: return "Vibration feedback on dig and explode"
        case .noGuessingOption: return "No Guessing Mode"
        case .noGuessingDesc: return "Ensures solvable boards without luck (Except Hell)"
        case .dataManagement: return "Data"
        case .clearHistoryConfirm: return "Delete all history? This cannot be undone."
        case .about: return "About"
        case .version: return "Version"
        case .keyZDig: return "Z: Dig"
        case .keyXFlag: return "X: Flag"
        case .inputSettings: return "Input"
        case .inputSettingsDesc: return "One action can have several keyboard or mouse bindings. Mouse side buttons are supported."
        case .inputActionDig: return "Dig"
        case .inputActionFlag: return "Flag"
        case .inputActionChord: return "Quick Reveal"
        case .inputActionNewGame: return "New Game"
        case .inputAdd: return "Add Binding"
        case .inputPressPrompt: return "Press a key or click a mouse button… (Esc to cancel)"
        case .inputReset: return "Restore Defaults"
        case .inputMouseLeft: return "Left Click"
        case .inputMouseRight: return "Right Click"
        case .inputMouseMiddle: return "Middle Click"
        case .inputMouseSideBack: return "Side Button 1"
        case .inputMouseSideForward: return "Side Button 2"
        case .inputMouseButton: return "Mouse Button %d"
        case .backToHome: return "Back to Home"
        case .newGame: return "New Game"
        case .inputHint: return "Left/right click and custom bindings work on any cell; double-click a revealed number to chord."
        case .inputConflictFormat: return "\u{201C}%@\u{201D} was bound to \u{201C}%@\u{201D} and has been moved here."
        case .gameMenu: return "Game"
        case .howToPlay: return "How to Play"
        case .ruleDigDesktop: return "Left click or a custom binding reveals cells"
        case .ruleFlagDesktop: return "Right click or a custom binding marks mines"
        case .betterLuckNextTime: return "Better luck next time."
        }
    }
    
    // MARK: - 繁体中文
    private var localizedTraditionalChinese: String {
        switch self {
        case .close: return "關閉"
        case .cancel: return "取消"
        case .delete: return "刪除"
        case .clearAll: return "清除全部"
        case .exit: return "退出"
            
        case .gameTitle: return "掃雷"
        case .selectDifficulty: return "選擇難度"
        case .startGame: return "開始遊戲"
        case .exitGame: return "退出遊戲"
        case .gameOver: return "遊戲結束"
        case .congratulations: return "恭喜通關!"
        case .playAgain: return "再試一次"
        case .reviewBoard: return "👀 查看雷區"
        case .timeElapsed: return "耗時"
        case .remainingMines: return "剩餘地雷"
            
        case .difficultyEasy: return "簡單"
        case .difficultyMedium: return "普通"
        case .difficultyHard: return "困難"
        case .difficultyHell: return "地獄"
        case .minesSuffix: return "個地雷"
            
        case .modeDigging: return "挖雷"
        case .modeFlagging: return "插旗"
            
        case .ruleDig: return "切換至[挖雷]模式翻開格子"
        case .ruleFlag: return "切換至[插旗]模式標記地雷"
        case .ruleSeed: return "使用相同種子可進行公平對決"
        case .historyTitle: return "歷史記錄"
        case .noHistory: return "暫無遊戲記錄"
        case .noHistoryDesc: return "完成一局遊戲後，可在此查看回放"
        case .win: return "勝利"
        case .lose: return "失敗"
        case .accessibilityCovered: return "未翻開"
        case .accessibilityFlagged: return "已插旗"
        case .accessibilityMine: return "地雷"
        case .accessibilityEmpty: return "空白"
        case .accessibilityNeighbors: return "周圍 %d 個雷"
        case .accessibilityBoard: return "掃雷棋盤，%d 行 %d 列"
        case .iCloudSync: return "iCloud 同步"
        case .iCloudQuotaExceeded: return "iCloud 儲存配額已滿"
        case .iCloudAccountChanged: return "iCloud 帳號已變更"
        case .iCloudSyncFailed: return "iCloud 同步失敗"
        case .iCloudHistoryTooLarge: return "歷史記錄過大，無法上傳到 iCloud"
        case .pin: return "置頂"
        case .unpin: return "取消置頂"
            
        case .seed: return "種子"
        case .seedCopied: return "種子已複製"
        case .inputSeed: return "開始"
        case .inputSeedTitle: return "輸入遊戲種子"
        case .inputSeedMessage: return "輸入相同的種子，並在相同的首發位置落子，才會生成完全一樣的雷區佈局。"
        case .inputSeedPlaceholder: return "例如: 123456"
        case .customSeedChallenge: return "輸入種子挑戰"
        case .iCloudUnavailable: return "iCloud 未登錄或不可用"
        case .lastSync: return "上次同步"
        case .waitingSync: return "等待同步..."
        case .syncNow: return "立即同步"
            
        case .replayTitle: return "遊戲回放"
        case .stepCount: return "步數"
        case .playbackSpeed: return "倍速"
            
        case .settings: return "設定"
        case .general: return "一般"
        case .language: return "多語言 (Language)"
        case .gameplay: return "遊戲體驗"
        case .theme: return "遊戲皮膚"
        case .themeClassic: return "經典 (💣)"
        case .themeFlower: return "花圃 (🌼)"
        case .haptics: return "震動回饋"
        case .hapticsDesc: return "開啟後，挖雷和爆炸時會有觸感回饋"
        case .noGuessingOption: return "無猜模式"
        case .noGuessingDesc: return "保證所有局面都可邏輯推導，無需瞎猜 (地獄難度除外)"
        case .dataManagement: return "數據管理"
        case .clearHistoryConfirm: return "確定要刪除所有歷史記錄嗎？此操作不可撤銷。"
        case .about: return "關於"
        case .version: return "版本"
        case .keyZDig: return "Z鍵: 挖雷"
        case .keyXFlag: return "X鍵: 插旗"
        case .inputSettings: return "按鍵與滑鼠"
        case .inputSettingsDesc: return "同一個操作可以綁定多個鍵盤按鍵或滑鼠按鍵；滑鼠側鍵也支援。"
        case .inputActionDig: return "挖開"
        case .inputActionFlag: return "插旗"
        case .inputActionChord: return "快速展開"
        case .inputActionNewGame: return "新遊戲"
        case .inputAdd: return "新增按鍵"
        case .inputPressPrompt: return "請按下鍵盤按鍵，或點擊滑鼠按鍵…（Esc 取消）"
        case .inputReset: return "恢復預設鍵位"
        case .inputMouseLeft: return "滑鼠左鍵"
        case .inputMouseRight: return "滑鼠右鍵"
        case .inputMouseMiddle: return "滑鼠中鍵"
        case .inputMouseSideBack: return "滑鼠側鍵 1"
        case .inputMouseSideForward: return "滑鼠側鍵 2"
        case .inputMouseButton: return "滑鼠按鍵 %d"
        case .backToHome: return "返回主頁"
        case .newGame: return "新遊戲"
        case .inputHint: return "左鍵/右鍵或自訂鍵位均可操作；雙擊已翻開的數字可快速展開。"
        case .inputConflictFormat: return "「%@」原本綁定在「%@」，已自動移到這裡。"
        case .gameMenu: return "遊戲"
        case .howToPlay: return "玩法"
        case .ruleDigDesktop: return "左鍵或自訂鍵位翻開格子"
        case .ruleFlagDesktop: return "右鍵或自訂鍵位標記地雷"
        case .betterLuckNextTime: return "下次好運."
        }
    }
    
    // MARK: - 日本語
    private var localizedJapanese: String {
        switch self {
        case .close: return "閉じる"
        case .cancel: return "キャンセル"
        case .delete: return "削除"
        case .clearAll: return "全て削除"
        case .exit: return "終了"
            
        case .gameTitle: return "マインスイーパー"
        case .selectDifficulty: return "難易度を選択"
        case .startGame: return "ゲーム開始"
        case .exitGame: return "ゲーム終了"
        case .gameOver: return "ゲームオーバー"
        case .congratulations: return "おめでとう!"
        case .playAgain: return "もう一度"
        case .reviewBoard: return "👀 盤面を確認"
        case .timeElapsed: return "経過時間"
        case .remainingMines: return "残り地雷"
            
        case .difficultyEasy: return "簡単"
        case .difficultyMedium: return "普通"
        case .difficultyHard: return "難しい"
        case .difficultyHell: return "地獄"
        case .minesSuffix: return "個"
            
        case .modeDigging: return "掘る"
        case .modeFlagging: return "旗"
            
        case .ruleDig: return "[掘る]モードでマスを開く"
        case .ruleFlag: return "[旗]モードで地雷をマーク"
        case .ruleSeed: return "同じシードで公平な対戦"
        case .historyTitle: return "ゲーム履歴"
        case .noHistory: return "記録がありません"
        case .noHistoryDesc: return "ゲームを完了するとリプレイを表示できます"
        case .win: return "勝利"
        case .lose: return "敗北"
        case .accessibilityCovered: return "未開封"
        case .accessibilityFlagged: return "旗あり"
        case .accessibilityMine: return "地雷"
        case .accessibilityEmpty: return "空白"
        case .accessibilityNeighbors: return "周囲 %d 個の地雷"
        case .accessibilityBoard: return "マインスイーパー盤面、%d 行 %d 列"
        case .iCloudSync: return "iCloud 同期"
        case .iCloudQuotaExceeded: return "iCloud の保存容量が不足しています"
        case .iCloudAccountChanged: return "iCloud アカウントが変更されました"
        case .iCloudSyncFailed: return "iCloud 同期に失敗しました"
        case .iCloudHistoryTooLarge: return "履歴が大きすぎて iCloud にアップロードできません"
        case .pin: return "ピン留め"
        case .unpin: return "ピン解除"
            
        case .seed: return "シード"
        case .seedCopied: return "シードをコピーしました"
        case .inputSeed: return "開始"
        case .inputSeedTitle: return "ゲームシード入力"
        case .inputSeedMessage: return "同じシードでも、最初にタップするマスが同じ場合だけ同じ地雷配置になります。"
        case .inputSeedPlaceholder: return "例: 123456"
        case .customSeedChallenge: return "カスタムシードチャレンジ"
        case .iCloudUnavailable: return "iCloud 利用不可"
        case .lastSync: return "前回の同期"
        case .waitingSync: return "同期待ち..."
        case .syncNow: return "今すぐ同期"
            
        case .replayTitle: return "ゲームリプレイ"
        case .stepCount: return "手数"
        case .playbackSpeed: return "速度"
            
        case .settings: return "設定"
        case .general: return "一般"
        case .language: return "言語 (Language)"
        case .gameplay: return "ゲームプレイ"
        case .theme: return "テーマ"
        case .themeClassic: return "クラシック (💣)"
        case .themeFlower: return "花畑 (🌼)"
        case .haptics: return "振動フィードバック"
        case .hapticsDesc: return "掘る時と爆発時に振動します"
        case .noGuessingOption: return "運任せなし"
        case .noGuessingDesc: return "論理的に解決可能な盤面を保証します (地獄を除く)"
        case .dataManagement: return "データ管理"
        case .clearHistoryConfirm: return "すべての履歴を削除しますか？この操作は取り消せません。"
        case .about: return "について"
        case .version: return "バージョン"
        case .keyZDig: return "Z: 掘る"
        case .keyXFlag: return "X: 旗"
        case .inputSettings: return "入力"
        case .inputSettingsDesc: return "1つの操作に複数のキーボード／マウスボタンを割り当てられます。マウスのサイドボタンにも対応しています。"
        case .inputActionDig: return "掘る"
        case .inputActionFlag: return "旗"
        case .inputActionChord: return "クイック展開"
        case .inputActionNewGame: return "新しいゲーム"
        case .inputAdd: return "入力を追加"
        case .inputPressPrompt: return "キーを押すか、マウスボタンを押してください…（Esc でキャンセル）"
        case .inputReset: return "デフォルトに戻す"
        case .inputMouseLeft: return "マウス左ボタン"
        case .inputMouseRight: return "マウス右ボタン"
        case .inputMouseMiddle: return "マウス中ボタン"
        case .inputMouseSideBack: return "サイドボタン 1"
        case .inputMouseSideForward: return "サイドボタン 2"
        case .inputMouseButton: return "マウスボタン %d"
        case .backToHome: return "ホームに戻る"
        case .newGame: return "新しいゲーム"
        case .inputHint: return "左右クリックやカスタムキーで操作できます。開いた数字をダブルクリックするとクイック展開します。"
        case .inputConflictFormat: return "「%@」は「%@」に割り当てられていたため、こちらへ移動しました。"
        case .gameMenu: return "ゲーム"
        case .howToPlay: return "遊び方"
        case .ruleDigDesktop: return "左クリックまたはカスタムキーでマスを開く"
        case .ruleFlagDesktop: return "右クリックまたはカスタムキーで地雷をマーク"
        case .betterLuckNextTime: return "次回がんばって."
        }
    }
}
