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

echo
echo "Done. History bleibt unter ~/.local/state/battinfo/ (manuell l\xc3\xb6schen falls gew\xc3\xbcnscht)."
