#!/usr/bin/env bash
# uninstall.sh — remove symlinks and disable the systemd timer.
# Leaves history at ~/.local/state/battinfo/ untouched.
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"

echo "Disabling timer ..."
systemctl --user disable --now battinfo-snapshot.timer 2>/dev/null || true

echo "Removing symlinks ..."
for f in \
    "$BIN_DIR/battinfo" \
    "$BIN_DIR/battinfo-snapshot" \
    "$UNIT_DIR/battinfo-snapshot.service" \
    "$UNIT_DIR/battinfo-snapshot.timer"; do
    if [[ -L "$f" ]]; then
        rm -v "$f"
    fi
done

systemctl --user daemon-reload

# --- Plasma widget ---
if command -v kpackagetool6 >/dev/null 2>&1; then
    if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q '^org.kde.battinfo'; then
        echo "Removing Plasma widget ..."
        kpackagetool6 -t Plasma/Applet -r org.kde.battinfo
    fi
fi

echo
echo "Done. History bleibt unter ~/.local/state/battinfo/ (manuell l\xc3\xb6schen falls gew\xc3\xbcnscht)."
echo "Falls das Widget noch auf dem Desktop liegt: per Rechtsklick entfernen."
