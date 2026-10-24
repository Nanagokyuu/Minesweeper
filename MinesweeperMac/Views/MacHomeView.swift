//
//  MacHomeView.swift
//  MinesweeperMac
//
//  Landing screen.  Native Mac structure: one window, wide two-column layout,
//  keyboard-focusable controls and no phone-style push navigation.
//

import Combine
import SwiftUI

struct MacHomeView: View {
    @ObservedObject var session: MacGameSession
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var history = HistoryManager.shared
    @Environment(\.openWindow) private var openWindow

    @State private var showSeedSheet = false
    @State private var seedInput = ""
    @State private var seedIsInvalid = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                let wide = proxy.size.width >= 900
                Group {
                    if wide {
                        HStack(alignment: .top, spacing: 40) {
                            VStack(alignment: .leading, spacing: 26) {
                                brand
                                difficultySection
                                rulesCard
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .leading, spacing: 22) {
                                startCard
                                optionsCard
                                recentCard
                            }
                            .frame(width: 360)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 24) {
                            brand
                            difficultySection
                            rulesCard
                            startCard
                            optionsCard
                            recentCard
                        }
                        .frame(maxWidth: 680)
                    }
                }
                .padding(36)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showSeedSheet) {
            seedSheet
        }
        .onAppear {
            history.reload()
        }
    }

    // MARK: - Brand

    private var brand: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Text(settings.currentTheme.mainIcon)
                    .font(.system(size: 64))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.text(.gameTitle))
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                    Text(localization.text(.ruleSeed))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Difficulty

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localization.text(.selectDifficulty))
                .font(.headline)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(Difficulty.allCases, id: \.self) { difficulty in
                    difficultyCard(difficulty)
                }
            }
        }
    }

    private func difficultyCard(_ difficulty: Difficulty) -> some View {
        let selected = session.difficulty == difficulty
        return Button {
            session.difficulty = difficulty
            HapticManager.shared.light()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(difficulty.icon).font(.title2)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                Text(difficulty.localizedName(localization: localization))
                    .font(.headline)
                Text(difficulty.localizedDescription(localization: localization))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        selected
                            ? Color.accentColor.opacity(0.14)
                            : Color.secondaryGroupedBackground
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        selected ? Color.accentColor : Color.primary.opacity(0.08),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Rules

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.text(.howToPlay))
                .font(.headline)

            RuleRow(icon: "hammer.fill", text: localization.text(.ruleDigDesktop))
            RuleRow(icon: "flag.fill", text: localization.text(.ruleFlagDesktop))
            RuleRow(icon: "number.square", text: localization.text(.ruleSeed))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondaryGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Start

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                session.start()
                HapticManager.shared.light()
            } label: {
                Text(localization.text(.startGame))
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Button {
                seedInput = ""
                seedIsInvalid = false
                showSeedSheet = true
            } label: {
                Label(localization.text(.customSeedChallenge), systemImage: "number.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Divider()

            Text(localization.text(.inputHint))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondaryGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Options

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localization.text(.gameplay))
                .font(.headline)

            Toggle(isOn: $settings.isNoGuessingEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.text(.noGuessingOption))
                    Text(localization.text(.noGuessingDesc))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            Toggle(isOn: $settings.isHapticsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.text(.haptics))
                    Text(localization.text(.hapticsDesc))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 6) {
                Text(localization.text(.theme))
                    .font(.subheadline.weight(.medium))
                Picker(localization.text(.theme), selection: $settings.selectedThemeName) {
                    Text(localization.text(.themeClassic)).tag("Classic")
                    Text(localization.text(.themeFlower)).tag("Flower")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondaryGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Recent history

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localization.text(.historyTitle))
                    .font(.headline)
                Spacer()
                Button {
                    openWindow(id: MacWindowID.history)
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(localization.text(.historyTitle))
            }

            if history.records.isEmpty {
                Text(localization.text(.noHistoryDesc))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            } else {
                ForEach(history.records.prefix(3)) { record in
                    HStack {
                        Image(systemName: record.isWin ? "trophy.fill" : "xmark.circle")
                            .foregroundStyle(record.isWin ? .yellow : .red)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(record.localizedDifficultyName)
                                .font(.subheadline)
                            Text(record.dateValue.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(MacReplayTime.format(record.durationSeconds))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondaryGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Seed sheet

    private var seedSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localization.text(.inputSeedTitle))
                .font(.title2.weight(.semibold))
            Text(localization.text(.inputSeedMessage))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField(localization.text(.inputSeedPlaceholder), text: $seedInput)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(seedIsInvalid ? Color.red : Color.clear, lineWidth: 1)
                )

            HStack {
                Spacer()
                Button(localization.text(.cancel)) {
                    showSeedSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button(localization.text(.inputSeed)) {
                    startSeedGame()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private func startSeedGame() {
        let trimmed = seedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()

        if lowered == "cytimax" {
            showSeedSheet = false
            session.start(godMode: true)
            HapticManager.shared.success()
        } else if lowered == "nanagokyuu" {
            showSeedSheet = false
            session.start(nanagokyuu: true)
            HapticManager.shared.success()
        } else if let seed = Int(trimmed) {
            showSeedSheet = false
            session.start(seed: seed)
        } else {
            seedIsInvalid = true
            HapticManager.shared.failure()
        }
    }
}
