import AppKit
import SwiftUI

/// State the controller pushes into the preview view.
final class PreviewModel: ObservableObject {
    @Published var image: NSImage?
    @Published var theme: FlowerTheme = .default
    @Published var visible: Bool = false
}

/// A tiny, transparent, non-activating panel that floats a window thumbnail next to the hovered
/// sub-petal. Same click-through / all-spaces behavior as `FlowerPanel` so it never steals focus
/// and rides along in full screen. It's a *separate* window from the flower because a window can't
/// draw outside its own frame — the thumbnail sits beyond the sub-ring, past the main panel's edge.
final class PreviewPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),   // resized per capture
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false                    // the SwiftUI view draws its own framed shadow
        level = .popUpMenu
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The framed thumbnail: the captured window image inset inside a rounded, themed card that
/// matches the hub label's look. Sized by the panel — the image fits exactly, no letterboxing.
struct PreviewView: View {
    @ObservedObject var model: PreviewModel

    /// Inset between the image and the card edge; kept in sync with the controller's sizing math.
    static let framePadding: CGFloat = 5
    /// Slack around the card so its drop shadow isn't hard-clipped at the panel edge.
    static let shadowPadding: CGFloat = 10

    var body: some View {
        Group {
            if let image = model.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(Self.framePadding)
        .background(model.theme.hubBackground,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(model.theme.hubBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
        .padding(Self.shadowPadding)
        .opacity(model.visible ? 1 : 0)
        .scaleEffect(model.visible ? 1 : 0.92)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: model.visible)
    }
}
