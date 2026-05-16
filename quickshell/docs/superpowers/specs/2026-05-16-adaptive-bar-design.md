# Adaptive Quickshell Bar — Design Spec

**Date:** 2026-05-16  
**Status:** Approved

---

## Overview

Transform the Quickshell TopBar into a distributable, multi-distro desktop environment:

1. **Widget registry** — configurable island layout via `settings.json` + GUI
2. **Unified settings app** — bar layout + Hyprland settings in one place
3. **Install script** — detects distro, installs deps, sets up config

Scope: Hyprland compositor only, any modern Linux distro.

---

## 1. Widget Registry

### settings.json schema addition

```json
{
  "islands": {
    "left":  ["workspaces", "search", "notifications", "theme", "update"],
    "right": ["volume", "network", "clock", "quicksettings", "recording"]
  }
}
```

- Array order = render order in the bar
- Omitting a widget name hides it completely
- Unknown names are silently ignored (forward-compat)

### Config.qml additions

```qml
property var islandLeft:  getSetting("islands.left",  ["workspaces","search","notifications","theme","update"])
property var islandRight: getSetting("islands.right", ["volume","network","clock","quicksettings","recording"])

function islandHas(side, name) {
    return (side === "left" ? islandLeft : islandRight).indexOf(name) !== -1
}
```

### Widget visibility gating

Every widget in `rebuiltLeftRow` / right island gets:
```qml
visible: Config.islandHas("left", "search")
```

Widgets are rendered in source order; the array controls which are shown (not order yet — ordering comes in a future phase once drag-reorder is wired up).

> **Note on ordering:** Phase 1 controls visibility only — widgets render in their existing source order (workspaces already at the left edge after the recent fix). Phase 2 adds full drag-to-reorder by switching to a dynamic `Repeater` over the island array.

### Available widgets

| ID | Island | Component |
|----|--------|-----------|
| `workspaces` | left | Workspace pills |
| `search` | left | App launcher button |
| `notifications` | left | Bell + badge |
| `theme` | left | Theme picker button |
| `update` | left | Update indicator |
| `volume` | right | Volume chip |
| `network` | right | WiFi/BT chip |
| `clock` | right | Time display |
| `quicksettings` | right | Quick settings toggle |
| `recording` | right | Recording indicator |

---

## 2. Unified Settings App

### Tab structure

The existing `SettingsPopup.qml` has tabs 0–3 (General, Weather, Keybinds, Startup). Add:

| Tab index | Name | Content |
|-----------|------|---------|
| 4 | Bar Layout | Island widget configurator |
| 5 | Hyprland | Hyprland keyword settings |

### Tab 4: Bar Layout

Two columns: **Left Island** and **Right Island**.

Each column:
- Active widgets shown as draggable chips (ordered list)
- X button removes a chip (writes to `islands.left/right`)
- "Add widget" row at bottom shows available-but-disabled widgets as + buttons
- Changes write to `settings.json` via `Config.setSetting("islands.left", newArray)` and take effect immediately (reactive)

No restart required — `Config.islandLeft` is reactive, so visibility updates live.

### Tab 5: Hyprland Settings

Settings applied immediately via `hyprctl keyword <key> <value>`. Persisted to `~/.config/hypr/hyprland.conf` by patching the relevant line (regex replace).

**Groups:**

**General**
- Border size (slider 1–8)
- Gap size inner/outer (sliders)
- Border rounding (slider 0–20)
- Active border color (color picker → mauve default)

**Input**
- Keyboard layout (text field → `kb_layout`)
- Repeat rate / repeat delay (sliders)
- Follow mouse focus (toggle)
- Natural scroll (toggle)

**Animations**
- Enable/disable animations (toggle)
- Animation speed multiplier (slider 0.5–3×, scales bezier durations)

**Monitors**
- Read current monitors via `hyprctl monitors -j`
- Show each monitor: resolution, refresh rate, scale, position
- Scale slider per monitor (0.5–2.0, step 0.25)
- Apply button → `hyprctl keyword monitor <name>,<res>@<hz>,<pos>,<scale>`

**Misc**
- Splash text (toggle)
- Window swallowing (toggle)

---

## 3. Install Script

### File: `install.sh` (repo root)

