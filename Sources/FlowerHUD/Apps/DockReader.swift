import AppKit

/// Reads the apps pinned to the user's Dock.
///
/// There is no public API for this, so we parse `com.apple.dock`'s `persistent-apps`.
/// Parsing is defensive: any unexpected shape is skipped rather than crashing, and the
/// caller can fall back to a custom preset if this returns empty.
enum DockReader {
    static func read() -> [AppItem] {
        guard let persistent = dockDefaults()?["persistent-apps"] as? [[String: Any]] else {
            return []
        }

        var items: [AppItem] = []
        var seen = Set<String>()

        for entry in persistent {
            guard
                let tileData = entry["tile-data"] as? [String: Any],
                let fileData = tileData["file-data"] as? [String: Any],
                let urlString = fileData["_CFURLString"] as? String,
                let url = resolveURL(urlString)
            else { continue }

            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            guard seen.insert(url.path).inserted else { continue }

            // Prefer the Dock's own label when present.
            let label = (tileData["file-label"] as? String)
            items.append(AppItem(url: url, name: label))
        }
        return items
    }

    /// Read the Dock preferences domain. `UserDefaults(suiteName:)` reflects the live
    /// values from cfprefsd, which is more reliable than reading the plist file directly.
    private static func dockDefaults() -> [String: Any]? {
        UserDefaults(suiteName: "com.apple.dock")?.persistentDomain(forName: "com.apple.dock")
    }

    private static func resolveURL(_ string: String) -> URL? {
        if let url = URL(string: string), url.isFileURL {
            return url.standardizedFileURL
        }
        // Fall back to treating it as a plain path.
        return URL(fileURLWithPath: string).standardizedFileURL
    }
}
