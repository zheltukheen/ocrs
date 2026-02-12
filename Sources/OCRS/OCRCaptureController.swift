import AppKit
import ScreenCaptureKit

final class OCRCaptureController {
    private var areaSelectionWindow: AreaSelectionWindow?
    private let resultWindow = OCRResultWindowController()
    private var currentScreenDisplayID: CGDirectDisplayID = 0
    private let permissionManager = OCRSPermissionManager.shared
    private var isSelecting = false
    private var isProcessing = false
    private var lastTriggerAt: TimeInterval = 0

    func startCapture(outputMode: OCRSOutputMode, accuracyMode: OCRSAccuracyMode, languageMode: OCRSLanguageMode) {
        let now = Date().timeIntervalSince1970
        if now - lastTriggerAt < 0.35 {
            return
        }
        lastTriggerAt = now

        if isSelecting {
            cancelSelection()
            return
        }

        guard !isProcessing else { return }

        guard permissionManager.ensureScreenRecordingPermission() else {
            OCRSErrorPresenter.shared.showScreenRecordingDenied()
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main else {
            return
        }

        if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            currentScreenDisplayID = displayID
        }

        isSelecting = true
        areaSelectionWindow = AreaSelectionWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        areaSelectionWindow?.configure { [weak self] selectedRect in
            guard let self else { return }
            Task { await self.captureArea(selectedRect, on: screen, outputMode: outputMode, accuracyMode: accuracyMode, languageMode: languageMode) }
        }

        areaSelectionWindow?.onCancel = { [weak self] in
            self?.cancelSelection()
        }

        NSApp.activate(ignoringOtherApps: true)
        areaSelectionWindow?.makeKeyAndOrderFront(nil)
    }

    private func captureArea(_ rect: CGRect, on screen: NSScreen, outputMode: OCRSOutputMode, accuracyMode: OCRSAccuracyMode, languageMode: OCRSLanguageMode) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        guard rect.width > 10 && rect.height > 10 else {
            await MainActor.run {
                cancelSelection()
            }
            return
        }

        if OCRSDebug.enabled {
            OCRSDebug.prepareOutputDir()
            OCRSDebug.log("Selection rect (view coords): \(rect)")
        }

