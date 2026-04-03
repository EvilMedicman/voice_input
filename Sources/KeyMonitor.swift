import Cocoa

final class KeyMonitor {
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isPressed = false

    var triggerKey: TriggerKey {
        didSet {
            isPressed = false
        }
    }

    init(triggerKey: TriggerKey) {
        self.triggerKey = triggerKey
    }

    func start() {
        stop()

        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .keyUp]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == triggerKey.keyCode else {
            return
        }

        if triggerKey.usesFlagsChanged {
            guard event.type == .flagsChanged else {
                return
            }

            let pressed = triggerKey.matchesPressedState(for: event)

            if pressed && !isPressed {
                isPressed = true
                onPressed?()
            } else if !pressed && isPressed {
                isPressed = false
                onReleased?()
            }

            return
        }

        switch event.type {
        case .keyDown:
            guard !event.isARepeat, !isPressed else {
                return
            }

            isPressed = true
            onPressed?()
        case .keyUp:
            guard isPressed else {
                return
            }

            isPressed = false
            onReleased?()
        default:
            break
        }
    }
}

