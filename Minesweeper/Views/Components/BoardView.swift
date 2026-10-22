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

// MARK: - Board geometry

struct BoardMetrics: Equatable {
    var cellSize: CGFloat = 35
    var spacing: CGFloat = 2
    var padding: CGFloat = 20

    func size(rows: Int, cols: Int) -> CGSize {
        CGSize(
            width: padding * 2 + CGFloat(cols) * cellSize + CGFloat(max(0, cols - 1)) * spacing,
            height: padding * 2 + CGFloat(rows) * cellSize + CGFloat(max(0, rows - 1)) * spacing
        )
    }

    func rect(row: Int, col: Int) -> CGRect {
        CGRect(
            x: padding + CGFloat(col) * (cellSize + spacing),
            y: padding + CGFloat(row) * (cellSize + spacing),
            width: cellSize,
            height: cellSize
        )
    }

    func index(at point: CGPoint, rows: Int, cols: Int) -> Int? {
        let x = point.x - padding
        let y = point.y - padding
        guard x >= 0, y >= 0 else { return nil }
        let stride = cellSize + spacing
        let col = Int(x / stride)
        let row = Int(y / stride)
        guard row >= 0, row < rows, col >= 0, col < cols else { return nil }
        let localX = x - CGFloat(col) * stride
        let localY = y - CGFloat(row) * stride
        guard localX <= cellSize, localY <= cellSize else { return nil }
        return row * cols + col
    }

    /// Fits a board into the available space.  Used by both the SwiftUI grid
    /// and the Canvas so an iPhone Duo (466x678 folded, 669x951 unfolded) and a
    /// regular iPhone all show the complete board without manual panning.
    static func fitted(
        in available: CGSize,
        rows: Int,
        cols: Int,
        minCell: CGFloat = 8,
        maxCell: CGFloat = 56,
        padding: CGFloat = 16,
        spacing: CGFloat = 2
    ) -> BoardMetrics {
        guard rows > 0, cols > 0 else { return BoardMetrics() }
        let horizontalChrome = padding * 2 + CGFloat(max(0, cols - 1)) * spacing
        let verticalChrome = padding * 2 + CGFloat(max(0, rows - 1)) * spacing
        let widthLimited = (available.width - horizontalChrome) / CGFloat(cols)
        let heightLimited = (available.height - verticalChrome) / CGFloat(rows)
        let ideal = min(widthLimited, heightLimited)
        let cellSize = min(maxCell, max(minCell, ideal.rounded(.down)))
        return BoardMetrics(cellSize: cellSize, spacing: spacing, padding: padding)
    }
}

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

    private var contentSize: CGSize {
        metrics.size(rows: rows, cols: cols)
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
            animationTask?.cancel()
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
            animationTask?.cancel()
            isAnimating = false
            animatingCells = Array(repeating: false, count: newCells.count)
            cellStartTimes = Array(repeating: nil, count: newCells.count)
            return
        }

        if reduceMotion {
            animationTask?.cancel()
            isAnimating = false
            animatingCells = Array(repeating: false, count: newCells.count)
            cellStartTimes = Array(repeating: nil, count: newCells.count)
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
            let finish = start.addingTimeInterval(newCells[index].animationDelay + 0.30)
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

    private func revealProgress(index: Int, cell: Cell, date: Date?) -> Double {
        guard cell.isRevealed else { return 0 }
        guard let date, isAnimating,
              index < animatingCells.count, animatingCells[index],
              index < cellStartTimes.count, let start = cellStartTimes[index] else {
            return 1
        }
        let elapsed = date.timeIntervalSince(start) - cell.animationDelay
        return min(1, max(0, elapsed / 0.26))
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
        let flagText = context.resolve(
            Text("🚩").font(.system(size: flagSize))
        )

        var coveredPath = Path()
        var coveredMinePath = Path()
        var revealedPath = Path()
        var triggeredPath = Path()
        var explodingPath = Path()
        var fading: [(rect: CGRect, alpha: Double, flagged: Bool, isMine: Bool)] = []

        for row in 0..<rows {
            for col in 0..<cols {
                let index = row * cols + col
                guard index < cells.count else { continue }
                let cell = cells[index]
                let rect = metrics.rect(row: row, col: col)
                let progress = reduceMotion ? 1 : revealProgress(index: index, cell: cell, date: date)

                if cell.isRevealed {
                    if cell.isMine && cell.isTriggeredMine {
                        triggeredPath.addRoundedRect(in: rect, cornerSize: corner)
                    } else {
                        revealedPath.addRoundedRect(in: rect, cornerSize: corner)
                    }
                    if progress < 1 {
                        fading.append((rect, 1 - progress, cell.isFlagged, cell.isMine))
                    }
                } else if isGodMode && cell.isMine {
                    coveredMinePath.addRoundedRect(in: rect, cornerSize: corner)
                } else {
                    coveredPath.addRoundedRect(in: rect, cornerSize: corner)
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

        // Only animating cells need an individual alpha-blended cover.
        for overlay in fading {
            let color = overlay.isMine ? Color.orange : theme.coveredColor
            var faded = context
            faded.fill(
                Path(roundedRect: overlay.rect, cornerRadius: cellCornerRadius),
                with: .color(color.opacity(overlay.alpha))
            )
            if overlay.flagged {
                faded.opacity = overlay.alpha
                faded.draw(
                    flagText,
                    at: CGPoint(x: overlay.rect.midX, y: overlay.rect.midY),
                    anchor: .center
                )
            }
        }

        // Glyphs are drawn in a second pass so the grouped backgrounds only
        // need one fill per color.
        for row in 0..<rows {
            for col in 0..<cols {
                let index = row * cols + col
                guard index < cells.count else { continue }
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

    private static let numberPalette: [Color] = [
        .blue, .green, .red, .purple, .orange, .cyan, .primary, .secondary,
    ]

    private static func numberColor(_ number: Int) -> Color {
        numberPalette[(number - 1) % numberPalette.count]
    }
}

// MARK: - Gesture overlay for Canvas

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
        // gesture; on iOS it is inert.
        let rightClick = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleRightClick(_:))
        )
        rightClick.buttonMaskRequired = .secondary
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
