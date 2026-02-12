import AppKit
import SwiftUI

final class OCRResultWindowController {
    private var window: NSPanel?

    func show(text: String) {
        close()

        let contentView = OCRResultView(text: text, onCopy: { [weak self] in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            OCRSToastPresenter.shared.show(message: "Copied")
            self?.close()
        }, onClose: { [weak self] in
            self?.close()
        })

        let hostingView = NSHostingView(rootView: contentView)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.center()
        panel.title = "OCR Result"
        panel.titleVisibility = .visible
        panel.isReleasedWhenClosed = false
        panel.contentView = hostingView

        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = panel
    }

    func close() {
        window?.close()
        window = nil
    }
}
