import Foundation
import AppKit

final class OCRSPermissionManager: ObservableObject {
    static let shared = OCRSPermissionManager()

    @Published private(set) var screenRecordingGranted: Bool = false

    private let screenRecordingGrantedKey = "ocrs_screen_recording_granted"
    private var didPromptScreenRecording = false

    private let launchTime = Date()
    private let tccGracePeriod: TimeInterval = 10.0

    private init() {
        refresh()
    }

    @discardableResult
    func refresh() -> Bool {
        let granted = CGPreflightScreenCaptureAccess()
        if granted {
            UserDefaults.standard.set(true, forKey: screenRecordingGrantedKey)
        }

        let cached = UserDefaults.standard.bool(forKey: screenRecordingGrantedKey)
        let timeSinceLaunch = Date().timeIntervalSince(launchTime)

        if granted {
            screenRecordingGranted = true
        } else if timeSinceLaunch < tccGracePeriod && cached {
            screenRecordingGranted = true
        } else {
            screenRecordingGranted = false
        }

        return screenRecordingGranted
    }

    func ensureScreenRecordingPermission() -> Bool {
        if refresh() { return true }

        if !didPromptScreenRecording {
            didPromptScreenRecording = true
            CGRequestScreenCaptureAccess()
        }

        return false
    }
}
