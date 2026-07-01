import AppKit
import SwiftUI

/// Owns the overlay panel and translates cursor movement into petal selection.
///
/// While the flower is visible we poll the cursor (in `.common` run-loop modes, so it keeps
/// updating even while a mouse button is held and the run loop is in tracking mode) and pick
/// the petal whose direction from the center best matches the cursor's direction.
final class FlowerController {
    var onSelect: ((PetalItem) -> Void)?

    private let panel: FlowerPanel
    private let model = FlowerModel()
    private let itemsProvider: () -> [PetalItem]
    private let themeProvider: () -> FlowerTheme

    private var pollTimer: Timer?
    private var center: CGPoint = .zero   // AppKit global coords (origin bottom-left)

    // Hover preview: a floating thumbnail of the highlighted window sub-petal.
    private let previewPanel = PreviewPanel()
    private let previewModel = PreviewModel()
    /// Captured images cached by sub-item id so re-hovering a window is instant. Rebuilt each
    /// drill-in (window refs are ephemeral) so it never outlives the windows it depicts.
    private var previewCache: [UUID: NSImage] = [:]
    /// Which sub-item the preview currently reflects; avoids redundant show/capture churn as the
    /// cursor jitters within one petal's arc.
    private var previewItemID: UUID?
    /// Bumped on every capture request so a slow capture that returns after the cursor has moved on
    /// is discarded instead of flashing a stale thumbnail.
    private var captureToken = 0

    init(itemsProvider: @escaping () -> [PetalItem],
         themeProvider: @escaping () -> FlowerTheme) {
        self.itemsProvider = itemsProvider
        self.themeProvider = themeProvider
        panel = FlowerPanel(size: FlowerLayout.panelSize)
        let hosting = NSHostingView(rootView: FlowerView(model: model))
        hosting.frame = NSRect(x: 0, y: 0, width: FlowerLayout.panelSize, height: FlowerLayout.panelSize)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        let previewHosting = NSHostingView(rootView: PreviewView(model: previewModel))
        previewHosting.autoresizingMask = [.width, .height]
        previewPanel.contentView = previewHosting
    }

    // MARK: - Show / hide

    func show() {
        let items = itemsProvider()
        guard !items.isEmpty else {
            NSSound.beep()  // nothing configured — give a hint rather than a silent no-op
            return
        }

        center = NSEvent.mouseLocation
        model.theme = themeProvider()   // pick up any theme change made in Settings
        model.items = items
        model.highlightedIndex = nil
        model.expandedIndex = nil
        model.subItems = []
        model.subHighlightedIndex = nil
        model.visible = false   // start collapsed so the fan-out animates

        previewModel.theme = model.theme
        previewCache.removeAll()   // fresh session — old window images are stale
        hidePreview()

        let origin = CGPoint(
            x: center.x - FlowerLayout.panelSize / 2,
            y: center.y - FlowerLayout.panelSize / 2
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()

        // Animate open on the next tick (after a render at the collapsed state).
        DispatchQueue.main.async { [weak self] in self?.model.visible = true }

        startPolling()
    }

    func hideAndSelect() {
        stopPolling()
        hidePreview()

        if let e = model.expandedIndex {
            // Drilled in: prefer the highlighted sub-petal (window / new-window); if the cursor
            // sits in the fan's gap, fall back to launching the anchored app.
            if let s = model.subHighlightedIndex, model.subItems.indices.contains(s) {
                onSelect?(model.subItems[s])
            } else if model.items.indices.contains(e) {
                onSelect?(model.items[e])
            }
        } else if let index = model.highlightedIndex, model.items.indices.contains(index) {
            onSelect?(model.items[index])
        }

        model.visible = false
        // Let the collapse animation play before pulling the panel.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.panel.orderOut(nil)
        }
    }

    // MARK: - Cursor tracking

