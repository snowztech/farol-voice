import AVFoundation
import ServiceManagement
import SwiftUI
import VoiceCore

struct SettingsView: View {
    @ObservedObject var library: ModelLibrary
    @ObservedObject var preferences: Preferences
    @State private var microphone = Permissions.microphone
    @State private var accessibility = Permissions.accessibility
    @State private var startAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginProblem: String?
    @State private var modelToDelete: VoiceModel?
    @State private var newWord = ""
    @State private var tryIt = ""

    private let permissionCheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Heading(title: "Farol Voice", detail: "Hold a key, talk, and your words appear wherever you're typing.")

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

            GroupTitle(title: "Your words")
            words

            GroupTitle(title: "Models")
            ForEach(VoiceModel.allCases, content: modelRow)
            if let problem = library.problem {
                Text(problem).font(.system(size: 11.5)).foregroundStyle(Theme.warning).padding(.top, 6)
            }

            GroupTitle(title: "Try it")
            TextField("Try it", text: $tryIt, prompt: Text("Click here, hold \(preferences.talkKey.title) and talk").foregroundColor(Theme.muted))
                .labelsHidden()
                .modifier(FieldStyle())
                .padding(.top, 6)

            footer.padding(.top, 22)
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .frame(width: 500, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
        .onReceive(permissionCheck) { _ in
            microphone = Permissions.microphone
            accessibility = Permissions.accessibility
        }
        .alert(item: $modelToDelete) { model in
            Alert(
                title: Text("Delete \(model.title)?"),
                message: Text("It frees the space on this Mac. You can install it again later."),
                primaryButton: .destructive(Text("Delete")) { library.delete(model) },
                secondaryButton: .cancel())
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Add a word", text: $newWord, prompt: Text("Add a name or term, then press Return").foregroundColor(Theme.muted))
                .labelsHidden()
                .modifier(FieldStyle())
                .onSubmit {
                    preferences.customWords = DictationText.list(preferences.customWords, adding: newWord)
                    newWord = ""
                }
            if !preferences.words.isEmpty {
                FlowLayout {
                    ForEach(preferences.words, id: \.self, content: wordChip)
                }
            }
            Text("Close matches become exactly what you add here, like Farrol becoming Farol.")
                .font(.system(size: 11.5)).foregroundStyle(Theme.muted)
        }
        .padding(.top, 6)
    }

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

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Speech runs on this Mac. Audio is never sent anywhere or saved.")
            HStack(spacing: 0) {
                Text("From ")
                Link("Farol", destination: URL(string: "https://farol.sh")!).underline().foregroundStyle(Theme.text)
                Text(", the terminal for coding agents.")
            }
        }
        .font(.system(size: 11.5))
        .foregroundStyle(Theme.muted)
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
