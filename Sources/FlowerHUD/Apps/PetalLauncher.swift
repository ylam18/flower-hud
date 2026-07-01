import AppKit
import Carbon.HIToolbox

/// Executes a selected petal by dispatching on its action. App launches reuse `AppLauncher`.
enum PetalLauncher {
    static func run(_ item: PetalItem) {
        switch item.action {
        case .launchApp(let app):
            AppLauncher.launch(app)

        case .openURL(let url, let inApp):
            if let inApp {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.open([url], withApplicationAt: inApp.url, configuration: config) { _, error in
                    if let error { logFailure(item, error) }
                }
            } else {
                NSWorkspace.shared.open(url)
            }

        case .openPath(let url):
            NSWorkspace.shared.open(url)

        case .systemAction(let action):
            runSystemAction(action)

        case .runScript(let kind, let source):
            runScript(kind: kind, source: source, item: item)

        case .focusWindow(let ref):
            WindowEnumerator.focus(window: ref.element, pid: ref.pid)

        case .newWindow(let app):
            WindowEnumerator.newWindow(for: app)
        }
    }

    // MARK: - System actions

    private static func runSystemAction(_ action: SystemAction) {
        switch action {
        case .missionControl:
            openSystemApp("/System/Applications/Mission Control.app")
        case .launchpad:
            openSystemApp("/System/Applications/Launchpad.app")
        case .screenSaver:
            openSystemApp("/System/Library/CoreServices/ScreenSaverEngine.app")
        case .sleep:
            runProcess("/usr/bin/pmset", ["sleepnow"])
        case .lockScreen:
            // Post ⌘⌃Q directly (the hardwired lock shortcut on modern macOS). Done via CGEvent
            // so it uses the Accessibility permission we already hold — unlike a System Events
            // keystroke, which needs a separate Automation grant a background agent can't prompt for.
            postKey(CGKeyCode(kVK_ANSI_Q), flags: [.maskCommand, .maskControl])
        case .showDesktop:
            // Best-effort: post the default Show-Desktop key (fn-F11). Depends on the
            // shortcut being enabled in System Settings ▸ Keyboard ▸ Shortcuts.
            postKey(CGKeyCode(kVK_F11), flags: .maskSecondaryFn)
        }
    }

    private static func openSystemApp(_ path: String) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: config) { _, error in
            if let error {
                NSLog("FlowerHUD: failed to open \(path): \(error.localizedDescription)")
            }
        }
    }

    private static func postKey(_ key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    // MARK: - Scripts

    private static func runScript(kind: ScriptKind, source: String, item: PetalItem) {
        switch kind {
        case .shell:       runProcess("/bin/zsh", ["-c", source], item: item)
        case .appleScript: runProcess("/usr/bin/osascript", ["-e", source], item: item)
        }
    }

    /// Runs a command off the main thread so the HUD stays responsive.
    private static func runProcess(_ launchPath: String, _ arguments: [String], item: PetalItem? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = arguments
            do {
                try process.run()
            } catch {
                if let item { logFailure(item, error) }
                else { NSLog("FlowerHUD: failed to run \(launchPath): \(error.localizedDescription)") }
            }
        }
    }

    private static func logFailure(_ item: PetalItem, _ error: Error) {
        NSLog("FlowerHUD: failed to run \(item.name): \(error.localizedDescription)")
    }
}
