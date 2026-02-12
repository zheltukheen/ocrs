import AppKit

final class OCRSErrorPresenter {
    static let shared = OCRSErrorPresenter()
    private var isShowing = false

    private init() {}

    func showScreenRecordingDenied() {
        showAlert(
            title: "Screen Recording Required",
            message: "OCRS needs Screen Recording permission to capture the selected area. Enable it in System Settings.",
            primaryButton: "Open Settings",
            secondaryButton: "Cancel",
            primaryAction: {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
                if let url { NSWorkspace.shared.open(url) }
            }
        )
    }

    func showError(message: String) {
        showAlert(
            title: "OCR Error",
            message: message,
            primaryButton: "OK",
            secondaryButton: nil,
            primaryAction: nil
        )
    }

    private func showAlert(
        title: String,
        message: String,
        primaryButton: String,
        secondaryButton: String?,
        primaryAction: (() -> Void)?
    ) {
        guard !isShowing else { return }
        isShowing = true

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: primaryButton)
            if let secondaryButton { alert.addButton(withTitle: secondaryButton) }

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                primaryAction?()
            }

            self.isShowing = false
        }
    }
}