    private func startPolling() {
        stopPolling()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateHighlight()
        }
        // `.common` keeps the timer alive during mouse-tracking run-loop mode.
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func updateHighlight() {
        let p = NSEvent.mouseLocation
        let dx = p.x - center.x
        let dy = p.y - center.y
        let distance = hypot(dx, dy)
        let cursorAngle = atan2(dy, dx)

        // Inside the deadzone nothing is selected, and any drill-down collapses.
        guard distance >= FlowerLayout.deadzone else {
            if model.highlightedIndex != nil { model.highlightedIndex = nil }
            collapse()
            return
        }

        let count = model.items.count
        guard count > 0 else { return }

        // Already drilled into an app: stay locked on it (so sliding along the wide arc doesn't
        // re-pick a different ring-1 app) and select among its sub-petals — unless the cursor is
        // pulled back inside the collapse threshold.
        if let expanded = model.expandedIndex {
            if distance < FlowerLayout.collapseThreshold {
                collapse()
                // Keep the just-collapsed app highlighted as the cursor pulls back in.
                if model.highlightedIndex != expanded { model.highlightedIndex = expanded }
            } else {
                selectSubPetal(cursorAngle: cursorAngle, base: FlowerLayout.angle(for: expanded, count: count))
                return
            }
        }

        // Ring 1: pick the app petal whose direction best matches the cursor. No window preview
        // out here — it belongs to the drilled-in sub-ring.
        hidePreview()
        let best = nearestPetal(to: cursorAngle, count: count)
        if model.highlightedIndex != best { model.highlightedIndex = best }

        // Drag out past the expand threshold over an app petal → drill into it.
        if distance >= FlowerLayout.expandThreshold,
           model.items.indices.contains(best),
           !model.items[best].isCommand {
            expand(appIndex: best)
        }
    }

    private func nearestPetal(to cursorAngle: Double, count: Int) -> Int {
        var best = 0
        var bestDelta = Double.greatestFiniteMagnitude
        for i in 0..<count {
            let delta = abs(angularDistance(cursorAngle, FlowerLayout.angle(for: i, count: count)))
            if delta < bestDelta { bestDelta = delta; best = i }
        }
        return best
    }

    private func selectSubPetal(cursorAngle: Double, base: Double) {
        let count = model.subItems.count
        guard count > 0 else { return }
        var best = 0
        var bestDelta = Double.greatestFiniteMagnitude
        for j in 0..<count {
            let delta = abs(angularDistance(cursorAngle, FlowerLayout.subAngle(for: j, count: count, base: base)))
            if delta < bestDelta { bestDelta = delta; best = j }
        }
        if model.subHighlightedIndex != best { model.subHighlightedIndex = best }
        updatePreview(forSubIndex: best)
    }

    /// Snapshot the app's windows and build the ephemeral sub-ring (windows + "New Window").
    private func expand(appIndex: Int) {
        guard model.items.indices.contains(appIndex),
              case .launchApp(let app) = model.items[appIndex].action else { return }

        // Cap the displayed windows so the fan never wraps back over the source petal.
        let windows = WindowEnumerator.windows(for: app).prefix(7)
        var subs: [PetalItem] = windows.map { w in
            PetalItem(name: w.title,
                      action: .focusWindow(WindowRef(element: w.element, pid: w.pid)),
                      symbolName: "macwindow")
        }
        subs.append(PetalItem(name: "New Window", action: .newWindow(app),
                              symbolName: "plus.rectangle.on.rectangle"))

        model.subItems = subs
        model.subHighlightedIndex = nil
        model.expandedIndex = appIndex

        previewCache.removeAll()   // sub-items just got fresh ids; drop the prior app's images
        hidePreview()
    }

    private func collapse() {
        if model.expandedIndex != nil {
            model.expandedIndex = nil
            model.subItems = []
            model.subHighlightedIndex = nil
        }
        hidePreview()
    }

    // MARK: - Window preview

