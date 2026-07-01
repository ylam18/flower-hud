import AppKit
import ApplicationServices

/// Helpers around the Accessibility (AXIsProcessTrusted) permission that a global
/// event tap requires.
enum Accessibility {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Registers the app with the Accessibility list (so it shows up in System
    /// Settings ▸ Privacy & Security ▸ Accessibility) *without* raising the system
    /// prompt. We deliberately avoid the system prompt (`AXTrustedCheckOptionPrompt`)
    /// because macOS offers no way to dismiss it — once granted it lingers on screen.
    /// Instead we drive our own dismissable prompt (see `AccessibilityPromptController`).
    @discardableResult
    static func register() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings directly to Privacy & Security → Accessibility.
    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
