//
//  MacGameView.swift
//  MinesweeperMac
//
//  The board screen: native header, Canvas board, mouse/keyboard bindings and
//  the result overlay.
//

import AppKit
import Combine
import SwiftUI

struct MacGameView: View {
    @ObservedObject var session: MacGameSession
    @ObservedObject var game: MinesweeperGame
    @ObservedObject private var localization = LocalizationManager.shared

    @StateObject private var input: MacInputController
    @StateObject private var keyMonitor = MacKeyMonitor()
    @State private var showSeedCopied = false

    init(session: MacGameSession, game: MinesweeperGame) {
        self.session = session
        self.game = game
        _input = StateObject(wrappedValue: MacInputController(game: game))
    }

    var body: some View {
        VStack(spacing: 12) {
            MacGameHeader(game: game, clock: game.clock) {
                game.startNewGame()
                HapticManager.shared.light()
            }

            seedButton

            MacBoardView(game: game, input: input)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            MacInputHintBar()
        }
        .padding(16)
        .frame(maxWidth: 1100)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            if showSeedCopied {
                Text(localization.text(.seedCopied))
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(Color.black.opacity(0.75))
                    )
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
        .overlay {
            if game.showResult {
                resultOverlay
            }
        }
        .onAppear {
            keyMonitor.start(controller: input)
        }
        .onDisappear {
            keyMonitor.stop()
            game.stop()
        }
    }

    private var seedButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(String(game.currentSeed), forType: .string)
            HapticManager.shared.light()
            withAnimation { showSeedCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation { showSeedCopied = false }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "number.square")
                Text("\(localization.text(.seed)) \(game.currentSeed)")
                    .monospacedDigit()
                Image(systemName: "doc.on.doc")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .help(localization.text(.seed))
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { }

            ResultPopup(
                isWin: game.gameStatus == .won,
                timeElapsed: game.timeElapsed,
                onRetry: {
                    game.startNewGame()
                    HapticManager.shared.light()
                },
                onReview: {
                    withAnimation { game.showResult = false }
                },
                onExit: {
                    session.backHome()
                }
            )
            .frame(maxWidth: 440)
        }
        .transition(.opacity)
    }
}

// MARK: - Header

private struct MacGameHeader: View {
    @ObservedObject var game: MinesweeperGame
    @ObservedObject var clock: GameClock
    let onNewGame: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            pill {
                Text(game.currentTheme.mineIcon)
                    .font(.title3)
                Text("\(game.remainingMines)")
                    .font(.title3.monospacedDigit().weight(.bold))
                    .frame(minWidth: 36, alignment: .leading)
            }

            Spacer(minLength: 8)

            Button(action: onNewGame) {
                Text(statusIcon)
                    .font(.system(size: 26))
                    .frame(width: 46, height: 46)
                    .background(
                        Circle()
                            .fill(Color.secondaryGroupedBackground)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(game.difficulty.localizedName(localization: LocalizationManager.shared))

            Spacer(minLength: 8)

            pill {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
                Text(MacReplayTime.format(clock.elapsed))
                    .font(.title3.monospacedDigit().weight(.bold))
                    .frame(minWidth: 58, alignment: .trailing)
            }
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    private var statusIcon: String {
        if game.isNanagokyuuMode { return "🤡" }
        if game.isGodMode { return "👁️" }
        return game.difficulty.icon
    }

    private func pill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6, content: content)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondaryGroupedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - Board

private struct MacBoardView: View {
    @ObservedObject var game: MinesweeperGame
    @ObservedObject var input: MacInputController
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        GeometryReader { proxy in
            let metrics = BoardMetrics.fitted(
                in: proxy.size,
                rows: game.rows,
                cols: game.cols,
                minCell: 10,
                maxCell: 64,
                padding: 12,
                spacing: 2
            )
            let contentSize = metrics.size(rows: game.rows, cols: game.cols)

            MacBoardCanvas(
                cells: game.state.cells,
                rows: game.rows,
                cols: game.cols,
                theme: game.currentTheme,
                isGodMode: game.isGodMode,
                metrics: metrics,
                hoveredIndex: input.hoveredIndex
            )
            .overlay(
                MacBoardMouseLayer(
                    metrics: metrics,
                    rows: game.rows,
                    cols: game.cols,
                    bindings: settings.inputBindings,
                    onAction: { action, index in
                        input.perform(action, at: index)
                    },
                    onHover: { index in
                        input.hoveredIndex = index
                    },
                    onWindow: { window in
                        input.window = window
                    }
                )
            )
            .frame(width: contentSize.width, height: contentSize.height)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Binding hint bar

private struct MacInputHintBar: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 18) {
                ForEach(InputAction.allCases) { action in
                    let names = settings.inputBindings[action].map {
                        $0.displayName(localization: localization)
                    }
                    if !names.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: action.systemImage)
                                .foregroundStyle(.secondary)
                            Text(localization.text(action.localizationKey))
                            Text(names.joined(separator: " / "))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Text(localization.text(.inputHint))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity)
    }
}

enum MacReplayTime {
    static func format(_ seconds: Int) -> String {
        String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }
}
