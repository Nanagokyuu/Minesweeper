//
//  GameViews.swift (多语言版本 + Mac 鼠标支持)
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/22.
//  Enhanced for Mac (iPad version) by Claude on 2026/01/16
//

import SwiftUI

struct GameView: View {
    @ObservedObject var localization = LocalizationManager.shared
    @StateObject var game: MinesweeperGame
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var inputMode: InputMode = .dig
    @State private var showCopyToast = false
    @State private var hoveredIndex: Int? = nil

    // 检测是否在 Mac 上运行（iPad 版本）
    private var isRunningOnMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return ProcessInfo.processInfo.isiOSAppOnMac
        #endif
    }

    init(
        difficulty: Difficulty,
        seed: Int? = nil,
        theme: GameTheme? = nil,
        isGodMode: Bool = false,
        isNanagokyuuMode: Bool = false
    ) {
        _game = StateObject(
            wrappedValue: MinesweeperGame(
                difficulty: difficulty,
                theme: theme ?? .classic,
                seed: seed,
                isGodMode: isGodMode,
                isNanagokyuuMode: isNanagokyuuMode
            )
        )
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 12) {
                // Header observes the clock separately; a timer tick only
                // re-renders this small view, never the board.
                GameHeaderView(game: game, clock: game.clock)

                seedDisplayView

                GameBoardView(
                    cells: game.state.cells,
                    rows: game.rows,
                    cols: game.cols,
                    theme: game.currentTheme,
                    isGodMode: game.isGodMode,
                    isRunningOnMac: isRunningOnMac,
                    inputMode: inputMode,
                    hoveredIndex: $hoveredIndex,
                    onTap: { handleSmartTap(at: $0) },
                    onLongPress: { handleSmartLongPress(at: $0) },
                    onRightClick: { game.toggleFlag(at: $0) }
                )
                .equatable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isRunningOnMac {
                    macFooterView
                } else {
                    footerView
                }
            }
            // Keep the game column readable on iPhone Duo's 7.6-inch inner
            // display and on iPad instead of stretching controls edge to edge.
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showCopyToast {
                VStack {
                    Spacer()
                    Text(localization.text(.seedCopied))
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                        .padding(.bottom, 100)
                }
                .transition(.opacity)
                .zIndex(100)
            }

            // A cheap dim layer replaces the old full-board blur.  Blurring a
            // 720-cell SwiftUI tree on every result is expensive on older
            // devices; the popup itself already uses a material background.
            if game.showResult {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(50)

                ResultPopup(
                    isWin: game.gameStatus == .won,
                    timeElapsed: game.timeElapsed,
                    onRetry: { game.startNewGame() },
                    onReview: { withAnimation { game.showResult = false } },
                    onExit: { presentationMode.wrappedValue.dismiss() }
                )
                .zIndex(60)
            }

            if isRunningOnMac && !game.showResult {
                Group {
                    Button(action: { handleKeyZ() }) { Text("Z").opacity(0) }
                        .keyboardShortcut("z", modifiers: [])

                    Button(action: { handleKeyX() }) { Text("X").opacity(0) }
                        .keyboardShortcut("x", modifiers: [])

                    Button(action: {
                        if game.gameStatus != .exploding {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) { Text("ESC").opacity(0) }
                        .keyboardShortcut(.escape, modifiers: [])
                }
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            }
        }
        .navigationBarHidden(true)
        .onChange(of: scenePhase) { phase in
            game.handleScenePhase(phase)
        }
        .onDisappear {
            game.stop()
        }
    }

    // MARK: - Seed

    private var seedDisplayView: some View {
        Button(action: {
            UIPasteboard.general.string = String(game.currentSeed)
            HapticManager.shared.light()
            withAnimation { showCopyToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showCopyToast = false }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "number.square")
                    .font(.caption)
                Text("\(localization.text(.seed)): \(game.currentSeed)")
                    .font(.caption).monospacedDigit()
                Image(systemName: "doc.on.doc")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
        }
    }

    // MARK: - Footers

    private var footerView: some View {
        VStack {
            HStack(spacing: 20) {
                ModeButton(
                    title: localization.text(.modeDigging),
                    icon: "hammer.fill",
                    isSelected: inputMode == .dig,
                    color: .blue
                ) {
                    inputMode = .dig
                    HapticManager.shared.light()
                }

                ModeButton(
                    title: localization.text(.modeFlagging),
                    icon: "flag.fill",
                    isSelected: inputMode == .flag,
                    color: .orange
                ) {
                    inputMode = .flag
                    HapticManager.shared.light()
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 10)
            .disabled(game.gameStatus != .playing)
            .opacity(game.gameStatus == .playing ? 1 : 0.6)

            Button(localization.text(.exitGame)) {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.gray).font(.caption).padding(.bottom, 5)
            .disabled(game.gameStatus == .exploding)
        }
    }

    private var macFooterView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .foregroundColor(.blue)
                    Text(localization.text(.keyZDig))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .foregroundColor(.orange)
                    Text(localization.text(.keyXFlag))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(12)

            Button(localization.text(.exitGame)) {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.gray).font(.caption).padding(.bottom, 5)
            .disabled(game.gameStatus == .exploding)
        }
    }

    // MARK: - Interaction

    private func handleKeyZ() {
        guard let index = hoveredIndex, game.gameStatus == .playing else { return }
        handleSmartTap(at: index)
    }

    private func handleKeyX() {
        guard let index = hoveredIndex, game.gameStatus == .playing else { return }
        let cell = game.grid[index]
        if !cell.isRevealed {
            game.toggleFlag(at: index)
        }
    }

    private func handleSmartTap(at index: Int) {
        guard index >= 0, index < game.grid.count else { return }
        let cell = game.grid[index]
        if cell.isRevealed {
            game.quickReveal(at: index)
        } else if isRunningOnMac {
            if cell.isFlagged {
                HapticManager.shared.light()
            } else {
                withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.3, dampingFraction: 0.6)) {
                    game.revealCell(at: index)
                }
            }
        } else {
            switch inputMode {
            case .dig:
                if cell.isFlagged {
                    HapticManager.shared.light()
                } else {
                    withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.3, dampingFraction: 0.6)) {
                        game.revealCell(at: index)
                    }
                }
            case .flag:
                game.toggleFlag(at: index)
            }
        }
    }

    private func handleSmartLongPress(at index: Int) {
        guard index >= 0, index < game.grid.count else { return }
        let cell = game.grid[index]
        guard !cell.isRevealed else { return }
        if inputMode == .dig {
            game.toggleFlag(at: index)
        }
    }
}
