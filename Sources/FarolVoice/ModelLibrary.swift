import Foundation
import VoiceCore
import VoiceEngine

/// What's installed and which one is in use. Choosing never downloads. Only `install` does.
final class ModelLibrary: ObservableObject {
    private static let chosenKey = "model"

    @Published private(set) var chosen: VoiceModel
    @Published private(set) var installed: Set<VoiceModel> = []
    @Published private(set) var installing: VoiceModel?
    @Published private(set) var installStatus = ""
    @Published private(set) var problem: String?
    @Published private(set) var sizes: [VoiceModel: Int64] = [:]

    let recommended = VoiceModel.recommended(languages: Locale.preferredLanguages)
    let engine = SpeechEngine(folder: SpeechEngine.defaultFolder)
    private var installTask: Task<Void, Never>?

    var isReady: Bool { installed.contains(chosen) }

    init() {
        chosen = UserDefaults.standard.string(forKey: Self.chosenKey).flatMap(VoiceModel.init) ?? recommended
        installed = Set(VoiceModel.allCases.filter(engine.isInstalled))
        if !installed.contains(chosen), let other = installed.first { chosen = other }
        refreshSizes()
    }

    func use(_ model: VoiceModel) {
        guard installed.contains(model) else { return }
        chosen = model
        UserDefaults.standard.set(model.rawValue, forKey: Self.chosenKey)
    }

    func install(_ model: VoiceModel) {
        guard installing == nil else { return }
        installing = model
        installStatus = "Starting"
        problem = nil
        installTask = Task { [weak self, engine] in
            do {
                try await engine.load(model, online: true) { fraction, status in
                    let text = fraction < 1 ? "\(status) \(Int(fraction * 100))%" : status
                    DispatchQueue.main.async { self?.installStatus = text }
                }
                await MainActor.run {
                    guard let self else { return }
                    self.installing = nil
                    self.installed.insert(model)
                    self.use(model)
                    self.refreshSizes()
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.installing = nil
                    if !(error is CancellationError) {
                        self.problem = "Couldn't install \(model.title): \(error.localizedDescription)"
                    }
                    self.refreshSizes()
                }
            }
        }
    }

    /// What was already downloaded stays on disk, so installing again can pick up from there.
    func cancelInstall() {
        installTask?.cancel()
        installing = nil
    }

    func delete(_ model: VoiceModel) {
        Task { [weak self, engine] in
            try? await engine.delete(model)
            await MainActor.run {
                guard let self else { return }
                self.installed.remove(model)
                if self.chosen == model, let other = self.installed.first { self.use(other) }
                self.refreshSizes()
            }
        }
    }

    func refreshSizes() {
        let engine = engine
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var sizes: [VoiceModel: Int64] = [:]
            for model in VoiceModel.allCases {
                var total: Int64 = 0
                let files = FileManager.default.enumerator(at: engine.directory(of: model), includingPropertiesForKeys: [.fileSizeKey])
                while let file = files?.nextObject() as? URL {
                    total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                }
                sizes[model] = total
            }
            DispatchQueue.main.async { self?.sizes = sizes }
        }
    }
}
