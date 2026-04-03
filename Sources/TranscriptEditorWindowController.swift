import Cocoa

final class TranscriptEditorWindowController: NSObject, NSWindowDelegate {
    var onInsert: ((String) -> TextInjectionResult)?

    private let window: NSWindow
    private let titleLabel = NSTextField(labelWithString: "Текст готов")
    private let hintLabel = NSTextField(labelWithString: "Подправьте текст, затем скопируйте или вставьте его.")
    private let feedbackLabel = NSTextField(labelWithString: "")
    private let scrollView: NSScrollView
    private let textView: NSTextView
    private lazy var copyButton = makeButton(title: "Скопировать", action: #selector(didCopy))
    private lazy var insertButton = makeButton(title: "Вставить", action: #selector(didInsert))
    private lazy var closeButton = makeButton(title: "Закрыть", action: #selector(didClose))

    override init() {
        let textView = NSTextView(frame: .zero)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.textContainerInset = NSSize(width: 18, height: 18)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let scrollView = NSScrollView(frame: .zero)
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        scrollView.drawsBackground = true

        textView.frame = NSRect(x: 0, y: 0, width: 700, height: 360)
        textView.textContainer?.containerSize = NSSize(width: 700, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        self.textView = textView
        self.scrollView = scrollView
        self.window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init()
        configure()
    }

    func present(transcript: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            let normalized = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            self.feedbackLabel.stringValue = normalized.isEmpty ? "Распознавание вернуло пустой текст." : ""
            self.feedbackLabel.textColor = normalized.isEmpty ? .systemRed : .secondaryLabelColor
            self.textView.string = normalized.isEmpty ? "" : normalized
            self.textView.setSelectedRange(NSRange(location: self.textView.string.count, length: 0))
            self.window.center()
            self.window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            self.window.makeFirstResponder(self.textView)
        }
    }

    func close() {
        DispatchQueue.main.async { [weak self] in
            self?.window.orderOut(nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        feedbackLabel.stringValue = ""
    }

    private func configure() {
        window.title = "VoiceInput"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        contentView.wantsLayer = true
        window.contentView = contentView

        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        hintLabel.font = .systemFont(ofSize: 13, weight: .regular)
        hintLabel.textColor = .secondaryLabelColor
        feedbackLabel.font = .systemFont(ofSize: 12, weight: .medium)
        feedbackLabel.textColor = .secondaryLabelColor

        let buttonRow = NSStackView(views: [copyButton, insertButton, closeButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 10

        [titleLabel, hintLabel, scrollView, buttonRow, feedbackLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            hintLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            hintLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            hintLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            scrollView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            scrollView.bottomAnchor.constraint(equalTo: buttonRow.topAnchor, constant: -16),

            buttonRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            buttonRow.bottomAnchor.constraint(equalTo: feedbackLabel.topAnchor, constant: -12),

            feedbackLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            feedbackLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            feedbackLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ])
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    private func currentText() -> String {
        textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func showFeedback(_ message: String, isError: Bool = false) {
        feedbackLabel.stringValue = message
        feedbackLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    @objc private func didCopy() {
        let text = currentText()

        guard !text.isEmpty else {
            showFeedback("Пока нечего копировать.", isError: true)
            return
        }

        copyToClipboard(text)
        close()
    }

    @objc private func didInsert() {
        let text = currentText()

        guard !text.isEmpty else {
            showFeedback("Пока нечего вставлять.", isError: true)
            return
        }

        guard let onInsert else {
            showFeedback("Вставка сейчас недоступна.", isError: true)
            return
        }

        let result = onInsert(text)

        switch result {
        case .typed:
            close()
        case .copiedToClipboard:
            showFeedback("Нет доступа к вставке. Текст скопирован в буфер.")
        case .empty:
            showFeedback("Пока нечего вставлять.", isError: true)
        case .unavailable:
            showFeedback("Включите Accessibility для автоматической вставки.", isError: true)
        }
    }

    @objc private func didClose() {
        close()
    }
}
