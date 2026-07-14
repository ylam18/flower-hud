import AppKit
import SwiftUI

/// First-run guided setup. Walks a new user through the two permissions Flower can
/// use — Accessibility (required) and Screen Recording (optional) — each with a button
/// to the exact System Settings pane and a live status that flips to a checkmark the
/// instant the grant lands (driven by a poll timer, same idea as `AppDelegate`'s tap
/// wait). Shown once; a UserDefaults flag records completion.
///
/// This does NOT start the trigger tap — `AppDelegate` still owns that via its own
/// Accessibility poll, so the tap arms whether or not this window is on screen.
final class OnboardingController {
    private var window: NSWindow?
    private let model = OnboardingModel()
    private var poll: Timer?

    private static let completedKey = "FlowerHUDHasCompletedOnboarding"

    /// Whether the user has already been through first-run setup.
    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    var isShowing: Bool { window != nil }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        model.refresh()
        let view = OnboardingView(
            model: model,
            openAccessibility: { Accessibility.openSettings() },
            // Just jump to the pane — no `request()`. Firing the system request here
            // pops a redundant "Flower needs Screen Recording" dialog on top of the
            // Settings window the user explicitly asked for. Flower is already in the
            // list because the poll below calls the (non-prompting) preflight.
            openScreenRecording: { ScreenRecording.openSettings() },
            relaunch: { AppRelauncher.relaunch() },
            finish: { [weak self] in self?.finish() }
        )

        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Welcome to Flower"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.center()
        window = win

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startPolling()
    }

    /// Refresh the checklist once a second so grants reflect live without a relaunch.
    private func startPolling() {
        poll?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.model.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        poll = timer
    }

    private func finish() {
        Self.markCompleted()
        poll?.invalidate()
        poll = nil
        window?.close()
        window = nil
    }
}

/// Observable permission state backing the onboarding view.
private final class OnboardingModel: ObservableObject {
    @Published var accessibilityGranted = false
    @Published var screenRecordingGranted = false

    func refresh() {
        let ax = Accessibility.isTrusted
        let sr = ScreenRecording.isGranted
        if ax != accessibilityGranted { accessibilityGranted = ax }
        if sr != screenRecordingGranted { screenRecordingGranted = sr }
    }
}

private struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    let openAccessibility: () -> Void
    let openScreenRecording: () -> Void
    let relaunch: () -> Void
    let finish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to Flower 🌸")
                    .font(.title2).bold()
                Text("Hold your trigger and a ring of your apps blooms around the cursor. Two quick permissions and you're set.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                PermissionRow(
                    title: "Accessibility",
                    requirement: "Required",
                    detail: "Lets Flower detect your trigger button anywhere on screen. The trigger starts working the moment you turn this on — no relaunch.",
                    granted: model.accessibilityGranted,
                    action: openAccessibility
                )
                PermissionRow(
                    title: "Screen Recording",
                    requirement: "Optional",
                    detail: "Shows a live thumbnail when you drill into an app's windows. After switching it on in Settings, click Relaunch so Flower picks it up.",
                    granted: model.screenRecordingGranted,
                    action: openScreenRecording,
                    // Screen Recording only applies to a fresh process, and macOS's own
                    // "Quit & Reopen" is unreliable for menu-bar apps — offer a relaunch
                    // that actually works.
                    secondaryTitle: "Relaunch",
                    secondaryAction: relaunch
                )
            }

            HStack {
                if model.accessibilityGranted {
                    Label("You're all set.", systemImage: "checkmark.seal.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                } else {
                    Text("Grant Accessibility above to start using Flower.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done", action: finish)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 460)
    }
}

private struct PermissionRow: View {
    let title: String
    let requirement: String
    let detail: String
    let granted: Bool
    let action: () -> Void
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(granted ? .green : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title).font(.headline)
                    Text(requirement)
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.secondary.opacity(0.15), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if granted {
                Text("Granted")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .trailing, spacing: 6) {
                    Button("Open Settings", action: action)
                    if let secondaryTitle, let secondaryAction {
                        Button(secondaryTitle, action: secondaryAction)
                    }
                }
            }
        }
        .padding(14)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
