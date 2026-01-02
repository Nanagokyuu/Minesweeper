//
//  MinesweeperApp.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/22.
//

import SwiftUI

@main
struct MinesweeperApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .preferredColorScheme(.light) // 强制浅色模式，未来也许会改，现在先这么待着吧
        }
    }
}

