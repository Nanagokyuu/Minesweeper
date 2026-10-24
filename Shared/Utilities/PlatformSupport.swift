//
//  PlatformSupport.swift
//  Minesweeper
//
//  The few platform APIs the shared game layer needs: haptics and semantic
//  colors.  Everything else in Shared/ is pure SwiftUI/Foundation.
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - 触感反馈
// iOS 用 Taptic Engine；macOS 用触控板反馈（没有触控板的机器上静默失败）。
// 共享层只调用 light/heavy/success/failure，不关心底层平台。
final class HapticManager {
    static let shared = HapticManager()

    private var settings: AppSettings {
        AppSettings.shared
    }

    func light() {
        guard settings.isHapticsEnabled else { return }
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
        #endif
    }

    func heavy() {
        guard settings.isHapticsEnabled else { return }
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .now
        )
        #endif
    }

    func success() {
        guard settings.isHapticsEnabled else { return }
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .now
        )
        #endif
    }

    func failure() {
        guard settings.isHapticsEnabled else { return }
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .now
        )
        #endif
    }
}

// MARK: - 语义色
extension Color {
    /// Revealed cell background.  Kept light on iOS so the classic number
    /// palette stays readable; macOS follows the system control color.
    static var cellRevealed: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// Full-window background.
    static var mainGradient: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// Grouped content background (settings cards, header pills).
    static var groupedBackground: Color {
        #if os(iOS)
        Color(UIColor.systemGroupedBackground)
        #else
        Color(nsColor: .underPageBackgroundColor)
        #endif
    }

    /// Secondary grouped background (cards on top of `groupedBackground`).
    static var secondaryGroupedBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
