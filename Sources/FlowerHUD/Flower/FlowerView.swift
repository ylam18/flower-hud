import SwiftUI

/// Shared geometry so the controller (hit-testing) and the view (rendering) agree exactly.
enum FlowerLayout {
    // The center hub shows the hovered item's name, so petals need no label room —
    // the ring can sit tighter. Panel just needs margin around the ring for the hover scale-up,
    // plus room for the drill-down sub-ring at `subRadius`.
    // The overlay is a borderless window, and a window cannot draw outside its own frame — so the
    // panel must be wide enough to contain the whole sub-ring plus the highlight scale-up, the
    // spring overshoot, and petal shadows, or those get hard-clipped at the window edge. Outermost
    // reach ≈ subRadius(172) + subPetalSize/2(24) + scale/overshoot/shadow(~14) ≈ 210 from center,
    // so a 270 half-extent (540 panel) leaves a comfortable margin.
    static let panelSize: CGFloat = 540   // square overlay (holds ring 1 + the sub-ring arc)
    static let radius: CGFloat = 100      // distance from center to each app petal
    static let deadzone: CGFloat = 42     // cursor within this of center = no selection
    static let petalSize: CGFloat = 60

    // Drill-down: a highlighted app expands into a fan of sub-petals (its windows + "New Window")
    // arranged on a wider arc. Dragging out past `expandThreshold` expands; pulling back inside
    // `collapseThreshold` collapses. The gap between the two is hysteresis to stop flicker.
    static let subRadius: CGFloat = 172
    static let subPetalSize: CGFloat = 48
    static let expandThreshold: CGFloat = 138
    static let collapseThreshold: CGFloat = 118

    /// Per-item angular step (radians, ~32°) and the widest the sub-fan may open (~220°).
    static let subArcStep: Double = 0.558
    static let subArcMax: Double = 220.0 * .pi / 180.0

    /// Angle (radians, math convention: CCW from +x, +y up) for petal `i` of `count`.
    /// Petal 0 is at the top and they proceed clockwise.
    static func angle(for i: Int, count: Int) -> Double {
        guard count > 0 else { return 0 }
        return .pi / 2 - 2 * .pi * Double(i) / Double(count)
    }

    /// Angle for sub-petal `j` of `count`, fanned clockwise and centered on the app's `base`
    /// direction so the drill-down reads as "deeper down that petal."
    static func subAngle(for j: Int, count: Int, base: Double) -> Double {
        guard count > 1 else { return base }
        let arc = min(subArcStep * Double(count - 1), subArcMax)
        return base + arc / 2 - arc / Double(count - 1) * Double(j)
    }
}

/// Observable state the controller pushes into the SwiftUI view.
final class FlowerModel: ObservableObject {
    @Published var items: [PetalItem] = []
    @Published var highlightedIndex: Int?
    @Published var visible: Bool = false

    /// The active visual theme. Set by the controller from the user's choice at show() time.
    @Published var theme: FlowerTheme = .default

    // Drill-down state. `expandedIndex` is the app petal currently drilled into; `subItems`
    // are its ephemeral window/new-window sub-petals; `subHighlightedIndex` is the selected one.
    @Published var expandedIndex: Int?
    @Published var subItems: [PetalItem] = []
    @Published var subHighlightedIndex: Int?
}

struct FlowerView: View {
    @ObservedObject var model: FlowerModel

