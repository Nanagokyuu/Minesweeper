//
//  MacBoardCanvas.swift
//  MinesweeperMac
//
//  One Canvas draws the whole board, so a 30x24 hell board does not create 720
//  SwiftUI views.  Ripple/explosion timing comes from the Rust snapshot's
//  per-cell reveal delays, exactly like the iOS Canvas path.
//

import SwiftUI

struct MacBoardCanvas: View {
    let cells: [Cell]
    let rows: Int
    let cols: Int
    let theme: GameTheme
    let isGodMode: Bool
    let metrics: BoardMetrics
    let hoveredIndex: Int?
    /// Replay scrubbing wants instant snapshots, not 30 fps ripples.
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var previousCells: [Cell] = []
    @State private var animatingCells: [Bool] = []
    @State private var cellStartTimes: [Date?] = []
    @State private var isAnimating = false
    @State private var animationTask: Task<Void, Never>?

    /// Matches CellView's reveal spring (response 0.6).
    private static let revealDuration: TimeInterval = 0.6
    /// The spring is visually settled by then; no need to keep the 30 fps
    /// timeline alive for the long, invisible tail.
    private static let revealSettleDuration: TimeInterval = 0.4

    private var contentSize: CGSize {
        metrics.size(rows: rows, cols: cols)
    }

    private var shouldAnimate: Bool {
        animated && !reduceMotion
    }

    private var cellCornerRadius: CGFloat {
        max(1.5, metrics.cellSize * 0.17)
    }

