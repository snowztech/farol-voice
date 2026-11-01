import AppKit

final class MenuBar: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let dictation: Dictation
    private let openSettings: () -> Void
    private let copyLast = NSMenuItem(title: "Copy Last Transcript", action: #selector(copyTranscript), keyEquivalent: "")

    init(dictation: Dictation, openSettings: @escaping () -> Void) {
        self.dictation = dictation
        self.openSettings = openSettings
        super.init()
        item.button?.image = Self.icon(lit: false)
        item.button?.setAccessibilityLabel("Farol Voice")
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        copyLast.target = self
        menu.addItem(copyLast)
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Farol Voice", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        dictation.onListeningChange = { [weak self] listening in self?.item.button?.image = Self.icon(lit: listening) }
    }

    func menuWillOpen(_ menu: NSMenu) {
        copyLast.isEnabled = dictation.lastTranscript != nil
    }

    @objc private func copyTranscript() {
        if let text = dictation.lastTranscript { Typer.copy(text) }
    }

    @objc private func showSettings() {
        openSettings()
    }

    /// Farol's lighthouse. Its beams light up while the mic is open.
    private static func icon(lit: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            let tower = NSBezierPath()
            tower.move(to: NSPoint(x: 6, y: 2.5))
            tower.line(to: NSPoint(x: 12, y: 2.5))
            tower.line(to: NSPoint(x: 10.6, y: 10.5))
            tower.line(to: NSPoint(x: 7.4, y: 10.5))
            tower.close()
            tower.fill()
            NSBezierPath(rect: NSRect(x: 4.5, y: 1.2, width: 9, height: 1.3)).fill()
            NSBezierPath(rect: NSRect(x: 7.6, y: 11.3, width: 2.8, height: 2.4)).fill()
            let roof = NSBezierPath()
            roof.move(to: NSPoint(x: 7.1, y: 14.3))
            roof.line(to: NSPoint(x: 10.9, y: 14.3))
            roof.line(to: NSPoint(x: 9, y: 16.4))
            roof.close()
            roof.fill()
            guard lit else { return true }
            NSColor.black.setStroke()
            for side in [CGFloat(-1), 1] {
                let beam = NSBezierPath()
                beam.lineWidth = 1.6
                beam.lineCapStyle = .round
                beam.lineJoinStyle = .round
                beam.move(to: NSPoint(x: 9 + side * 6.8, y: 14.6))
                beam.line(to: NSPoint(x: 9 + side * 3.6, y: 12.5))
                beam.line(to: NSPoint(x: 9 + side * 6.8, y: 10.4))
                beam.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
