# SketchyBar Configuration (Lua + AeroSpace, TokyoNight Night)

A dynamic, event-driven [SketchyBar](https://github.com/FelixKratz/SketchyBar) config written in **Lua** (via [SbarLua](https://github.com/FelixKratz/SbarLua)), themed **TokyoNight Night**, and tightly integrated with the [AeroSpace](https://github.com/nikitabobko/AeroSpace) tiling window manager.

A floating, rounded, translucent bar with per-item pills (navy fill + colored borders), fully event-driven.

## Features

- **Workspaces (AeroSpace):** Per-workspace pills showing an icon for each open app, with the **active window's app highlighted red**. Icons are ordered **left-to-right to match the on-screen tiling** and **re-order instantly** when you move a window. Empty workspaces hide automatically.
- **App fallback:** When AeroSpace is disabled or not running, the workspaces auto-swap to a single pill listing your **open apps** with the **active app highlighted** — sourced from native macOS, no AeroSpace required.
- **CPU:** Live load sparkline + percentage; graph color shifts blue → yellow → orange → red with load. Click → Activity Monitor.
- **Memory (RAM):** Live memory-usage sparkline + percentage.
- **Temperature:** Live CPU temperature graph (°C), works on Apple Silicon — all three fed by a single native stats provider.
- **Wi-Fi:** Stacked ↓ download / ↑ upload throughput, greyed when idle. Click → Wi-Fi settings.
- **Volume:** Compact percentage + icon.
- **Battery:** Compact percentage with charging states + time-remaining popup (native helper).
- **Menus (≡):** Renders the **focused app's macOS menu bar** on click, via a native Accessibility helper.
- **Clock:** Date + time in a rounded pill.
- **Resilient:** Providers auto-restart after the Mac wakes from sleep; workspaces rebuild automatically if AeroSpace starts after SketchyBar.

> Everything below is the exact recipe to reproduce this setup on a fresh Apple Silicon Mac.

---

## 1. Prerequisites

| Tool | Why |
|------|-----|
| macOS (Apple Silicon; tested on arm64) | Platform |
| [Homebrew](https://brew.sh) | Package manager |
| Xcode Command Line Tools (`clang`, `make`, `swiftc`) | Compiles the C/Swift helpers |

```bash
# Homebrew (skip if already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Xcode Command Line Tools (provides clang, make, swiftc)
xcode-select --install
```

---

## 2. Install dependencies

### 2.1 Core apps

```bash
# SketchyBar
brew tap FelixKratz/formulae
brew install sketchybar

# AeroSpace tiling window manager
brew install --cask nikitabobko/tap/aerospace

# Lua interpreter (the config runs as a Lua script)
brew install lua
```

### 2.2 SbarLua module (required — the config is Lua)

SketchyBar has no built-in Lua; SbarLua is a C module that bridges Lua ⇆ SketchyBar. It installs to `~/.local/share/sketchybar_lua/sketchybar.so`, which `helpers/init.lua` adds to `package.cpath`.

```bash
git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua
cd /tmp/SbarLua && make install
# verify:
ls ~/.local/share/sketchybar_lua/sketchybar.so
```

### 2.3 System stats provider (CPU / RAM / Temp)

A single Rust binary (`stats_provider`) emits a `system_stats` event. It reads CPU temperature on Apple Silicon without sudo.

```bash
brew tap joncrangle/tap
brew trust joncrangle/tap          # newer Homebrew gates third-party taps
brew install sketchybar-system-stats
# verify:
stats_provider --version
```

### 2.4 Fonts

```bash
# Icon + label fonts
brew install --cask font-hack-nerd-font          # icon font
brew install --cask font-jetbrains-mono-nerd-font # label font
```

- **SF Pro** ships with macOS (used for some SF Symbol glyphs; install from Apple's *SF Pro* download if missing).
- **sketchybar-app-font** — used for the per-app workspace icons. **Install a RECENT release** (older versions lack newer app glyphs such as `:ghostty:`):

```bash
curl -fsSL -o ~/Library/Fonts/sketchybar-app-font.ttf \
  https://github.com/kvndrsslr/sketchybar-app-font/releases/latest/download/sketchybar-app-font.ttf
```

---

## 3. Install this configuration

Place this repo at `~/.config/sketchybar`:

```bash
# if you keep it in a dotfiles repo, symlink or copy it into place
git clone <your-dotfiles> ~/dotfiles
ln -s ~/dotfiles/config/sketchybar ~/.config/sketchybar
# — or just copy the folder to ~/.config/sketchybar
chmod +x ~/.config/sketchybar/sketchybarrc
```

### 3.1 Build the helper binaries

The compiled helpers live under `helpers/` and their `bin/` outputs are **git-ignored** (see [helpers/.gitignore](helpers/.gitignore)), so they must be built on each machine. `helpers/init.lua` runs `make` automatically on every SketchyBar load, but you can build them manually:

```bash
cd ~/.config/sketchybar/helpers && make
```

This builds:
- `event_providers/cpu_load`, `event_providers/network_load` (C) — network throughput for the WiFi widget.
- `menus` (C) — reads the focused app's macOS menu bar for the `≡` button.
- `window_positions` (Swift) — prints each window's CoreGraphics id + x/y so workspace app icons can be ordered by on-screen position.

> Requires `clang`, `make`, and `swiftc` (from Xcode CLT).

---

## 4. Grant permissions

### 4.1 Accessibility — **required** for the `≡` menu button

The `menus` helper uses the Accessibility API to read the frontmost app's menu bar. Without permission it returns nothing and the `≡` button does nothing.

1. **System Settings → Privacy & Security → Accessibility**
2. Click **+**, press **⌘⇧G**, and add the real binary path (use the Cellar path, not the symlink):
   `/opt/homebrew/Cellar/sketchybar/<version>/bin/sketchybar`
3. Toggle **sketchybar ON**, then restart it (`brew services restart sketchybar`).

> SketchyBar runs as a background service, so macOS usually won't auto-prompt — add it manually.

### 4.2 Accessibility — AeroSpace

AeroSpace also needs Accessibility permission (it prompts on first launch). Grant it so window management works.

---

## 5. AeroSpace integration

The workspace items react to AeroSpace events. Two things must be wired in `~/.config/aerospace/aerospace.toml`:

### 5.1 Workspace-change event (usually already present)

```toml
exec-on-workspace-change = [
  '/bin/bash', '-c',
  'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE'
]
```

### 5.2 Instant icon re-ordering on window moves (added by this setup)

AeroSpace fires no event when you *move* a window within a workspace, so each move/join binding also triggers a custom `window_moved` event that SketchyBar listens for. Update these bindings to command **lists**:

```toml
# Move within a workspace
alt-shift-h = ['move left',  'exec-and-forget sketchybar --trigger window_moved']
alt-shift-k = ['move down',  'exec-and-forget sketchybar --trigger window_moved']
alt-shift-j = ['move up',    'exec-and-forget sketchybar --trigger window_moved']
alt-shift-l = ['move right', 'exec-and-forget sketchybar --trigger window_moved']

# Join
cmd-alt-h = ['join-with left',  'exec-and-forget sketchybar --trigger window_moved']
cmd-alt-k = ['join-with down',  'exec-and-forget sketchybar --trigger window_moved']
cmd-alt-j = ['join-with up',    'exec-and-forget sketchybar --trigger window_moved']
cmd-alt-l = ['join-with right', 'exec-and-forget sketchybar --trigger window_moved']

# Move a window to another workspace
alt-shift-1 = ['move-node-to-workspace 1', 'exec-and-forget sketchybar --trigger window_moved']
# ... repeat for 2–9
```

Reload AeroSpace after editing: `aerospace reload-config`.

---

## 6. Start it

```bash
brew services start sketchybar     # start on login + now
# or restart after changes:
brew services restart sketchybar
# reload config without a full restart:
sketchybar --reload
```

---

## 7. How the config loads

```text
sketchybarrc                     ← entry point (a Lua script, shebang: #!/usr/bin/env lua)
  └─ require("helpers")          ← sets package.cpath for SbarLua, runs `make` on helpers
  └─ require("init")
       ├─ sbar.begin_config()    ← batches the whole initial setup into one message
       ├─ require("bar")         ← bar geometry (floating, rounded, translucent)
       ├─ require("appearance")  ← TokyoNight palette + global item defaults (sbar.default)
       ├─ require("items")       ← loads every bar item (see items/init.lua)
       ├─ sbar.end_config()      ← flushes the batch
       └─ sbar.event_loop()      ← long-running loop that dispatches callbacks
```

### File map

| File | Purpose |
|------|---------|
| [sketchybarrc](sketchybarrc) | Entry point (don't edit) |
| [init.lua](init.lua) | Orchestrates load order |
| [bar.lua](bar.lua) | Bar position/size/blur/margins |
| [settings.lua](settings.lua) | Heights, paddings (data table) |
| [appearance.lua](appearance.lua) | **Colors** (TokyoNight), workspace styles, global `sbar.default` |
| [fonts.lua](fonts.lua) | Font families/sizes (labels = JetBrainsMono Nerd Font 14, icons = Hack Nerd Font) |
| [icons.lua](icons.lua) | SF Symbol / Nerd Font glyph map |
| [items/init.lua](items/init.lua) | Which items load (comment a line to remove one) |
| [items/spaces.lua](items/spaces.lua) | AeroSpace workspaces + per-app icons (the big one) |
| [items/menus.lua](items/menus.lua) | `≡` button → focused app's menu bar |
| [items/calendar.lua](items/calendar.lua) | Clock (magenta) |
| [items/widgets/init.lua](items/widgets/init.lua) | Which widgets load |
| [items/widgets/cpu.lua](items/widgets/cpu.lua) | CPU graph + **starts `stats_provider`** |
| [items/widgets/ram.lua](items/widgets/ram.lua) | RAM graph (uses `system_stats`) |
| [items/widgets/temp.lua](items/widgets/temp.lua) | CPU temp graph (uses `system_stats`) |
| [items/widgets/wifi.lua](items/widgets/wifi.lua) | Stacked ↓/↑ network speeds (uses `network_load`) |
| [items/widgets/battery.lua](items/widgets/battery.lua) | Battery |
| [items/widgets/volume.lua](items/widgets/volume.lua) | Volume + slider popup |

---

## 8. The workspace widget ([items/spaces.lua](items/spaces.lua))

Each workspace is a **bracket pill** wrapping a number item (`N:`) + a fixed pool of per-app icon items, plus an invisible spacer for the gap between pills. Key behaviors:

- **Per-app icons** via `sketchybar-app-font` (mapped in [helpers/app_icons.lua](helpers/app_icons.lua)).
- **Focused window highlight** — the number and the active window's app icon turn **red**; everything else blue.
- **Position ordering** — app icons are ordered left-to-right by real window X/Y (from the `window_positions` helper). Only the *visible* workspace has real coordinates (hidden ones are parked off-screen), so hidden workspaces keep their last on-screen order via an order cache.
- **Instant updates** — reacts to `aerospace_workspace_change`, `front_app_switched`, `window_moved`, plus a 2 s poller as a backstop for mouse moves.
- **Memoized rendering** — only items whose state actually changed are re-`set()`, which is what stops the pills from resizing/flickering on every update.

---

## 9. System widgets

- **CPU / RAM / Temp** are fed by ONE `stats_provider` process (started in [cpu.lua](items/widgets/cpu.lua)) emitting `system_stats` every 2 s (`--no-units` → plain numbers). Each is a sparkline graph + value in a padded pill; color shifts blue → yellow → orange → red with load/temperature.
- **WiFi** uses the `network_load` C provider (`network_update` event) and shows ↓download over ↑upload, stacked in one compact pill (the upload item is added first with `width = 0` so the download item overlaps it; `y_offset` stacks them).

---

## 10. Customizing

| Want to change… | Edit |
|---|---|
| Theme colors | [appearance.lua](appearance.lua) — `M.colors.active = M.colors.tokyonight` and the palette |
| Bar height / margins / blur | [bar.lua](bar.lua), [settings.lua](settings.lua) |
| Fonts | [fonts.lua](fonts.lua) |
| Add/remove an item | comment its `require` in [items/init.lua](items/init.lua) / [items/widgets/init.lua](items/widgets/init.lua) |
| Workspace label format | [items/spaces.lua](items/spaces.lua) — `string = workspace_index .. ":"` |
| Gap between workspace pills | [items/spaces.lua](items/spaces.lua) — `WORKSPACE_GAP` |
| Widget thresholds/colors | the respective `items/widgets/*.lua` |

After edits: `sketchybar --reload`.

---

## 11. Troubleshooting

- **Bar disappears / shows default look after a reload** — a batched config sometimes half-applies if reloads overlap async AeroSpace queries. Fix: `sketchybar --reload` (or `brew services restart sketchybar`).
- **`≡` button does nothing** — grant Accessibility to sketchybar (§4.1) and restart it.
- **CPU/RAM/Temp frozen or blank** — the `stats_provider` process died. It's restarted on reload; check `pgrep -x stats_provider`. Don't `killall stats_provider` without reloading.
- **Missing app icons in a workspace** — update `sketchybar-app-font` to the latest release (§2.4).
- **Icons don't reorder on window move** — ensure the `window_moved` triggers are in `aerospace.toml` (§5.2) and `aerospace reload-config` was run.

---

## 12. External dependencies checklist (not in this repo)

These live outside the repo and must be reinstalled on a new machine:

- [ ] `sketchybar` (brew) + Accessibility permission
- [ ] `aerospace` (brew cask) + Accessibility permission + `aerospace.toml` triggers
- [ ] `lua` (brew)
- [ ] **SbarLua** → `~/.local/share/sketchybar_lua/sketchybar.so`
- [ ] `sketchybar-system-stats` (`stats_provider`, brew tap)
- [ ] Fonts: Hack Nerd Font, JetBrainsMono Nerd Font, **recent** sketchybar-app-font, SF Pro
- [ ] Helper binaries built (`cd helpers && make`; needs Xcode CLT + `swiftc`)
