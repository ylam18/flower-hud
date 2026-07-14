import AppKit
import CoreGraphics

/// Helpers around the Screen Recording (`ScreenCapture` TCC) permission that live
/// window previews require. Kept parallel to `Accessibility` so the onboarding flow
/// can treat both permissions uniformly.
enum ScreenRecording {
    /// Non-prompting check — safe to poll from a timer.
    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Fires the one-time system request. Its side effect is registering Flower in the
    /// Screen Recording list (so the user has a toggle to flip); it returns the current
    /// grant state, which macOS often reports `false` until a relaunch even once granted.
    @discardableResult
    static func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Opens System Settings directly to Privacy & Security → Screen Recording.
    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
