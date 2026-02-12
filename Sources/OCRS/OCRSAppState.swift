import AppKit
import SwiftUI

final class OCRSAppState: ObservableObject {
    private let captureController = OCRCaptureController()
    let hotkeyManager = HotkeyManager()
    let permissionManager = OCRSPermissionManager.shared
    
    @AppStorage(OCRSPreferenceKey.outputMode) private var outputModeRaw: String = OCRSOutputMode.copy.rawValue
    @AppStorage(OCRSPreferenceKey.accuracyMode) private var accuracyModeRaw: String = OCRSAccuracyMode.standard.rawValue
    @AppStorage(OCRSPreferenceKey.languageMode) private var languageModeRaw: String = OCRSLanguageMode.auto.rawValue

    init() {
        hotkeyManager.onTrigger = { [weak self] in
            self?.captureOCR()
        }
    }

    func captureOCR() {
        let mode = OCRSOutputMode(rawValue: outputModeRaw) ?? .copy
        let accuracy = OCRSAccuracyMode(rawValue: accuracyModeRaw) ?? .standard
        let language = OCRSLanguageMode(rawValue: languageModeRaw) ?? .auto
        captureController.startCapture(outputMode: mode, accuracyMode: accuracy, languageMode: language)
    }

}
