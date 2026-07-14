# Flower

A macOS quick-launcher. **Hold** a configurable trigger (a mouse button *or* a keyboard key)
and a radial "flower" of app icons fans out around your cursor. Move toward an app and
**release** to open it — Flower brings the app's existing window forward, or launches it
fresh if it isn't running.

By default the flower shows the apps pinned to your **Dock**. A settings window lets you build
a **custom preset** and rebind the trigger.

## Download & install

The ready-to-run app is committed to this repo as **`Flower.zip`** — no build tools needed,
just download it straight from here:

1. In the file list at the top of this repo, click **`Flower.zip`**, then **Download raw file**.
2. Unzip it. Inside the **Flower** folder, double-click **Install Flower.command**.
3. macOS shows a one-time *"downloaded from the Internet — open?"* prompt — click **Open**.
   The installer copies Flower into your Applications folder, clears the download-quarantine
   flag, and launches it. A 🌸 icon appears in your menu bar.

Flower is shared directly (not via the App Store) and is ad-hoc signed, not notarized — that
single "Open" click is expected and only happens once. See **[SHARING.md](SHARING.md)** for the
full walkthrough, including the permissions Flower requests on first launch.

## Build from source (developers)

Prefer to build it yourself?

**Requirements**
- macOS 13 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`) — full Xcode is **not** required

```bash
./build.sh       # compiles and assembles Flower.app (Apple Silicon)
open Flower.app  # launches it (menu-bar icon only — no Dock icon)
```

For Intel: `ARCH=x86_64 ./build.sh`. To rebuild the shareable `Flower.zip` (universal binary
+ installer), run `./package.sh`.

### First launch

1. Flower appears as a ❀ icon in the menu bar.
2. It will ask for **Accessibility access** — this is required to detect your trigger button
   anywhere on the system. Grant it in **System Settings → Privacy & Security → Accessibility**.
3. The trigger activates automatically the moment access is granted — no relaunch needed.

### Using it

- **Default trigger:** a side mouse button (button 4 / "back"). Rebind it in
  **menu bar → Settings → General**.
- Hold the trigger → the flower appears at your cursor → move toward an app → release to open it.
- Releasing while the cursor is still near the center selects nothing.

## Settings

- **General** — rebind the trigger (any key or mouse button), check Accessibility status,
  toggle launch-at-login.
- **Apps** — choose the source: **Dock apps** (default, read live) or a **Custom preset** you
  build by adding apps from `/Applications` (reorder by dragging, remove with Delete).

## How it works

| Concern | Approach |
|---|---|
| Background agent (no Dock icon) | `NSApplication` with `.accessory` activation policy + `LSUIElement` |
| Global trigger (mouse **or** key) | one `CGEventTap` (`Sources/FlowerHUD/Trigger`) — needs Accessibility |
| Overlay at the cursor | non-activating, transparent `NSPanel` (`Sources/FlowerHUD/Flower`) |
| Petal selection | computed from cursor angle/distance, not hover — works through a click-through panel |
| App list | live Dock read (`Apps/DockReader`) or a custom preset (`Apps/PresetStore`) |
| Launch / switch | `NSWorkspace.openApplication` (`Apps/AppLauncher`) |

## Notes & limitations

- **Window previews need Screen Recording.** Drilling into an app fans out its open windows; hovering
  a window shows a small live thumbnail in a floating frame. Capturing that image requires the
  **Screen Recording** permission (System Settings → Privacy & Security → Screen Recording) — separate
  from Accessibility. The first hover triggers the one-time system prompt; grant it and previews
  appear. Minimized/off-screen windows have no capturable image, so they simply show no preview.
- **Not sandboxed.** Reading the Dock and installing a global event tap both preclude the App
  Store sandbox. Fine for personal use; sharing the app would require notarization.
- **Trigger choice matters.** The bound key/button is *consumed* while held (so it doesn't also
  type or click). Avoid binding a primary mouse button or a common typing key — a side button or
  an unused key is ideal.
- **Dock reading is best-effort** (no public API). If it ever comes back empty, switch to a
  custom preset.
- Building uses `swiftc` directly because SwiftPM's manifest API doesn't link under Command Line
  Tools alone. `Package.swift` is kept for opening the project in full Xcode later.
