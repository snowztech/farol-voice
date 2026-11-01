import Sparkle

/// Sparkle looks for a new version once a day, then downloads it, checks its signature and relaunches the app on it.
final class Updates {
    private var controller: SPUStandardUpdaterController?

    /// Dev builds have no feed, so they never offer to replace themselves with a release.
    var canCheck: Bool { controller != nil }

    init() {
        guard Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    func check() {
        controller?.checkForUpdates(nil)
    }
}
