//
//  BoardView.swift
//  Minesweeper
//
//  Small boards use the SwiftUI CellView grid, which preserves the flip
//  animations and per-cell accessibility.  Large iOS boards (hell: 30x24) use
//  a single Canvas, one gesture overlay and a TimelineView-driven ripple.
//

import SwiftUI
import UIKit

// MARK: - Board façade

struct GameBoardView: View, Equatable {
    let cells: [Cell]
    let rows: Int
    let cols: Int
    let theme: GameTheme
    let isGodMode: Bool
    let isRunningOnMac: Bool
    let inputMode: InputMode
    @Binding var hoveredIndex: Int?
    let onTap: (Int) -> Void
    let onLongPress: (Int) -> Void
    let onRightClick: (Int) -> Void

    static func == (lhs: GameBoardView, rhs: GameBoardView) -> Bool {
        lhs.cells == rhs.cells &&
            lhs.rows == rhs.rows &&
            lhs.cols == rhs.cols &&
            lhs.theme == rhs.theme &&
            lhs.isGodMode == rhs.isGodMode &&
            lhs.isRunningOnMac == rhs.isRunningOnMac &&
            lhs.inputMode == rhs.inputMode
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = BoardMetrics.fitted(
                in: proxy.size,
                rows: rows,
                cols: cols
            )
            Group {
                if useCanvas {
                    ZoomableScrollView {
                        CanvasBoardView(
                            cells: cells,
                            rows: rows,
                            cols: cols,
                            theme: theme,
                            isGodMode: isGodMode,
                            metrics: metrics,
                            hoveredIndex: $hoveredIndex,
                            onTap: onTap,
                            onLongPress: onLongPress,
                            onRightClick: onRightClick
                        )
                    }
                } else {
                    GridBoardView(
                        cells: cells,
                        rows: rows,
                        cols: cols,
                        theme: theme,
                        isGodMode: isGodMode,
                        isRunningOnMac: isRunningOnMac,
                        hoveredIndex: $hoveredIndex,
                        metrics: metrics,
                        onTap: onTap,
                        onLongPress: onLongPress,
                        onRightClick: onRightClick
                    )
                }
            }
        }
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 10)
    }

    private var useCanvas: Bool {
        // VoiceOver/Switch Control need per-cell accessibility elements; the
        // Canvas is a single element, so fall back to the grid for those users.
        let assistiveTechnology = UIAccessibility.isVoiceOverRunning
            || UIAccessibility.isSwitchControlRunning
        guard !assistiveTechnology else { return false }

        // Mac: use the Canvas for every board size.  The overlay already
        // provides hover and secondary-click, so this avoids up to 256
        // per-cell UIHostingControllers.
        if isRunningOnMac { return true }

        // iOS: keep the animated CellView grid for small boards and switch to
        // the Canvas for hell-sized boards.
        return cells.count > 300
    }
}

// MARK: - Small board

struct GridBoardView: View {
    let cells: [Cell]
    let rows: Int
    let cols: Int
    let theme: GameTheme
    let isGodMode: Bool
    let isRunningOnMac: Bool
    @Binding var hoveredIndex: Int?
    let metrics: BoardMetrics
    let onTap: (Int) -> Void
    let onLongPress: (Int) -> Void
    let onRightClick: (Int) -> Void
    @ObservedObject var localization = LocalizationManager.shared

    var body: some View {
        ZoomableScrollView {
            VStack(spacing: metrics.spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: metrics.spacing) {
                        ForEach(0..<cols, id: \.self) { col in
                            let index = row * cols + col
                            if index < cells.count {
                                cellView(index: index)
                            }
                        }
                    }
                }
            }
            .padding(metrics.padding)
            .background(Color.clear)
        }
    }

    @ViewBuilder
    private func cellView(index: Int) -> some View {
        Group {
            if isRunningOnMac {
                MouseAwareCellView(
                    cell: cells[index],
                    isGodMode: isGodMode,
                    theme: theme,
                    size: metrics.cellSize,
                    onLeftClick: { onTap(index) },
                    onRightClick: { onRightClick(index) }
                )
                .frame(width: metrics.cellSize, height: metrics.cellSize)
                .onHover { isHovering in
                    if isHovering {
                        hoveredIndex = index
                    } else if hoveredIndex == index {
                        hoveredIndex = nil
                    }
                }
            } else {
                CellView(
                    cell: cells[index],
                    isGodMode: isGodMode,
                    theme: theme,
                    size: metrics.cellSize
                )
                .equatable()
                .frame(width: metrics.cellSize, height: metrics.cellSize)
                .onTapGesture { onTap(index) }
                .onLongPressGesture(minimumDuration: 0.25) { onLongPress(index) }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(index / cols + 1), \(index % cols + 1)"))
        .accessibilityValue(Text(accessibilityValue(for: cells[index])))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap(index) }
        .accessibilityAction(named: Text(localization.text(.modeFlagging))) {
            onRightClick(index)
        }
    }

    private func accessibilityValue(for cell: Cell) -> String {
        if cell.isRevealed {
            if cell.isMine {
                return localization.text(.accessibilityMine)
            }
            if cell.neighborMines > 0 {
                return String(format: localization.text(.accessibilityNeighbors), cell.neighborMines)
            }
            return localization.text(.accessibilityEmpty)
        }
        return cell.isFlagged
            ? localization.text(.accessibilityFlagged)
            : localization.text(.accessibilityCovered)
    }
}

