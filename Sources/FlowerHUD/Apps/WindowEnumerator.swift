import AppKit
import ApplicationServices

/// Reads a running app's open windows and drives per-window actions via the Accessibility API.
///
/// The app already holds Accessibility permission (its global `CGEventTap` needs it), which is
/// exactly what `AXUIElement` queries and actions require — so no extra entitlement is involved.
/// Window lists are a single snapshot taken when a petal is drilled into; we never poll.
enum WindowEnumerator {
    /// A standard window of a running app, captured at drill-in time.
    struct OpenWindow {
        let title: String
        let element: AXUIElement
        let pid: pid_t
    }

    // MARK: - Resolve the running app

    static func runningApp(for app: AppItem) -> NSRunningApplication? {
        if let bundleID = Bundle(url: app.url)?.bundleIdentifier {
            if let match = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                return match
            }
        }
        // Fallback for bundles without a readable identifier: match by bundle URL.
        return NSWorkspace.shared.runningApplications.first { $0.bundleURL == app.url }
    }

    // MARK: - Enumerate windows

    /// All standard windows (including minimized) of the app, or `[]` if it isn't running.
    static func windows(for app: AppItem) -> [OpenWindow] {
        guard let running = runningApp(for: app) else { return [] }
        let pid = running.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)
        // Don't let an unresponsive target stall the 60fps poll loop that calls us.
        AXUIElementSetMessagingTimeout(axApp, 0.25)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let windowList = value as? [AXUIElement] else { return [] }

        var result: [OpenWindow] = []
        for w in windowList {
            // Keep only standard document/app windows — skip palettes, sheets, dialogs.
            var subroleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(w, kAXSubroleAttribute as CFString, &subroleRef)
            if let subrole = subroleRef as? String, subrole != (kAXStandardWindowSubrole as String) {
                continue
            }
            // Include minimized windows on purpose; `focus` de-minimizes them on select.
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &titleRef)
            let title = (titleRef as? String).flatMap { $0.isEmpty ? nil : $0 } ?? app.name
            result.append(OpenWindow(title: title, element: w, pid: pid))
        }
        return result
    }

    // MARK: - Actions

    /// Bring one specific window forward, de-minimizing it first if needed.
    static func focus(window element: AXUIElement, pid: pid_t) {
        NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateIgnoringOtherApps])
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    /// Open a new window for the app. If it isn't running, launching it yields a window;
    /// if it is, find and press its "New Window"-style menu item (more robust than ⌘N,
    /// which apps rebind freely).
    static func newWindow(for app: AppItem) {
        guard let running = runningApp(for: app) else {
            AppLauncher.launch(app)
            return
        }
        running.activate(options: [.activateIgnoringOtherApps])
        let pid = running.processIdentifier
        // Activation + menu traversal can take a beat; do it off the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            guard let item = findNewWindowMenuItem(pid: pid) else {
                NSLog("FlowerHUD: no 'New Window' menu item found for \(app.name)")
                return
            }
            AXUIElementPerformAction(item, kAXPressAction as CFString)
        }
    }

    // MARK: - Menu lookup

    /// Locate a "New Window"-style menu item: prefer the File menu, then scan all top-level menus.
    private static func findNewWindowMenuItem(pid: pid_t) -> AXUIElement? {
        let axApp = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(axApp, 0.5)

        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBar = ifAXElement(menuBarRef) else { return nil }

        let topLevel = children(of: menuBar)
        // Prefer "File", then everything else.
        let ordered = topLevel.sorted { a, _ in title(of: a)?.caseInsensitiveCompare("File") == .orderedSame }
        for menuBarItem in ordered {
            // Each menu-bar item has a single submenu child holding the actual menu items.
            for menu in children(of: menuBarItem) {
                if let hit = searchMenu(menu) { return hit }
            }
        }
        return nil
    }

    /// Recursively search a menu (and its submenus) for a matching item.
    private static func searchMenu(_ menu: AXUIElement) -> AXUIElement? {
        for item in children(of: menu) {
            if let t = title(of: item), matchesNewWindow(t) { return item }
            // Descend into nested submenus.
            for sub in children(of: item) {
                if let hit = searchMenu(sub) { return hit }
            }
        }
        return nil
    }

    private static func matchesNewWindow(_ title: String) -> Bool {
        let t = title.lowercased()
        if t == "new window" { return true }
        return t.contains("new") && t.contains("window")
    }

    // MARK: - AX helpers

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &ref) == .success,
              let kids = ref as? [AXUIElement] else { return [] }
        return kids
    }

    private static func title(of element: AXUIElement) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &ref) == .success
        else { return nil }
        return ref as? String
    }

    /// Narrow a copied attribute value to an AXUIElement (CFTypeRef bridging guard).
    private static func ifAXElement(_ ref: CFTypeRef?) -> AXUIElement? {
        guard let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        return (ref as! AXUIElement)
    }
}
