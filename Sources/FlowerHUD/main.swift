import AppKit

// Programmatic entry point. Using NSApplication directly (rather than the SwiftUI
// App lifecycle) gives us full control over a hand-assembled menu-bar agent bundle.
let app = NSApplication.shared

// `.accessory` = no Dock icon, no menu bar of its own; lives only in the status bar.
// This mirrors LSUIElement and is what makes Flower a background agent.
app.setActivationPolicy(.accessory)

// Held for the lifetime of the process (NSApplication.delegate is a weak reference).
let delegate = AppDelegate()
app.delegate = delegate

app.run()
