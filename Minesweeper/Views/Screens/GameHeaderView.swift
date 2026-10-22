//
//  GameHeaderView.swift
//  Minesweeper
//
//  Header observes the clock separately from the board, so the once-per-second
//  timer tick never rebuilds the 720-cell board.
//

import SwiftUI

struct GameHeaderView: View {
    @ObservedObject var game: MinesweeperGame
    @ObservedObject var clock: GameClock

    var body: some View {
        HStack {
            // Remaining mines
            HStack(spacing: 4) {
                if UIImage(systemName: game.currentTheme.mineIcon) != nil {
                    Image(systemName: game.currentTheme.mineIcon)
                        .foregroundColor(game.gameStatus == .lost ? .gray : game.currentTheme.explodedColor)
                } else {
                    Text(game.currentTheme.mineIcon)
                }

                Text("\(game.remainingMines)")
                    .foregroundColor(.primary)
                    .monospacedDigit()
                    .fontWeight(.bold)
                    .frame(minWidth: 25, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2)

            Spacer()

            // Reset / new game
            Button(action: {
                withAnimation { game.startNewGame() }
                HapticManager.shared.light()
            }) {
                ZStack {
                    VStack(spacing: 0) {
                        if game.isNanagokyuuMode {
                            Text("🤡").font(.headline)
                        } else if game.isGodMode {
                            Text("👁️").font(.headline)
                        } else {
                            Text(game.difficulty.icon).font(.headline)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.05), radius: 2)
                }
            }
            .onLongPressGesture {
                withAnimation { game.startNewGame() }
                HapticManager.shared.heavy()
            }

            Spacer()

            // Clock
            HStack(spacing: 4) {
                Image(systemName: "clock.fill").foregroundColor(.blue)
                Text(Self.formatTime(clock.elapsed))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                    .fontWeight(.bold)
                    .frame(minWidth: 45, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    static func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
