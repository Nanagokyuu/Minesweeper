//
//  DeviceCapabilities.swift
//  Minesweeper
//
//  Small, dependency-free capability checks used by the UI.  Keep layout
//  decisions based on geometry and size classes where possible; this file is
//  only for the few decisions the system asks for before a scene exists
//  (supported orientations) and for identifying iPhone Duo.
//

import UIKit

enum DeviceCapabilities {
    /// Hardware model identifier, e.g. "iPhone19,4".
    ///
    /// `UIDevice` has no public model-identifier API, so use `uname` on device
    /// and the simulator-provided environment variable on the Simulator.
    static let modelIdentifier: String = {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           !simulated.isEmpty {
            return simulated
        }

        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else { return "" }
        var machine = systemInfo.machine
        let capacity = MemoryLayout.size(ofValue: machine)
        return withUnsafePointer(to: &machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: capacity) {
                String(cString: $0)
            }
        }
    }()

    /// iPhone Duo is Apple's first foldable iPhone (`iPhone19,4`).
    ///
    /// The model identifier is authoritative.  The width/height fallback keeps
    /// future foldables working without a new build: a phone-class device with
    /// an iPad-like canvas is only possible on a foldable.
    static var isFoldableIPhone: Bool {
        if modelIdentifier == "iPhone19,4" {
            return true
        }
        return UIDevice.current.userInterfaceIdiom == .phone && primaryScreenIsLarge
    }

    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// iPad and iPhone Duo can use landscape.  Regular iPhones stay portrait,
    /// which keeps the existing one-handed interaction model.
    static var supportsLandscape: Bool {
        isPad || isFoldableIPhone
    }

    private static var primaryScreenIsLarge: Bool {
        let bounds = primaryScreenBounds
        return bounds.width >= 600 && bounds.height >= 600
    }

    private static var primaryScreenBounds: CGRect {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            return scene.screen.bounds
        }
        return UIScreen.main.bounds
    }
}
