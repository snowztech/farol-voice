import AppKit

final class MenuBar: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let dictation: Dictation
    private let library: ModelLibrary
    private let preferences: Preferences
    private let openSettings: () -> Void
    private let status = NSMenuItem(title: "", action: #selector(showSettings), keyEquivalent: "")
    private let model = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let copyLast = NSMenuItem(title: "Copy Last Transcript", action: #selector(copyTranscript), keyEquivalent: "")

    init(dictation: Dictation, library: ModelLibrary, preferences: Preferences, openSettings: @escaping () -> Void) {
        self.dictation = dictation
        self.library = library
        self.preferences = preferences
        self.openSettings = openSettings
        super.init()
        item.button?.image = Self.icon(lit: false)
        item.button?.setAccessibilityLabel("Farol Voice")
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        status.target = self
        model.isEnabled = false
        copyLast.target = self
        menu.addItem(status)
        menu.addItem(model)
        menu.addItem(.separator())
        menu.addItem(copyLast)
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Farol Voice", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        dictation.onListeningChange = { [weak self] listening in self?.item.button?.image = Self.icon(lit: listening) }
    }

    /// Says what to do next, which turns into the way to fix it when something's missing.
    func menuWillOpen(_ menu: NSMenu) {
        copyLast.isEnabled = dictation.lastTranscript != nil
        model.title = library.isReady ? library.chosen.title : "No model installed"
        if !Permissions.accessibility || Permissions.microphone != .authorized {
            status.title = "Needs your OK…"
            status.isEnabled = true
        } else if !library.isReady {
            status.title = "Install a model…"
            status.isEnabled = true
        } else {
            status.title = "Hold \(preferences.talkKey.title) to talk"
            status.isEnabled = false
        }
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
