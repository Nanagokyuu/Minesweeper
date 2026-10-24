//
//  MacBoardMouseLayer.swift
//  MinesweeperMac
//
//  Transparent AppKit overlay used for precise mouse handling: hover tracking,
//  left/right/middle/side buttons, double-click chording and the pointing-hand
//  cursor.  SwiftUI keeps drawing the board underneath.
//

import AppKit
import SwiftUI

struct MacBoardMouseLayer: NSViewRepresentable {
    let metrics: BoardMetrics
    let rows: Int
    let cols: Int
    let bindings: InputBindings
    let onAction: (InputAction, Int?) -> Void
    let onHover: (Int?) -> Void
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> BoardMouseView {
        let view = BoardMouseView()
        configure(view)
        return view
    }

    func updateNSView(_ view: BoardMouseView, context: Context) {
        configure(view)
    }

    private func configure(_ view: BoardMouseView) {
        view.metrics = metrics
        view.rows = rows
        view.cols = cols
        view.bindings = bindings
        view.onAction = onAction
        view.onHover = onHover
        view.onWindow = onWindow
    }
}

final class BoardMouseView: NSView {
    var metrics = BoardMetrics()
    var rows = 0
    var cols = 0
    var bindings = InputBindings.default
    var onAction: ((InputAction, Int?) -> Void)?
    var onHover: ((Int?) -> Void)?
    var onWindow: ((NSWindow?) -> Void)?

    private var trackingArea: NSTrackingArea?
    private var lastHovered: Int?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindow?(window)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [
                .mouseMoved,
                .mouseEnteredAndExited,
                .activeInKeyWindow,
                .inVisibleRect,
            ],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    // MARK: - Hover

    override func mouseMoved(with event: NSEvent) {
        updateHover(event)
    }

    override func mouseEntered(with event: NSEvent) {
        updateHover(event)
    }

    override func mouseExited(with event: NSEvent) {
        setHovered(nil)
    }

    private func updateHover(_ event: NSEvent) {
        let index = index(for: event)
        setHovered(index)
    }

    private func setHovered(_ index: Int?) {
        guard index != lastHovered else { return }
        lastHovered = index
        onHover?(index)
    }

    // MARK: - Clicks

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let index = index(for: event)
        setHovered(index)

        // Double-click chords, matching the common Minesweeper convention.
        if event.clickCount >= 2 {
            onAction?(.chord, index)
            return
        }
        if let action = bindings.actionForMouse(button: 0) {
            onAction?(action, index)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let index = index(for: event)
        setHovered(index)
        if let action = bindings.actionForMouse(button: 1) {
            onAction?(action, index)
        }
    }

    override func otherMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let index = index(for: event)
        setHovered(index)
        if let action = bindings.actionForMouse(button: event.buttonNumber) {
            onAction?(action, index)
        }
    }

    private func index(for event: NSEvent) -> Int? {
        let point = convert(event.locationInWindow, from: nil)
        return metrics.index(at: point, rows: rows, cols: cols)
    }
}
