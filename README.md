# Lenovo Legion Battery Conservation Mode — Omarchy Waybar Toggle

A waybar module for [Omarchy](https://omarchy.org/) that adds a one-click toggle for the Lenovo Legion battery conservation mode. Conservation mode limits charging to ~80% to extend long-term battery lifespan.

## Preview

| State | Icon | Behavior |
|-------|------|----------|
| Conservation ON | 󰌪 (leaf) | Charging limited to ~80% |
| Conservation OFF | 󱐋 (lightning) | Full charging to 100% |

Clicking the icon opens a floating terminal with an Omarchy-styled TUI confirmation dialog powered by [gum](https://github.com/charmbracelet/gum).

## Requirements

- **Omarchy** — [omarchy.org](https://omarchy.org/)
- **Lenovo Legion laptop** with `ideapad_acpi` kernel module loaded
- **gum** — `sudo pacman -S gum` (Charm TUI toolkit)
- **Python 3** — for patching the waybar config (pre-installed on Arch)

Verify the sysfs path exists before installing:

```bash
cat /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode
```

If this returns `0` or `1`, you're good to go. If the path doesn't exist, your laptop may use a different driver path — check `ls /sys/bus/platform/drivers/ideapad_acpi/`.

## Installation

```bash
chmod +x omarchy-legion-conservation.sh
./omarchy-legion-conservation.sh
```

The installer will prompt for your sudo password once to create the sudoers entry, then set everything up automatically.

### What the installer does

1. Creates `~/.config/waybar/battery-conservation/` with three scripts:
   - `conservation-mode.sh` — reads/writes the sysfs conservation mode file
   - `status.sh` — outputs Waybar JSON with the current icon and tooltip
   - `toggle.sh` — TUI confirmation dialog (gum + Omarchy logo)
2. Adds a `sudo NOPASSWD` entry for `conservation-mode.sh` so toggling works without a password prompt
3. Patches `~/.config/waybar/config.jsonc` to add the module between the CPU and battery icons
4. Patches `~/.config/waybar/style.css` with the module's margin/sizing
5. Restarts waybar

The installer is **idempotent** — safe to re-run if something needs to be repaired.

## Usage

- **Hover** the icon to see current mode in a tooltip
- **Click** the icon to open the confirmation dialog
- Confirm or cancel — a desktop notification confirms the change

## File Layout

```
~/.config/waybar/battery-conservation/
├── conservation-mode.sh   # sysfs read/write (runs via sudo)
├── status.sh              # waybar JSON status output
└── toggle.sh              # TUI dialog (gum + omarchy-show-logo)

/etc/sudoers.d/
└── battery-conservation   # NOPASSWD entry for conservation-mode.sh
```

## Uninstalling

```bash
# Remove scripts
rm -rf ~/.config/waybar/battery-conservation/

# Remove sudoers entry
sudo rm /etc/sudoers.d/battery-conservation

# Remove waybar module from config (edit manually)
# ~/.config/waybar/config.jsonc — remove "custom/battery-conservation" from modules-right and the module definition block
# ~/.config/waybar/style.css — remove the #custom-battery-conservation block at the bottom

omarchy-restart-waybar
```

## Compatibility

Tested on:
- Lenovo Legion 7 Gen 10
- Omarchy (Arch Linux + Hyprland)
- Waybar with JetBrainsMono Nerd Font

Other Lenovo laptops with `ideapad_acpi` should work. Check the sysfs path first (see Requirements above).
