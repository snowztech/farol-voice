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

    private let permissionCheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                permissionRow("Microphone", detail: "Opens only while you hold the key.", allowed: microphone == .authorized) {
                    if microphone == .notDetermined {
                        AVCaptureDevice.requestAccess(for: .audio) { _ in }
                    } else {
                        Permissions.openPrivacy("Microphone")
                    }
                }
                permissionRow("Accessibility", detail: "Lets the key work everywhere and your words be typed.", allowed: accessibility) {
                    Permissions.askForAccessibility()
                    Permissions.openPrivacy("Accessibility")
                }
            } header: {
                Text("Permissions")
            }

            Section {
                Picker("Hold to talk", selection: $preferences.talkKey) {
                    ForEach(TalkKey.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Start at login", isOn: $startAtLogin)
                    .onChange(of: startAtLogin) { _, on in setStartAtLogin(on) }
                if let loginProblem {
                    Text(loginProblem).font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Your words", text: $preferences.customWords)
                    Text("Names and terms to get right, separated by commas.").font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("Dictation")
            } footer: {
                Text("Speech runs on this Mac. Audio is never sent anywhere or saved.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                ForEach(VoiceModel.allCases) { model in
                    modelRow(model)
                }
                if let problem = library.problem {
                    Text(problem).font(.caption).foregroundStyle(.red)
                }
            } header: {
                Text("Models")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 640)
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

    private func permissionRow(_ title: String, detail: String, allowed: Bool, allow: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if allowed {
                Label("Allowed", systemImage: "checkmark.circle.fill").labelStyle(.iconOnly).foregroundStyle(.green)
                    .accessibilityLabel("Allowed")
            } else {
                Button("Allow", action: allow)
            }
        }
    }

    private func modelRow(_ model: VoiceModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.title)
                    if model == library.recommended {
                        Text("Recommended").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(detail(of: model)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if library.installing == model {
                Button("Cancel", action: library.cancelInstall)
            } else if library.installed.contains(model) {
                if library.chosen == model {
                    Text("In use").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("Use") { library.use(model) }
                }
                Button("Delete") { modelToDelete = model }
            } else {
                Button("Install") { library.install(model) }.disabled(library.installing != nil)
            }
        }
    }

    private func detail(of model: VoiceModel) -> String {
        if library.installing == model { return library.installStatus }
        guard library.installed.contains(model), let size = library.sizes[model], size > 0 else { return model.detail }
        return "\(model.detail) Uses \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) on this Mac."
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
