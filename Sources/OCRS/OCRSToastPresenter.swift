import AppKit
import SwiftUI

struct OCRSToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 16, weight: .semibold))
            Text(message)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
    }
}

final class OCRSToastPresenter {
    static let shared = OCRSToastPresenter()

    private var window: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    func show(message: String) {
        dismissWorkItem?.cancel()

        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let size = NSSize(width: 220, height: 48)
        let origin = CGPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true

        let view = OCRSToastView(message: message)
        panel.contentView = NSHostingView(rootView: view)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }

        window?.close()
        window = panel

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let window = self.window else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.close()
                if self.window == window {
                    self.window = nil
                }
            })
        }

        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
}
