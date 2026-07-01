import AppKit

/// One app shown as a petal in the flower. `url` points at the `.app` bundle.
struct AppItem: Identifiable, Equatable, Codable {
    let url: URL
    let name: String

    var id: String { url.path }

    /// The app's Finder icon. Computed (never persisted) so it always reflects the current bundle.
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    init(url: URL, name: String? = nil) {
        self.url = url
        self.name = name ?? FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
    }

    // Persist only url + name; icon is derived.
    private enum CodingKeys: String, CodingKey { case url, name }
}
