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

echo
echo "Done."
echo "  Run:           battinfo"
echo "  Watch:         battinfo -w"
echo "  History:       battinfo --history"
echo "  Manual log:    systemctl --user start battinfo-snapshot.service"
echo "  Timer status:  systemctl --user status battinfo-snapshot.timer"
echo
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "WARNUNG: $BIN_DIR liegt nicht in \$PATH. Shell-Rc anpassen." ;;
esac
