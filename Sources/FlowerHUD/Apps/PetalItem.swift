import AppKit
import ApplicationServices

/// One petal in the flower: either an app to launch or a command to run.
/// Apps are just the `.launchApp` action, so the Dock source and the app picker
/// keep producing `AppItem`s that we wrap via `PetalItem.app(_:)`.
struct PetalItem: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var action: PetalAction
    /// Optional SF Symbol name overriding the petal/row icon.
    var symbolName: String?

    /// Convenience for Dock entries and app picks.
    static func app(_ app: AppItem) -> PetalItem {
        PetalItem(name: app.name, action: .launchApp(app))
    }

    /// What the petal/row should render. Computed → not part of Equatable/Codable.
    var iconKind: PetalIcon {
        if let symbolName, !symbolName.isEmpty { return .symbol(symbolName) }
        switch action {
        case .launchApp(let app):    return .image(app.icon)
        case .openURL(_, let inApp): return inApp.map { .image($0.icon) } ?? .symbol("link")
        case .openPath(let url):     return .image(NSWorkspace.shared.icon(forFile: url.path))
        case .systemAction(let a):   return .symbol(a.symbolName)
        case .runScript:             return .symbol("terminal")
        case .focusWindow:           return .symbol("macwindow")
        case .newWindow:             return .symbol("plus.rectangle.on.rectangle")
        }
    }

    /// True for everything except a plain app launch (used to gate the editor and to decide
    /// whether a petal can be drilled into for its windows).
    var isCommand: Bool {
        if case .launchApp = action { return false }
        return true
    }

    /// The `.app` bundle URL when this petal is a plain app launch, for dedup in the picker.
    var appURL: URL? {
        if case .launchApp(let app) = action { return app.url }
        return nil
    }

    /// Short secondary label for the settings row.
    var actionSummary: String {
        switch action {
        case .launchApp:                   return "App"
        case .openURL(let url, let inApp):
            if let inApp { return "Open link in \(inApp.name)" }
            return "Open link · \(url.absoluteString)"
        case .openPath(let url):           return "Open \(url.lastPathComponent)"
        case .systemAction(let a):         return a.label
        case .runScript(let kind, _):      return kind.label
        case .focusWindow:                 return "Window"
        case .newWindow:                   return "New Window"
        }
    }
}

/// A live reference to one of a running app's windows. Holds the AXUIElement + owning pid.
/// `AXUIElement` is a CF type that retains correctly when stored, but it is only valid while
/// the target window exists, so these are built fresh each flower session and never persisted.
/// The `Codable` conformance exists only to satisfy `PetalAction`'s synthesized conformance —
/// `.focusWindow` petals live solely in the ephemeral sub-ring, never in the saved preset.
final class WindowRef: Equatable, Codable {
    let element: AXUIElement
    let pid: pid_t

    init(element: AXUIElement, pid: pid_t) {
        self.element = element
        self.pid = pid
    }

    static func == (l: WindowRef, r: WindowRef) -> Bool { l === r }   // identity

    func encode(to encoder: Encoder) throws {}                        // never persisted
    init(from decoder: Decoder) throws {                              // never decoded
        throw DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "WindowRef is ephemeral and not decodable"))
    }
}

/// How a petal draws its icon: a bitmap (app/file icon) or an SF Symbol (commands).
enum PetalIcon: Equatable {
    case image(NSImage)
    case symbol(String)
}

/// What selecting a petal does.
enum PetalAction: Equatable, Codable {
    case launchApp(AppItem)
    case openURL(url: URL, inApp: AppItem?)
    case openPath(url: URL)
    case systemAction(SystemAction)
    case runScript(kind: ScriptKind, source: String)
    /// Raise a specific open window of a running app (ephemeral; sub-ring only).
    case focusWindow(WindowRef)
    /// Open a fresh window for an app (sub-ring only).
    case newWindow(AppItem)
}

/// The interpreter a `.runScript` action uses.
enum ScriptKind: String, Codable, CaseIterable, Identifiable {
    case shell
    case appleScript

    var id: String { rawValue }
    var label: String { self == .shell ? "Shell (/bin/zsh)" : "AppleScript" }
}

/// Curated, safe built-in actions the user can pick from a dropdown.
enum SystemAction: String, Codable, CaseIterable, Identifiable {
    case missionControl
    case launchpad
    case showDesktop
    case lockScreen
    case sleep
    case screenSaver
    case screenshotSelection

    var id: String { rawValue }

    var label: String {
        switch self {
        case .missionControl:     return "Mission Control"
        case .launchpad:          return "Launchpad"
        case .showDesktop:        return "Show Desktop"
        case .lockScreen:         return "Lock Screen"
        case .sleep:              return "Sleep"
        case .screenSaver:        return "Screen Saver"
        case .screenshotSelection: return "Screenshot Selection"
        }
    }

    var symbolName: String {
        switch self {
        case .missionControl:      return "rectangle.3.group"
        case .launchpad:           return "square.grid.3x3.fill"
        case .showDesktop:         return "menubar.dock.rectangle"
        case .lockScreen:          return "lock.fill"
        case .sleep:               return "moon.fill"
        case .screenSaver:         return "display"
        case .screenshotSelection: return "camera.viewfinder"
        }
    }
}
