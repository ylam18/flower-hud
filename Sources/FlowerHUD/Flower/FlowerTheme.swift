import SwiftUI

/// How a petal's background is painted. Materials stay translucent and adapt to whatever is
/// behind the overlay (the original look); solids and gradients are bold and fully opaque.
enum PetalFill: Equatable {
    /// `.ultraThinMaterial`, optionally tinted with a translucent color laid over it. A `nil`
    /// tint is the bare adaptive material (the app's original appearance).
    case material(tint: Color?)
    case solid(Color)
    case gradient(top: Color, bottom: Color)
}

/// A visual theme controlling the flower's colors. Themes are predefined and named after
/// flowers; the user picks one in Settings. Only the selected theme's `id` is persisted —
/// the palettes themselves live here in code, so adding a theme never migrates user config.
struct FlowerTheme: Identifiable, Equatable {
    let id: String        // stable key written to config.json — never rename
    let name: String      // display name (a flower)

    // Petal ring
    var petalFill: PetalFill
    var petalStroke: Color        // idle border
    var petalStrokeWidth: CGFloat
    var highlightStroke: Color    // border of the highlighted/selected petal
    var highlightStrokeWidth: CGFloat
    var petalShadow: Color

    /// Tint for command petals' SF Symbols (app/file icons are bitmaps and stay untouched).
    var symbolColor: Color

    // Center hub label
    var hubText: Color
    var hubBackground: Color
    var hubBorder: Color

    init(
        id: String,
        name: String,
        petalFill: PetalFill,
        petalStroke: Color = .white.opacity(0.15),
        petalStrokeWidth: CGFloat = 1,
        highlightStroke: Color,
        highlightStrokeWidth: CGFloat = 3,
        petalShadow: Color = .black.opacity(0.25),
        symbolColor: Color = .white,
        hubText: Color = .white,
        hubBackground: Color = .black.opacity(0.85),
        hubBorder: Color = .white.opacity(0.18)
    ) {
        self.id = id
        self.name = name
        self.petalFill = petalFill
        self.petalStroke = petalStroke
        self.petalStrokeWidth = petalStrokeWidth
        self.highlightStroke = highlightStroke
        self.highlightStrokeWidth = highlightStrokeWidth
        self.petalShadow = petalShadow
        self.symbolColor = symbolColor
        self.hubText = hubText
        self.hubBackground = hubBackground
        self.hubBorder = hubBorder
    }
}

// MARK: - Palette

extension FlowerTheme {
    /// All selectable themes, in display order. `nightshade` is first and is the default —
    /// it reproduces the app's original adaptive dark look exactly.
    static let all: [FlowerTheme] = [
        nightshade, rose, sunflower, marigold, poppy,
        hibiscus, orchid, iris, bluebell, lavender,
        lotus, daisy,
    ]

    static let `default` = nightshade

    /// Resolve a persisted id back to a theme, falling back to the default if unknown
    /// (e.g. a theme that existed in a newer build).
    static func theme(id: String?) -> FlowerTheme {
        guard let id else { return .default }
        return all.first { $0.id == id } ?? .default
    }

    // — Adaptive / dark —

    /// The original look: bare adaptive material, system-accent highlight, black hub.
    static let nightshade = FlowerTheme(
        id: "nightshade",
        name: "Nightshade",
        petalFill: .material(tint: nil),
        highlightStroke: .accentColor
    )

    static let rose = FlowerTheme(
        id: "rose",
        name: "Rose",
        petalFill: .material(tint: Color(red: 0.90, green: 0.18, blue: 0.34).opacity(0.20)),
        petalStroke: Color(red: 1.0, green: 0.55, blue: 0.65).opacity(0.30),
        highlightStroke: Color(red: 1.0, green: 0.38, blue: 0.52),
        symbolColor: Color(red: 1.0, green: 0.80, blue: 0.85),
        hubBackground: Color(red: 0.32, green: 0.04, blue: 0.12).opacity(0.92)
    )

    static let sunflower = FlowerTheme(
        id: "sunflower",
        name: "Sunflower",
        petalFill: .material(tint: Color(red: 0.98, green: 0.74, blue: 0.10).opacity(0.20)),
        petalStroke: Color(red: 1.0, green: 0.85, blue: 0.35).opacity(0.35),
        highlightStroke: Color(red: 1.0, green: 0.78, blue: 0.10),
        symbolColor: Color(red: 1.0, green: 0.88, blue: 0.45),
        hubBackground: Color(red: 0.24, green: 0.16, blue: 0.0).opacity(0.92)
    )

    static let marigold = FlowerTheme(
        id: "marigold",
        name: "Marigold",
        petalFill: .material(tint: Color(red: 1.0, green: 0.50, blue: 0.08).opacity(0.22)),
        petalStroke: Color(red: 1.0, green: 0.62, blue: 0.25).opacity(0.35),
        highlightStroke: Color(red: 1.0, green: 0.52, blue: 0.12),
        symbolColor: Color(red: 1.0, green: 0.80, blue: 0.55),
        hubBackground: Color(red: 0.28, green: 0.12, blue: 0.0).opacity(0.92)
    )

