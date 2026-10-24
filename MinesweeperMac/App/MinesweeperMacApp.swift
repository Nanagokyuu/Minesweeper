//
//  MinesweeperMacApp.swift
//  MinesweeperMac
//
//  Native macOS front end.  Game rules, board generation, history and replay
//  all come from the shared Rust core; this target only owns the Mac window,
//  menu and input experience.
//

import Combine
import SwiftUI

@main
struct MinesweeperMacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    @StateObject private var session: MacGameSession
    @StateObject private var localization = LocalizationManager.shared

    init() {
        let session = MacGameSession()
        #if DEBUG
        // Used by local UI checks: MS_AUTOSTART_DIFFICULTY=hell
        if let raw = ProcessInfo.processInfo.environment["MS_AUTOSTART_DIFFICULTY"],
           let difficulty = Difficulty(rawValue: raw.lowercased()) {
            session.start(difficulty: difficulty)
        }
        #endif
        _session = StateObject(wrappedValue: session)
    }

    var body: some Scene {
        WindowGroup {
            MacRootView(session: session)
                .frame(minWidth: 760, minHeight: 600)
        }
        .defaultSize(width: 1040, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            MacCommands(session: session)
        }

        Settings {
            MacSettingsView()
        }

        Window(localization.text(.historyTitle), id: MacWindowID.history) {
            MacHistoryView()
                .frame(minWidth: 640, minHeight: 440)
        }
        .defaultSize(width: 820, height: 600)
    }
}

enum MacWindowID {
    static let history = "minesweeper.history"
}

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}

// MARK: - Menu bar

struct MacCommands: Commands {
    @ObservedObject var session: MacGameSession
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button {
                session.newGame()
            } label: {
                Text(localization.text(.newGame))
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandMenu(localization.text(.gameMenu)) {
            Button {
                session.backHome()
            } label: {
                Text(localization.text(.backToHome))
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(session.screen != .game)

            Menu(localization.text(.selectDifficulty)) {
                ForEach(Array(Difficulty.allCases.enumerated()), id: \.element) { index, difficulty in
                    Button {
                        session.start(difficulty: difficulty)
                    } label: {
                        Text("\(difficulty.icon)  \(difficulty.localizedName(localization: localization))")
                    }
                    .keyboardShortcut(
                        KeyEquivalent(Character("\(index + 1)")),
                        modifiers: .command
                    )
                }
            }

            Divider()

            Button {
                openWindow(id: MacWindowID.history)
            } label: {
                Text(localization.text(.historyTitle))
            }
            .keyboardShortcut("y", modifiers: .command)
        }
    }
}
