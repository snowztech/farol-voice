import AVFoundation
import ServiceManagement
import SwiftUI
import VoiceCore

struct SettingsView: View {
    enum Section: String, CaseIterable {
        case general = "General"
        case speech = "Speech"
        case about = "About"

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .speech: "waveform"
            case .about: "info.circle"
            }
        }
    }

    @ObservedObject var library: ModelLibrary
    @ObservedObject var preferences: Preferences
    @State var section = Section.general
    @State private var microphone = Permissions.microphone
    @State private var accessibility = Permissions.accessibility
    @State private var startAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginProblem: String?
    @State private var modelToDelete: VoiceModel?
    @State private var newWord = ""
    @State private var tryIt = ""

    private let permissionCheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(Section.allCases, id: \.self) { item in
                    TabItem(title: item.rawValue, symbol: item.symbol, selected: item == section) { section = item }
                }
            }
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }

            VStack(alignment: .leading, spacing: 0) {
                switch section {
                case .general: general
                case .speech: speech
                case .about: about
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 2)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The window takes its height from the tab showing, so no tab has empty space.
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
        .onReceive(permissionCheck) { _ in
            microphone = Permissions.microphone
            accessibility = Permissions.accessibility
        }
        .onAppear(perform: library.refreshSizes)
        .alert(item: $modelToDelete) { model in
            Alert(
                title: Text("Delete \(model.title)?"),
                message: Text("It frees the space on this Mac. You can install it again later."),
                primaryButton: .destructive(Text("Delete")) { library.delete(model) },
                secondaryButton: .cancel())
        }
    }

    // MARK: Sections

    @ViewBuilder private var general: some View {
        // Out of the way once it's done, since nobody needs to see it again.
        if microphone != .authorized || !accessibility {
            GroupTitle(title: "Needs your OK")
            PermissionRows(microphone: microphone, accessibility: accessibility)
        }
        GroupTitle(title: "Dictation")
        SettingRow(title: "Hold to talk",
                   detail: preferences.talkKey == .fn ? "If Fn opens the emoji picker, change it in System Settings, Keyboard." : nil) {
            TalkKeyPicker(preferences: preferences)
        }
        SettingRow(title: "Start at login", detail: loginProblem) {
            Toggle("", isOn: $startAtLogin).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(Theme.control)
                .onChange(of: startAtLogin) { _, on in setStartAtLogin(on) }
        }
        GroupTitle(title: "Waveform")
        PillPreview(size: preferences.waveSize)
            .padding(.top, 6)
        SettingRow(title: "Size") {
            Picker("Waveform size", selection: $preferences.waveSize) {
                ForEach(WaveSize.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)
            .fixedSize()
        }
        GroupTitle(title: "Try it")
        TextField("Try it", text: $tryIt, prompt: Text("Click here, hold \(preferences.talkKey.title) and talk").foregroundColor(Theme.muted))
            .labelsHidden()
            .modifier(FieldStyle())
            .padding(.top, 6)
    }

    @ViewBuilder private var speech: some View {
        GroupTitle(title: "Models")
        ForEach(VoiceModel.allCases, content: modelRow)
        if let problem = library.problem {
            Text(problem).font(.system(size: 11.5)).foregroundStyle(Theme.warning).padding(.top, 6)
        }
        GroupTitle(title: "Your words")
        TextField("Add a word", text: $newWord, prompt: Text("Add a name or term, then press Return").foregroundColor(Theme.muted))
            .labelsHidden()
            .modifier(FieldStyle())
            .padding(.top, 6)
            .onSubmit {
                preferences.customWords = DictationText.list(preferences.customWords, adding: newWord)
                newWord = ""
            }
        if !preferences.words.isEmpty {
            FlowLayout {
                ForEach(preferences.words, id: \.self, content: wordChip)
            }
            .padding(.top, 10)
        }
        Text("Close matches become exactly what you add, like Farrol becoming Farol.")
            .font(.system(size: 11.5)).foregroundStyle(Theme.muted).padding(.top, 10)
        Text("Speech runs on this Mac. Audio is never sent anywhere or saved.")
            .font(.system(size: 11.5)).foregroundStyle(Theme.muted).padding(.top, 3)
    }

    @ViewBuilder private var about: some View {
        VStack(spacing: 6) {
            PulsingIcon().frame(width: 96, height: 96).padding(.bottom, 6)
            Text("Farol Voice").font(.system(size: 20, weight: .semibold))
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
            HStack(spacing: 0) {
                Text("From ")
                Link("Farol", destination: URL(string: "https://farol.sh")!).underline().foregroundStyle(Theme.text)
                Text(", the terminal for coding agents.")
            }
            .font(.system(size: 12.5)).foregroundStyle(Theme.muted).padding(.top, 8)
            Link("Source code on GitHub", destination: URL(string: "https://github.com/snowztech/farol-voice")!)
                .underline().font(.system(size: 12.5)).foregroundStyle(Theme.text)
            Text("Speech by Parakeet from NVIDIA (CC BY 4.0) and Whisper from OpenAI (MIT).")
                .font(.system(size: 11.5)).foregroundStyle(Theme.muted).padding(.top, 14)
            // The string literal is read as Markdown, so snowztech becomes a link in the same words.
            Text("© 2026 Lucas Neves Pereira, [snowztech](https://github.com/snowztech)")
                .font(.system(size: 11.5)).foregroundStyle(Theme.muted).tint(Theme.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
    }

    // MARK: Parts

    private func wordChip(_ word: String) -> some View {
        HStack(spacing: 5) {
            Text(word).font(.system(size: 12)).lineLimit(1)
            Button {
                preferences.customWords = DictationText.list(preferences.customWords, removing: word)
            } label: {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.muted)
                    .frame(width: 12, height: 12).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(word)")
        }
        .padding(.leading, 9)
        .padding(.trailing, 5)
        .padding(.vertical, 3)
        .background(Capsule().fill(Theme.raised))
    }

    private func modelRow(_ model: VoiceModel) -> some View {
        SettingRow(title: model.title, note: model == library.recommended ? "Recommended" : nil, detail: detail(of: model)) {
            HStack(spacing: 8) {
                if library.installing == model {
                    QuietButton(title: "Cancel", action: library.cancelInstall)
                } else if library.installed.contains(model) {
                    QuietButton(title: "Delete") { modelToDelete = model }
                    if library.chosen == model {
                        Label("In use", systemImage: "circle.fill")
                            .labelStyle(InUseLabelStyle())
                    } else {
                        QuietButton(title: "Use", prominent: true) { library.use(model) }
                    }
                } else {
                    QuietButton(title: "Install", prominent: true) { library.install(model) }.disabled(library.installing != nil)
                }
            }
        }
    }

    private func detail(of model: VoiceModel) -> String {
        if library.installing == model { return library.installStatus }
        if library.installed.contains(model), let size = library.sizes[model], size > 0 {
            return "\(model.strengths) \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) on this Mac."
        }
        return "\(model.strengths) \(model.downloadSize)"
    }

    private func setStartAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginProblem = nil
        } catch {
            loginProblem = "Couldn't change that: \(error.localizedDescription)"
            startAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// The pill on a stand-in screen, as if someone were talking and it were then thinking.
private struct PillPreview: View {
    let size: WaveSize

    @State private var signal = VoiceSignal()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let talking = 3.2
    private static let thinking = 1.6

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let moment = time.truncatingRemainder(dividingBy: Self.talking + Self.thinking)
            let isTalking = reduceMotion || moment < Self.talking
            let _ = signal.target = reduceMotion ? 0.7 : Self.voice(at: time)
            PillView(content: isTalking ? .listening : .working, signal: signal, size: size)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line))
        .accessibilityHidden(true)
    }

    /// Syllables inside phrases: fast bumps under a slow swell, with short gaps, so it moves like speech.
    private static func voice(at time: TimeInterval) -> Double {
        let phrase = max(0, sin(time * 1.9) * 0.5 + 0.55)
        let syllable = abs(sin(time * 7.3)) * 0.7 + abs(sin(time * 11.1)) * 0.3
        return min(1, phrase * syllable * 1.15)
    }
}

