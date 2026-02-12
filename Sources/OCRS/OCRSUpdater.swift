import Sparkle

@MainActor
final class OCRSUpdater: ObservableObject {
    private let updaterController: SPUStandardUpdaterController
    private let updater: SPUUpdater

    @Published var automaticallyChecksForUpdates: Bool
    @Published var automaticallyDownloadsUpdates: Bool

    init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updaterController = controller
        self.updater = controller.updater
        self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    func syncSettings() {
        updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
    }
}
