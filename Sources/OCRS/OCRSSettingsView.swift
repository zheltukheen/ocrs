import SwiftUI
import AppKit

struct OCRSSettingsView: View {
    @ObservedObject var appState: OCRSAppState
    @ObservedObject var updater: OCRSUpdater
    @ObservedObject private var permissionManager = OCRSPermissionManager.shared
    @AppStorage(OCRSPreferenceKey.outputMode) private var outputModeRaw: String = OCRSOutputMode.copy.rawValue
    @AppStorage(OCRSPreferenceKey.accuracyMode) private var accuracyModeRaw: String = OCRSAccuracyMode.standard.rawValue
    @AppStorage(OCRSPreferenceKey.languageMode) private var languageModeRaw: String = OCRSLanguageMode.auto.rawValue
    @State private var launchAtLogin = OCRSLaunchAtLogin.isEnabled()

    var body: some View {
        VStack(spacing: 20) {
            header

            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 16) {
                        Text("Launch")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 110, alignment: .leading)
                        Toggle("Launch at Login", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .labelsHidden()
                        Text("Launch at Login")
                            .font(.subheadline)
                        Spacer(minLength: 0)
                    }
                    Text("Start OCRS automatically when you sign in.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 126)
                }
                .padding(4)
            } label: {
                Text("General")
                    .font(.headline)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 16) {
                        Text("Updates")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 110, alignment: .leading)

                        Toggle("Auto Check", isOn: $updater.automaticallyChecksForUpdates)
                            .toggleStyle(.switch)
                            .labelsHidden()
                        Text("Auto Check")
                            .font(.subheadline)
                            .frame(width: 90, alignment: .leading)

                        Toggle("Auto Download", isOn: $updater.automaticallyDownloadsUpdates)
                            .toggleStyle(.switch)
                            .labelsHidden()
                        Text("Auto Download")
                            .font(.subheadline)
                        Spacer(minLength: 0)
                    }

                    Text("Automatic checks and downloads are handled by Sparkle.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 126)

                    HStack(alignment: .center, spacing: 16) {
                        Text("")
                            .frame(width: 110)
                        Button("Check for Updates...") {
                            updater.checkForUpdates()
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(4)
            } label: {
                Text("Updates")
                    .font(.headline)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 16) {
                        Text("Hotkey")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 110, alignment: .leading)
                        ShortcutRecorderView(shortcut: Binding(
                            get: { appState.hotkeyManager.shortcut },
                            set: { appState.hotkeyManager.shortcut = $0 }
                        ))
                        Spacer(minLength: 0)
                    }

                    Divider()

                    HStack(alignment: .top, spacing: 16) {
                        Text("Output")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 110, alignment: .leading)
                        Picker("", selection: $outputModeRaw) {
                            ForEach(OCRSOutputMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 280)
                        Spacer(minLength: 0)
                    }

                    HStack(alignment: .top, spacing: 16) {
                        Text("Accuracy")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 110, alignment: .leading)
                        Picker("", selection: $accuracyModeRaw) {
                            ForEach(OCRSAccuracyMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .frame(maxWidth: 280, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                    Text("High Accuracy improves small or low-contrast text but takes longer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 126)

                    HStack(alignment: .top, spacing: 16) {
                        Text("Language")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 110, alignment: .leading)
                        Picker("", selection: $languageModeRaw) {
                            ForEach(OCRSLanguageMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: 280, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                    Text("Auto works best for mixed languages. Choose a specific language for higher accuracy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 126)
                }
                .padding(4)
            } label: {
                Text("Capture")
                    .font(.headline)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: permissionManager.screenRecordingGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(permissionManager.screenRecordingGranted ? .green : .red)
                        Text(permissionManager.screenRecordingGranted ? "Screen Recording: Granted" : "Screen Recording: Not Granted")
                            .font(.subheadline.weight(.semibold))
                    }

                    Text("OCRS needs Screen Recording permission to capture the selected area.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button("Open Screen Recording Settings") {
                            openPrivacyPane("ScreenCapture")
                        }
                        Button("Refresh Status") {
                            _ = permissionManager.refresh()
                        }
                    }

                    Divider()

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Input Monitoring: Not Required")
                            .font(.subheadline.weight(.semibold))
                    }
                    Text("OCRS uses Carbon hotkeys and does not require Input Monitoring permission.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            } label: {
                Text("Permissions")
                    .font(.headline)
            }

            HStack {
                Spacer()
                Button("Test Capture") {
                    appState.captureOCR()
                }
                .keyboardShortcut(.return, modifiers: [])
                Spacer()
            }

            VStack(spacing: 4) {
                Divider()
                Text("Created by zheltukheen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(24)
        .frame(width: 560)
        .onAppear {
            _ = permissionManager.refresh()
            launchAtLogin = OCRSLaunchAtLogin.isEnabled()
        }
        .onChange(of: updater.automaticallyChecksForUpdates) { _, _ in
            updater.syncSettings()
        }
        .onChange(of: updater.automaticallyDownloadsUpdates) { _, _ in
            updater.syncSettings()
        }
        .onChange(of: launchAtLogin) { _, newValue in
            let ok = OCRSLaunchAtLogin.setEnabled(newValue)
            if !ok {
                launchAtLogin = OCRSLaunchAtLogin.isEnabled()
                OCRSErrorPresenter.shared.showError(message: "Could not update Login Item. Please try again.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .padding(12)
                .background(Circle().fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 4) {
                Text("OCRS")
                    .font(.title3.weight(.semibold))
                Text("Capture any area and extract text instantly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func openPrivacyPane(_ pane: String) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)")
        if let url { NSWorkspace.shared.open(url) }
    }
}
