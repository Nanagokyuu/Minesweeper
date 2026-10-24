//
//  MacInputController.swift
//  MinesweeperMac
//
//  Routes mouse and keyboard events through the user's bindings.  The board
//  overlay and the window key monitor share this controller, so left-click and
//  Z always perform the same action, as do right-click and X.
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class MacInputController: ObservableObject {
    let game: MinesweeperGame
    @Published var hoveredIndex: Int?
    weak var window: NSWindow?

    init(game: MinesweeperGame) {
        self.game = game
    }

    var bindings: InputBindings {
        AppSettings.shared.inputBindings
    }

    func actionForMouse(button: Int) -> InputAction? {
        bindings.actionForMouse(button: button)
    }

    // MARK: - Keyboard

    func handleKey(_ event: NSEvent) -> Bool {
        guard !event.isARepeat else { return false }
        guard event.window?.isSheet != true else { return false }
        if let window, event.window !== window { return false }
        if let responder = window?.firstResponder, responder is NSTextView { return false }

        let modifiers = event.modifierFlags.rawValue & InputModifiers.relevant
        guard let action = bindings.actionForKey(
            keyCode: event.keyCode,
            modifiers: modifiers
        ) else {
            return false
        }

        perform(action, at: hoveredIndex)
        return true
    }

    // MARK: - Actions

    func perform(_ action: InputAction, at index: Int?) {
        // Restart must keep working after a win or a loss, which is exactly
        // when the player is most likely to press R.
        if action == .newGame {
            game.startNewGame()
            HapticManager.shared.light()
            return
        }

        guard game.gameStatus == .playing else { return }
        guard let index, index >= 0, index < game.grid.count else { return }
        let cell = game.grid[index]

        switch action {
        case .dig:
            if cell.isRevealed {
                game.quickReveal(at: index)
            } else if cell.isFlagged {
                HapticManager.shared.light()
            } else {
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                    game.revealCell(at: index)
                }
            }

        case .flag:
            if !cell.isRevealed {
                game.toggleFlag(at: index)
            }

        case .chord:
            if cell.isRevealed {
                game.quickReveal(at: index)
            }

        case .newGame:
            break
        }
    }
}

// MARK: - Window key monitor

/// Installs one local monitor while a game is on screen.  `NSEvent` monitors are
/// removed when the game view disappears so text fields in Settings keep their
/// normal typing behavior.
@MainActor
final class MacKeyMonitor: ObservableObject {
    private var monitor: Any?

    func start(controller: MacInputController) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            controller.handleKey(event) ? nil : event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}

// MARK: - Binding recorder

/// Captures the next key press or mouse click for the input settings sheet.
/// Mouse buttons 2...n arrive through `otherMouseDown`, which is what makes
/// side buttons (3/4 and beyond) bindable.
@MainActor
final class MacBindingRecorder: ObservableObject {
    private var monitors: [Any] = []
    private var finished = false

    func start(
        onCapture: @escaping (InputBinding) -> Void,
        onCancel: @escaping () -> Void
    ) {
        stop()
        finished = false
        addMonitor(for: [.keyDown]) { [weak self] event in
            guard let self, !self.finished else { return event }
            let modifiers = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)

            if event.keyCode == 53 && modifiers.isEmpty {
                self.finished = true
                onCancel()
                return nil
            }

            self.finished = true
            onCapture(
                .key(
                    keyCode: event.keyCode,
                    modifiers: event.modifierFlags.rawValue & InputModifiers.relevant
                )
            )
            return nil
        }

        addMonitor(for: [.leftMouseDown]) { [weak self] _ in
            guard let self, !self.finished else { return nil }
            self.finished = true
            onCapture(.mouse(button: 0))
            return nil
        }

        addMonitor(for: [.rightMouseDown]) { [weak self] _ in
            guard let self, !self.finished else { return nil }
            self.finished = true
            onCapture(.mouse(button: 1))
            return nil
        }

        addMonitor(for: [.otherMouseDown]) { [weak self] event in
            guard let self, !self.finished else { return event }
            self.finished = true
            onCapture(.mouse(button: event.buttonNumber))
            return nil
        }
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        finished = true
    }

    private func addMonitor(
        for mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> NSEvent?
    ) {
        if let monitor = NSEvent.addLocalMonitorForEvents(
            matching: mask,
            handler: handler
        ) {
            monitors.append(monitor)
        }
    }
}