```
install.sh
  ├── detect_distro()     → reads /etc/os-release → sets PKG_MANAGER, INSTALL_CMD
  ├── install_deps()      → installs quickshell, fonts, hyprland tools per distro
  ├── setup_config()      → copies/symlinks ~/.config/quickshell
  └── post_install()      → prints next steps
```

### Distro → package manager mapping

| Distro family | Detection | Package manager |
|---------------|-----------|-----------------|
| Arch / CachyOS / EndeavourOS | `ID=arch` or `ID_LIKE=arch` | `pacman` + `yay`/`paru` for AUR |
| Fedora | `ID=fedora` | `dnf` |
| Gentoo | `ID=gentoo` | `emerge` |
| NixOS | `ID=nixos` | `nix-env` or Home Manager module |
| Debian/Ubuntu | `ID=debian` or `ID_LIKE=debian` | `apt` (best-effort, Quickshell may need manual build) |

### Dependencies per distro

Common: `quickshell`, `hyprland`, `pipewire`, `networkmanager`, `inotify-tools`, `jq`, `ttf-jetbrains-mono-nerd`, `ttf-iosevka-nerd`

NixOS: generate a `home.nix` snippet the user can include; no `nix-env` install.

### Config setup

```bash
DEST="$HOME/.config/quickshell"
if [ -d "$DEST" ]; then
    mv "$DEST" "${DEST}.bak.$(date +%s)"
fi
# Symlink so git pull updates the install
ln -sf "$(pwd)/quickshell" "$DEST"
```

### Repo structure

```
/
├── install.sh
├── README.md
├── quickshell/          ← the bar config (existing dotfiles/quickshell/)
│   ├── Shell.qml
│   ├── TopBar.qml
│   ├── settings.json    ← user config (gitignored after first install)
│   ├── docs/
│   └── ...
└── nixos/
    └── quickshell-module.nix   ← optional Home Manager module
```

---

## 4. Implementation Phases

### Phase 1 — Widget visibility gating
- Add `islands` to `settings.json` defaults
- Add `islandLeft`/`islandRight`/`islandHas()` to `Config.qml`
- Gate every widget in `rebuiltLeftRow` and right island with `visible: Config.islandHas(...)`
- Add Bar Layout tab to `SettingsPopup.qml` (toggle UI, no drag yet)

### Phase 2 — Bar Layout drag-reorder
- Switch left/right row to `Repeater` over island arrays
- Drag-to-reorder chips in settings tab

### Phase 3 — Hyprland settings tab
- Add Hyprland tab with all groups above
- `hyprctl keyword` on change + conf file patching

### Phase 4 — Install script + GitHub repo
- Write `install.sh`
- Set up repo structure
- Write README with screenshots

---

## 5. Public Repo Sanitization

Before pushing to GitHub, strip all personal data and AI attribution:

### Personal data to remove
- Any hardcoded paths (`/home/daniel/`, personal usernames)
- Personal API keys, tokens, passwords in any config
- Personal email, name, or machine-specific values in code/comments
- Wallpaper paths or personal wallpaper files
- Any personal keybind configs that reveal personal info

### AI attribution cleanup
- No "Co-Authored-By: Claude" trailers in commits
- No AI-generated comment blocks explaining what code does
- No references to Claude, Anthropic, or AI tools in source files
- Commit history for the public repo starts fresh (orphan branch or fresh repo init)

### What stays
- All QML code, shell scripts, settings schema
- Generic default configs (`settings.json` with sensible defaults, no personal values)
- `install.sh`, `README.md`, `nixos/` module
- Font/dep lists

### Process
1. Create a fresh git repo (not a fork of the dotfiles repo)
2. Copy only the `quickshell/` directory contents
3. Audit every file for personal data before first push
4. Set `settings.json` back to generic defaults (no personal wallpaper dir, no personal keybinds)

---

## Constraints

- Hyprland only (no Sway/KDE support)
- QML changes must be backward-compatible with existing `settings.json` (use fallback defaults)
- `hyprctl` must be available at runtime (already guaranteed on Hyprland)
- NixOS install is documentation + module, not automated (system config is too user-specific)
- Public repo must have zero personal data and no AI attribution — fresh commit history
