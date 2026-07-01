#!/bin/bash
# Builds Flower and assembles a runnable .app bundle, then ad-hoc code-signs it.
#
# Compiles directly with `swiftc` (no SwiftPM): the Command Line Tools ship a
# PackageDescription library that fails to link, so `swift build` is unavailable
# without full Xcode. Direct compilation needs only the Swift toolchain + macOS SDK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# User-facing app + executable name. Sources still live in Sources/FlowerHUD and the
# bundle ID is unchanged, so internal identifiers and existing config are preserved.
APP_NAME="Flower"
BUNDLE_ID="com.safeship.flowerhud"
APP_DIR="$ROOT/$APP_NAME.app"
BUILD_DIR="$ROOT/.build-bin"
mkdir -p "$BUILD_DIR"

# Apple Silicon by default; override with: ARCH=x86_64 ./build.sh
ARCH="${ARCH:-arm64}"
TARGET="${ARCH}-apple-macosx13.0"

# --- Workaround for a Command Line Tools packaging bug -----------------------
# Some CLT versions ship BOTH `module.modulemap` and `bridging.modulemap` in
# usr/include/swift, each defining `SwiftBridging` -> "redefinition of module"
# breaks every compile that builds AppKit/Foundation from their interfaces.
# When we detect the duplicate, we hide `module.modulemap` behind an empty file
# via a VFS overlay (non-invasive; touches no system files). On a healthy
# toolchain (only one map present) we skip the overlay entirely.
OVERLAY_ARGS=()
SWIFT_INC="$(cd "$(dirname "$(xcrun -f swiftc)")/../include/swift" 2>/dev/null && pwd || true)"
if [ -n "$SWIFT_INC" ] && [ -f "$SWIFT_INC/module.modulemap" ] && [ -f "$SWIFT_INC/bridging.modulemap" ]; then
    echo "==> Detected duplicate SwiftBridging modulemap; applying VFS overlay."
    EMPTY_MAP="$BUILD_DIR/empty.modulemap"
    OVERLAY="$BUILD_DIR/overlay.yaml"
    : > "$EMPTY_MAP"
    cat > "$OVERLAY" <<EOF
{
  "version": 0,
  "case-sensitive": false,
  "roots": [
    {
      "type": "directory",
      "name": "$SWIFT_INC",
      "contents": [
        { "type": "file", "name": "module.modulemap", "external-contents": "$EMPTY_MAP" }
      ]
    }
  ]
}
EOF
    OVERLAY_ARGS=(-vfsoverlay "$OVERLAY")
fi
# ----------------------------------------------------------------------------

echo "==> Compiling ($TARGET)… (first build rebuilds system modules and is slow; later builds are cached)"
# Null-delimited so paths containing spaces (e.g. "Will Projects") are handled correctly.
SOURCES=()
while IFS= read -r -d '' f; do SOURCES+=("$f"); done \
    < <(find "$ROOT/Sources/FlowerHUD" -name '*.swift' -print0)
xcrun swiftc -O -target "$TARGET" \
    "${OVERLAY_ARGS[@]}" \
    -module-cache-path "$BUILD_DIR/modulecache" \
    -o "$BUILD_DIR/$APP_NAME" \
    "${SOURCES[@]}"

echo "==> Assembling $APP_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT/Info.plist" "$APP_DIR/Contents/Info.plist"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

# Bundle resources: app icon (Finder/Dock/⌘-Tab) and the colored menu-bar icon.
cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/MenuBarIcon.png" "$APP_DIR/Contents/Resources/MenuBarIcon.png"

echo "==> Ad-hoc code-signing…"
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_DIR"

# Ad-hoc signatures change hash every build, so prior TCC grants go stale (the toggle
# shows "on" but no longer applies to the new binary). Clear them so the next launch
# shows ONE clean prompt each instead of a confusing stuck toggle. This covers both
# Accessibility (the trigger tap) and ScreenCapture (the window-preview thumbnails).
echo "==> Clearing stale Accessibility + Screen Recording grants…"
tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
tccutil reset ScreenCapture "$BUNDLE_ID" >/dev/null 2>&1 || true

echo ""
echo "✅ Built: $APP_DIR"
echo "   Run with:  open \"$APP_DIR\""
echo "   First run: grant Accessibility access when prompted, then relaunch."
