//
//  MinesweeperApp.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/22.
//
//  Copyright (C) 2025 Nanagokyuu
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.


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

