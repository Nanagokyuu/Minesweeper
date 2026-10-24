//
//  InputBinding.swift
//  Minesweeper
//
//  User-rebindable input map shared by the platform front ends.  A binding is
//  either a keyboard key (macOS virtual key code + modifier flags) or a mouse
//  button (0 = left, 1 = right, 2 = middle, 3/4 = side buttons).  One action
//  may own several bindings; one physical input belongs to exactly one action.
//

import Foundation

// MARK: - Actions

enum InputAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case dig
    case flag
    case chord
    case newGame

    var id: String { rawValue }

    var localizationKey: LocalizedKey {
        switch self {
        case .dig: return .inputActionDig
        case .flag: return .inputActionFlag
        case .chord: return .inputActionChord
        case .newGame: return .inputActionNewGame
        }
    }

    var systemImage: String {
        switch self {
        case .dig: return "hammer.fill"
        case .flag: return "flag.fill"
        case .chord: return "square.grid.3x3.middle.filled"
        case .newGame: return "arrow.clockwise"
        }
    }
}

// MARK: - Binding

enum InputBinding: Hashable, Codable, Identifiable, Sendable {
    case key(keyCode: UInt16, modifiers: UInt)
    case mouse(button: Int)

    var id: String {
        switch self {
        case let .key(keyCode, modifiers):
            return "key-\(keyCode)-\(modifiers)"
        case let .mouse(button):
            return "mouse-\(button)"
        }
    }

    var isMouse: Bool {
        if case .mouse = self { return true }
        return false
    }

    var mouseButton: Int? {
        if case let .mouse(button) = self { return button }
        return nil
    }

    var keyCode: UInt16? {
        if case let .key(keyCode, _) = self { return keyCode }
        return nil
    }

    /// Modifier flags matching `NSEvent.ModifierFlags` raw values, so the
    /// macOS event monitor can compare them without an AppKit dependency here.
    var modifiers: UInt {
        if case let .key(_, modifiers) = self { return modifiers }
        return 0
    }
}

// MARK: - Modifier constants

enum InputModifiers {
    static let shift: UInt = 1 << 17
    static let control: UInt = 1 << 18
    static let option: UInt = 1 << 19
    static let command: UInt = 1 << 20

    static let relevant: UInt = shift | control | option | command

    static func symbols(_ raw: UInt) -> String {
        var result = ""
        if raw & control != 0 { result += "⌃" }
        if raw & option != 0 { result += "⌥" }
        if raw & shift != 0 { result += "⇧" }
        if raw & command != 0 { result += "⌘" }
        return result
    }
}

// MARK: - Key names

enum InputKeyNames {
    /// macOS virtual key codes.  Names are hardware-independent and match the
    /// US layout labels macOS uses for shortcuts.
    private static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
        50: "`", 51: "⌫", 53: "⎋", 96: "F5", 97: "F6", 98: "F7",
        99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13",
        107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help",
        115: "↖", 116: "⇞", 117: "⌦", 118: "F4", 119: "↘", 120: "F2",
        121: "⇟", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }
}

// MARK: - Display

extension InputBinding {
    func displayName(localization: LocalizationManager = .shared) -> String {
        switch self {
        case let .key(keyCode, modifiers):
            return InputModifiers.symbols(modifiers) + InputKeyNames.name(for: keyCode)
        case let .mouse(button):
            switch button {
            case 0: return localization.text(.inputMouseLeft)
            case 1: return localization.text(.inputMouseRight)
            case 2: return localization.text(.inputMouseMiddle)
            case 3: return localization.text(.inputMouseSideBack)
            case 4: return localization.text(.inputMouseSideForward)
            default:
                return String(
                    format: localization.text(.inputMouseButton),
                    button + 1
                )
            }
        }
    }
}

// MARK: - Map

struct InputBindings: Codable, Equatable {
    /// String-keyed storage keeps the persisted JSON readable and stable.
    private var storage: [String: [InputBinding]]

    init(storage: [String: [InputBinding]] = [:]) {
        self.storage = storage
    }

    static var `default`: InputBindings {
        InputBindings(storage: [
            InputAction.dig.rawValue: [
                .mouse(button: 0),
                .key(keyCode: 6, modifiers: 0),   // Z
            ],
            InputAction.flag.rawValue: [
                .mouse(button: 1),
                .key(keyCode: 7, modifiers: 0),   // X
            ],
            InputAction.chord.rawValue: [
                .mouse(button: 2),
                .key(keyCode: 8, modifiers: 0),   // C
            ],
            InputAction.newGame.rawValue: [
                .key(keyCode: 15, modifiers: 0),  // R
            ],
        ])
    }

    subscript(action: InputAction) -> [InputBinding] {
        get { storage[action.rawValue] ?? [] }
        set {
            if newValue.isEmpty {
                storage.removeValue(forKey: action.rawValue)
            } else {
                storage[action.rawValue] = newValue
            }
        }
    }

    func action(for binding: InputBinding) -> InputAction? {
        for action in InputAction.allCases where self[action].contains(binding) {
            return action
        }
        return nil
    }

    func actionForMouse(button: Int) -> InputAction? {
        action(for: .mouse(button: button))
    }

    func actionForKey(keyCode: UInt16, modifiers: UInt) -> InputAction? {
        action(for: .key(keyCode: keyCode, modifiers: modifiers & InputModifiers.relevant))
    }

    /// Adds `binding` to `action`, removing it from any other action first so a
    /// physical input never fires two conflicting actions.
    mutating func bind(_ binding: InputBinding, to action: InputAction) {
        for other in InputAction.allCases {
            self[other].removeAll { $0 == binding }
        }
        if !self[action].contains(binding) {
            self[action].append(binding)
        }
    }

    mutating func unbind(_ binding: InputBinding, from action: InputAction) {
        self[action].removeAll { $0 == binding }
    }

    mutating func reset() {
        self = .default
    }

    /// True when the binding is already owned by another action.
    func conflictingAction(for binding: InputBinding, assignedTo action: InputAction) -> InputAction? {
        guard let owner = self.action(for: binding), owner != action else { return nil }
        return owner
    }
}
