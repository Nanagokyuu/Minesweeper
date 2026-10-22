import XCTest
@testable import Minesweeper

final class BoardMetricsTests: XCTestCase {
    func testFittedBoardFitsDuoCoverHell() {
        let available = CGSize(width: 446, height: 393)
        let metrics = BoardMetrics.fitted(in: available, rows: 30, cols: 24)
        let content = metrics.size(rows: 30, cols: 24)

        XCTAssertGreaterThanOrEqual(metrics.cellSize, 8)
        XCTAssertLessThanOrEqual(content.width, available.width + 0.5)
        XCTAssertLessThanOrEqual(content.height, available.height + 0.5)
    }

    func testFittedBoardFitsDuoInnerHell() {
        let available = CGSize(width: 649, height: 650)
        let metrics = BoardMetrics.fitted(in: available, rows: 30, cols: 24)
        let content = metrics.size(rows: 30, cols: 24)

        XCTAssertLessThanOrEqual(content.width, available.width + 0.5)
        XCTAssertLessThanOrEqual(content.height, available.height + 0.5)
    }

    func testFittedBoardFitsPhoneHardWithoutHorizontalScroll() {
        let available = CGSize(width: 382, height: 650)
        let metrics = BoardMetrics.fitted(in: available, rows: 16, cols: 16)
        let content = metrics.size(rows: 16, cols: 16)

        XCTAssertLessThanOrEqual(content.width, available.width + 0.5)
        XCTAssertLessThanOrEqual(content.height, available.height + 0.5)
    }

    func testIndexRoundTripForEveryCell() {
        let metrics = BoardMetrics(cellSize: 24, spacing: 2, padding: 16)
        let rows = 9
        let cols = 9

        for row in 0..<rows {
            for col in 0..<cols {
                let rect = metrics.rect(row: row, col: col)
                let point = CGPoint(x: rect.midX, y: rect.midY)
                XCTAssertEqual(
                    metrics.index(at: point, rows: rows, cols: cols),
                    row * cols + col
                )
            }
        }
    }
}
