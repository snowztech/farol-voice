#if DEBUG
import AppKit
import SwiftUI

/// `FarolVoice --snapshot <folder>` renders the screens to images, for looking at the design without clicking through it. Debug builds only.
enum Snapshot {
    static func run(into folder: String) {
        let library = ModelLibrary()
        let preferences = Preferences()
        let signal = VoiceSignal()
        signal.target = 0.8
        for _ in 0..<30 { _ = signal.step() }
        NSApp.applicationIconImage = NSImage(contentsOfFile: "assets/FarolVoice.icns")
        for section in SettingsView.Section.allCases {
            save(SettingsView(library: library, preferences: preferences, section: section, farolStatus: .needsSetting), "settings-\(section.rawValue)", folder)
        }
        save(SetupView(library: library, preferences: preferences) {}, "setup", folder)
        for size in WaveSize.allCases {
            save(PillView(content: .listening(command: false), signal: signal, size: size), "pill-listening-\(size.rawValue)", folder)
            save(PillView(content: .listening(command: true), signal: signal, size: size), "pill-command-\(size.rawValue)", folder)
            save(PillView(content: .working, signal: signal, size: size), "pill-working-\(size.rawValue)", folder)
        }
        save(PillView(content: .message("Copied to the clipboard"), signal: signal), "pill-message", folder)
    }

    private static func save<Content: View>(_ view: Content, _ name: String, _ folder: String) {
        let host = NSHostingView(rootView: view.preferredColorScheme(.dark))
        host.appearance = NSAppearance(named: .darkAqua)
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Theme.window
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        guard let image = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: image)
        try? image.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(folder)/\(name).png"))
    }
}
#endif
