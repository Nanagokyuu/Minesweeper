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
                // 【删除】删掉了 .preferredColorScheme(.light)
                // 现在系统是什么模式，App 就是什么模式
                // 之前一直都是浅色模式，大晚上还是有可能闪瞎眼的
        }
    }
}
