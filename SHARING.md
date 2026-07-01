# Installing Flower

Flower is a menu-bar app: hold a trigger (a side mouse button by default), a ring
of your apps blooms around the cursor, and releasing over one opens it.

It's a small app shared directly (not from the App Store), so macOS needs you to
OK it once. Three steps:

### 1. Move it to Applications
Unzip `Flower.zip`, then drag **Flower.app** into your **Applications** folder.

### 2. Clear the "downloaded from the internet" flag
macOS quarantines apps that didn't come from the App Store. Open **Terminal**
(Applications ▸ Utilities ▸ Terminal) and paste this, then press Return:

```bash
xattr -dr com.apple.quarantine /Applications/Flower.app
```

(If you put Flower somewhere other than Applications, change the path to match.)

Now double-click **Flower** to launch it. A flower icon appears in your menu bar.

> If you skip step 2, macOS will say Flower is "damaged" or "can't be opened" —
> it isn't; that's just Gatekeeper blocking the quarantine flag. Run the command
> and it'll open fine.

### 3. Grant Accessibility access
Flower watches for its trigger globally, which macOS gates behind Accessibility
permission. On first launch it'll prompt you — or turn it on manually at:

**System Settings ▸ Privacy & Security ▸ Accessibility** → enable **Flower**.

The trigger starts working the moment access is granted (no relaunch needed).

---

## Using it
- **Open the ring:** hold the trigger (default = mouse side button), move toward
  an app, release to launch it. Set your own trigger in **Settings**.
- **Drill into windows:** while holding, drag *outward* over an app to fan out its
  open windows + "New Window."
- **Settings:** click the menu-bar flower → **Settings…** — pick your apps, rebind
  the trigger, choose "Launch at login," and pick a **Theme** (12 flower themes).

Enjoy 🌸