    var body: some View {
        ZStack {
            ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                PetalView(item: item, highlighted: model.highlightedIndex == index, theme: model.theme)
                    .offset(offset(for: index))
                    .scaleEffect(model.visible ? (model.highlightedIndex == index ? 1.18 : 1.0) : 0.1)
                    .opacity(ringOpacity(for: index))
            }

            // Drill-down sub-ring: the expanded app's windows + "New Window", fanned outward.
            if model.expandedIndex != nil {
                ForEach(Array(model.subItems.enumerated()), id: \.element.id) { index, item in
                    PetalView(item: item,
                              highlighted: model.subHighlightedIndex == index,
                              theme: model.theme,
                              size: FlowerLayout.subPetalSize)
                        .offset(subOffset(for: index))
                        .scaleEffect(model.subHighlightedIndex == index ? 1.18 : 1.0)
                        .transition(.opacity)
                }
            }

            hubLabel
        }
        .frame(width: FlowerLayout.panelSize, height: FlowerLayout.panelSize)
        .animation(.spring(response: 0.30, dampingFraction: 0.72), value: model.visible)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: model.highlightedIndex)
        .animation(.spring(response: 0.26, dampingFraction: 0.74), value: model.expandedIndex)
        .animation(.spring(response: 0.20, dampingFraction: 0.7), value: model.subHighlightedIndex)
    }

    /// While drilled in, fade ring-1 petals other than the anchored app to focus the sub-ring.
    private func ringOpacity(for index: Int) -> Double {
        guard model.visible else { return 0 }
        guard let expanded = model.expandedIndex else { return 1 }
        return index == expanded ? 1 : 0.35
    }

    /// The hovered item's name, shown once in the dead-zone center — never overlaps a petal
    /// and never clips at the panel edge.
    @ViewBuilder
    private var hubLabel: some View {
        if model.visible, let name = highlightedName {
            // The text sizes to its content (capped by the outer maxWidth) so the capsule hugs
            // short names instead of being a fixed-width black bar; long names truncate at the
            // cap, which keeps it clear of the inner petal edge (radius - petalSize/2 = 70).
            Text(name)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(model.theme.hubText)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(model.theme.hubBackground, in: Capsule())
                .overlay(Capsule().strokeBorder(model.theme.hubBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
                .frame(maxWidth: 120)
                .transition(.opacity)
        }
    }

    /// When drilled in, the hub names the highlighted sub-item (window title / "New Window");
    /// otherwise it names the highlighted app.
    private var highlightedName: String? {
        if model.expandedIndex != nil {
            if let s = model.subHighlightedIndex, model.subItems.indices.contains(s) {
                return model.subItems[s].name
            }
            // Drilled in but pointing at the gap — name the anchored app.
            if let e = model.expandedIndex, model.items.indices.contains(e) {
                return model.items[e].name
            }
            return nil
        }
        guard let i = model.highlightedIndex, model.items.indices.contains(i) else { return nil }
        return model.items[i].name
    }

    /// Convert the math-convention angle into a SwiftUI offset (y grows downward).
    private func offset(for index: Int) -> CGSize {
        let a = FlowerLayout.angle(for: index, count: model.items.count)
        let r = model.visible ? FlowerLayout.radius : 0
        return CGSize(width: cos(a) * r, height: -sin(a) * r)
    }

    /// Position a sub-petal on the fan arc around the expanded app's direction.
    private func subOffset(for index: Int) -> CGSize {
        guard let expanded = model.expandedIndex else { return .zero }
        let base = FlowerLayout.angle(for: expanded, count: model.items.count)
        let a = FlowerLayout.subAngle(for: index, count: model.subItems.count, base: base)
        return CGSize(width: cos(a) * FlowerLayout.subRadius, height: -sin(a) * FlowerLayout.subRadius)
    }
}

private struct PetalView: View {
    let item: PetalItem
    let highlighted: Bool
    let theme: FlowerTheme
    var size: CGFloat = FlowerLayout.petalSize

    var body: some View {
        ZStack {
            Circle()
                .fill(fillStyle)
                .overlay(petalTint)
                .overlay(
                    Circle().strokeBorder(
                        highlighted ? theme.highlightStroke : theme.petalStroke,
                        lineWidth: highlighted ? theme.highlightStrokeWidth : theme.petalStrokeWidth
                    )
                )
                .shadow(color: theme.petalShadow, radius: 6, y: 2)
            icon
        }
        .frame(width: size, height: size)
    }

    /// The base fill. Material themes paint the adaptive material here and lay their tint on
    /// top via `petalTint`; solid/gradient themes paint their color directly.
    private var fillStyle: AnyShapeStyle {
        switch theme.petalFill {
        case .material:
            return AnyShapeStyle(.ultraThinMaterial)
        case .solid(let color):
            return AnyShapeStyle(color)
        case .gradient(let top, let bottom):
            return AnyShapeStyle(LinearGradient(colors: [top, bottom],
                                                startPoint: .top, endPoint: .bottom))
        }
    }

    /// Translucent color laid over the material so it still adapts to the background behind it.
    @ViewBuilder
    private var petalTint: some View {
        if case .material(let tint?) = theme.petalFill {
            Circle().fill(tint)
        }
    }

    /// App/file icons render as bitmaps; commands render as a tinted SF Symbol.
    @ViewBuilder
    private var icon: some View {
        switch item.iconKind {
        case .image(let nsImage):
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .frame(width: size * 0.66, height: size * 0.66)
        case .symbol(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .fontWeight(.medium)
                .foregroundStyle(theme.symbolColor)
                .frame(width: size * 0.5, height: size * 0.5)
        }
    }
}
