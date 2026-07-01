import AppKit
import SwiftUI

/// An app-controlled window that asks the user to grant Accessibility access.
///
/// Unlike the system `AXIsProcessTrustedWithOptions` prompt — which macOS leaves on
/// screen even after access is granted — this window can be closed programmatically,
/// so it disappears the moment the grant lands.
///
/// Only ever driven from the main thread (app launch + the main run-loop poll timer).
final class AccessibilityPromptController {
    private var window: NSWindow?

    var isShowing: Bool { window != nil }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(
            rootView: AccessibilityPromptView(openSettings: { Accessibility.openSettings() })
        )
        let win = NSWindow(contentViewController: hosting)
        win.title = "Enable Accessibility Access"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.center()
        window = win

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        window?.close()
        window = nil
    }
}

private struct AccessibilityPromptView: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 38))
                .foregroundStyle(.orange)
            Text("Enable Accessibility Access")
                .font(.headline)
            Text("Flower needs Accessibility access to detect your trigger. Open System Settings, then turn on Flower under Privacy & Security ▸ Accessibility.\n\nThis window closes itself as soon as access is granted — no need to relaunch.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open System Settings", action: openSettings)
                .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(width: 420)
    }
}
