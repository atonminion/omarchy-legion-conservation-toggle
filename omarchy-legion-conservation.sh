#!/bin/bash
set -e

CONSERVATION_DIR="$HOME/.config/waybar/battery-conservation"
WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"
WAYBAR_CSS="$HOME/.config/waybar/style.css"

# ── 1. Create directory and write conservation-mode.sh ─────────────────────
mkdir -p "$CONSERVATION_DIR"

cat > "$CONSERVATION_DIR/conservation-mode.sh" << 'EOF'
#!/bin/bash

# Path to the conservation_mode file
CONSERVATION_MODE_PATH="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

# Check if argument is passed
if [ $# -eq 0 ]; then
    # If no argument, display the current status
    cat "$CONSERVATION_MODE_PATH"
elif [ "$1" == "enable" ]; then
    # If 'enable' argument, set conservation mode to 1
    echo 1 > "$CONSERVATION_MODE_PATH"
    echo "Battery conservation mode enabled."
elif [ "$1" == "disable" ]; then
    # If 'disable' argument, set conservation mode to 0
    echo 0 > "$CONSERVATION_MODE_PATH"
    echo "Battery conservation mode disabled."
else
    # If invalid argument, show usage
    echo "Invalid argument. Use 'enable' or 'disable'."
    exit 1
fi
EOF
chmod +x "$CONSERVATION_DIR/conservation-mode.sh"
echo "✓ Wrote conservation-mode.sh"

# ── 2. Create status.sh ────────────────────────────────────────────────────
cat > "$CONSERVATION_DIR/status.sh" << 'EOF'
#!/bin/bash
CONSERVATION_MODE_PATH="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"
STATE=$(cat "$CONSERVATION_MODE_PATH" 2>/dev/null)

if [ "$STATE" = "1" ]; then
  echo '{"text": "󰌪", "tooltip": "Conservation Mode: ON (charging ≤ 80%)", "class": "on"}'
else
  echo '{"text": "󱐋", "tooltip": "Conservation Mode: OFF (full charging)", "class": "off"}'
fi
EOF
chmod +x "$CONSERVATION_DIR/status.sh"
echo "✓ Created status.sh"

# ── 3. Create toggle.sh ────────────────────────────────────────────────────
cat > "$CONSERVATION_DIR/toggle.sh" << 'EOF'
#!/bin/bash
omarchy-show-logo
SCRIPT_DIR="$HOME/.config/waybar/battery-conservation"
CONSERVATION_MODE_PATH="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"
STATE=$(cat "$CONSERVATION_MODE_PATH" 2>/dev/null)

if [ "$STATE" = "1" ]; then
  STATUS="󰌪  Conservation Mode: ON"
  DETAIL="Charging is limited to ~80% to extend battery lifespan."
  QUESTION="Disable conservation mode and allow full charging?"
  NEXT="disable"
  NOTIFY_ICON="󱐋"
  NOTIFY_MSG="Full charging restored"
else
  STATUS="󱐋  Conservation Mode: OFF"
  DETAIL="Battery charges to 100%."
  QUESTION="Enable conservation mode and limit charging to ~80%?"
  NEXT="enable"
  NOTIFY_ICON="󰌪"
  NOTIFY_MSG="Charging limited to ~80%"
fi

gum style --border rounded --padding "1 2" --bold "$STATUS" "" "$DETAIL"

if gum confirm "$QUESTION"; then
  sudo "$SCRIPT_DIR/conservation-mode.sh" "$NEXT"
  notify-send -u low "$NOTIFY_ICON   Conservation Mode ${NEXT^}d" "$NOTIFY_MSG"
  pkill -RTMIN+11 waybar
fi
EOF
chmod +x "$CONSERVATION_DIR/toggle.sh"
echo "✓ Created toggle.sh"

# ── 4. sudoers entry ───────────────────────────────────────────────────────
echo "$USER ALL=(ALL) NOPASSWD: $CONSERVATION_DIR/conservation-mode.sh" \
  | sudo tee /etc/sudoers.d/battery-conservation > /dev/null
sudo chmod 440 /etc/sudoers.d/battery-conservation
echo "✓ Created sudoers entry"

# ── 5. Patch waybar config.jsonc ───────────────────────────────────────────
python3 - "$WAYBAR_CONFIG" << 'PYEOF'
import sys

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

ON_CLICK = "setsid uwsm-app -- xdg-terminal-exec --app-id=org.omarchy.terminal --title='Battery Conservation' -e ~/.config/waybar/battery-conservation/toggle.sh"

# Always ensure on-click is the terminal-launcher version (idempotent fix)
if '"custom/battery-conservation"' in content:
    import re
    content = re.sub(
        r'"on-click": "[^"]*battery-conservation[^"]*toggle\.sh[^"]*"',
        f'"on-click": "{ON_CLICK}"',
        content
    )
    with open(path, 'w') as f:
        f.write(content)
    print("✓ waybar config on-click updated")
    sys.exit(0)

content = content.replace(
    '    "cpu",\n    "battery"',
    '    "cpu",\n    "custom/battery-conservation",\n    "battery"'
)

module_def = (
    '  "custom/battery-conservation": {\n'
    '    "exec": "~/.config/waybar/battery-conservation/status.sh",\n'
    '    "return-type": "json",\n'
    '    "interval": 10,\n'
    '    "signal": 11,\n'
    f'    "on-click": "{ON_CLICK}",\n'
    '    "tooltip": true\n'
    '  },\n'
    '  "clock": {'
)
content = content.replace('  "clock": {', module_def, 1)

with open(path, 'w') as f:
    f.write(content)
print("✓ Patched waybar config.jsonc")
PYEOF

# ── 6. Patch waybar style.css ──────────────────────────────────────────────
if grep -q 'custom-battery-conservation' "$WAYBAR_CSS"; then
  echo "✓ waybar style.css already patched, skipping"
else
  cat >> "$WAYBAR_CSS" << 'EOF'

#custom-battery-conservation {
  min-width: 12px;
  margin: 0 7.5px;
}
EOF
  echo "✓ Patched waybar style.css"
fi

# ── 7. Restart waybar ──────────────────────────────────────────────────────
omarchy-restart-waybar
echo "✓ Waybar restarted"
echo ""
echo "Done! Click the leaf/lightning icon in the waybar to toggle conservation mode."
