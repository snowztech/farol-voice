import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?
    private var setupWindow: NSWindow?
    private var menuBar: MenuBar?
    private var dictation: Dictation?
    private let library = ModelLibrary()
    private let preferences = Preferences()
    private let updates = Updates()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = Self.editMenu()
        let dictation = Dictation(library: library, preferences: preferences, openSettings: { [weak self] in self?.showSettings() })
        self.dictation = dictation
        menuBar = MenuBar(dictation: dictation, library: library, preferences: preferences, updates: updates, openSettings: { [weak self] in self?.showSettings() })
        dictation.begin()
        if !preferences.setupDone {
            showSetup()
        } else if !library.isReady || !Permissions.accessibility || Permissions.microphone != .authorized {
            showSettings()
        }
    }

    /// Never shown, since this app has no menu bar of its own. Without it, text fields here ignore ⌘V, ⌘C and the rest, including the paste that types your words.
    static func editMenu() -> NSMenu {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let item = NSMenuItem()
        item.submenu = edit
        let main = NSMenu()
        main.addItem(NSMenuItem())
        main.addItem(item)
        return main
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
