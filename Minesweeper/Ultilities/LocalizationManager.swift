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
    case korean = "ko"
    // Cytimax这家伙非让我把五常的语言全加进去，那加就加吧
    case russian = "ru"
    case french = "fr"
    case arabic = "ar"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .russian: return "Русский"
        case .french: return "Français"
        case .arabic: return "العربية"
        }
    }
    
    var flag: String {
        switch self {
        case .simplifiedChinese: return "🇨🇳"
        case .traditionalChinese: return "🇭🇰"
        case .english: return "🇺🇸"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .russian: return "🇷🇺"
        case .french: return "🇫🇷"
        case .arabic: return "🇸🇦"
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
            // Locale.preferredLanguages通常比Locale.current更诚实，它返回的是类似 ["zh-Hans-CN", "en-US"] 这样的数组
            let preferredLanguages = Locale.preferredLanguages
            let firstLang = preferredLanguages.first ?? "en"
            
            // 简单的字符串匹配，粗暴但有效
            if firstLang.hasPrefix("zh-Hans") {
                self.currentLanguage = .simplifiedChinese
            } else if firstLang.hasPrefix("zh-Hant") || firstLang.hasPrefix("zh-HK") || firstLang.hasPrefix("zh-TW") {
                self.currentLanguage = .traditionalChinese
            } else if firstLang.hasPrefix("ja") {
                self.currentLanguage = .japanese
            } else if firstLang.hasPrefix("ko") {
                self.currentLanguage = .korean
            } else if firstLang.hasPrefix("ru") {
                self.currentLanguage = .russian
            } else if firstLang.hasPrefix("fr") {
                self.currentLanguage = .french
            } else if firstLang.hasPrefix("ar") {
                self.currentLanguage = .arabic
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
enum LocalizedKey {
    // 通用
    case close
    case cancel
    case confirm
    case delete
    case clearAll
    case retry
    case exit
    case start
    case ok
    
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
    
    // 【新增】地雷数量后缀
    case minesSuffix
    
    // 模式
    case modeDigging
    case modeFlagging
    
    // 【新增】无猜模式相关
    case modeNoGuessing
    case solverFailed
    
    // 规则说明
    case ruleDig
    case ruleFlag
    case ruleSeed
    
    // 历史记录
    case history
    case historyTitle
    case noHistory
    case noHistoryDesc
    case replay
    case pin
    case unpin
    case pinned
    
    // 种子相关
    case seed
    case seedCopied
    case inputSeed
    case inputSeedTitle
    case inputSeedMessage
    case inputSeedPlaceholder
    case customSeedChallenge
    
    // iCloud
    case iCloudReady
    case iCloudUnavailable
    case lastSync
    case waitingSync
    case syncNow
    
    // 回放
    case replayTitle
    case stepCount
    case playbackSpeed
    
    // 其他
    case goodLuck
    case betterLuckNextTime
    
    func localized(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            return localizedSimplifiedChinese
        case .traditionalChinese:
            return localizedTraditionalChinese
        case .english:
            return localizedEnglish
        case .japanese:
            return localizedJapanese
        case .korean:
            return localizedKorean
        case .russian:
            return localizedRussian
        case .french:
            return localizedFrench
        case .arabic:
            return localizedArabic
        }
    }
    
    // MARK: - 简体中文
    private var localizedSimplifiedChinese: String {
        switch self {
        case .close: return "关闭"
        case .cancel: return "取消"
        case .confirm: return "确定"
        case .delete: return "删除"
        case .clearAll: return "清除全部"
        case .retry: return "再试一次"
        case .exit: return "退出"
        case .start: return "开始"
        case .ok: return "好的"
            
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
        
        case .modeNoGuessing: return "无猜模式"
        case .solverFailed: return "你的运气有点背……自求多福吧"
            
        case .ruleDig: return "切换至[挖雷]模式翻开格子"
        case .ruleFlag: return "切换至[插旗]模式标记地雷"
        case .ruleSeed: return "使用相同种子可进行公平对决"
            
        case .history: return "历史记录"
        case .historyTitle: return "历史记录"
        case .noHistory: return "暂无游戏记录"
        case .noHistoryDesc: return "完成一局游戏后，可在此查看回放"
        case .replay: return "回放"
        case .pin: return "置顶"
        case .unpin: return "取消置顶"
        case .pinned: return "已置顶"
            
        case .seed: return "种子"
        case .seedCopied: return "种子已复制"
        case .inputSeed: return "开始"
        case .inputSeedTitle: return "输入游戏种子"
        case .inputSeedMessage: return "输入相同的数字将生成完全一样的雷区布局。"
        case .inputSeedPlaceholder: return "例如: 123456"
        case .customSeedChallenge: return "输入种子挑战"
            
        case .iCloudReady: return "iCloud 已就绪"
        case .iCloudUnavailable: return "iCloud 未登录或不可用"
        case .lastSync: return "上次同步"
        case .waitingSync: return "等待同步..."
        case .syncNow: return "立即同步"
            
        case .replayTitle: return "游戏回放"
        case .stepCount: return "步数"
        case .playbackSpeed: return "倍速"
            
        case .goodLuck: return "祝你好运"
        case .betterLuckNextTime: return "下次好运."
        }
    }
    
    // MARK: - 繁体中文
    private var localizedTraditionalChinese: String {
        switch self {
        case .close: return "關閉"
        case .cancel: return "取消"
        case .confirm: return "確定"
        case .delete: return "刪除"
        case .clearAll: return "清除全部"
        case .retry: return "再試一次"
        case .exit: return "退出"
        case .start: return "開始"
        case .ok: return "好的"
            
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
            
        case .modeNoGuessing: return "無猜模式"
        case .solverFailed: return "你的運氣有點背……自求多福吧"
            
        case .ruleDig: return "切換至[挖雷]模式翻開格子"
        case .ruleFlag: return "切換至[插旗]模式標記地雷"
        case .ruleSeed: return "使用相同種子可進行公平對決"
            
        case .history: return "歷史記錄"
        case .historyTitle: return "歷史記錄"
        case .noHistory: return "暫無遊戲記錄"
        case .noHistoryDesc: return "完成一局遊戲後，可在此查看回放"
        case .replay: return "回放"
        case .pin: return "置頂"
        case .unpin: return "取消置頂"
        case .pinned: return "已置頂"
            
        case .seed: return "種子"
        case .seedCopied: return "種子已複製"
        case .inputSeed: return "開始"
        case .inputSeedTitle: return "輸入遊戲種子"
        case .inputSeedMessage: return "輸入相同的數字將生成完全一樣的雷區佈局。"
        case .inputSeedPlaceholder: return "例如: 123456"
        case .customSeedChallenge: return "輸入種子挑戰"
            
        case .iCloudReady: return "iCloud 已就緒"
        case .iCloudUnavailable: return "iCloud 未登錄或不可用"
        case .lastSync: return "上次同步"
        case .waitingSync: return "等待同步..."
        case .syncNow: return "立即同步"
            
        case .replayTitle: return "遊戲回放"
        case .stepCount: return "步數"
        case .playbackSpeed: return "倍速"
            
        case .goodLuck: return "祝你好運"
        case .betterLuckNextTime: return "下次好運."
        }
    }
    
    // MARK: - English
    private var localizedEnglish: String {
        switch self {
        case .close: return "Close"
        case .cancel: return "Cancel"
        case .confirm: return "Confirm"
        case .delete: return "Delete"
        case .clearAll: return "Clear All"
        case .retry: return "Retry"
        case .exit: return "Exit"
        case .start: return "Start"
        case .ok: return "OK"
            
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
            
        case .modeNoGuessing: return "No Guessing"
        case .solverFailed: return "Luck is not on your side... Good luck."
            
        case .ruleDig: return "Switch to [Dig] mode to reveal cells"
        case .ruleFlag: return "Switch to [Flag] mode to mark mines"
        case .ruleSeed: return "Use the same seed for fair competition"
            
        case .history: return "History"
        case .historyTitle: return "Game History"
        case .noHistory: return "No Game Records"
        case .noHistoryDesc: return "Complete a game to view replays here"
        case .replay: return "Replay"
        case .pin: return "Pin"
        case .unpin: return "Unpin"
        case .pinned: return "Pinned"
            
        case .seed: return "Seed"
        case .seedCopied: return "Seed Copied"
        case .inputSeed: return "Start"
        case .inputSeedTitle: return "Enter Game Seed"
        case .inputSeedMessage: return "Entering the same number will generate an identical minefield layout."
        case .inputSeedPlaceholder: return "e.g., 123456"
        case .customSeedChallenge: return "Custom Seed Challenge"
            
        case .iCloudReady: return "iCloud Ready"
        case .iCloudUnavailable: return "iCloud Unavailable"
        case .lastSync: return "Last Sync"
        case .waitingSync: return "Waiting to sync..."
        case .syncNow: return "Sync Now"
            
        case .replayTitle: return "Game Replay"
        case .stepCount: return "Steps"
        case .playbackSpeed: return "Speed"
            
        case .goodLuck: return "Good luck"
        case .betterLuckNextTime: return "Better luck next time."
        }
    }
    
    // MARK: - 日本語
    private var localizedJapanese: String {
        switch self {
        case .close: return "閉じる"
        case .cancel: return "キャンセル"
        case .confirm: return "確定"
        case .delete: return "削除"
        case .clearAll: return "全て削除"
        case .retry: return "もう一度"
        case .exit: return "終了"
        case .start: return "開始"
        case .ok: return "OK"
            
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
            
        case .modeNoGuessing: return "運任せなし"
        case .solverFailed: return "運が悪かったね……健闘を祈る"
            
        case .ruleDig: return "[掘る]モードでマスを開く"
        case .ruleFlag: return "[旗]モードで地雷をマーク"
        case .ruleSeed: return "同じシードで公平な対戦"
            
        case .history: return "履歴"
        case .historyTitle: return "ゲーム履歴"
        case .noHistory: return "記録がありません"
        case .noHistoryDesc: return "ゲームを完了するとリプレイを表示できます"
        case .replay: return "リプレイ"
        case .pin: return "ピン留め"
        case .unpin: return "ピン解除"
        case .pinned: return "ピン留め済み"
            
        case .seed: return "シード"
        case .seedCopied: return "シードをコピーしました"
        case .inputSeed: return "開始"
        case .inputSeedTitle: return "ゲームシード入力"
        case .inputSeedMessage: return "同じ数字を入力すると同じ地雷配置が生成されます。"
        case .inputSeedPlaceholder: return "例: 123456"
        case .customSeedChallenge: return "カスタムシードチャレンジ"
            
        case .iCloudReady: return "iCloud 準備完了"
        case .iCloudUnavailable: return "iCloud 利用不可"
        case .lastSync: return "前回の同期"
        case .waitingSync: return "同期待ち..."
        case .syncNow: return "今すぐ同期"
            
        case .replayTitle: return "ゲームリプレイ"
        case .stepCount: return "手数"
        case .playbackSpeed: return "速度"
            
        case .goodLuck: return "がんばって"
        case .betterLuckNextTime: return "次回がんばって."
        }
    }
    
    // MARK: - 한국어
    private var localizedKorean: String {
        switch self {
        case .close: return "닫기"
        case .cancel: return "취소"
        case .confirm: return "확인"
        case .delete: return "삭제"
        case .clearAll: return "전체 삭제"
        case .retry: return "다시 시도"
        case .exit: return "나가기"
        case .start: return "시작"
        case .ok: return "확인"
            
        case .gameTitle: return "지뢰찾기"
        case .selectDifficulty: return "난이도 선택"
        case .startGame: return "게임 시작"
        case .exitGame: return "게임 종료"
        case .gameOver: return "게임 오버"
        case .congratulations: return "축하합니다!"
        case .playAgain: return "다시 하기"
        case .reviewBoard: return "👀 판 보기"
        case .timeElapsed: return "경과 시간"
        case .remainingMines: return "남은 지뢰"
            
        case .difficultyEasy: return "쉬움"
        case .difficultyMedium: return "보통"
        case .difficultyHard: return "어려움"
        case .difficultyHell: return "지옥"
        case .minesSuffix: return "개의 지뢰"
            
        case .modeDigging: return "파기"
        case .modeFlagging: return "깃발"
            
        case .modeNoGuessing: return "운빨 금지"
        case .solverFailed: return "운이 좀 없었네요... 행운을 빕니다."
            
        case .ruleDig: return "[파기] 모드로 칸 열기"
        case .ruleFlag: return "[깃발] 모드로 지뢰 표시"
        case .ruleSeed: return "같은 시드로 공정한 대결"
            
        case .history: return "기록"
        case .historyTitle: return "게임 기록"
        case .noHistory: return "게임 기록 없음"
        case .noHistoryDesc: return "게임을 완료하면 리플레이를 볼 수 있습니다"
        case .replay: return "리플레이"
        case .pin: return "고정"
        case .unpin: return "고정 해제"
        case .pinned: return "고정됨"
            
        case .seed: return "시드"
        case .seedCopied: return "시드 복사됨"
        case .inputSeed: return "시작"
        case .inputSeedTitle: return "게임 시드 입력"
        case .inputSeedMessage: return "같은 숫자를 입력하면 동일한 지뢰 배치가 생성됩니다."
        case .inputSeedPlaceholder: return "예: 123456"
        case .customSeedChallenge: return "커스텀 시드 도전"
            
        case .iCloudReady: return "iCloud 준비됨"
        case .iCloudUnavailable: return "iCloud 사용 불가"
        case .lastSync: return "마지막 동기화"
        case .waitingSync: return "동기화 대기 중..."
        case .syncNow: return "지금 동기화"
            
        case .replayTitle: return "게임 리플레이"
        case .stepCount: return "단계"
        case .playbackSpeed: return "속도"
            
        case .goodLuck: return "행운을 빕니다"
        case .betterLuckNextTime: return "다음엔 잘하세요."
        }
    }
    
    // MARK: - Русский (俄语)
    private var localizedRussian: String {
        switch self {
        case .close: return "Закрыть"
        case .cancel: return "Отмена"
        case .confirm: return "OK"
        case .delete: return "Удалить"
        case .clearAll: return "Очистить все"
        case .retry: return "Повторить"
        case .exit: return "Выход"
        case .start: return "Старт"
        case .ok: return "ОК"
            
        case .gameTitle: return "Сапёр"
        case .selectDifficulty: return "Сложность"
        case .startGame: return "Начать игру"
        case .exitGame: return "Закончить игру"
        case .gameOver: return "Игра окончена"
        case .congratulations: return "Победа!"
        case .playAgain: return "Ещё раз"
        case .reviewBoard: return "👀 Обзор поля"
        case .timeElapsed: return "Время"
        case .remainingMines: return "Мины"
            
        case .difficultyEasy: return "Легко"
        case .difficultyMedium: return "Средне"
        case .difficultyHard: return "Сложно"
        case .difficultyHell: return "Ад"
        case .minesSuffix: return " мин"
            
        case .modeDigging: return "Копать"
        case .modeFlagging: return "Флаг"
            
        case .modeNoGuessing: return "Без догадок"
        case .solverFailed: return "Не повезло... Удачи в следующий раз."
            
        case .ruleDig: return "Режим [Копать] открывает клетки"
        case .ruleFlag: return "Режим [Флаг] ставит метки"
        case .ruleSeed: return "Один сид - одно поле"
            
        case .history: return "История"
        case .historyTitle: return "История игр"
        case .noHistory: return "Нет записей"
        case .noHistoryDesc: return "Завершите игру, чтобы увидеть повтор"
        case .replay: return "Повтор"
        case .pin: return "Закрепить"
        case .unpin: return "Открепить"
        case .pinned: return "Закреплено"
            
        case .seed: return "Сид"
        case .seedCopied: return "Сид скопирован"
        case .inputSeed: return "Старт"
        case .inputSeedTitle: return "Введите сид"
        case .inputSeedMessage: return "Одинаковые цифры создают одинаковое поле."
        case .inputSeedPlaceholder: return "Напр.: 123456"
        case .customSeedChallenge: return "Игра по сиду"
            
        case .iCloudReady: return "iCloud готов"
        case .iCloudUnavailable: return "Нет iCloud"
        case .lastSync: return "Синхр."
        case .waitingSync: return "Ожидание..."
        case .syncNow: return "Синхронизировать"
            
        case .replayTitle: return "Повтор игры"
        case .stepCount: return "Ходы"
        case .playbackSpeed: return "Скор."
            
        case .goodLuck: return "Удачи"
        case .betterLuckNextTime: return "Повезет в другой раз."
        }
    }
    
    // MARK: - Français (法语)
    private var localizedFrench: String {
        switch self {
        case .close: return "Fermer"
        case .cancel: return "Annuler"
        case .confirm: return "Confirmer"
        case .delete: return "Supprimer"
        case .clearAll: return "Tout effacer"
        case .retry: return "Réessayer"
        case .exit: return "Quitter"
        case .start: return "Démarrer"
        case .ok: return "OK"
            
        case .gameTitle: return "Démineur"
        case .selectDifficulty: return "Difficulté"
        case .startGame: return "Jouer"
        case .exitGame: return "Quitter la partie"
        case .gameOver: return "Perdu"
        case .congratulations: return "Gagné !"
        case .playAgain: return "Rejouer"
        case .reviewBoard: return "👀 Voir le plateau"
        case .timeElapsed: return "Temps"
        case .remainingMines: return "Mines"
            
        case .difficultyEasy: return "Facile"
        case .difficultyMedium: return "Moyen"
        case .difficultyHard: return "Difficile"
        case .difficultyHell: return "Enfer"
        case .minesSuffix: return " Mines"
            
        case .modeDigging: return "Creuser"
        case .modeFlagging: return "Drapeau"
            
        case .modeNoGuessing: return "Sans deviner"
        case .solverFailed: return "Pas de chance... Bonne chance."
            
        case .ruleDig: return "Mode [Creuser] pour révéler"
        case .ruleFlag: return "Mode [Drapeau] pour marquer"
        case .ruleSeed: return "Même graine pour un duel équitable"
            
        case .history: return "Historique"
        case .historyTitle: return "Historique"
        case .noHistory: return "Aucun enregistrement"
        case .noHistoryDesc: return "Terminez une partie pour voir le replay"
        case .replay: return "Replay"
        case .pin: return "Épingler"
        case .unpin: return "Désépingler"
        case .pinned: return "Épinglé"
            
        case .seed: return "Graine"
        case .seedCopied: return "Copié"
        case .inputSeed: return "Go"
        case .inputSeedTitle: return "Entrer une graine"
        case .inputSeedMessage: return "Le même numéro génère le même champ de mines."
        case .inputSeedPlaceholder: return "ex: 123456"
        case .customSeedChallenge: return "Défi personnalisé"
            
        case .iCloudReady: return "iCloud prêt"
        case .iCloudUnavailable: return "iCloud indisponible"
        case .lastSync: return "Dernière sync"
        case .waitingSync: return "En attente..."
        case .syncNow: return "Synchroniser"
            
        case .replayTitle: return "Replay du jeu"
        case .stepCount: return "Coups"
        case .playbackSpeed: return "Vitesse"
            
        case .goodLuck: return "Bonne chance"
        case .betterLuckNextTime: return "La prochaine fois sera la bonne."
        }
    }
    
    // MARK: - العربية (阿拉伯语)
    private var localizedArabic: String {
        switch self {
        case .close: return "إغلاق"
        case .cancel: return "إلغاء"
        case .confirm: return "تأكيد"
        case .delete: return "حذف"
        case .clearAll: return "مسح الكل"
        case .retry: return "إعادة المحاولة"
        case .exit: return "خروج"
        case .start: return "بدء"
        case .ok: return "موافق"
            
        case .gameTitle: return "كاسحة الألغام"
        case .selectDifficulty: return "اختر الصعوبة"
        case .startGame: return "بدء اللعبة"
        case .exitGame: return "إنهاء اللعبة"
        case .gameOver: return "انتهت اللعبة"
        case .congratulations: return "مبروك الفوز!"
        case .playAgain: return "العب مجدداً"
        case .reviewBoard: return "👀 مراجعة اللوحة"
        case .timeElapsed: return "الوقت"
        case .remainingMines: return "الألغام المتبقية"
            
        case .difficultyEasy: return "سهل"
        case .difficultyMedium: return "متوسط"
        case .difficultyHard: return "صعب"
        case .difficultyHell: return "جحيم"
        case .minesSuffix: return " ألغام"
            
        case .modeDigging: return "حفر"
        case .modeFlagging: return "عَلَم"
        
        case .modeNoGuessing: return "بدون تخمين"
        case .solverFailed: return "حظ سيء... بالتوفيق."
            
        case .ruleDig: return "وضع [حفر] لكشف الخلايا"
        case .ruleFlag: return "وضع [عَلَم] لتمييز الألغام"
        case .ruleSeed: return "استخدم نفس الرمز للمنافسة العادلة"
            
        case .history: return "السجل"
        case .historyTitle: return "سجل الألعاب"
        case .noHistory: return "لا يوجد سجلات"
        case .noHistoryDesc: return "أكمل لعبة لمشاهدة الإعادة هنا"
        case .replay: return "إعادة العرض"
        case .pin: return "تثبيت"
        case .unpin: return "إلغاء التثبيت"
        case .pinned: return "مثبت"
            
        case .seed: return "الرمز (Seed)"
        case .seedCopied: return "تم نسخ الرمز"
        case .inputSeed: return "بدء"
        case .inputSeedTitle: return "أدخل رمز اللعبة"
        case .inputSeedMessage: return "إدخال نفس الرقم سيولد نفس توزيع الألغام تماماً."
        case .inputSeedPlaceholder: return "مثال: 123456"
        case .customSeedChallenge: return "تحدي الرمز الخاص"
            
        case .iCloudReady: return "iCloud جاهز"
        case .iCloudUnavailable: return "iCloud غير متوفر"
        case .lastSync: return "آخر مزامنة"
        case .waitingSync: return "انتظار المزامنة..."
        case .syncNow: return "مزامنة الآن"
            
        case .replayTitle: return "إعادة اللعبة"
        case .stepCount: return "خطوات"
        case .playbackSpeed: return "سرعة"
            
        case .goodLuck: return "حظاً موفقاً"
        case .betterLuckNextTime: return "حظاً أوفر في المرة القادمة."
        }
    }
}
