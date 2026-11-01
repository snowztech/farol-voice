import AppKit
import Carbon.HIToolbox

/// Types into whatever app is in front, by pasting: it handles any language and any length, and works in terminals.
enum Typer {
    enum Outcome {
        case typed
        /// It couldn't go where you were, so it's on the clipboard, with the reason.
        case copied(String)
        /// A password field has focus. It stays out of the clipboard too.
        case refused
    }

    /// Long enough for the app in front to read the paste before the clipboard goes back to what you had.
    /// ponytail: a fixed wait, a very slow app could read the old clipboard. A longer wait if it ever shows up.
    private static let restoreDelay: TimeInterval = 0.5
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    static func insert(_ text: String, into app: pid_t?) -> Outcome {
        if IsSecureEventInputEnabled() { return .refused }
        guard Permissions.accessibility else {
            copy(text)
            return .copied("Allow Accessibility to type")
        }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app else {
            copy(text)
            return .copied("You switched apps")
        }
        let pasteboard = NSPasteboard.general
        let saved = snapshot(pasteboard)
        pasteboard.clearContents()
        // Marked transient so clipboard managers skip it, since it isn't something you copied.
        pasteboard.setString("", forType: transientType)
        pasteboard.setString(text, forType: .string)
        let ours = pasteboard.changeCount
        pressPaste()
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            // If something else was copied meanwhile, that one wins.
            guard pasteboard.changeCount == ours else { return }
            pasteboard.clearContents()
            pasteboard.writeObjects(saved)
        }
        return .typed
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private static func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    /// ponytail: the physical V key, which is wrong on layouts like Dvorak. Look it up from the layout if someone hits it.
    private static func pressPaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