    var body: some View {
        Group {
            if isAnimating {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    canvas(date: timeline.date)
                }
            } else {
                canvas(date: nil)
            }
        }
        .frame(width: contentSize.width, height: contentSize.height)
        .onAppear {
            previousCells = cells
            animatingCells = Array(repeating: false, count: cells.count)
            cellStartTimes = Array(repeating: nil, count: cells.count)
        }
        .onChange(of: cells) { _, newCells in
            handleCellsChanged(newCells)
        }
        .onDisappear {
            resetAnimation(count: cells.count)
        }
    }

    private func canvas(date: Date?) -> some View {
        Canvas { context, _ in
            draw(context: &context, date: date)
        }
    }

    // MARK: - Animation bookkeeping

    private func handleCellsChanged(_ newCells: [Cell]) {
        let old = previousCells
        previousCells = newCells

        guard old.count == newCells.count else {
            resetAnimation(count: newCells.count)
            return
        }

        // A new game or a replay jump can replace the board without changing
        // its cell count.  Cancel the old ripple instead of letting stale
        // animating flags turn newly covered cells into fake revealed faces.
        if newCells.indices.contains(where: { old[$0].isRevealed && !newCells[$0].isRevealed }) {
            resetAnimation(count: newCells.count)
            return
        }

        guard shouldAnimate else {
            resetAnimation(count: newCells.count)
            return
        }

        var newlyRevealed: [Int] = []
        for index in newCells.indices where newCells[index].isRevealed && !old[index].isRevealed {
            newlyRevealed.append(index)
        }
        let hasExplosion = newCells.contains { $0.isExploding }

        guard !newlyRevealed.isEmpty || hasExplosion else { return }

        if animatingCells.count != newCells.count {
            animatingCells = Array(repeating: false, count: newCells.count)
            cellStartTimes = Array(repeating: nil, count: newCells.count)
        }

        let now = Date()
        for index in newlyRevealed {
            animatingCells[index] = true
            cellStartTimes[index] = now
        }

        var end = now
        for index in newCells.indices where animatingCells[index] {
            guard let start = cellStartTimes[index] else { continue }
            let finish = start.addingTimeInterval(
                newCells[index].animationDelay + Self.revealSettleDuration + 0.05
            )
            if finish > end { end = finish }
        }
        if hasExplosion {
            end = max(end, now.addingTimeInterval(0.35))
        }

        let duration = max(0.05, end.timeIntervalSince(now))
        animationTask?.cancel()
        isAnimating = true
        animationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            isAnimating = false
            animatingCells = Array(repeating: false, count: newCells.count)
            cellStartTimes = Array(repeating: nil, count: newCells.count)
        }
    }

    private func resetAnimation(count: Int) {
        animationTask?.cancel()
        isAnimating = false
        animatingCells = Array(repeating: false, count: count)
        cellStartTimes = Array(repeating: nil, count: count)
    }

    private struct RevealAnimation {
        /// 0 = covered face, 0.5 = edge-on, 1 = fully revealed face.
        let flip: Double
        /// Number glyph pop-in, which CellView animates separately.
        let glyph: Double
    }

    private func isAnimatingCell(_ index: Int) -> Bool {
        isAnimating
            && index >= 0
            && index < animatingCells.count
            && animatingCells[index]
    }

    private func revealAnimation(index: Int, cell: Cell, date: Date?) -> RevealAnimation {
        guard cell.isRevealed,
              let date,
              isAnimatingCell(index),
              index < cellStartTimes.count,
              let start = cellStartTimes[index] else {
            return RevealAnimation(flip: 1, glyph: 1)
        }

        let elapsed = max(0, date.timeIntervalSince(start) - cell.animationDelay)

        // Same normalized motion as CellView's
        // .spring(response: 0.6, dampingFraction: 0.75).
        let zeta = 0.75
        let omega = 2 * Double.pi / Self.revealDuration
        let dampedOmega = omega * (1 - zeta * zeta).squareRoot()
        let envelope = exp(-zeta * omega * elapsed)
        let rawFlip = 1 - envelope * (
            cos(dampedOmega * elapsed)
                + (zeta * omega / dampedOmega) * sin(dampedOmega * elapsed)
        )
        let flip = min(1, max(0, rawFlip))

        // CellView runs the number's 0.3 s ease-out scale/fade in parallel
        // with the flip.
        let glyphT = min(1, elapsed / 0.3)
        let glyphRemaining = 1 - glyphT
        let glyph = 1 - glyphRemaining * glyphRemaining

        return RevealAnimation(flip: flip, glyph: glyph)
    }

    // MARK: - Drawing

    private func draw(context: inout GraphicsContext, date: Date?) {
        let corner = CGSize(width: cellCornerRadius, height: cellCornerRadius)
        let numberSize = metrics.cellSize * 0.7
        let mineSize = metrics.cellSize * 0.7
        let flagSize = metrics.cellSize * 0.5

        var numberTexts = [GraphicsContext.ResolvedText?](repeating: nil, count: 8)
        for number in 1...8 {
            numberTexts[number - 1] = context.resolve(
                Text("\(number)")
                    .font(.system(size: numberSize, weight: .heavy, design: .rounded))
                    .foregroundColor(Self.numberColor(number))
            )
        }
        let mineText = context.resolve(
            Text(theme.explosionIcon).font(.system(size: mineSize))
        )
        // Match the shared CellView style (orange SF Symbol) instead of the
        // multicolor emoji.
        let flagText = context.resolve(
            Text(Image(systemName: theme.flagIcon))
                .font(.system(size: flagSize))
                .foregroundColor(.orange)
        )

        var coveredPath = Path()
        var coveredMinePath = Path()
        var revealedPath = Path()
        var triggeredPath = Path()
        var explodingPath = Path()

        // Static cells stay batched.  Cells that are mid-flip are drawn one by
        // one with a horizontal squash, mirroring CellView's 3D flip.
        for row in 0..<rows {
            for col in 0..<cols {
                let index = row * cols + col
                guard index < cells.count else { continue }
                let cell = cells[index]
                let rect = metrics.rect(row: row, col: col)
                let animating = shouldAnimate && isAnimatingCell(index)

                if !animating {
                    if cell.isRevealed {
                        if cell.isMine && cell.isTriggeredMine {
                            triggeredPath.addRoundedRect(in: rect, cornerSize: corner)
                        } else {
                            revealedPath.addRoundedRect(in: rect, cornerSize: corner)
                        }
                    } else if isGodMode && cell.isMine {
                        coveredMinePath.addRoundedRect(in: rect, cornerSize: corner)
                    } else {
                        coveredPath.addRoundedRect(in: rect, cornerSize: corner)
                    }
                }

                if cell.isExploding {
                    explodingPath.addRoundedRect(in: rect, cornerSize: corner)
                }
            }
        }

        if !revealedPath.isEmpty {
            context.fill(revealedPath, with: .color(Color.cellRevealed))
        }
        if !triggeredPath.isEmpty {
            context.fill(triggeredPath, with: .color(.red))
        }
        if !coveredPath.isEmpty {
            context.fill(coveredPath, with: .color(theme.coveredColor))
        }
        if !coveredMinePath.isEmpty {
            context.fill(coveredMinePath, with: .color(.orange))
        }

        // Per-cell flip for cells revealed by the current ripple.
        if isAnimating {
            for row in 0..<rows {
                for col in 0..<cols {
                    let index = row * cols + col
                    guard index < cells.count, isAnimatingCell(index) else { continue }
                    let cell = cells[index]
                    drawAnimatingCell(
                        cell,
                        rect: metrics.rect(row: row, col: col),
                        animation: revealAnimation(index: index, cell: cell, date: date),
                        context: context,
                        numberTexts: numberTexts,
                        mineText: mineText,
                        flagText: flagText
                    )
                }
            }
        }

        for row in 0..<rows {
            for col in 0..<cols {
                let index = row * cols + col
                guard index < cells.count else { continue }
                guard !(shouldAnimate && isAnimatingCell(index)) else { continue }
                let cell = cells[index]
                let rect = metrics.rect(row: row, col: col)
                let center = CGPoint(x: rect.midX, y: rect.midY)

                if cell.isRevealed {
                    if cell.isMine {
                        context.draw(mineText, at: center, anchor: .center)
                    } else if cell.neighborMines > 0 {
                        if let text = numberTexts[cell.neighborMines - 1] {
                            context.draw(text, at: center, anchor: .center)
                        }
                    }
                } else if cell.isFlagged {
                    context.draw(flagText, at: center, anchor: .center)
                }
            }
        }

        if !explodingPath.isEmpty {
            context.fill(
                explodingPath,
                with: .color(theme.explodedColor.opacity(0.65))
            )
        }

        // Mouse hover ring.  Only redraws one cell, and only while the pointer
        // is over the board.
        if let hoveredIndex,
           hoveredIndex >= 0,
           hoveredIndex < cells.count,
           hoveredIndex < rows * cols {
            let row = hoveredIndex / cols
            let col = hoveredIndex % cols
            let rect = metrics.rect(row: row, col: col).insetBy(dx: 1, dy: 1)
            context.stroke(
                Path(roundedRect: rect, cornerRadius: cellCornerRadius),
                with: .color(.white.opacity(0.7)),
                lineWidth: 2
            )
            context.stroke(
                Path(roundedRect: rect, cornerRadius: cellCornerRadius),
                with: .color(.black.opacity(0.18)),
                lineWidth: 1
            )
        }
    }

    private func drawAnimatingCell(
        _ cell: Cell,
        rect: CGRect,
        animation: RevealAnimation,
        context: GraphicsContext,
        numberTexts: [GraphicsContext.ResolvedText?],
        mineText: GraphicsContext.ResolvedText,
        flagText: GraphicsContext.ResolvedText
    ) {
        let flip = min(1, max(0, animation.flip))
        let glyph = min(1, max(0, animation.glyph))
        let scaleX = max(0.001, abs(flip * 2 - 1))

        // CellView keeps both faces alive and puts the revealed face on top
        // while the covered face fades out, so composite them the same way.
        drawCoveredFace(
            cell,
            rect: rect,
            scaleX: scaleX,
            opacity: 1 - flip,
            context: context,
            flagText: flagText
        )
        drawRevealedFace(
            cell,
            rect: rect,
            scaleX: scaleX,
            opacity: flip,
            glyph: glyph,
            context: context,
            numberTexts: numberTexts,
            mineText: mineText
        )
    }

    private func scaledContext(
        _ context: GraphicsContext,
        rect: CGRect,
        scaleX: CGFloat
    ) -> GraphicsContext {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var scaled = context
        scaled.translateBy(x: center.x, y: center.y)
        scaled.scaleBy(x: scaleX, y: 1)
        scaled.translateBy(x: -center.x, y: -center.y)
        return scaled
    }

    private func drawCoveredFace(
        _ cell: Cell,
        rect: CGRect,
        scaleX: CGFloat,
        opacity: Double,
        context: GraphicsContext,
        flagText: GraphicsContext.ResolvedText
    ) {
        guard opacity > 0.001 else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let background = Path(roundedRect: rect, cornerRadius: cellCornerRadius)
        var face = scaledContext(context, rect: rect, scaleX: scaleX)
        face.opacity = opacity
        let color = (isGodMode && cell.isMine) ? Color.orange : theme.coveredColor
        face.fill(background, with: .color(color))
        if cell.isFlagged {
            face.draw(flagText, at: center, anchor: .center)
        }
    }

    private func drawRevealedFace(
        _ cell: Cell,
        rect: CGRect,
        scaleX: CGFloat,
        opacity: Double,
        glyph: Double,
        context: GraphicsContext,
        numberTexts: [GraphicsContext.ResolvedText?],
        mineText: GraphicsContext.ResolvedText
    ) {
        guard opacity > 0.001 else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let background = Path(roundedRect: rect, cornerRadius: cellCornerRadius)
        var face = scaledContext(context, rect: rect, scaleX: scaleX)
        face.opacity = opacity
        if cell.isMine && cell.isTriggeredMine {
            face.fill(background, with: .color(.red))
        } else {
            face.fill(background, with: .color(Color.cellRevealed))
        }

        if cell.isMine {
            var glyphContext = face
            let mineScale = 0.1 + 0.9 * opacity
            glyphContext.translateBy(x: center.x, y: center.y)
            glyphContext.scaleBy(x: mineScale, y: mineScale)
            glyphContext.translateBy(x: -center.x, y: -center.y)
            glyphContext.draw(mineText, at: center, anchor: .center)
        } else if cell.neighborMines > 0,
                  let text = numberTexts[cell.neighborMines - 1] {
            var glyphContext = face
            glyphContext.opacity = opacity * glyph
            let numberScale = 0.5 + 0.5 * glyph
            glyphContext.translateBy(x: center.x, y: center.y)
            glyphContext.scaleBy(x: numberScale, y: numberScale)
            glyphContext.translateBy(x: -center.x, y: -center.y)
            glyphContext.draw(text, at: center, anchor: .center)
        }
    }

    private static let numberPalette: [Color] = [
        .blue, .green, .red, .purple, .orange, .cyan, .primary, .secondary,
    ]

    private static func numberColor(_ number: Int) -> Color {
        numberPalette[(number - 1) % numberPalette.count]
    }
}
