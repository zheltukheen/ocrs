# Changelog

## 1.20 - 2026-02-12
- Release 1.20.


## 1.1.0 - 2026-02-12
- Initial public release of OCRS as a lightweight macOS menu bar OCR app.
- Menu bar UI with Capture, Settings, and Quit actions.
- Global hotkey capture with custom shortcut recorder.
- Area selection overlay with live size indicator and cancel support.
- Clipboard and popup output modes.
- On-screen “Copied” toast.
- Screen Recording permission check with System Settings shortcut.
- Launch at Login toggle.
- App icon, Info.plist metadata, and menu bar branding.
- Standard and High Accuracy OCR modes.
- Language options with Auto Detect, System Languages, English, and Russian.
- Multi-pass OCR pipelines tuned for low-contrast and small text.
- White-on-black handling via inversion-aware pipelines.
- OCR fallback from Standard to High on empty results.
- Error handling and user-friendly messages.
- Fixed settings window stability.
- Fixed capture alignment for retina and multi-display setups.
- Debug tooling for capture and pipeline inspection (disabled by default).
- Performance improvements with adaptive downscale for large captures.
- vImage preprocessing with contrast stretch and light sharpening.
- Pre-detect text blocks and OCR only within regions of interest.
- Two-stage recognition to reduce latency without harming accuracy.
- Parallelized batch OCR for faster end-to-end results.
- CI build workflow and automated release workflow.
- Comprehensive README and usage documentation.
