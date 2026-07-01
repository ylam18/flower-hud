import AppKit
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit

/// Renders a bitmap thumbnail of a specific open window, for the hover preview shown over the
/// drill-down sub-ring.
///
/// The sub-ring identifies windows by `AXUIElement` (see `WindowEnumerator`), but the image APIs
/// address windows by `CGWindowID`, so we bridge the two with the private `_AXUIElementGetWindow`.
/// Capturing pixels needs the **Screen Recording** TCC permission — separate from the Accessibility
/// grant the trigger tap already relies on, and (a macOS quirk) newly granted the app usually has to
/// be relaunched before it takes effect.
///
/// On macOS 14+ we use **ScreenCaptureKit** (`SCScreenshotManager`) — the legacy
/// `CGWindowListCreateImage` is deprecated and, on macOS 15+, effectively returns nothing for other
/// apps' windows, so it survives only as the pre-14 fallback.
enum WindowCapture {
    /// Asynchronously produce a best-effort thumbnail of `element`, calling `completion` with the
    /// image — or `nil` when it can't be captured (permission not yet granted/effective, or the
    /// window is minimized/off-screen and has no on-screen image). `completion` may run on a
    /// background thread; the caller hops back to the main thread.
    static func image(for element: AXUIElement, completion: @escaping (NSImage?) -> Void) {
        guard hasScreenRecordingAccess() else { completion(nil); return }
        guard let windowID = windowID(for: element) else { completion(nil); return }

        if #available(macOS 14.0, *) {
            captureViaScreenCaptureKit(windowID: windowID, completion: completion)
        } else {
            completion(legacyImage(windowID: windowID))
        }
    }

    // MARK: - ScreenCaptureKit (macOS 14+)

    @available(macOS 14.0, *)
    private static func captureViaScreenCaptureKit(windowID: CGWindowID,
                                                   completion: @escaping (NSImage?) -> Void) {
        Task {
            do {
                // `onScreenWindowsOnly: true` also drops minimized windows — fine, they have no
                // capturable image and we intend to show no preview for them.
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false, onScreenWindowsOnly: true)
                guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                    completion(nil)
                    return
                }

                let filter = SCContentFilter(desktopIndependentWindow: window)
                let config = SCStreamConfiguration()
                // Capture at the window's *point* size. Matching the content 1:1 guarantees the
                // whole window fills the canvas on any display — hardcoding a 2× scale letterboxes
                // the content into a corner on non-Retina (1×) monitors. The controller downscales
                // into the small preview box anyway, so point resolution is plenty crisp.
                config.width = max(1, Int(window.frame.width))
                config.height = max(1, Int(window.frame.height))
                config.showsCursor = false

                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter, configuration: config)
                completion(NSImage(cgImage: cgImage,
                                   size: NSSize(width: cgImage.width, height: cgImage.height)))
            } catch {
                NSLog("FlowerHUD: ScreenCaptureKit window capture failed: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    // MARK: - Legacy fallback (macOS 13)

    private static func legacyImage(windowID: CGWindowID) -> NSImage? {
        let options: CGWindowImageOption = [.boundsIgnoreFraming, .nominalResolution]
        guard let cgImage = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, options),
              cgImage.width > 1, cgImage.height > 1 else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    // MARK: - AXUIElement → CGWindowID

    private static func windowID(for element: AXUIElement) -> CGWindowID? {
        var id = CGWindowID(0)
        guard _AXUIElementGetWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    // MARK: - Permission

    /// Whether we can capture window pixels. Preflight is non-prompting; if it fails we fire the
    /// one-time request (which surfaces the system prompt) and report `false` for now. Note macOS
    /// often keeps returning `false` here until the app is relaunched after the grant.
    private static func hasScreenRecordingAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        _ = CGRequestScreenCaptureAccess()
        return false
    }
}

/// Private HIServices SPI: fills `*identifier` with the `CGWindowID` backing an accessibility
/// window element. Bound directly to the framework symbol via `@_silgen_name`, so no bridging
/// header is needed under the direct-`swiftc` build.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement,
                                   _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError
