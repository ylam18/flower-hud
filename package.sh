#!/bin/bash
# Builds a UNIVERSAL (Apple Silicon + Intel) Flower.app and zips it for sharing.
#
# Unlike build.sh (which builds one arch for local use), this compiles for both
# arm64 and x86_64, fuses them with `lipo`, assembles the bundle, ad-hoc signs,
# and produces Flower.zip ready to send to friends. The app is NOT notarized, so
# recipients must clear the download quarantine once — see SHARING.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP_NAME="Flower"
BUNDLE_ID="com.safeship.flowerhud"
APP_DIR="$ROOT/$APP_NAME.app"
BUILD_DIR="$ROOT/.build-bin"
ZIP_PATH="$ROOT/$APP_NAME.zip"
mkdir -p "$BUILD_DIR"

# --- SwiftBridging duplicate-modulemap workaround (see build.sh for the why) --
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

# Gather sources (null-delimited so the "Will Projects" space is handled).
SOURCES=()
while IFS= read -r -d '' f; do SOURCES+=("$f"); done \
    < <(find "$ROOT/Sources/FlowerHUD" -name '*.swift' -print0)

# Compile each architecture to its own binary.
SLICES=()
for ARCH in arm64 x86_64; do
    TARGET="${ARCH}-apple-macosx13.0"
    OUT="$BUILD_DIR/$APP_NAME-$ARCH"
    echo "==> Compiling $ARCH ($TARGET)…"
    xcrun swiftc -O -target "$TARGET" \
        ${OVERLAY_ARGS[@]+"${OVERLAY_ARGS[@]}"} \
        -module-cache-path "$BUILD_DIR/modulecache-$ARCH" \
        -o "$OUT" \
        "${SOURCES[@]}"
    SLICES+=("$OUT")
done

# Fuse the slices into one universal binary.
echo "==> Creating universal binary (arm64 + x86_64)…"
lipo -create "${SLICES[@]}" -output "$BUILD_DIR/$APP_NAME-universal"

echo "==> Assembling $APP_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME-universal" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT/Info.plist" "$APP_DIR/Contents/Info.plist"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"
cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/MenuBarIcon.png" "$APP_DIR/Contents/Resources/MenuBarIcon.png"

echo "==> Ad-hoc code-signing…"
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_DIR"

# Stage the app alongside the double-clickable installer so the zip unpacks to a
# single "Flower" folder containing both — recipients just double-click the installer.
echo "==> Staging distributables…"
STAGE_ROOT="$BUILD_DIR/dist"
STAGE="$STAGE_ROOT/$APP_NAME"
rm -rf "$STAGE_ROOT"
mkdir -p "$STAGE"
cp -R "$APP_DIR" "$STAGE/"
cp "$ROOT/Install $APP_NAME.command" "$STAGE/"
chmod +x "$STAGE/Install $APP_NAME.command"

echo "==> Zipping…"
rm -f "$ZIP_PATH"
# ditto preserves the bundle structure, resource forks, and the installer's +x bit.
ditto -c -k --keepParent "$STAGE" "$ZIP_PATH"

echo ""
echo "✅ Universal build zipped: $ZIP_PATH"
lipo -info "$APP_DIR/Contents/MacOS/$APP_NAME"
echo "   Unzips to a '$APP_NAME' folder with $APP_NAME.app + 'Install $APP_NAME.command'."
echo "   Send this zip to friends along with SHARING.md."
