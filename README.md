# OCRS

Menu bar OCR for macOS with area capture, hotkeys, and clipboard or popup output.

**Features**
- Menu bar app with global hotkey and area selection.
- Fast OCR using Apple Vision with multi-pass pipelines for small and low-contrast text.
- Language options for Auto, System, English, and Russian.
- Output to clipboard or popup window.
- On-screen “Copied” toast.
- Screen Recording permission status and one-click access to settings.
- Launch at Login toggle.

**Requirements**
- macOS 14 (Sonoma) or newer.

**Install**
1. Download the latest release from GitHub.
2. Move `OCRS.app` to `/Applications`.
3. Launch OCRS and grant Screen Recording permission when prompted.

**Build**
1. `swift build -c release`
2. `./build_app.sh`
3. The app is created at `OCRS.app`.

**Usage**
1. Click the menu bar icon and choose “Capture OCR”, or use the global hotkey.
2. Drag to select a region.
3. The recognized text is copied or shown in a popup based on settings.

**Settings**
- Output: Copy to Clipboard or Show Popup.
- Accuracy: Standard or High Accuracy (slower).
- Language: Auto Detect, System Languages, English, Russian.
- Launch at Login toggle.

**Permissions**
- Screen Recording is required for capturing the selected area.
- Input Monitoring is not required (Carbon hotkeys).

**Performance**
- Large captures are downscaled for speed.
- Pre-detection limits OCR to text regions.
- Two-stage recognition improves latency without reducing accuracy.
- vImage preprocessing improves contrast and edge clarity.

**Troubleshooting**
- If capture fails, confirm Screen Recording permission in System Settings.
- If OCR is slow, capture smaller regions and use Standard accuracy.

**CI and Releases**
- `ci.yml` builds the app on each push and pull request.
- `release.yml` builds a signed artifact and publishes GitHub Releases.
- Release notes are pulled from `CHANGELOG.md`.

**Local release**
1. `./scripts/bump_version.sh 1.2.0 "Release notes line 1" "Release notes line 2"`
2. `git push --follow-tags`
