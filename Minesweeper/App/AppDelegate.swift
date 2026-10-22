//
//  AppDelegate.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/22.
//

import SwiftUI

// MARK: - 方向配置
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        // iPhone Duo is a foldable: the cover display and the 7.6-inch inner
        // display have very different aspect ratios, so both orientations must
        // be available.  iPad already supports all orientations.  Regular
        // iPhones keep the original portrait-only interaction.
        if DeviceCapabilities.isPad {
            return .all
        }
        if DeviceCapabilities.isFoldableIPhone {
            return .allButUpsideDown
        }
        return .portrait
    }
}
