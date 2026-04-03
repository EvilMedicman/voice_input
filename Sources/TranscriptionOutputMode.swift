import Foundation

enum TranscriptionOutputMode: String, CaseIterable {
    case instantInsert
    case editorWindow

    var shortTitle: String {
        switch self {
        case .instantInsert:
            return "Моментальная вставка"
        case .editorWindow:
            return "Через окно редактора"
        }
    }

    var menuTitle: String {
        switch self {
        case .instantInsert:
            return "Моментальная вставка в текущее поле"
        case .editorWindow:
            return "Показать текст в окне редактора"
        }
    }
}
