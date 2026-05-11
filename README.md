# battinfo

Schlankes CLI-Tool für detaillierte Akku-Informationen unter Linux.
Reines Bash, keine Runtime-Abhängigkeiten außer Coreutils + `upower`.

```
$ battinfo

  SMP 5B11M90082 — BAT0
  ──────────────────────────────────────────────
  Health         87.0%  █████████████████░░░
  Cycles         139
  Designed       51.97 Wh
  Full (now)     45.23 Wh
  Remaining      40.36 Wh  (89%)
  ──────────────────────────────────────────────
  Status         Discharging ↓ — 5h 36m left
  Power draw     7.41 W
  Voltage        12.67 V  (design min 11.64 V)
  Technology     Li-poly
  Serial         496
  ── Lenovo ───────────────────────────────────
  Charge limit   75%–80%
  Charge mode    auto
```

## Was es zeigt

Alles, was `/sys/class/power_supply/BAT0/` und `upower` hergeben:

- **Identität:** Manufacturer, Model, Serial, Technology
- **Kapazität:** Designed capacity, current full charge capacity, remaining capacity
- **Health:** `energy_full / energy_full_design × 100`, mit Farbe (>90% grün, 75–90% gelb, <75% rot)
- **Verschleiß:** Ladezyklen (cycle_count)
- **Live:** Status, Power draw, Voltage (current + design min), verbleibende Zeit
- **Lenovo-Specials:** Charge-Thresholds (start/stop %), Charge-Behaviour

## Subcommands

```
battinfo              # einmalige Anzeige
battinfo -w           # Live-Watch (refresh 2s)
battinfo --history    # gelogger Verlauf (täglich via systemd timer)
battinfo --raw        # rohes /sys-Dump (debug)
battinfo --help
```

## KDE Plasma Widget

Zusätzlich zum CLI gibt's ein Plasma-6-Widget, das alle Werte auf den Desktop bringt:

- **Vollkarte** auf dem Desktop (Health-Bar mit Farbe, Cycles, Designed/Full/Remaining, Live-Werte, Lenovo-Specials)
- **Kompakt** im Panel (Icon · Charge% · Health%) mit Klick-Popup
- Refresh-Intervall im Widget-Settings konfigurierbar (Default 5 s, 2–30 s)
- Liest direkt `/sys/class/power_supply/BAT0` — kein Subprocess, kein Polling der CLI

Wird automatisch von `install.sh` mitinstalliert (falls KDE Plasma 6 da ist). Nach der
Installation: Rechtsklick auf den Desktop → **Widget hinzufügen** → „Battery Info" suchen
und reinziehen.

**Widget-Updates nach `git pull`:** `install.sh` erneut ausführen. `kpackagetool6 -u` ist
ein atomic upgrade — falls das Widget bereits auf dem Desktop liegt, einmal entfernen und
neu reinziehen reicht, kein plasmashell-Restart nötig.

## Installation

```bash
git clone <repo> ~/Schreibtisch/battinfo
~/Schreibtisch/battinfo/install.sh
```

`install.sh` ist idempotent und tut Folgendes:

- legt stabile Symlinks in `~/.local/bin/` an (`battinfo`, `battinfo-snapshot`)
- legt systemd-`--user`-Unit-Symlinks an (`battinfo-snapshot.{service,timer}`)
- aktiviert den Timer (daily, persistent)
- installiert (oder upgraded) das Plasma-Widget via `kpackagetool6` — übersprungen falls KDE nicht da

**Updates:** `git pull` und ggf. `install.sh` neu — keine Versions-Pflege irgendwo.
Die Symlinks zeigen auf den Projektpfad, das Widget wird atomisch geswappt.

## History

Der Timer schreibt täglich (mit ±15 min Jitter) eine Zeile nach
`~/.local/state/battinfo/history.tsv`:

```
date                   health_pct  fcc_wh   designed_wh  cycles
2026-05-11 09:00:00    87.03       45.23    51.97        139
2026-05-12 09:14:00    87.01       45.22    51.97        140
…
```

Persistent=true → falls der Laptop aus war, wird der verpasste Run nachgeholt.

Manuell triggern:
```bash
systemctl --user start battinfo-snapshot.service
```

Status / Logs:
```bash
systemctl --user status battinfo-snapshot.timer
journalctl --user -u battinfo-snapshot --since "1 week ago"
```

## Deinstallation

```bash
~/Schreibtisch/battinfo/uninstall.sh
```

Entfernt Symlinks + deaktiviert Timer. Die History unter `~/.local/state/battinfo/`
bleibt liegen (bewusst — manuell löschen falls gewünscht).

## Anforderungen

- Linux mit `/sys/class/power_supply/BAT0`
- bash 4+, coreutils, awk, sed, `tput`, `upower`
- systemd (für den optionalen History-Timer)
