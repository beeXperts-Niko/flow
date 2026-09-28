import Cocoa

enum Hotkey: String, CaseIterable {
    case rightOption
    case rightCommand
    case rightControl
    case function
    case leftControl

    var keyCode: UInt16 {
        switch self {
        case .rightOption: return 61
        case .rightCommand: return 54
        case .rightControl: return 62
        case .function: return 63
        case .leftControl: return 59
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .rightOption: return .option
        case .rightCommand: return .command
        case .rightControl, .leftControl: return .control
        case .function: return .function
        }
    }

    var cgFlag: CGEventFlags {
        switch self {
        case .rightOption: return .maskAlternate
        case .rightCommand: return .maskCommand
        case .rightControl, .leftControl: return .maskControl
        case .function: return .maskSecondaryFn
        }
    }

    var symbol: String {
        switch self {
        case .rightOption: return L10n.s("hotkey.rightOption.symbol")
        case .rightCommand: return L10n.s("hotkey.rightCommand.symbol")
        case .rightControl: return L10n.s("hotkey.rightControl.symbol")
        case .function: return L10n.s("hotkey.function.symbol")
        case .leftControl: return L10n.s("hotkey.leftControl.symbol")
        }
    }

    var title: String {
        switch self {
        case .rightOption: return L10n.s("hotkey.rightOption")
        case .rightCommand: return L10n.s("hotkey.rightCommand")
        case .rightControl: return L10n.s("hotkey.rightControl")
        case .function: return L10n.s("hotkey.function")
        case .leftControl: return L10n.s("hotkey.leftControl")
        }
    }
}

/// Globale Diktiertaste über CGEvent-Tap (zuverlässiger als NSEvent-Monitore).
final class HotkeyMonitor {
    var hotkey: Hotkey = .function {
        didSet { /* nächster Event nutzt die neue Taste */ }
    }
    var onPress: (() -> Void)?
    var onHoldStart: (() -> Void)?
    var onHoldEnd: (() -> Void)?
    var onToggle: (() -> Void)?
    var onEscape: (() -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var localMonitors: [Any] = []

    private var armed = false
    private var holdActive = false
    private var lastTap: Date?
    private var armToken = UUID()
    private let holdDelay: TimeInterval = 0.18

    func start() {
        stop()
        installTap()
        // Lokal zusätzlich, falls Flow selbst im Vordergrund ist.
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            guard let self else { return event }
            self.handleFlags(keyCode: event.keyCode, down: event.modifierFlags.contains(self.hotkey.flag))
            return event
        }) {
            localMonitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            self?.handleKey(keyCode: event.keyCode)
            return event
        }) {
            localMonitors.append(monitor)
        }
    }

    func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            self.source = nil
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            self.tap = nil
        }
        for monitor in localMonitors {
            NSEvent.removeMonitor(monitor)
        }
        localMonitors.removeAll()
        armed = false
        holdActive = false
    }

    private func installTap() {
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        let unmanaged = Unmanaged.passUnretained(self)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleCGEvent(type: type, event: event)
            },
            userInfo: unmanaged.toOpaque()
        ) else {
            // Ohne Bedienungshilfen schlägt der Tap fehl – globale Monitore als Fallback.
            if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
                guard let self else { return }
                self.handleFlags(keyCode: event.keyCode, down: event.modifierFlags.contains(self.hotkey.flag))
            }) {
                localMonitors.append(monitor)
            }
            if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
                self?.handleKey(keyCode: event.keyCode)
            }) {
                localMonitors.append(monitor)
            }
            return
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleCGEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .flagsChanged {
            let down = event.flags.contains(hotkey.cgFlag)
            // Nur reagieren, wenn dieser Modifier-Keycode betroffen ist.
            if keyCode == hotkey.keyCode {
                DispatchQueue.main.async { [weak self] in
                    self?.handleFlags(keyCode: keyCode, down: down)
                }
            }
        } else if type == .keyDown {
            DispatchQueue.main.async { [weak self] in
                self?.handleKey(keyCode: keyCode)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleFlags(keyCode: UInt16, down: Bool) {
        guard keyCode == hotkey.keyCode else { return }
        if down {
            onPress?()
            armed = true
            let token = UUID()
            armToken = token
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDelay) { [weak self] in
                guard let self, self.armed, self.armToken == token, !self.holdActive else { return }
                self.holdActive = true
                self.onHoldStart?()
            }
        } else {
            let wasHold = holdActive
            let wasArmed = armed
            armed = false
            holdActive = false
            if wasHold {
                onHoldEnd?()
                return
            }
            guard wasArmed else { return }
            let now = Date()
            if let lastTap, now.timeIntervalSince(lastTap) < 0.45 {
                self.lastTap = nil
                onToggle?()
            } else {
                lastTap = now
            }
        }
    }

    private func handleKey(keyCode: UInt16) {
        if keyCode == 53 {
            onEscape?()
            return
        }
        if armed && !holdActive {
            armed = false
        }
    }
}