// MARK: - Large board Canvas

struct CanvasBoardView: View {
    let cells: [Cell]
    let rows: Int
    let cols: Int
    let theme: GameTheme
    let isGodMode: Bool
    let metrics: BoardMetrics
    @Binding var hoveredIndex: Int?
    let onTap: (Int) -> Void
    let onLongPress: (Int) -> Void
    let onRightClick: (Int) -> Void
    @ObservedObject var localization = LocalizationManager.shared
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
        !reduceMotion
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
        .overlay(
            BoardGestureOverlay(
                metrics: metrics,
                rows: rows,
                cols: cols,
                onTap: onTap,
                onLongPress: onLongPress,
                onRightClick: onRightClick,
                onHover: { hoveredIndex = $0 }
            )
        )
        .onAppear {
            previousCells = cells
            animatingCells = Array(repeating: false, count: cells.count)
            cellStartTimes = Array(repeating: nil, count: cells.count)
        }
        .onChange(of: cells) { newCells in
            handleCellsChanged(newCells)
        }
        .onDisappear {
            resetAnimation(count: cells.count)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(String(format: localization.text(.accessibilityBoard), rows, cols))
        )
    }

    private func canvas(date: Date?) -> some View {
        Canvas { context, _ in
            draw(context: &context, date: date)
        }
    }

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

        if reduceMotion {
            resetAnimation(count: newCells.count)
            return
        }

        var newlyRevealed: [Int] = []
        for index in newCells.indices where newCells[index].isRevealed && !old[index].isRevealed {
            newlyRevealed.append(index)
        }
        let hasExplosion = newCells.contains { $0.isExploding }

        // A flag toggle during a ripple must not cancel the ripple.  Only a
        // reveal or explosion starts/replaces the timeline.
        guard !newlyRevealed.isEmpty || hasExplosion else { return }

        if animatingCells.count != newCells.count {
            animatingCells = Array(repeating: false, count: newCells.count)
            cellStartTimes = Array(repeating: nil, count: newCells.count)
        }

        let now = Date()
        for index in newlyRevealed {
            animatingCells[index] = true
            // Do not touch start times of cells from a previous ripple: this
            // is what makes overlapping reveals animate instead of snapping.
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

    private var cellCornerRadius: CGFloat {
        max(1.5, metrics.cellSize * 0.17)
    }

    private func draw(context: inout GraphicsContext, date: Date?) {
        let corner = CGSize(width: cellCornerRadius, height: cellCornerRadius)
        let numberSize = metrics.cellSize * 0.7
        let mineSize = metrics.cellSize * 0.7
        let flagSize = metrics.cellSize * 0.5

        // Resolve each distinct glyph once per frame instead of once per cell.
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
        // Match CellView's flag (orange SF Symbol) instead of the multicolor
        // emoji, so hell boards and the small grid look the same.
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

        // Glyphs are drawn in a second pass so the grouped backgrounds only
        // need one fill per color.
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

// MARK: - Gesture overlay for Canvas

/// Tap recognizer that only accepts secondary-button events.  Filtering on the
/// event's button mask keeps it inert for direct finger touches, while still
/// recognizing right-clicks from mice and trackpads (even when the system
/// delivers them as compatibility touches).
private final class SecondaryClickTapGestureRecognizer: UITapGestureRecognizer {
    override func shouldReceive(_ event: UIEvent) -> Bool {
        event.buttonMask.contains(.secondary)
    }
}

struct BoardGestureOverlay: UIViewRepresentable {
    let metrics: BoardMetrics
    let rows: Int
    let cols: Int
    let onTap: (Int) -> Void
    let onLongPress: (Int) -> Void
    let onRightClick: (Int) -> Void
    let onHover: (Int?) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.3
        longPress.cancelsTouchesInView = false

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        tap.require(toFail: longPress)

        // iOS apps on Apple silicon Macs deliver secondary clicks through this
        // gesture.  A finger touch has no mouse buttons, so checking the button
        // mask on the recognizer alone still lets it win over the deferred
        // single-tap gesture and every touch on a Canvas board (hell on iOS)
        // becomes a flag.  The subclass filters the actual event mask instead.
        let rightClick = SecondaryClickTapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleRightClick(_:))
        )
        rightClick.cancelsTouchesInView = false

        let hover = UIHoverGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleHover(_:))
        )
        hover.cancelsTouchesInView = false

        view.addGestureRecognizer(longPress)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(rightClick)
        view.addGestureRecognizer(hover)

        context.coordinator.update(
            metrics: metrics,
            rows: rows,
            cols: cols,
            onTap: onTap,
            onLongPress: onLongPress,
            onRightClick: onRightClick,
            onHover: onHover
        )
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(
            metrics: metrics,
            rows: rows,
            cols: cols,
            onTap: onTap,
            onLongPress: onLongPress,
            onRightClick: onRightClick,
            onHover: onHover
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        private var metrics = BoardMetrics()
        private var rows = 0
        private var cols = 0
        private var onTap: ((Int) -> Void)?
        private var onLongPress: ((Int) -> Void)?
        private var onRightClick: ((Int) -> Void)?
        private var onHover: ((Int?) -> Void)?

        func update(
            metrics: BoardMetrics,
            rows: Int,
            cols: Int,
            onTap: @escaping (Int) -> Void,
            onLongPress: @escaping (Int) -> Void,
            onRightClick: @escaping (Int) -> Void,
            onHover: @escaping (Int?) -> Void
        ) {
            self.metrics = metrics
            self.rows = rows
            self.cols = cols
            self.onTap = onTap
            self.onLongPress = onLongPress
            self.onRightClick = onRightClick
            self.onHover = onHover
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let index = index(for: gesture) else { return }
            onTap?(index)
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let index = index(for: gesture) else { return }
            onLongPress?(index)
        }

        @objc func handleRightClick(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let index = index(for: gesture) else { return }
            onRightClick?(index)
        }

        @objc func handleHover(_ gesture: UIHoverGestureRecognizer) {
            switch gesture.state {
            case .began, .changed:
                onHover?(index(for: gesture))
            case .ended, .cancelled, .failed:
                onHover?(nil)
            default:
                break
            }
        }

        private func index(for gesture: UIGestureRecognizer) -> Int? {
            guard let view = gesture.view else { return nil }
            let point = gesture.location(in: view)
            return metrics.index(at: point, rows: rows, cols: cols)
        }
    }
}

