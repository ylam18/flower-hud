import AppKit
import CoreGraphics

/// The user-configurable button or key that summons the flower while held.
enum Trigger: Codable, Equatable {
    /// A keyboard key (virtual key code) plus any required modifier flags.
    case keyboard(keyCode: UInt16, modifiers: UInt64)
    /// A mouse button by CGEvent button number (0 = left, 1 = right, 2 = middle, 3+ = side buttons).
    case mouse(button: Int)

    /// Sensible default: a side mouse button (typically "back" on a 5-button mouse).
    /// Chosen because side buttons rarely carry critical default actions; rebind in Settings.
    static let `default`: Trigger = .mouse(button: 3)

    /// The subset of modifier flags we consider when matching keyboard triggers.
    static let modifierMask: UInt64 =
        CGEventFlags.maskCommand.rawValue |
        CGEventFlags.maskShift.rawValue |
        CGEventFlags.maskControl.rawValue |
        CGEventFlags.maskAlternate.rawValue

    var displayName: String {
        switch self {
        case .mouse(let button):
            switch button {
            case 0: return "Left Mouse Button"
            case 1: return "Right Mouse Button"
            case 2: return "Middle Mouse Button"
            default: return "Mouse Button \(button + 1)"
            }
        case .keyboard(let code, let mods):
            return Trigger.modifierString(mods) + Trigger.keyName(for: code)
        }
    }

    private static func modifierString(_ mods: UInt64) -> String {
        var s = ""
        if mods & CGEventFlags.maskControl.rawValue != 0 { s += "⌃" }
        if mods & CGEventFlags.maskAlternate.rawValue != 0 { s += "⌥" }
        if mods & CGEventFlags.maskShift.rawValue != 0 { s += "⇧" }
        if mods & CGEventFlags.maskCommand.rawValue != 0 { s += "⌘" }
        return s
    }

    /// Human-readable names for common virtual key codes; falls back to a numeric label.
    static func keyName(for code: UInt16) -> String {
        let map: [UInt16: String] = [
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
            34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P",
            12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X",
            16: "Y", 6: "Z",
            29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
            28: "8", 25: "9",
            49: "Space", 36: "Return", 48: "Tab", 53: "Esc", 51: "Delete",
            50: "`", 27: "-", 24: "=", 33: "[", 30: "]", 42: "\\",
            41: ";", 39: "'", 43: ",", 47: ".", 44: "/",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return map[code] ?? "Key \(code)"
    }
}
