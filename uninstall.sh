#!/usr/bin/env bash
# uninstall.sh — remove HealthPanel: the Plasma widget, the battinfo CLI + its
# user timer, and the system-level SMART timer. Run as your NORMAL user (NOT with
# sudo); the SMART part calls sudo itself. Battery history in
# ~/.local/state/battinfo/ is left untouched.
set -euo pipefail

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "Bitte OHNE sudo ausführen: ./uninstall.sh" >&2
    echo "Die System-Teile rufen sudo selbst auf." >&2
    exit 1
fi

BIN_DIR="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"

echo "Removing battinfo CLI + user timer ..."
systemctl --user disable --now battinfo-snapshot.timer 2>/dev/null || true
for f in \
    "$BIN_DIR/battinfo" \
    "$BIN_DIR/battinfo-snapshot" \
    "$UNIT_DIR/battinfo-snapshot.service" \
    "$UNIT_DIR/battinfo-snapshot.timer"; do
    rm -fv "$f"
done
systemctl --user daemon-reload || true

# --- Plasma widget ---
if command -v kpackagetool6 >/dev/null 2>&1 \
   && kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q '^io.github.sunsetterphoto.healthpanel'; then
    echo "Removing Plasma widget ..."
    kpackagetool6 -t Plasma/Applet -r io.github.sunsetterphoto.healthpanel || true
fi

# --- system-level SMART timer + cache (needs root) ---
echo "Removing SMART timer (sudo erforderlich) ..."
sudo systemctl disable --now healthpanel-smart.timer 2>/dev/null || true
sudo rm -fv /etc/systemd/system/healthpanel-smart.service \
            /etc/systemd/system/healthpanel-smart.timer \
            /usr/local/bin/healthpanel-smart
sudo systemctl daemon-reload || true
sudo rm -rf /var/lib/healthpanel

echo
echo "Done. HealthPanel entfernt."
echo "  Akku-History bleibt unter ~/.local/state/battinfo/ (manuell löschen falls gewünscht)."
echo "  Liegt das Widget noch auf dem Desktop/Panel: per Rechtsklick entfernen."
