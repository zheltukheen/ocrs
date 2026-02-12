import ServiceManagement

enum OCRSLaunchAtLogin {
    static func isEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            OCRSDebug.log("LaunchAtLogin error: \(error.localizedDescription)")
            return false
        }
    }
}
