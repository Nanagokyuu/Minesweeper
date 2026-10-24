//
//  MacSettingsView.swift
//  MinesweeperMac
//
//  Standard macOS Settings scene (Cmd-,): General, Input, Data and About.
//  Input bindings live here so keyboard and mouse remapping is discoverable.
//

import AppKit
import Combine
import SwiftUI

struct MacSettingsView: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        TabView {
            MacGeneralSettings()
                .tabItem {
                    Label(localization.text(.general), systemImage: "gearshape")
                }

            MacInputSettings()
                .tabItem {
                    Label(localization.text(.inputSettings), systemImage: "keyboard")
                }

            MacDataSettings()
                .tabItem {
                    Label(localization.text(.dataManagement), systemImage: "externaldrive")
                }

            MacAboutSettings()
                .tabItem {
                    Label(localization.text(.about), systemImage: "info.circle")
                }
        }
        .padding(16)
        .frame(width: 640, height: 520)
    }
}

// MARK: - General

private struct MacGeneralSettings: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        Form {
            Section(localization.text(.general)) {
                Picker(localization.text(.language), selection: $localization.currentLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text("\(language.flag)  \(language.displayName)")
                            .tag(language)
                    }
                }
            }

            Section(localization.text(.gameplay)) {
                Picker(localization.text(.theme), selection: $settings.selectedThemeName) {
                    Text(localization.text(.themeClassic)).tag("Classic")
                    Text(localization.text(.themeFlower)).tag("Flower")
                }

                Toggle(isOn: $settings.isNoGuessingEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization.text(.noGuessingOption))
                        Text(localization.text(.noGuessingDesc))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $settings.isHapticsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization.text(.haptics))
                        Text(localization.text(.hapticsDesc))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Input

private struct MacInputSettings: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var localization = LocalizationManager.shared

    @State private var recorderAction: InputAction?
    @State private var conflictMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.text(.inputSettings))
                .font(.title3.weight(.semibold))
            Text(localization.text(.inputSettingsDesc))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(InputAction.allCases) { action in
                        actionRow(action)
                    }
                }
                .padding(.vertical, 4)
            }

            if let conflictMessage {
                Text(conflictMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack(alignment: .top, spacing: 12) {
                Text(localization.text(.inputHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button(localization.text(.inputReset)) {
                    settings.inputBindings.reset()
                    conflictMessage = nil
                    HapticManager.shared.light()
                }
                .controlSize(.small)
            }
        }
        .padding(20)
        .sheet(item: $recorderAction) { action in
            MacBindingRecorderView(action: action) { binding in
                add(binding, to: action)
            }
        }
    }

    private func actionRow(_ action: InputAction) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: action.systemImage)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            Text(localization.text(action.localizationKey))
                .frame(width: 110, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(settings.inputBindings[action]) { binding in
                    chip(binding, action: action)
                }
            }

            Spacer(minLength: 8)

            Button {
                recorderAction = action
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .help(localization.text(.inputAdd))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondaryGroupedBackground)
        )
    }

    private func chip(_ binding: InputBinding, action: InputAction) -> some View {
        HStack(spacing: 5) {
            Text(binding.displayName(localization: localization))
                .font(.callout.monospaced())
            Button {
                settings.inputBindings.unbind(binding, from: action)
                conflictMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(localization.text(.delete))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.07))
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func add(_ binding: InputBinding, to action: InputAction) {
        let conflict = settings.inputBindings.conflictingAction(
            for: binding,
            assignedTo: action
        )
        settings.inputBindings.bind(binding, to: action)

        if let conflict {
            conflictMessage = String(
                format: localization.text(.inputConflictFormat),
                binding.displayName(localization: localization),
                localization.text(conflict.localizationKey)
            )
        } else {
            conflictMessage = nil
        }
        HapticManager.shared.light()
    }
}

// MARK: - Recorder

private struct MacBindingRecorderView: View {
    let action: InputAction
    let onCapture: (InputBinding) -> Void

    @ObservedObject private var localization = LocalizationManager.shared
    @StateObject private var recorder = MacBindingRecorder()
    @State private var captured: InputBinding?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: action.systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.blue)

            Text(localization.text(action.localizationKey))
                .font(.title3.weight(.semibold))

            if let captured {
                Text(captured.displayName(localization: localization))
                    .font(.title2.monospaced())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.accentColor.opacity(0.16))
                    )
            } else {
                Text(localization.text(.inputPressPrompt))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(width: 440, height: 230)
        .onAppear {
            // Start on the next run-loop turn so the click that opened the
            // sheet is not captured as the new binding.
            DispatchQueue.main.async {
                recorder.start { binding in
                    captured = binding
                    onCapture(binding)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                } onCancel: {
                    dismiss()
                }
            }
        }
        .onDisappear {
            recorder.stop()
        }
    }
}

// MARK: - Data

private struct MacDataSettings: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var cloud = CloudSyncManager.shared
    @State private var showClearConfirmation = false

    var body: some View {
        Form {
            Section(localization.text(.iCloudSync)) {
                HStack(spacing: 10) {
                    Image(systemName: "icloud.fill")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization.text(.iCloudSync))
                        statusText
                    }
                    Spacer()
                    if cloud.isSyncing {
                        ProgressView().controlSize(.small)
                    } else if cloud.isCloudAvailable {
                        Button(localization.text(.syncNow)) {
                            HistoryManager.shared.syncWithCloud()
                            HapticManager.shared.light()
                        }
                    }
                }
            }

            Section(localization.text(.dataManagement)) {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Label(localization.text(.clearAll), systemImage: "trash")
                }
            }
        }
        .formStyle(.grouped)
        .alert(localization.text(.clearAll), isPresented: $showClearConfirmation) {
            Button(localization.text(.delete), role: .destructive) {
                HistoryManager.shared.clear()
                HapticManager.shared.heavy()
            }
            Button(localization.text(.cancel), role: .cancel) { }
        } message: {
            Text(localization.text(.clearHistoryConfirm))
        }
    }

    @ViewBuilder
    private var statusText: some View {
        if !cloud.isCloudAvailable {
            Text(localization.text(.iCloudUnavailable))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let error = cloud.lastError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        } else if let date = cloud.lastSyncDate {
            Text("\(localization.text(.lastSync)): \(date.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text(localization.text(.waitingSync))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - About

private struct MacAboutSettings: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        VStack(spacing: 14) {
            Text("💣")
                .font(.system(size: 64))

            Text(localization.text(.gameTitle))
                .font(.system(size: 26, weight: .heavy, design: .rounded))

            Text(versionText)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("SwiftUI + Rust · macOS")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                if let url = URL(string: "https://github.com/Nanagokyuu/Minesweeper") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .buttonStyle(.link)
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.2.1"
        let build = info?["CFBundleVersion"] as? String ?? "2"
        return "v\(version) (\(build))"
    }
}
