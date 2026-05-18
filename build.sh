#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/MirrorCheck.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
CACHE_DIR="$ROOT_DIR/.build/module-cache"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$CACHE_DIR"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

if [[ -f "$ROOT_DIR/logo.png" ]]; then
  cp "$ROOT_DIR/logo.png" "$RESOURCES_DIR/logo.png"
  ICONSET_DIR="$ROOT_DIR/.build/AppIcon.iconset"
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"
  sips -z 16 16 "$ROOT_DIR/logo.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ROOT_DIR/logo.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ROOT_DIR/logo.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ROOT_DIR/logo.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ROOT_DIR/logo.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ROOT_DIR/logo.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ROOT_DIR/logo.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ROOT_DIR/logo.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ROOT_DIR/logo.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ROOT_DIR/logo.png" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
  if ! iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null; then
    true
  fi
fi

clang \
  -fobjc-arc \
  -fmodules \
  -fmodules-cache-path="$CACHE_DIR" \
  -O2 \
  -framework Cocoa \
  -framework AVFoundation \
  "$ROOT_DIR/Sources/MirrorCheck/main.m" \
  -o "$MACOS_DIR/MirrorCheck"

codesign --force --sign - "$APP_DIR"

echo "Built $APP_DIR"
