import AVFoundation
import SwiftUI
import VoiceCore

/// The first time you open it: four steps in one window, ending with your own words on screen.
struct SetupView: View {
    @ObservedObject var library: ModelLibrary
    @ObservedObject var preferences: Preferences
    let onDone: () -> Void

    @State private var microphone = Permissions.microphone
    @State private var accessibility = Permissions.accessibility
    @State private var tryIt = ""

    private let permissionCheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var isReady: Bool { microphone == .authorized && accessibility && library.isReady }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Set up Farol Voice").font(.system(size: 20, weight: .semibold))
                    Text("It runs on this Mac, so your voice stays here.").font(.system(size: 12.5)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.bottom, 14)

            step(1, "Allow the microphone", detail: "It opens only while you hold the key.", done: microphone == .authorized) {
                QuietButton(title: "Allow", prominent: true) {
                    if microphone == .notDetermined {
                        AVCaptureDevice.requestAccess(for: .audio) { _ in }
                    } else {
                        Permissions.openPrivacy("Microphone")
                    }
                }
            }
            step(2, "Allow Accessibility", detail: "Lets the key work everywhere, and types your words for you.", done: accessibility) {
                QuietButton(title: "Allow", prominent: true, action: Permissions.askForAccessibility)
            }
            step(3, "Install a speech model", detail: modelDetail, done: library.isReady) {
                if library.installing == nil {
                    QuietButton(title: "Install", prominent: true) { library.install(library.recommended) }
                } else {
                    QuietButton(title: "Cancel", action: library.cancelInstall)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    marker(4, done: !tryIt.isEmpty, active: isReady)
                    Text(tryIt.isEmpty ? "Try it" : "It works. Now use it anywhere you can type.").font(.system(size: 13))
                        .foregroundStyle(tryIt.isEmpty ? Theme.text : Theme.beam)
                    Spacer()
                    TalkKeyPicker(preferences: preferences)
                }
                TextField("Try it", text: $tryIt, prompt: Text("Click here, hold \(preferences.talkKey.title) and talk").foregroundColor(Theme.muted))
                    .labelsHidden()
                    .modifier(FieldStyle())
                    .disabled(!isReady)
            }
            .padding(.vertical, 12)
            .opacity(isReady ? 1 : 0.45)
            .animation(.easeOut(duration: 0.18), value: tryIt.isEmpty)

            if let problem = library.problem {
                Text(problem).font(.system(size: 11.5)).foregroundStyle(Theme.warning).padding(.bottom, 8)
            }

            HStack {
                Text("Settings stay in the menu bar, under the sound bars.").font(.system(size: 11.5)).foregroundStyle(Theme.muted)
                Spacer()
                QuietButton(title: isReady ? "Done" : "Later", prominent: isReady, action: onDone)
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .frame(width: 480, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
        .onReceive(permissionCheck) { _ in
            microphone = Permissions.microphone
            accessibility = Permissions.accessibility
        }
    }

    private var modelDetail: String {
        if library.installing != nil { return library.installStatus }
        let model = library.isReady ? library.chosen : library.recommended
        return library.isReady ? "\(model.title) is ready." : "\(model.title). \(model.downloadSize)"
    }

    private func step<Action: View>(_ number: Int, _ title: String, detail: String, done: Bool, @ViewBuilder action: () -> Action) -> some View {
        HStack(spacing: 10) {
            marker(number, done: done, active: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                Text(detail).font(.system(size: 11.5)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            if !done { action() }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func marker(_ number: Int, done: Bool, active: Bool) -> some View {
        ZStack {
            Circle().strokeBorder(done ? Theme.beam : Theme.line)
            if done {
                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.beam)
            } else {
                Text("\(number)").font(.system(size: 10.5, weight: .medium)).foregroundStyle(active ? Theme.text : Theme.muted)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityLabel(done ? "Step \(number), done" : "Step \(number)")
    }
}
