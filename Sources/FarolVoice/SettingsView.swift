import AVFoundation
import ServiceManagement
import SwiftUI
import VoiceCore

struct SettingsView: View {
    enum Section: String, CaseIterable {
        case general = "General"
        case dictation = "Dictation"
        case farol = "Farol"
        case models = "Models"
        case about = "About"

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .dictation: "text.cursor"
            case .farol: "light.beacon.max"
            case .models: "square.stack.3d.up"
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
    @State var farolStatus: FarolStatus?
    /// Asks the window to fit this much height. It's only asked when a tab opens, so a size you chose stays until you change tabs.
    var onFit: ((CGFloat) -> Void)?
    /// Until when a new height means the window should fit it. Short, so it's over before you could resize anything yourself.
    @State private var fitUntil = Date().addingTimeInterval(1)
    @State private var contentHeight: CGFloat = 0

    /// The tabs above the scrolling part.
    private static let tabsHeight: CGFloat = 64

    private let permissionCheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let farolCheck = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

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

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch section {
                    case .general: general
                    case .dictation: dictation
                    case .farol: farol
                    case .models: models
                    case .about: about
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 2)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GeometryReader { Color.clear.preference(key: ContentHeight.self, value: $0.size.height) })
            }
        }
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        .onPreferenceChange(ContentHeight.self) { height in
            contentHeight = height
            fitIfNew()
        }
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
        .onReceive(permissionCheck) { _ in
            microphone = Permissions.microphone
            accessibility = Permissions.accessibility
        }
        .onAppear(perform: library.refreshSizes)
        .onChange(of: section) { _, _ in
            // The new tab may already have been measured by now, or may not be yet, so this covers both.
            fitUntil = Date().addingTimeInterval(0.3)
            DispatchQueue.main.async { fitIfNew() }
            checkFarol()
        }
        // Switches by itself only to what's already installed. A download is always your choice.
        .onChange(of: preferences.languageChoice) { _, _ in library.use(bestModel) }
        .onReceive(farolCheck) { _ in checkFarol() }
        .alert(item: $modelToDelete) { model in
            Alert(
                title: Text("Delete \(model.title)?"),
                message: Text("It frees the space on this Mac. You can install it again later."),
                primaryButton: .destructive(Text("Delete")) { library.delete(model) },
                secondaryButton: .cancel())
        }
    }

    private func fitIfNew() {
        guard Date() < fitUntil, contentHeight > 0 else { return }
        onFit?(contentHeight + Self.tabsHeight)
    }

    // MARK: Sections

    @ViewBuilder private var general: some View {
        // Out of the way once it's done, since nobody needs to see it again.
        if microphone != .authorized || !accessibility {
            GroupTitle(title: "Needs your OK")
            PermissionRows(microphone: microphone, accessibility: accessibility)
            GroupTitle(title: "Startup")
        } else {
            GroupTitle(title: "Startup")
        }
        SettingRow(title: "Start at login", detail: loginProblem) {
            Toggle("", isOn: $startAtLogin).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(Theme.control)
                .onChange(of: startAtLogin) { _, on in setStartAtLogin(on) }
        }
        GroupTitle(title: "Waveform")
        HStack(spacing: 10) {
            PillPreview(title: "Dictating", size: preferences.waveSize, command: false)
            PillPreview(title: "Telling Farol", size: preferences.waveSize, command: true)
        }
        .padding(.top, 6)
        SettingRow(title: "Size") {
            Picker("Waveform size", selection: $preferences.waveSize) {
                ForEach(WaveSize.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
        }
    }

    @ViewBuilder private var dictation: some View {
        GroupTitle(title: "Type in any app")
        SettingRow(title: "Hold to talk",
                   detail: preferences.talkKey == .fn ? "If Fn opens the emoji picker, change it in System Settings, Keyboard." : nil) {
            TalkKeyPicker(preferences: preferences)
        }
        GroupTitle(title: "Try it")
        TextField("Try it", text: $tryIt, prompt: Text("Click here, hold \(preferences.talkKey.title) and talk").foregroundColor(Theme.muted))
            .labelsHidden()
            .modifier(FieldStyle())
            .padding(.top, 6)
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
    }

    @ViewBuilder private var farol: some View {
        GroupTitle(title: "Control your agents")
        farolStatusRow
        SettingRow(title: "Hold to tell Farol") {
            Picker("Hold to tell Farol", selection: $preferences.commandKey) {
                ForEach(TalkKey.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
        }
        SettingRow(title: "Read out what agents ask",
                   detail: "It says when an agent asks something or finishes, and listens for your answer for a few seconds. Say yes, no or an option's name. It stays quiet during calls.") {
            Toggle("", isOn: $preferences.speaksAgents).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(Theme.control)
        }
        GroupTitle(title: "What you can say")
        sayRow("Open Farol", "From any app, even if it's closed.")
        sayRow("Go to auth", "Switches to a session, by name or branch.")
        sayRow("Tell auth to run the tests", "Types it there, and you press Return. Add \"and send it\" to send it after a moment.")
        sayRow("New task, add a search box", "Starts an agent in its own worktree.")
        Text("It reads session names and status, never your conversations.")
            .font(.system(size: 11.5)).foregroundStyle(Theme.muted).padding(.top, 10)
    }

    private func sayRow(_ phrase: String, _ meaning: String) -> some View {
        SettingRow(title: phrase, detail: meaning) { EmptyView() }
    }

    private var farolStatusRow: some View {
        let (title, detail, action) = describe(farolStatus)
        return SettingRow(title: title, detail: detail) {
            if farolStatus == .ready {
                Circle().fill(Theme.beam).frame(width: 5, height: 5).padding(.horizontal, 9).accessibilityLabel("Connected")
            } else if let action {
                QuietButton(title: action, prominent: true, action: Commander.openFarol)
            }
        }
    }

    private func describe(_ status: FarolStatus?) -> (String, String?, String?) {
        switch status {
        case .ready: ("Connected to Farol", nil, nil)
        case .closed: ("Farol is closed", "It opens by itself when you give a command.", "Open Farol")
        case .notInstalled: ("Farol isn't installed", "Dictation works without it. This needs the Farol terminal.", "Get Farol")
        case .tooOld: ("Farol needs an update", "Update it from Farol's menu, then come back.", "Open Farol")
        case .needsSetting: ("One setting to turn on", "In Farol: Settings, Agents, Let Farol Voice control sessions.", "Open Farol")
        case .notVerified: ("This build can't control Farol", "Farol only accepts signed builds of Farol Voice.", nil)
        case .unreachable: ("Can't reach Farol", "Try again in a moment.", "Open Farol")
        case nil: ("Checking Farol", nil, nil)
        }
    }

    private func checkFarol() {
        guard section == .farol else { return }
        Task {
            let status = await Task.detached { Commander.status() }.value
            farolStatus = status
        }
    }

    private var bestModel: VoiceModel { VoiceModel.best(for: preferences.language) }

    @ViewBuilder private var models: some View {
        GroupTitle(title: "What you speak")
        SettingRow(title: "Language", detail: preferences.language == nil ? "Detected as you talk. Choose yours for the best model." : nil) {
            LanguagePicker(preferences: preferences)
        }
        GroupTitle(title: "Models")
        // Only a few, so they all stay in view, with the one for your language first.
        ForEach([bestModel] + VoiceModel.allCases.filter { $0 != bestModel }, content: modelRow)
        if let problem = library.problem {
            Text(problem).font(.system(size: 11.5)).foregroundStyle(Theme.warning).padding(.top, 6)
        }
        Text("Speech runs on this Mac. Audio is never sent anywhere or saved.")
            .font(.system(size: 11.5)).foregroundStyle(Theme.muted).padding(.top, 10)
    }

    @ViewBuilder private var about: some View {
        VStack(spacing: 4) {
            PulsingIcon().frame(width: 88, height: 88).padding(.bottom, 8)
            Text("Farol Voice").font(.system(size: 18, weight: .semibold))
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
            HStack(spacing: 14) {
                Link("Farol", destination: URL(string: "https://farol.sh")!)
                Link("GitHub", destination: URL(string: "https://github.com/snowztech/farol-voice")!)
                Link("Changelog", destination: URL(string: "https://github.com/snowztech/farol-voice/blob/main/CHANGELOG.md")!)
                Link("Credits", destination: URL(string: "https://github.com/snowztech/farol-voice/blob/main/THIRD_PARTY_NOTICES")!)
            }
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.text)
            .padding(.top, 14)
            // The string literal is read as Markdown, so snowztech becomes a link in the same words.
            Text("© 2026 Lucas Neves Pereira, [snowztech](https://github.com/snowztech)")
                .font(.system(size: 11)).foregroundStyle(Theme.muted).tint(Theme.muted)
                .padding(.top, 18)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
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
        SettingRow(title: model.friendlyName, note: model == bestModel ? "\(model.title), recommended" : model.title, detail: detail(of: model)) {
            HStack(spacing: 8) {
                if library.installing == model {
                    QuietButton(title: "Cancel", action: library.cancelInstall)
                } else if library.installed.contains(model) {
                    if library.chosen == model {
                        Label("In use", systemImage: "circle.fill")
                            .labelStyle(InUseLabelStyle())
                    } else {
                        QuietButton(title: "Use", prominent: true) { library.use(model) }
                    }
                    QuietButton(title: "Delete") { modelToDelete = model }
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
    let title: String
    let size: WaveSize
    let command: Bool

    @State private var signal = VoiceSignal()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let talking = 3.2
    private static let thinking = 1.6

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let moment = time.truncatingRemainder(dividingBy: Self.talking + Self.thinking)
                let isTalking = reduceMotion || moment < Self.talking
                let _ = signal.target = reduceMotion ? 0.7 : Self.voice(at: time)
                PillView(content: isTalking ? .listening(command: command) : .working, signal: signal, size: size)
            }
            .frame(height: 54)
            Text(title).font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
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

private struct ContentHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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

struct LanguagePicker: View {
    @ObservedObject var preferences: Preferences

    private static func name(of code: String) -> String? {
        Locale.current.localizedString(forLanguageCode: code)?.localizedCapitalized
    }

    private static let yours = SpeechLanguage.yours(preferred: Locale.preferredLanguages)

    /// In your Mac's language, in alphabetical order, leaving out any it has no name for.
    private static let all: [(code: String, name: String)] = SpeechLanguage.codes
        .compactMap { code in name(of: code).map { (code, $0) } }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    var body: some View {
        Picker("Language", selection: $preferences.languageChoice) {
            Text("Automatic").tag(SpeechLanguage.automatic)
            Divider()
            ForEach(Self.yours, id: \.self) { Text(Self.name(of: $0) ?? $0).tag($0) }
            Divider()
            // A second copy of your languages would give the menu two items for one choice.
            ForEach(Self.all.filter { !Self.yours.contains($0.code) }, id: \.code) { Text($0.name).tag($0.code) }
        }
        .labelsHidden()
        .controlSize(.small)
        .fixedSize()
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