    /// Show/refresh the hover thumbnail for the highlighted sub-petal. Only window petals
    /// (`.focusWindow`) get one — "New Window" and app petals don't. Uses the cache if present,
    /// otherwise captures off the main thread and applies the result if the hover hasn't moved on.
    private func updatePreview(forSubIndex j: Int) {
        guard model.subItems.indices.contains(j),
              case .focusWindow(let ref) = model.subItems[j].action else {
            hidePreview()
            return
        }

        let item = model.subItems[j]
        // Already showing this exact window? Nothing to do — avoids re-capturing on cursor jitter.
        if previewItemID == item.id { return }
        previewItemID = item.id
        captureToken += 1
        let token = captureToken

        if let cached = previewCache[item.id] {
            presentPreview(cached, forSubIndex: j)
            return
        }

        // Capture is async (ScreenCaptureKit) and its completion may land on a background thread —
        // hop to main and apply only if this is still the hover we requested.
        let element = ref.element
        WindowCapture.image(for: element) { [weak self] image in
            DispatchQueue.main.async {
                guard let self, token == self.captureToken else { return }   // stale — cursor moved
                guard let image else { self.hidePreview(); return }
                self.previewCache[item.id] = image
                self.presentPreview(image, forSubIndex: j)
            }
        }
    }

    /// Size the panel to the image's aspect ratio, park it just outside the sub-petal (clamped to
    /// the screen), and fade it in.
    private func presentPreview(_ image: NSImage, forSubIndex j: Int) {
        previewModel.theme = model.theme
        previewModel.image = image

        let content = fittedSize(for: image.size)
        let chrome = 2 * (PreviewView.framePadding + PreviewView.shadowPadding)
        let panelSize = NSSize(width: content.width + chrome, height: content.height + chrome)
        previewPanel.setContentSize(panelSize)
        previewPanel.setFrameOrigin(previewOrigin(forSubIndex: j, panelSize: panelSize))
        previewPanel.orderFrontRegardless()
        previewModel.visible = true
    }

    private func hidePreview() {
        previewItemID = nil
        // Called every poll tick while in ring 1 — bail cheaply once it's already down.
        guard previewModel.visible || previewPanel.isVisible else { return }
        previewModel.visible = false
        previewPanel.orderOut(nil)
    }

    /// Fit the window image within a comfortable thumbnail box, preserving aspect ratio.
    private func fittedSize(for size: NSSize) -> NSSize {
        let maxW: CGFloat = 380, maxH: CGFloat = 260
        guard size.width > 0, size.height > 0 else { return NSSize(width: maxW, height: maxH) }
        let scale = min(maxW / size.width, maxH / size.height)
        return NSSize(width: size.width * scale, height: size.height * scale)
    }

    /// Screen-space origin for the preview: push the card radially outward from the sub-petal so it
    /// sits beyond the ring (never covering a petal), then clamp so it stays fully on screen.
    private func previewOrigin(forSubIndex j: Int, panelSize: NSSize) -> CGPoint {
        guard let e = model.expandedIndex else {
            return CGPoint(x: center.x - panelSize.width / 2, y: center.y - panelSize.height / 2)
        }
        let base = FlowerLayout.angle(for: e, count: model.items.count)
        let a = FlowerLayout.subAngle(for: j, count: model.subItems.count, base: base)

        // Unit vector along the petal's direction (CGFloat to disambiguate cos/sin overloads).
        let ux = CGFloat(cos(a))
        let uy = CGFloat(sin(a))

        // Sub-petal center in AppKit screen coords (y up), then the card center pushed outward by
        // the petal's radius plus the card's bounding radius so the two never overlap.
        let petalX = center.x + ux * FlowerLayout.subRadius
        let petalY = center.y + uy * FlowerLayout.subRadius
        let push = FlowerLayout.subPetalSize / 2 + 10 + hypot(panelSize.width, panelSize.height) / 2
        var origin = CGPoint(x: petalX + ux * push - panelSize.width / 2,
                             y: petalY + uy * push - panelSize.height / 2)

        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        if let frame = screen?.frame {
            origin.x = min(max(origin.x, frame.minX + 4), frame.maxX - panelSize.width - 4)
            origin.y = min(max(origin.y, frame.minY + 4), frame.maxY - panelSize.height - 4)
        }
        return origin
    }

    /// Smallest signed angular difference between two angles, in [-π, π].
    private func angularDistance(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 2 * .pi)
        if d > .pi { d -= 2 * .pi }
        if d < -.pi { d += 2 * .pi }
        return d
    }
}
