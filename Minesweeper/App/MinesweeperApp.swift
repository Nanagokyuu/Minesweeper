//
//  MinesweeperApp.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/22.
//


import SwiftUI

// MARK: - 锁屏配置
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

@main
struct MinesweeperApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .preferredColorScheme(.light) // 强制浅色模式
        }
    }
}

