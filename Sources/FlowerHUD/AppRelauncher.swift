import AppKit

/// Relaunches Flower reliably from within itself.
///
/// Needed after granting **Screen Recording**: macOS only applies that grant to a
/// fresh process, because the in-process `CGPreflight/RequestScreenCaptureAccess`
/// result is cached at the pre-grant (denied) value for the lifetime of the process.
/// macOS's own "Quit & Reopen" prompt is unreliable for background/accessory
/// (`LSUIElement`) apps — it quits the app but frequently never reopens it — so we
/// do the relaunch ourselves: spawn a small detached helper that waits for this
/// process to exit, then `open`s the bundle again. The helper is reparented to
/// launchd when we terminate, so it survives to relaunch us.
enum AppRelauncher {
    static func relaunch() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Wait a beat so this instance is fully gone before `open` runs — otherwise
        // LaunchServices treats it as already-running and just reactivates it.
        task.arguments = ["-c", "sleep 1; /usr/bin/open \"\(bundlePath)\""]
        do {
            try task.run()
        } catch {
            NSLog("FlowerHUD: relaunch failed to spawn helper: \(error.localizedDescription)")
            return
        }
        NSApp.terminate(nil)
    }
}
