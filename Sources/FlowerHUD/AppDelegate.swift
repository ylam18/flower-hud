import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PresetStore.shared
    private var triggerMonitor: TriggerMonitor!
    private var flowerController: FlowerController!
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()
    private var accessibilityPoll: Timer?
    private let accessibilityPrompt = AccessibilityPromptController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()

        flowerController = FlowerController(itemsProvider: { [store] in store.currentItems },
                                            themeProvider: { [store] in store.theme })
        flowerController.onSelect = { item in PetalLauncher.run(item) }

        triggerMonitor = TriggerMonitor(trigger: store.trigger)
        triggerMonitor.onPress = { [weak self] in self?.flowerController.show() }
        triggerMonitor.onRelease = { [weak self] in self?.flowerController.hideAndSelect() }

        // Keep the live monitor in sync when the user rebinds the trigger in Settings.
        store.$trigger
            .sink { [weak self] newTrigger in self?.triggerMonitor.trigger = newTrigger }
            .store(in: &cancellables)

        startMonitoring()
    }

    private func startMonitoring() {
        if Accessibility.isTrusted {
            beginTap()
        } else {
            // Register the app in the Accessibility list (no lingering system prompt),
            // show our own dismissable prompt, and poll so the trigger starts working
            // the moment access is granted — no quit-and-relaunch required.
            Accessibility.register()
            accessibilityPrompt.show()
            waitForAccessibility()
        }
    }

    private func beginTap() {
        if !triggerMonitor.start() {
            presentAlert(
                title: "Couldn’t start input monitoring",
                message: "Flower failed to create a global event tap even though Accessibility access appears granted. Try toggling Flower off and on in System Settings → Privacy & Security → Accessibility."
            )
        }
    }

    /// Polls for the Accessibility grant and starts the tap as soon as it lands.
    private func waitForAccessibility() {
        accessibilityPoll?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard Accessibility.isTrusted else { return }
            self.accessibilityPoll?.invalidate()
            self.accessibilityPoll = nil
            self.accessibilityPrompt.dismiss()
            self.beginTap()
        }
        RunLoop.main.add(timer, forMode: .common)
        accessibilityPoll = timer
    }

    // MARK: - Status bar menu

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // Prefer the bundled colored flower; fall back to an SF Symbol, then text.
            if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                // Scale to the menu-bar height, preserving the flower's aspect ratio.
                let height: CGFloat = 18
                let width = height * (img.size.width / max(img.size.height, 1))
                img.size = NSSize(width: width, height: height)
                img.isTemplate = false // keep the orange/green color
                button.image = img
            } else if let img = NSImage(systemSymbolName: "camera.macro", accessibilityDescription: "Flower") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "❀"
            }
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Flower", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Accessibility…", action: #selector(openAccessibility), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Flower", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if let win = settingsWindow {
            win.makeKeyAndOrderFront(nil)
            return
        }
        let view = SettingsView(store: store)
        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Flower Settings"
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.setContentSize(NSSize(width: 480, height: 420))
        win.center()
        win.isReleasedWhenClosed = false
        settingsWindow = win
        win.makeKeyAndOrderFront(nil)
    }

    @objc private func openAccessibility() {
        Accessibility.openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            Accessibility.openSettings()
        }
    }
}
