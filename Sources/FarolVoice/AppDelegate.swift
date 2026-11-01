import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?
    private var setupWindow: NSWindow?
    private var menuBar: MenuBar?
    private var dictation: Dictation?
    private let library = ModelLibrary()
    private let preferences = Preferences()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let dictation = Dictation(library: library, preferences: preferences, openSettings: { [weak self] in self?.showSettings() })
        self.dictation = dictation
        menuBar = MenuBar(dictation: dictation, library: library, preferences: preferences, openSettings: { [weak self] in self?.showSettings() })
        dictation.begin()
        if !preferences.setupDone {
            showSetup()
        } else if !library.isReady || !Permissions.accessibility || Permissions.microphone != .authorized {
            showSettings()
        }
    }

    private func showSetup() {
        let view = SetupView(library: library, preferences: preferences) { [weak self] in
            self?.preferences.setupDone = true
            self?.setupWindow?.close()
        }
        let window = Self.window(title: "Set up Farol Voice", rootView: view)
        setupWindow = window
        present(window)
    }

    private func showSettings() {
        let window = settingsWindow ?? Self.window(title: "Farol Voice", rootView: SettingsView(library: library, preferences: preferences))
        settingsWindow = window
        present(window)
    }

    private func present(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// The window takes its size from its content, so there's never an empty gap or a scroll bar.
    private static func window<Content: View>(title: String, rootView: Content) -> NSWindow {
        let host = NSHostingController(rootView: rootView)
        host.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.title = title
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = Theme.window
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