/// The app icon with its sound waves gently pulsing outward. Still, with Reduce Motion on.
private struct PulsingIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Image(nsImage: NSApp.applicationIconImage).resizable()
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    Canvas { context, size in
                        draw(in: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
        .accessibilityLabel("Farol Voice icon")
    }

    /// Dims the icon's own bars in turn, using the positions `scripts/make-icon.swift` draws them at.
    private func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let scale = size.width / 1024
        for sign in [CGFloat(1), -1] {
            for (index, height) in [CGFloat(132), 96, 58].enumerated() {
                let dim = 0.5 + 0.5 * sin(time * 2.4 - Double(index) * 0.9)
                let x = 512 + sign * (118 + CGFloat(index) * 52)
                let bar = CGRect(x: (x - 16) * scale, y: (398 - height / 2 - 1) * scale, width: 32 * scale, height: (height + 2) * scale)
                context.fill(Path(roundedRect: bar, cornerRadius: 16 * scale),
                             with: .color(Color(red: 0x13 / 255, green: 0x18 / 255, blue: 0x25 / 255).opacity(dim * 0.55)))
            }
        }
    }
}

private struct InUseLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            Circle().fill(Theme.beam).frame(width: 5, height: 5)
            configuration.title
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.muted)
        .padding(.horizontal, 9)
    }
}

struct TalkKeyPicker: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        Picker("Hold to talk", selection: $preferences.talkKey) {
            ForEach(TalkKey.allCases) { Text($0.title).tag($0) }
        }
        .labelsHidden()
        .controlSize(.small)
        .fixedSize()
    }
}

struct PermissionRows: View {
    let microphone: AVAuthorizationStatus
    let accessibility: Bool

    var body: some View {
        row("Microphone", detail: "Opens only while you hold the key.", allowed: microphone == .authorized) {
            if microphone == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { _ in }
            } else {
                Permissions.openPrivacy("Microphone")
            }
        }
        row("Accessibility", detail: "Lets the key work everywhere, and types your words for you.", allowed: accessibility) {
            Permissions.askForAccessibility()
        }
    }

    private func row(_ title: String, detail: String, allowed: Bool, allow: @escaping () -> Void) -> some View {
        SettingRow(title: title, detail: detail) {
            if allowed {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.beam)
                    .padding(.horizontal, 9)
                    .accessibilityLabel("Allowed")
            } else {
                QuietButton(title: "Allow", prominent: true, action: allow)
            }
        }
    }
}
