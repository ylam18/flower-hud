#!/bin/bash
# Double-clickable installer for Flower.
#
# Moves Flower into /Applications, clears the "downloaded from the internet"
# quarantine flag (so Gatekeeper doesn't wrongly call it "damaged"), and launches
# it. No Terminal typing — just double-click this file in Finder.
#
# The first time you double-click, macOS shows a one-time "downloaded from the
# Internet — open?" confirmation. Click Open; that's expected for a directly-shared
# (non-App-Store) app.
set -euo pipefail

# Resolve the folder this script lives in, so it works from wherever you unzipped.
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="Flower.app"
SRC="$HERE/$APP"
DEST="/Applications/$APP"

echo "🌸  Installing Flower…"
echo ""

if [ ! -d "$SRC" ]; then
    echo "❌  Couldn't find $APP next to this installer."
    echo "    Keep Flower.app and this file in the same folder, then try again."
    echo ""
    read -n 1 -s -r -p "Press any key to close."
    echo ""
    exit 1
fi

# Replace any previous install cleanly.
if [ -d "$DEST" ]; then
    echo "→  Removing the previous Flower in /Applications…"
    rm -rf "$DEST"
fi

echo "→  Installing Flower to /Applications…"
cp -R "$SRC" "$DEST"

echo "→  Clearing the download quarantine flag…"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "→  Launching Flower…"
open "$DEST"

echo ""
echo "✅  Done! Look for the 🌸 icon in your menu bar."
echo ""
echo "Flower will now walk you through two quick permissions:"
echo "   • Accessibility     (required — lets Flower detect your trigger)"
echo "   • Screen Recording  (optional — for live window previews)"
echo ""
read -n 1 -s -r -p "Press any key to close this window."
echo ""
