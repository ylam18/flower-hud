import AppKit

/// Activates the chosen app: brings an already-running instance's window to the front,
/// or launches it (creating a window) if it isn't running.
enum AppLauncher {
    static func launch(_ item: AppItem) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: item.url, configuration: config) { _, error in
            if let error {
                NSLog("FlowerHUD: failed to open \(item.name): \(error.localizedDescription)")
            }
        }
    }
}
