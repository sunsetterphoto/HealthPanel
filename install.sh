#!/usr/bin/env bash
# install.sh — set up stable symlinks in ~/.local/bin and enable the systemd timer.
# Idempotent: safe to re-run after `git pull`.
#
# Run as your NORMAL user (NOT with sudo): the user-level parts go into your
# own ~/.local and ~/.config, and the system-level SMART timer block calls
# `sudo` itself only where it needs root.
set -euo pipefail

ENABLE_CPU_POWER=0
ENABLE_SENSOR_MODULES=0
USER_ONLY=0
for a in "$@"; do
    case "$a" in
        --user-only)             USER_ONLY=1 ;;
        --enable-cpu-power)      ENABLE_CPU_POWER=1 ;;
        --enable-sensor-modules) ENABLE_SENSOR_MODULES=1 ;;
        -h|--help)
            echo "Usage: ./install.sh [--user-only] [--enable-cpu-power] [--enable-sensor-modules]"
            echo "  --user-only              only the parts that need no root (widget, CLI, user"
            echo "                           timer) — what the built-in updater runs"
            echo "  --enable-cpu-power       make RAPL CPU package power readable (udev rule)"
            echo "  --enable-sensor-modules  load optional hwmon modules at boot when the hardware"
            echo "                           has them: drivetemp (SATA drive temperatures) and"
            echo "                           hp-wmi-sensors (fans/ambient on HP business desktops)"
            exit 0 ;;
        *) echo "Unbekannte Option: $a (siehe ./install.sh --help)" >&2; exit 2 ;;
    esac
done

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

chmod +x "$PROJECT_DIR/healthpanel" "$PROJECT_DIR/healthpanel-snapshot" "$PROJECT_DIR/healthpanel-update"

link "$PROJECT_DIR/healthpanel"          "$BIN_DIR/healthpanel"
link "$PROJECT_DIR/healthpanel-snapshot" "$BIN_DIR/healthpanel-snapshot"
link "$PROJECT_DIR/healthpanel-update"   "$BIN_DIR/healthpanel-update"

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

# Remember which commit is installed — the built-in updater compares against it.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/healthpanel"
mkdir -p "$STATE_DIR"
if git -C "$PROJECT_DIR" rev-parse HEAD > "$STATE_DIR/installed-commit.tmp" 2>/dev/null; then
    mv -f "$STATE_DIR/installed-commit.tmp" "$STATE_DIR/installed-commit"
else
    rm -f "$STATE_DIR/installed-commit.tmp"
fi

echo
echo "Done."
echo "  Updates:       healthpanel-update"
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

if [[ "$USER_ONLY" -eq 1 ]]; then
    echo "--user-only: System-Teile (SMART-Timer, udev, Module) übersprungen."
    exit 0
fi

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

# ---- optional: RAPL CPU-power exposure (opt-in, needs root) ----
if [[ "$ENABLE_CPU_POWER" -eq 1 ]]; then
    echo "Aktiviere CPU-Power (RAPL) — installiere udev-Regel (sudo erforderlich)…"
    sudo install -m 644 "$PROJECT_DIR/udev/99-healthpanel-rapl.rules" \
        /etc/udev/rules.d/99-healthpanel-rapl.rules
    command -v restorecon >/dev/null 2>&1 && sudo restorecon -F /etc/udev/rules.d/99-healthpanel-rapl.rules || true
    sudo udevadm control --reload
    sudo udevadm trigger --subsystem-match=powercap --action=add
    # apply immediately to already-present domains (no reboot needed)
    sudo chmod 0444 /sys/class/powercap/intel-rapl:*/energy_uj 2>/dev/null || true
    echo "  CPU-Power aktiv. Rückgängig: ./uninstall.sh oder Regel in /etc/udev/rules.d entfernen."
else
    echo "CPU-Power (RAPL) NICHT aktiviert. Optional einschalten mit: ./install.sh --enable-cpu-power"
fi

# ---- optional: extra hwmon sensor modules (opt-in, needs root) ----
# Some sensors only exist once a kernel module is loaded that no distro loads by
# default. Only modules that match this machine's hardware are considered:
#   drivetemp       temperatures of SATA drives
#   hp-wmi-sensors  fan speeds + ambient temperature on HP business desktops /
#                   workstations (HP's numeric-sensor WMI interface)
HP_WMI_SENSOR_GUID="8F1F6435-9F42-42C8-BADC-0E9424F20C9A"
WANT_MODS=()
if lsblk -dno TRAN 2>/dev/null | grep -qx sata && modinfo drivetemp >/dev/null 2>&1; then
    WANT_MODS+=(drivetemp)
fi
if compgen -G "/sys/bus/wmi/devices/${HP_WMI_SENSOR_GUID}*" >/dev/null \
   && modinfo hp-wmi-sensors >/dev/null 2>&1; then
    WANT_MODS+=(hp-wmi-sensors)
fi
if [[ "$ENABLE_SENSOR_MODULES" -eq 1 ]]; then
    if [[ ${#WANT_MODS[@]} -eq 0 ]]; then
        echo "Sensor-Module: auf dieser Hardware nichts nachzuladen."
    else
        echo "Aktiviere Sensor-Module: ${WANT_MODS[*]} (sudo erforderlich)…"
        printf '%s\n' "# HealthPanel: optional hwmon sensor modules (./install.sh --enable-sensor-modules)" \
            "${WANT_MODS[@]}" | sudo tee /etc/modules-load.d/healthpanel.conf >/dev/null
        command -v restorecon >/dev/null 2>&1 && sudo restorecon -F /etc/modules-load.d/healthpanel.conf || true
        for m in "${WANT_MODS[@]}"; do sudo modprobe "$m" || echo "  WARNUNG: modprobe $m fehlgeschlagen"; done
        echo "  Geladen und für jeden Boot eingetragen: /etc/modules-load.d/healthpanel.conf"
    fi
else
    MISSING=()
    for m in ${WANT_MODS[@]+"${WANT_MODS[@]}"}; do
        [[ -d "/sys/module/${m//-/_}" ]] || MISSING+=("$m")
    done
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        echo "Hinweis: weitere Sensoren verfügbar über Kernel-Modul(e): ${MISSING[*]}"
        echo "  Einschalten mit: ./install.sh --enable-sensor-modules"
    fi
fi
