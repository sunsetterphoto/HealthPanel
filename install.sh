#!/usr/bin/env bash
# install.sh — set up stable symlinks in ~/.local/bin and enable the systemd timer.
# Idempotent: safe to re-run after `git pull`.
#
# Run as your NORMAL user (NOT with sudo): the user-level parts go into your
# own ~/.local and ~/.config, and the system-level SMART timer block calls
# `sudo` itself only where it needs root.
set -euo pipefail

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "Bitte OHNE sudo ausführen: ./install.sh" >&2
    echo "Die User-Teile gehören in dein Home; der SMART-Block ruft sudo selbst auf." >&2
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"

mkdir -p "$BIN_DIR" "$UNIT_DIR"

link() {
    local src="$1" dest="$2"
    ln -sfn "$src" "$dest"
    echo "  link  $dest -> $src"
}

echo "Installing HealthPanel (widget + healthpanel CLI) from $PROJECT_DIR ..."

chmod +x "$PROJECT_DIR/healthpanel" "$PROJECT_DIR/healthpanel-snapshot"

link "$PROJECT_DIR/healthpanel"          "$BIN_DIR/healthpanel"
link "$PROJECT_DIR/healthpanel-snapshot" "$BIN_DIR/healthpanel-snapshot"

link "$PROJECT_DIR/systemd/healthpanel-snapshot.service" "$UNIT_DIR/healthpanel-snapshot.service"
link "$PROJECT_DIR/systemd/healthpanel-snapshot.timer"   "$UNIT_DIR/healthpanel-snapshot.timer"

echo "Reloading systemd --user and enabling timer ..."
systemctl --user daemon-reload
systemctl --user enable --now healthpanel-snapshot.timer

# --- Plasma 6 widget (optional, skipped on headless / non-KDE) ---
if command -v kpackagetool6 >/dev/null 2>&1; then
    echo "Installing Plasma widget ..."
    if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q '^io.github.sunsetterphoto.healthpanel'; then
        kpackagetool6 -t Plasma/Applet -u "$PROJECT_DIR/plasmoid"
        echo "  widget upgraded — re-add to desktop to pick up the new code if needed"
    else
        kpackagetool6 -t Plasma/Applet -i "$PROJECT_DIR/plasmoid"
        echo "  widget installed — add 'HealthPanel' from the widgets menu"
    fi
else
    echo "kpackagetool6 not found — skipping Plasma widget install (no KDE Plasma here?)"
fi

echo
echo "Done."
echo "  Run:           healthpanel"
echo "  Watch:         healthpanel -w"
echo "  History:       healthpanel --history"
echo "  Manual log:    systemctl --user start healthpanel-snapshot.service"
echo "  Timer status:  systemctl --user status healthpanel-snapshot.timer"
echo "  Plasma widget: rechts auf Desktop -> Widget hinzufügen -> 'HealthPanel'"
echo
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "WARNUNG: $BIN_DIR liegt nicht in \$PATH. Shell-Rc anpassen." ;;
esac

# ---- system-level SMART cache (needs root) ----
# NOTE: system units are COPIED (not symlinked) into /etc and /usr/local/bin.
# On SELinux-enforcing systems (Fedora) systemd refuses to load a unit symlinked
# into a user home (user_home_t context). restorecon then sets the correct
# contexts (systemd_unit_file_t / bin_t). Re-run this after changing SMART files.
echo "Richte SMART-Timer ein (sudo erforderlich)…"
sudo install -d -m 755 /var/lib/healthpanel
sudo install -m 755 "$PROJECT_DIR/healthpanel-smart" /usr/local/bin/healthpanel-smart
sudo install -m 644 "$PROJECT_DIR/systemd/healthpanel-smart.service" /etc/systemd/system/healthpanel-smart.service
sudo install -m 644 "$PROJECT_DIR/systemd/healthpanel-smart.timer"   /etc/systemd/system/healthpanel-smart.timer
if command -v restorecon >/dev/null 2>&1; then
    sudo restorecon -F /usr/local/bin/healthpanel-smart \
        /etc/systemd/system/healthpanel-smart.service \
        /etc/systemd/system/healthpanel-smart.timer
fi
sudo systemctl daemon-reload
sudo systemctl enable --now healthpanel-smart.timer
sudo /usr/local/bin/healthpanel-smart || true   # initial fill
echo "  SMART-Cache: /var/lib/healthpanel/smart.json"
