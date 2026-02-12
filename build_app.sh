#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

swift build -c release

BIN_PATH="${SCRIPT_DIR}/.build/release/OCRS"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "Binary not found at $BIN_PATH" >&2
  exit 1
fi

APP_DIR="${SCRIPT_DIR}/OCRS.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/OCRS"
cp "$SCRIPT_DIR/OCRS-Info.plist" "$CONTENTS_DIR/Info.plist"

ICON_ICNS="$SCRIPT_DIR/OCRS.icns"
if [[ ! -f "$ICON_ICNS" && -f "$SCRIPT_DIR/Assets/ocrs-icon.png" ]]; then
  ICONSET="$SCRIPT_DIR/Assets/OCRS.iconset"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  sips -z 16 16 "$SCRIPT_DIR/Assets/ocrs-icon.png" --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$SCRIPT_DIR/Assets/ocrs-icon.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$SCRIPT_DIR/Assets/ocrs-icon.png" --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$SCRIPT_DIR/Assets/ocrs-icon.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$SCRIPT_DIR/Assets/ocrs-icon.png" --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$SCRIPT_DIR/Assets/ocrs-icon.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$SCRIPT_DIR/Assets/ocrs-icon.png" --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$SCRIPT_DIR/Assets/ocrs-icon.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$SCRIPT_DIR/Assets/ocrs-icon.png" --out "$ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$SCRIPT_DIR/Assets/ocrs-icon.png" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET" -o "$SCRIPT_DIR/OCRS.icns"
  ICON_ICNS="$SCRIPT_DIR/OCRS.icns"
fi

if [[ -f "$ICON_ICNS" ]]; then
  cp "$ICON_ICNS" "$RESOURCES_DIR/OCRS.icns"
fi

chmod +x "$MACOS_DIR/OCRS"

echo "Built app at: $APP_DIR"
