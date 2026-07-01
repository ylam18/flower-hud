import AppKit
import CoreGraphics

/// Watches global input via a `CGEventTap` and reports press / release of the configured trigger.
///
/// A single tap handles both mouse buttons and keyboard keys. The matched trigger event is
/// *consumed* (so e.g. a key bound as the trigger doesn't also type, and a held mouse button
/// doesn't also click); every other event passes straight through untouched.
final class TriggerMonitor {
    var trigger: Trigger
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isPressed = false

    init(trigger: Trigger) {
        self.trigger = trigger
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: triggerTapCallback,
            userInfo: selfPtr
        ) else {
            return false
        }

        eventTap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
    }

    /// Returns true if the event should be consumed (not propagated to other apps).
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        // The system can disable a tap that takes too long or on certain input; re-arm it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }

        switch trigger {
        case .keyboard(let code, let mods):
            guard type == .keyDown || type == .keyUp else { return false }
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            guard keyCode == code else { return false }
            let flags = event.flags.rawValue & Trigger.modifierMask
            guard flags == (mods & Trigger.modifierMask) else { return false }

            if type == .keyDown {
                // Key auto-repeat fires repeated keyDowns; only the first is a "press".
                if !isPressed { isPressed = true; onPress?() }
            } else {
                if isPressed { isPressed = false; onRelease?() }
            }
            return true // consume so the key doesn't type while bound as the trigger

        case .mouse(let button):
            let isDown = (type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown)
            let isUp = (type == .leftMouseUp || type == .rightMouseUp || type == .otherMouseUp)
            guard isDown || isUp else { return false }
            let btn = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            guard btn == button else { return false }

            if isDown {
                if !isPressed { isPressed = true; onPress?() }
            } else {
                if isPressed { isPressed = false; onRelease?() }
            }
            return true // consume so the bound button doesn't also register a normal click
        }
    }

    deinit { stop() }
}

/// C-compatible tap callback. Recovers the monitor instance from `userInfo` and asks it
/// whether to consume the event. Runs on the main run loop (where the source is installed).
private func triggerTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<TriggerMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    let consume = monitor.handle(type: type, event: event)
    return consume ? nil : Unmanaged.passUnretained(event)
}