    static let poppy = FlowerTheme(
        id: "poppy",
        name: "Poppy",
        petalFill: .gradient(top: Color(red: 0.92, green: 0.16, blue: 0.12),
                             bottom: Color(red: 0.62, green: 0.06, blue: 0.06)),
        petalStroke: .white.opacity(0.25),
        highlightStroke: .white,
        petalShadow: Color(red: 0.4, green: 0.0, blue: 0.0).opacity(0.45),
        symbolColor: .white,
        hubBackground: Color(red: 0.20, green: 0.0, blue: 0.0).opacity(0.92)
    )

    static let hibiscus = FlowerTheme(
        id: "hibiscus",
        name: "Hibiscus",
        petalFill: .gradient(top: Color(red: 0.95, green: 0.18, blue: 0.45),
                             bottom: Color(red: 0.78, green: 0.10, blue: 0.55)),
        petalStroke: .white.opacity(0.28),
        highlightStroke: Color(red: 1.0, green: 0.85, blue: 0.30),
        petalShadow: Color(red: 0.35, green: 0.0, blue: 0.20).opacity(0.45),
        symbolColor: .white,
        hubBackground: Color(red: 0.30, green: 0.02, blue: 0.22).opacity(0.92)
    )

    // — Purple / blue —

    static let orchid = FlowerTheme(
        id: "orchid",
        name: "Orchid",
        petalFill: .material(tint: Color(red: 0.65, green: 0.30, blue: 0.85).opacity(0.22)),
        petalStroke: Color(red: 0.80, green: 0.55, blue: 0.95).opacity(0.35),
        highlightStroke: Color(red: 0.78, green: 0.45, blue: 1.0),
        symbolColor: Color(red: 0.90, green: 0.78, blue: 1.0),
        hubBackground: Color(red: 0.22, green: 0.08, blue: 0.32).opacity(0.92)
    )

    static let iris = FlowerTheme(
        id: "iris",
        name: "Iris",
        petalFill: .gradient(top: Color(red: 0.42, green: 0.38, blue: 0.92),
                             bottom: Color(red: 0.26, green: 0.20, blue: 0.62)),
        petalStroke: .white.opacity(0.24),
        highlightStroke: Color(red: 0.70, green: 0.78, blue: 1.0),
        petalShadow: Color(red: 0.10, green: 0.06, blue: 0.30).opacity(0.45),
        symbolColor: .white,
        hubBackground: Color(red: 0.14, green: 0.10, blue: 0.38).opacity(0.92)
    )

    static let bluebell = FlowerTheme(
        id: "bluebell",
        name: "Bluebell",
        petalFill: .material(tint: Color(red: 0.22, green: 0.48, blue: 0.98).opacity(0.22)),
        petalStroke: Color(red: 0.50, green: 0.70, blue: 1.0).opacity(0.35),
        highlightStroke: Color(red: 0.35, green: 0.62, blue: 1.0),
        symbolColor: Color(red: 0.75, green: 0.86, blue: 1.0),
        hubBackground: Color(red: 0.04, green: 0.10, blue: 0.34).opacity(0.92)
    )

    static let lavender = FlowerTheme(
        id: "lavender",
        name: "Lavender",
        petalFill: .material(tint: Color(red: 0.62, green: 0.55, blue: 0.88).opacity(0.20)),
        petalStroke: Color(red: 0.78, green: 0.72, blue: 0.96).opacity(0.40),
        highlightStroke: Color(red: 0.60, green: 0.48, blue: 0.92),
        symbolColor: Color(red: 0.88, green: 0.84, blue: 1.0),
        hubBackground: Color(red: 0.40, green: 0.34, blue: 0.62).opacity(0.92)
    )

    // — Light —

    static let lotus = FlowerTheme(
        id: "lotus",
        name: "Lotus",
        petalFill: .gradient(top: Color(red: 1.0, green: 0.95, blue: 0.97),
                             bottom: Color(red: 0.99, green: 0.82, blue: 0.88)),
        petalStroke: Color(red: 0.85, green: 0.55, blue: 0.65).opacity(0.45),
        highlightStroke: Color(red: 0.95, green: 0.45, blue: 0.62),
        petalShadow: Color(red: 0.6, green: 0.3, blue: 0.4).opacity(0.25),
        symbolColor: Color(red: 0.70, green: 0.30, blue: 0.45),
        hubText: Color(red: 0.45, green: 0.12, blue: 0.25),
        hubBackground: .white.opacity(0.92),
        hubBorder: Color(red: 0.85, green: 0.55, blue: 0.65).opacity(0.5)
    )

    static let daisy = FlowerTheme(
        id: "daisy",
        name: "Daisy",
        petalFill: .solid(.white.opacity(0.94)),
        petalStroke: Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.12),
        highlightStroke: Color(red: 1.0, green: 0.78, blue: 0.12),
        highlightStrokeWidth: 4,
        petalShadow: .black.opacity(0.20),
        symbolColor: Color(red: 0.85, green: 0.62, blue: 0.0),
        hubText: Color(red: 0.20, green: 0.18, blue: 0.0),
        hubBackground: Color(red: 1.0, green: 0.85, blue: 0.30).opacity(0.95),
        hubBorder: Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.10)
    )
}
