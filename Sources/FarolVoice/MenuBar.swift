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

    /// Sound bars, which grow while the mic is open. Not Farol's lighthouse, so the two apps can sit side by side.
    private static func icon(lit: Bool) -> NSImage {
        let heights: [CGFloat] = lit ? [7, 12, 16, 12, 7] : [4, 8, 12, 8, 4]
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            for (index, height) in heights.enumerated() {
                let x = 2.5 + CGFloat(index) * 2.8
                let bar = NSRect(x: x, y: (18 - height) / 2, width: 1.8, height: height)
                NSBezierPath(roundedRect: bar, xRadius: 0.9, yRadius: 0.9).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
