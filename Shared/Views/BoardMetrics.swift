//
//  BoardMetrics.swift
//  Minesweeper
//
//  Pure geometry shared by the iOS and macOS boards.
//

import CoreGraphics

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
