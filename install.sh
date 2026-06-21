#!/usr/bin/env bash
# install.sh — set up stable symlinks in ~/.local/bin and enable the systemd timer.
# Idempotent: safe to re-run after `git pull`.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"

mkdir -p "$BIN_DIR" "$UNIT_DIR"

link() {
    local src="$1" dest="$2"
    ln -sfn "$src" "$dest"
    echo "  link  $dest -> $src"
}

echo "Installing battinfo from $PROJECT_DIR ..."

chmod +x "$PROJECT_DIR/battinfo" "$PROJECT_DIR/battinfo-snapshot"

link "$PROJECT_DIR/battinfo"          "$BIN_DIR/battinfo"
link "$PROJECT_DIR/battinfo-snapshot" "$BIN_DIR/battinfo-snapshot"

link "$PROJECT_DIR/systemd/battinfo-snapshot.service" "$UNIT_DIR/battinfo-snapshot.service"
link "$PROJECT_DIR/systemd/battinfo-snapshot.timer"   "$UNIT_DIR/battinfo-snapshot.timer"

echo "Reloading systemd --user and enabling timer ..."
systemctl --user daemon-reload
systemctl --user enable --now battinfo-snapshot.timer

# --- Plasma 6 widget (optional, skipped on headless / non-KDE) ---
if command -v kpackagetool6 >/dev/null 2>&1; then
    echo "Installing Plasma widget ..."
    if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q '^org.kde.battinfo'; then
        kpackagetool6 -t Plasma/Applet -u "$PROJECT_DIR/plasmoid"
        echo "  widget upgraded — re-add to desktop to pick up the new code if needed"
    else
        kpackagetool6 -t Plasma/Applet -i "$PROJECT_DIR/plasmoid"
        echo "  widget installed — add 'Battery Info' from the widgets menu"
    fi
else
    echo "kpackagetool6 not found — skipping Plasma widget install (no KDE Plasma here?)"
fi

echo
echo "Done."
echo "  Run:           battinfo"
echo "  Watch:         battinfo -w"
echo "  History:       battinfo --history"
echo "  Manual log:    systemctl --user start battinfo-snapshot.service"
echo "  Timer status:  systemctl --user status battinfo-snapshot.timer"
echo "  Plasma widget: rechts auf Desktop -> Widget hinzufügen -> 'Battery Info'"
echo
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "WARNUNG: $BIN_DIR liegt nicht in \$PATH. Shell-Rc anpassen." ;;
esac

# ---- system-level SMART cache (needs root) ----
echo "Richte SMART-Timer ein (sudo erforderlich)…"
sudo install -d -m 755 /var/lib/battinfo
sudo ln -sf "$PROJECT_DIR/battinfo-smart" /usr/local/bin/battinfo-smart
sudo ln -sf "$PROJECT_DIR/systemd/battinfo-smart.service" /etc/systemd/system/battinfo-smart.service
sudo ln -sf "$PROJECT_DIR/systemd/battinfo-smart.timer"   /etc/systemd/system/battinfo-smart.timer
sudo systemctl daemon-reload
sudo systemctl enable --now battinfo-smart.timer
sudo /usr/local/bin/battinfo-smart || true   # initial fill
