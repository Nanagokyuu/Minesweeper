//
// SettingsView.swift
// Minesweeper
//
// Created by Nanagokyuu on 2026/1/2.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var localization = LocalizationManager.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var cloudManager = CloudSyncManager.shared
    @Environment(\.dismiss) var dismiss
   
    // 控制弹窗
    @State private var showClearHistoryAlert = false
   
    var body: some View {
        NavigationStack {
            List {
                // MARK: - 通用设置
                Section(header: Text(localization.text(.general))) {
                    // 语言设置
                    NavigationLink {
                        // 【关键】这里引用的就是下面定义的 LanguagePickerView
                        LanguagePickerView()
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(localization.text(.language))
                            Spacer()
                            Text(localization.currentLanguage.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                }
               
                // MARK: - 游戏体验
                Section(header: Text(localization.text(.gameplay))) {
                    // 皮肤设置
                    Picker(selection: $settings.selectedThemeName) {
                        Text(localization.text(.themeClassic)).tag("Classic")
                        Text(localization.text(.themeFlower)).tag("Flower")
                    } label: {
                        HStack {
                            Image(systemName: "paintpalette.fill")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            Text(localization.text(.theme))
                        }
                    }
                    .onChange(of: settings.selectedThemeName) { _ in
                        HapticManager.shared.light()
                    }
                    // 震动开关
                    Toggle(isOn: $settings.isHapticsEnabled) {
                        HStack {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text(localization.text(.haptics))
                                Text(localization.text(.hapticsDesc))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                   
                    // 无猜模式开关
                    Toggle(isOn: $settings.isNoGuessingEnabled) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text(localization.text(.noGuessingOption))
                                Text(localization.text(.noGuessingDesc))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
               
                // MARK: - 历史与数据
                Section(header: Text(localization.text(.dataManagement))) {
                    // 历史记录入口
                    NavigationLink {
                        HistoryView(game: MinesweeperGame())
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text(localization.text(.historyTitle))
                        }
                    }
                   
                    // iCloud 同步状态 (保留在设置里查看)
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text("iCloud Sync")
                            if let date = cloudManager.lastSyncDate {
                                Text("\(localization.text(.lastSync)): \(date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundColor(.secondary)
                            } else {
                                Text(localization.text(.waitingSync))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if cloudManager.isSyncing {
                            ProgressView()
                        } else {
                            Button(localization.text(.syncNow)) {
                                cloudManager.downloadFromCloud()
                                HapticManager.shared.light()
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                   
                    // 清除历史记录
                    Button(role: .destructive) {
                        showClearHistoryAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text(localization.text(.clearAll))
                        }
                    }
                }
               
                // MARK: - 关于
                Section(header: Text(localization.text(.about))) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        Text(localization.text(.version))
                        Spacer()
                        Text("v0.9.255")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(localization.text(.settings))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localization.text(.close)) {
                        dismiss()
                    }
                }
            }
            .alert(localization.text(.clearAll), isPresented: $showClearHistoryAlert) {
                Button(localization.text(.delete), role: .destructive) {
                    HistoryManager.shared.clear()
                    CloudSyncManager.shared.uploadToCloud()
                    HapticManager.shared.heavy()
                }
                Button(localization.text(.cancel), role: .cancel) {}
            } message: {
                Text(localization.text(.clearHistoryConfirm))
            }
        }
    }
}
// MARK: - 语言选择子页面
// 这里定义了 LanguagePickerView，确保它就在 SettingsView 下面
struct LanguagePickerView: View {
    @ObservedObject var localization = LocalizationManager.shared
    @Environment(\.dismiss) var dismiss
   
    var body: some View {
        List {
            ForEach(AppLanguage.allCases) { language in
                Button(action: {
                    localization.currentLanguage = language
                    HapticManager.shared.light()
                    dismiss()
                }) {
                    HStack {
                        Text(language.flag).font(.title2)
                        Text(language.displayName).foregroundColor(.primary)
                        Spacer()
                        if localization.currentLanguage == language {
                            Image(systemName: "checkmark").foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle(localization.text(.language))
    }
}
