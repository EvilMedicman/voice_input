import Cocoa

final class OverlayWindowController {
    private let panel: NSPanel
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 180),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.ignoresMouseEvents = true

        let effectView = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .hudWindow
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 24
        effectView.layer?.masksToBounds = true

        let contentView = NSView(frame: effectView.bounds)
        contentView.autoresizingMask = [.width, .height]

        titleLabel.font = .systemFont(ofSize: 30, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.font = .systemFont(ofSize: 18, weight: .regular)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.92)
        subtitleLabel.alignment = .center
        subtitleLabel.maximumNumberOfLines = 4
        subtitleLabel.lineBreakMode = .byWordWrapping

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        effectView.addSubview(contentView)
        panel.contentView = effectView

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),

            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 18),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -28)
        ])

        self.panel = panel
    }

    func showRecording(triggerKeyTitle: String, transcript: String) {
        DispatchQueue.main.async { [weak self] in
            self?.show(title: "Говорите", subtitle: transcript.isEmpty ? "Удерживайте \(triggerKeyTitle) и диктуйте текст" : transcript)
        }
    }

    func showTranscribing() {
        DispatchQueue.main.async { [weak self] in
            self?.show(title: "Обрабатываю", subtitle: "Финализирую текст и готовлю вставку")
        }
    }

    func showError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.show(title: "Нужно внимание", subtitle: message)
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.panel.orderOut(nil)
        }
    }

    private func show(title: String, subtitle: String) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        centerPanel()
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    private func centerPanel() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let frame = panel.frame
        let x = screen.frame.midX - frame.width / 2
        let y = screen.frame.midY - frame.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
