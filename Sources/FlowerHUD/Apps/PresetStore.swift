import AppKit
import Combine

/// Where the flower's apps come from.
enum SourceMode: String, Codable, CaseIterable, Identifiable {
    case dock      // pinned Dock apps (default)
    case custom    // a user-curated list

    var id: String { rawValue }
    var label: String { self == .dock ? "Dock apps" : "Custom preset" }
}

/// Central, observable configuration: trigger binding + app source + custom preset.
/// Persists to `~/Library/Application Support/FlowerHUD/config.json`.
final class PresetStore: ObservableObject {
    static let shared = PresetStore()

    @Published var trigger: Trigger { didSet { save() } }
    @Published var sourceMode: SourceMode { didSet { save() } }
    @Published var customItems: [PetalItem] { didSet { save() } }

    /// Persisted id of the selected visual theme. Read/write the theme itself via `theme`.
    @Published var themeID: String { didSet { save() } }

    /// The selected theme, resolved from `themeID` (falls back to the default if unknown).
    var theme: FlowerTheme {
        get { FlowerTheme.theme(id: themeID) }
        set { themeID = newValue.id }
    }

    /// The ordered petals (apps + commands) the flower should display right now.
    var currentItems: [PetalItem] {
        switch sourceMode {
        case .dock: return DockReader.read().map(PetalItem.app)
        case .custom: return customItems
        }
    }

    // MARK: - Persistence

    private struct Config: Codable {
        var trigger: Trigger
        var sourceMode: SourceMode
        var customItems: [PetalItem]
        var themeID: String

        private enum CodingKeys: String, CodingKey { case trigger, sourceMode, customItems, customApps, themeID }

        init(trigger: Trigger, sourceMode: SourceMode, customItems: [PetalItem], themeID: String) {
            self.trigger = trigger
            self.sourceMode = sourceMode
            self.customItems = customItems
            self.themeID = themeID
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            trigger = try container.decode(Trigger.self, forKey: .trigger)
            sourceMode = try container.decode(SourceMode.self, forKey: .sourceMode)
            // Prefer the new key; migrate legacy app-only presets transparently.
            if let items = try container.decodeIfPresent([PetalItem].self, forKey: .customItems) {
                customItems = items
            } else {
                let apps = try container.decodeIfPresent([AppItem].self, forKey: .customApps) ?? []
                customItems = apps.map(PetalItem.app)
            }
            // Older configs predate themes — fall back to the default.
            themeID = try container.decodeIfPresent(String.self, forKey: .themeID) ?? FlowerTheme.default.id
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(trigger, forKey: .trigger)
            try container.encode(sourceMode, forKey: .sourceMode)
            try container.encode(customItems, forKey: .customItems)
            try container.encode(themeID, forKey: .themeID)
        }
    }

    private let configURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("FlowerHUD", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()

    private var isLoading = false

    private init() {
        // Defaults
        trigger = .default
        sourceMode = .dock
        customItems = []
        themeID = FlowerTheme.default.id

        isLoading = true
        if let data = try? Data(contentsOf: configURL),
           let config = try? JSONDecoder().decode(Config.self, from: data) {
            trigger = config.trigger
            sourceMode = config.sourceMode
            customItems = config.customItems
            themeID = config.themeID
        }
        isLoading = false
    }

    private func save() {
        guard !isLoading else { return }
        let config = Config(trigger: trigger, sourceMode: sourceMode, customItems: customItems, themeID: themeID)
        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: configURL, options: .atomic)
        }
    }
}
