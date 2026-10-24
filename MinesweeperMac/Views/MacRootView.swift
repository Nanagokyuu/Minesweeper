//
//  MacRootView.swift
//  MinesweeperMac
//
//  Window-level chrome: background, toolbar and the transition between the
//  landing screen and the board.
//

import Combine
import SwiftUI

struct MacRootView: View {
    @ObservedObject var session: MacGameSession
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.groupedBackground
                .ignoresSafeArea()

            switch session.screen {
            case .home:
                MacHomeView(session: session)
            case .game:
                if let game = session.game {
                    MacGameView(session: session, game: game)
                        .id(ObjectIdentifier(game))
                } else {
                    MacHomeView(session: session)
                }
            }
        }
        .navigationTitle(windowTitle)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if session.screen == .game {
                    Button {
                        session.backHome()
                    } label: {
                        Label(localization.text(.backToHome), systemImage: "chevron.left")
                    }
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if session.screen == .game {
                    Button {
                        session.newGame()
                        HapticManager.shared.light()
                    } label: {
                        Label(localization.text(.newGame), systemImage: "arrow.clockwise")
                    }
                    .help(localization.text(.newGame))
                }

                Button {
                    openWindow(id: MacWindowID.history)
                } label: {
                    Label(localization.text(.historyTitle), systemImage: "clock.arrow.circlepath")
                }
                .help(localization.text(.historyTitle))

                Button {
                    openSettings()
                } label: {
                    Label(localization.text(.settings), systemImage: "gearshape")
                }
                .help(localization.text(.settings))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            session.game?.handleScenePhase(phase)
        }
    }

    private var windowTitle: String {
        switch session.screen {
        case .home:
            return localization.text(.gameTitle)
        case .game:
            return "\(localization.text(.gameTitle)) — \(session.difficulty.localizedName(localization: localization))"
        }
    }
}
