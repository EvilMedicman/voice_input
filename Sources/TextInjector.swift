import ApplicationServices
import Cocoa

enum TextInjectionResult {
    case typed
    case copiedToClipboard
    case empty
    case unavailable
}

final class TextInjector {
    func insert(_ text: String) -> TextInjectionResult {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return .empty
        }

        if type(normalized) {
            return .typed
        }

        copyToClipboard(normalized)
        return .copiedToClipboard
    }

    func syncLiveText(from oldText: String, to newText: String) -> TextInjectionResult {
        guard AXIsProcessTrusted() else {
            return .unavailable
        }

        let oldCharacters = Array(oldText)
        let newCharacters = Array(newText)
        let sharedPrefixCount = commonPrefixLength(lhs: oldCharacters, rhs: newCharacters)
        let deleteCount = oldCharacters.count - sharedPrefixCount
        let suffix = String(newCharacters.dropFirst(sharedPrefixCount))

        if deleteCount > 0, !pressDeleteBackward(count: deleteCount) {
            return .unavailable
        }

        if !suffix.isEmpty, !type(suffix) {
            return .unavailable
        }

        return .typed
    }

    private func type(_ text: String) -> Bool {
        guard AXIsProcessTrusted() else {
            return false
        }

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            return false
        }

        let utf16 = Array(text.utf16)
        let unicode = utf16.map { UniChar($0) }

        keyDown.keyboardSetUnicodeString(stringLength: unicode.count, unicodeString: unicode)
        keyUp.keyboardSetUnicodeString(stringLength: unicode.count, unicodeString: unicode)

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }

    private func pressDeleteBackward(count: Int) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        for _ in 0 ..< count {
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false) else {
                return false
            }

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }

        return true
    }

    private func commonPrefixLength(lhs: [Character], rhs: [Character]) -> Int {
        let count = min(lhs.count, rhs.count)
        var prefixLength = 0

        while prefixLength < count, lhs[prefixLength] == rhs[prefixLength] {
            prefixLength += 1
        }

        return prefixLength
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
