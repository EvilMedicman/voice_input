import Cocoa

enum TriggerKey: String, CaseIterable {
    case rightOption
    case rightCommand
    case f18
    case f19

    var title: String {
        switch self {
        case .rightOption:
            return "Правый Option"
        case .rightCommand:
            return "Правый Command"
        case .f18:
            return "F18"
        case .f19:
            return "F19"
        }
    }

    var keyCode: UInt16 {
        switch self {
        case .rightOption:
            return 61
        case .rightCommand:
            return 54
        case .f18:
            return 79
        case .f19:
            return 80
        }
    }

    var usesFlagsChanged: Bool {
        switch self {
        case .rightOption, .rightCommand:
            return true
        case .f18, .f19:
            return false
        }
    }

    func matchesPressedState(for event: NSEvent) -> Bool {
        switch self {
        case .rightOption:
            return event.modifierFlags.contains(.option)
        case .rightCommand:
            return event.modifierFlags.contains(.command)
        case .f18, .f19:
            return event.type == .keyDown
        }
    }
}