        await MainActor.run {
            cancelSelection()
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        let screenRect = CGRect(
            x: screen.frame.origin.x + rect.origin.x,
            y: screen.frame.origin.y + rect.origin.y,
            width: rect.width,
            height: rect.height
        )

        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let quartzRect = CGRect(
            x: screenRect.origin.x,
            y: primaryScreenHeight - screenRect.origin.y - screenRect.height,
            width: screenRect.width,
            height: screenRect.height
        )

        do {
            let image = try await captureRect(quartzRect)
            if OCRSDebug.enabled {
                OCRSDebug.save(image, name: "last_capture")
                OCRSDebug.log("Saved last capture to /tmp/ocrs_debug/last_capture.png")
            }
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            let text = try await OCRService.shared.performOCR(on: nsImage, mode: accuracyMode, languageMode: languageMode)
            var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty, accuracyMode == .standard {
                let retryText = try await OCRService.shared.performOCR(on: nsImage, mode: .high, languageMode: languageMode)
                trimmed = retryText.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if trimmed.isEmpty {
                OCRSDebug.log("No text recognized after OCR.")
                OCRSErrorPresenter.shared.showError(message: "Could not recognize. Please try again.")
            } else {
                await handleResult(text: trimmed, mode: outputMode)
            }
        } catch {
            if let captureError = error as? CaptureError {
                switch captureError {
                case .permissionDenied:
                    OCRSErrorPresenter.shared.showScreenRecordingDenied()
                case .invalidRect:
                    OCRSDebug.log("Capture error: invalidRect")
                    OCRSErrorPresenter.shared.showError(message: "Could not recognize. Please try again.")
                case .noDisplay:
                    OCRSDebug.log("Capture error: noDisplay")
                    OCRSErrorPresenter.shared.showError(message: "No display available. Please try again.")
                }
            } else {
                OCRSDebug.log("Capture error: \(error.localizedDescription)")
                OCRSErrorPresenter.shared.showError(message: "Could not recognize. Please try again.")
            }
        }

        await MainActor.run {
            areaSelectionWindow = nil
        }
    }

    private func cancelSelection() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.areaSelectionWindow?.orderOut(nil)
            self.areaSelectionWindow = nil
            self.isSelecting = false
        }
    }

    @MainActor
    private func handleResult(text: String, mode: OCRSOutputMode) {
        switch mode {
        case .copy:
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            OCRSToastPresenter.shared.show(message: "Copied")
        case .popup:
            resultWindow.show(text: text)
        }
    }

    private func captureRect(_ rect: CGRect) async throws -> CGImage {
        guard permissionManager.ensureScreenRecordingPermission() else {
            throw CaptureError.permissionDenied
        }

        guard rect.width > 0 && rect.height > 0 && rect.width < 50000 && rect.height < 50000 else {
            throw CaptureError.invalidRect
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == currentScreenDisplayID }) else {
            throw CaptureError.noDisplay
        }

        guard let targetScreen = NSScreen.screens.first(where: { screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
            return displayID == display.displayID
        }) else {
            throw CaptureError.noDisplay
        }

        // Use screen points + backing scale to keep capture rect aligned across retina/non-retina.
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let displayOriginQuartz = CGPoint(
            x: targetScreen.frame.origin.x,
            y: primaryScreenHeight - targetScreen.frame.origin.y - targetScreen.frame.height
        )

        var relativeRect = CGRect(
            x: rect.origin.x - displayOriginQuartz.x,
            y: rect.origin.y - displayOriginQuartz.y,
            width: rect.width,
            height: rect.height
        )

        let displayPointBounds = CGRect(x: 0, y: 0, width: targetScreen.frame.width, height: targetScreen.frame.height)

        if relativeRect.origin.x < 0 {
            relativeRect.size.width += relativeRect.origin.x
            relativeRect.origin.x = 0
        }
        if relativeRect.origin.y < 0 {
            relativeRect.size.height += relativeRect.origin.y
            relativeRect.origin.y = 0
        }
        if relativeRect.maxX > displayPointBounds.width {
            relativeRect.size.width = displayPointBounds.width - relativeRect.origin.x
        }
        if relativeRect.maxY > displayPointBounds.height {
            relativeRect.size.height = displayPointBounds.height - relativeRect.origin.y
        }

        guard relativeRect.width >= 1 && relativeRect.height >= 1 else {
            throw CaptureError.invalidRect
        }

        let fallbackScale = max(targetScreen.backingScaleFactor, 1.0)
        let scaleX = fallbackScale
        let scaleY = fallbackScale

        var pixelRect = CGRect(
            x: relativeRect.origin.x * scaleX,
            y: relativeRect.origin.y * scaleY,
            width: relativeRect.width * scaleX,
            height: relativeRect.height * scaleY
        ).integral

        let displayPixelBounds = CGRect(
            x: 0,
            y: 0,
            width: displayPointBounds.width * scaleX,
            height: displayPointBounds.height * scaleY
        )
        pixelRect = pixelRect.intersection(displayPixelBounds)

        guard pixelRect.width >= 1 && pixelRect.height >= 1 else {
            throw CaptureError.invalidRect
        }

        let sourceRect = CGRect(
            x: pixelRect.origin.x / scaleX,
            y: pixelRect.origin.y / scaleY,
            width: pixelRect.width / scaleX,
            height: pixelRect.height / scaleY
        )

        let pixelWidth = max(1, Int(pixelRect.width))
        let pixelHeight = max(1, Int(pixelRect.height))

        let filter = SCContentFilter(display: display, excludingWindows: [])

        if OCRSDebug.enabled {
            OCRSDebug.log("Capture rect quartz=\(rect) relative=\(relativeRect) source=\(sourceRect) scale=\(scaleX)")
        }

        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = pixelWidth
        config.height = pixelHeight
        config.scalesToFit = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        if #available(macOS 14.0, *) {
            config.captureResolution = .best
        }

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}

enum CaptureError: LocalizedError {
    case permissionDenied
    case invalidRect
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Screen Recording permission not granted."
        case .invalidRect: return "Invalid capture rectangle."
        case .noDisplay: return "No display available for capture."
        }
    }
}
