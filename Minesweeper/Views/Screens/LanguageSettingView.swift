//
//  LanguageSettingsView.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2026/1/1.
//  语言设置界面 - 巴别塔的现代版本
//  在这里，你可以自由选择用哪种语言被地雷炸飞
//

import SwiftUI

// 语言选择面板：五大语言，总有一款适合你
// 从🇨🇳到🇺🇸，从🇯🇵到🇰🇷，语言不同，但被炸的心情是相通的
struct LanguageSettingsView: View {
    @ObservedObject var localization = LocalizationManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // 遍历所有语言：民主选举，一人一票（哦不对，一个App一票）
                ForEach(AppLanguage.allCases) { language in
                    Button(action: {
                        // 切换语言：瞬间穿越到另一个语言世界
                        localization.currentLanguage = language
                        HapticManager.shared.light()
                    }) {
                        HStack {
                            Text(language.flag)
                                .font(.title2)
                            
                            Text(language.displayName)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if localization.currentLanguage == language {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle()) // 关键：让整个HStack区域都可点击
                    }
                    .buttonStyle(PlainButtonStyle()) // 使用PlainButtonStyle避免默认按钮样式
                }
            }
            .navigationTitle("Language / 语言")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localization.text(.close)) {
                        dismiss()
                    }
                }
            }
        }
    }
}
