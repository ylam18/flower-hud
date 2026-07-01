import AppKit
import SwiftUI
import CoreGraphics

/// A button that, while "recording", captures the next key press or mouse-button press
/// (including side buttons). The captured value is held as `pending` and only applied to
/// the bound `trigger` once the user presses Confirm. Left and right mouse buttons are
/// rejected — they're primary buttons and would be unusable if bound.
struct TriggerRecorder: View {
    @Binding var trigger: Trigger
    @State private var recording = false
    /// A captured-but-not-yet-confirmed trigger. Discarded if the user navigates away.
    @State private var pending: Trigger?
    /// A transient hint shown when the user presses a disallowed button.
    @State private var rejection: String?
    @State private var monitors: [Any] = []

    /// The value shown on the record button: a pending capture, else the live binding.
    private var displayed: Trigger { pending ?? trigger }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Button(action: toggle) {
                    Text(recording ? "Press any key or mouse button…" : displayed.displayName)
                        .frame(minWidth: 200)
                }
                .buttonStyle(.bordered)
                .tint(recording ? .red : nil)

                Button("Confirm", action: confirm)
                    .buttonStyle(.borderedProminent)
                    .disabled(pending == nil || pending == trigger)
            }
            if let rejection {
                Text(rejection)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onDisappear(perform: stop)
    }

    private func toggle() {
        if recording { stop() } else { start() }
    }

    private func confirm() {
        if let pending { trigger = pending }
        self.pending = nil
        rejection = nil
    }

    private func start() {
        recording = true
        rejection = nil
        // Defer install by one tick so the click that started recording isn't captured.
        DispatchQueue.main.async {
            let events: NSEvent.EventTypeMask = [
                .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown
            ]
            let local = NSEvent.addLocalMonitorForEvents(matching: events) { event in
                switch event.type {
                case .keyDown:
                    // Escape cancels without capturing.
                    if event.keyCode == 53 { self.stop(); return nil }
                    self.pending = .keyboard(keyCode: event.keyCode,
                                             modifiers: self.cgFlags(from: event.modifierFlags))
                    self.rejection = nil
                    self.stop()
                    return nil // swallow the recording event
                case .leftMouseDown, .rightMouseDown:
                    // Primary buttons can't be bound — swallow the click and keep recording.
                    self.rejection = "The left and right mouse buttons can’t be used. Try a side button or a key."
                    return nil
                case .otherMouseDown:
                    self.pending = .mouse(button: event.buttonNumber)
                    self.rejection = nil
                    self.stop()
                    return nil
                default:
                    return event
                }
            }
            if let local { self.monitors.append(local) }
        }
    }

    private func stop() {
        recording = false
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors.removeAll()
    }

    private func cgFlags(from flags: NSEvent.ModifierFlags) -> UInt64 {
        var raw: UInt64 = 0
        if flags.contains(.command) { raw |= CGEventFlags.maskCommand.rawValue }
        if flags.contains(.shift) { raw |= CGEventFlags.maskShift.rawValue }
        if flags.contains(.control) { raw |= CGEventFlags.maskControl.rawValue }
        if flags.contains(.option) { raw |= CGEventFlags.maskAlternate.rawValue }
        return raw
    }
}