// MARK: - Mac pointer support

struct MouseAwareCellView: UIViewRepresentable {
    let cell: Cell
    let isGodMode: Bool
    let theme: GameTheme
    let size: CGFloat
    let onLeftClick: () -> Void
    let onRightClick: () -> Void

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear

        let cellView = CellView(cell: cell, isGodMode: isGodMode, theme: theme, size: size)
            .equatable()

        let hostingController = UIHostingController(rootView: cellView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = containerView.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(hostingController.view)

        context.coordinator.hostingController = hostingController
        context.coordinator.onLeftClick = onLeftClick
        context.coordinator.onRightClick = onRightClick

        let leftClickGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLeftClick)
        )
        leftClickGesture.buttonMaskRequired = .primary
        containerView.addGestureRecognizer(leftClickGesture)

        let rightClickGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleRightClick)
        )
        rightClickGesture.buttonMaskRequired = .secondary
        containerView.addGestureRecognizer(rightClickGesture)

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let cellView = CellView(cell: cell, isGodMode: isGodMode, theme: theme, size: size)
            .equatable()

        context.coordinator.hostingController?.rootView = cellView
        context.coordinator.onLeftClick = onLeftClick
        context.coordinator.onRightClick = onRightClick
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        var onLeftClick: (() -> Void)?
        var onRightClick: (() -> Void)?
        var hostingController: UIHostingController<EquatableView<CellView>>?

        @objc func handleLeftClick() {
            onLeftClick?()
        }

        @objc func handleRightClick() {
            onRightClick?()
        }
    }
}
