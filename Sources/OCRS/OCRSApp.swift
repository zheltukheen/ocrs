import SwiftUI
import AppKit

@main
struct OCRSApp: App {
    @NSApplicationDelegateAdaptor(OCRSAppDelegate.self) private var appDelegate
    @StateObject private var appState = OCRSAppState()
    @StateObject private var updater = OCRSUpdater()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("OCRS", systemImage: "text.viewfinder") {
            Button("Capture OCR") {
                appState.captureOCR()
            }

            Divider()

            Button("Check for Updates...") {
                updater.checkForUpdates()
            }

            Button("Settings...") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("Quit OCRS") {
                NSApp.terminate(nil)
            }
        }

        Window("OCRS Settings", id: "settings") {
            OCRSSettingsView(appState: appState, updater: updater)
        }
        .defaultSize(width: 560, height: 560)
        .windowResizability(.contentSize)
    }
}

final class OCRSAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
