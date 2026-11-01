import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?
    private var menuBar: MenuBar?
    private var dictation: Dictation?
    private let library = ModelLibrary()
    private let preferences = Preferences()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let dictation = Dictation(library: library, preferences: preferences, openSettings: { [weak self] in self?.showSettings() })
        self.dictation = dictation
        menuBar = MenuBar(dictation: dictation, openSettings: { [weak self] in self?.showSettings() })
        dictation.begin()
        if !library.isReady || !Permissions.accessibility || Permissions.microphone != .authorized {
            showSettings()
        }
    }

    private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Farol Voice"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(library: library, preferences: preferences))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
