import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)

#if DEBUG
if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), index + 1 < CommandLine.arguments.count {
    Snapshot.run(into: CommandLine.arguments[index + 1])
    exit(0)
}
#endif

app.run()
