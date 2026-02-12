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
- `release-please.yml` manages versioning and release PRs.
- When a release is created, `release-please.yml` builds the app, generates `appcast.xml`, and uploads both to GitHub Releases.
- Release notes come from `CHANGELOG.md`.

**Release flow (Release Please)**
1. Merge changes into `main`.
2. Release Please opens a PR with version + changelog.
3. Merge the PR and a GitHub Release is created with `OCRS.app` attached.
4. The release also publishes `appcast.xml` for Sparkle auto-updates.

**Required GitHub settings**
1. Repository Settings → Actions → General.
2. Workflow permissions: **Read and write**.
3. Enable **“Allow GitHub Actions to create and approve pull requests.”**

**Sparkle updates**
- The app uses Sparkle for automatic updates.
- The appcast is published as a GitHub Release asset (`appcast.xml`).
- For production-grade security, add Sparkle EdDSA signing and `SUPublicEDKey`.

**Manual version bump (optional)**
1. `./scripts/bump_version.sh 1.2.0 "Release notes line 1" "Release notes line 2"`
2. `git push --follow-tags`
