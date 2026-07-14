# Installing Flower

Flower is a menu-bar app: hold a trigger (a side mouse button by default), a ring
of your apps blooms around the cursor, and releasing over one opens it.

It's a small app shared directly (not from the App Store), so macOS needs you to
OK it once. Two steps:

### 1. Run the installer
Unzip `Flower.zip`. Inside the **Flower** folder, double-click
**Install Flower.command**.

macOS shows a one-time *"downloaded from the Internet — open?"* box the first time —
click **Open**. The installer moves Flower into your Applications folder, clears the
download flag for you, and launches it. A 🌸 icon appears in your menu bar.

> This replaces the old copy-into-Applications + Terminal step. The installer does
> the `xattr` quarantine cleanup itself, so Flower won't get the bogus "damaged"
> error.

### 2. Grant the permissions Flower asks for
On first launch a **Welcome to Flower** window walks you through two permissions,
each with a button that opens the exact System Settings pane:

- **Accessibility** *(required)* — lets Flower detect your trigger globally. The
  trigger starts working the moment you flip it on (no relaunch).
- **Screen Recording** *(optional)* — only for the live window-preview thumbnails.
  You may need to relaunch Flower once after granting this.

Each row flips to a green checkmark as soon as the grant lands. Click **Done** when
you're set.

---

## Using it
- **Open the ring:** hold the trigger (default = mouse side button), move toward
  an app, release to launch it. Set your own trigger in **Settings**.
- **Drill into windows:** while holding, drag *outward* over an app to fan out its
  open windows + "New Window."
- **Settings:** click the menu-bar flower → **Settings…** — pick your apps, rebind
  the trigger, choose "Launch at login," and pick a **Theme** (12 flower themes).

Enjoy 🌸
