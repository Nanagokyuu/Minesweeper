//
//  CellView.swift
//  Minesweeper
//
//  Rendering only.  Game state comes from Rust snapshots; the per-cell delay
//  is used purely for the ripple/explosion animation.
//

import SwiftUI

struct CellView: View, Equatable {
    let cell: Cell
    let isGodMode: Bool
    let theme: GameTheme
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(cell: Cell, isGodMode: Bool, theme: GameTheme, size: CGFloat = 35) {
        self.cell = cell
        self.isGodMode = isGodMode
        self.theme = theme
        self.size = size
    }

    static func == (lhs: CellView, rhs: CellView) -> Bool {
        lhs.cell == rhs.cell &&
            lhs.isGodMode == rhs.isGodMode &&
            lhs.theme == rhs.theme &&
            lhs.size == rhs.size
    }

    var body: some View {
        ZStack {
            // Back: covered cell
            Group {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isGodMode && cell.isMine ? Color.orange : theme.coveredColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(0.3), Color.clear]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                if cell.isFlagged {
                    Image(systemName: theme.flagIcon)
                        .foregroundColor(.orange)
                        .font(.system(size: size * 0.5))
                        .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                }
            }
            .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            .opacity(cell.isRevealed ? 0 : 1)
            .zIndex(cell.isRevealed ? 0 : 1)

            // Front: revealed cell
            Group {
                RoundedRectangle(cornerRadius: 6)
                    .foregroundColor(cell.isMine && cell.isTriggeredMine ? .red : Color.cellRevealed)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.explodedColor)
                            .opacity(cell.isExploding ? 0.8 : 0.0)
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 0.15).repeatCount(2, autoreverses: true),
                                value: cell.isExploding
                            )
                    )

                if cell.isMine {
                    Text(theme.explosionIcon)
                        .font(.system(size: size * 0.7))
                        .scaleEffect(cell.isExploding ? 1.5 : (cell.isRevealed ? 1.0 : 0.1))
                        .rotationEffect(.degrees(reduceMotion ? 0 : (cell.isExploding ? 360 : 0)))
                        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: cell.isRevealed)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: cell.isExploding)
                        .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                } else if cell.neighborMines > 0 {
                    Text("\(cell.neighborMines)")
                        .font(.system(size: size * 0.7, weight: .heavy, design: .rounded))
                        .foregroundColor(numberColor(cell.neighborMines))
                        .opacity(cell.isRevealed ? 1.0 : 0.0)
                        .scaleEffect(cell.isRevealed ? 1.0 : 0.5)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(cell.animationDelay), value: cell.isRevealed)
                        .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                }
            }
            .opacity(cell.isRevealed ? 1 : 0)
            .zIndex(cell.isRevealed ? 1 : 0)

            // Only the mine the player actually clicked gets the extra
            // particle overlay.  On hell boards there can be 200 exploding
            // cells at once; the flash/scale animation is enough for the rest.
            if cell.isExploding && cell.isTriggeredMine && !reduceMotion {
                ExplosionParticles(color: theme.explodedColor)
            }
        }
        .frame(width: size, height: size)
        .rotation3DEffect(
            .degrees(reduceMotion ? 0 : (cell.isRevealed ? 180 : 0)),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .scaleEffect(cell.isExploding ? 1.15 : (cell.isRevealed ? 1.0 : 0.95))
        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.75).delay(cell.animationDelay), value: cell.isRevealed)
        .animation(reduceMotion ? nil : .spring(response: 0.15, dampingFraction: 0.3), value: cell.isExploding)
    }

    private static let numberPalette: [Color] = [
        // 7/8 use semantic colors so they remain readable in dark mode.
        .blue, .green, .red, .purple, .orange, .cyan, .primary, .secondary,
    ]

    func numberColor(_ num: Int) -> Color {
        Self.numberPalette[(num - 1) % Self.numberPalette.count]
    }
}

// MARK: - Explosion particles
struct ExplosionParticles: View {
    let color: Color
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            ForEach(0..<4) { i in
                Circle()
                    .fill(Color.orange)
                    .frame(width: 4, height: 4)
                    .offset(
                        x: isAnimating ? cos(Double(i) * .pi / 2) * 15 : 0,
                        y: isAnimating ? sin(Double(i) * .pi / 2) * 15 : 0
                    )
                    .opacity(isAnimating ? 0 : 1)
            }

            ForEach(0..<4) { i in
                Circle()
                    .fill(color)
                    .frame(width: 3, height: 3)
                    .offset(
                        x: isAnimating ? cos(Double(i) * .pi / 2 + .pi / 4) * 12 : 0,
                        y: isAnimating ? sin(Double(i) * .pi / 2 + .pi / 4) * 12 : 0
                    )
                    .opacity(isAnimating ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                isAnimating = true
            }
        }
    }
}
