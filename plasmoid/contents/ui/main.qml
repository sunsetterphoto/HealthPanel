pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5S

PlasmoidItem {
    id: root

    // When pinned, the expanded popup stays open after losing focus.
    property bool keepOpen: false
    hideOnWindowDeactivate: !keepOpen

    // Resolved UI language ("system" → locale, else de/en override).
    readonly property string uiLang: {
        var c = Plasmoid.configuration.language
        if (c === "de" || c === "en") return c
        return Qt.locale().name.indexOf("de") === 0 ? "de" : "en"
    }

    // Expose the data object as a root property so the representation
    // Components (which sit in their own scope) can reference it via root.battery.
    property alias battery: batteryData

    BatteryData {
        id: batteryData
        refreshSeconds: Plasmoid.configuration.refreshSeconds
    }

    property alias system: systemData

    SystemData { id: systemData }

    property alias control: controlData

    ControlData { id: controlData }

    // ---- data probe via executable DataSource ----
    // Pick the first battery (BAT0, BAT1, … or vendor names like "macsmc-battery")
    // dynamically, then cat its uevent plus three optional Lenovo charge files;
    // missing files become empty BATTINFO_* values the parser treats as "not supported".
    readonly property string _probeCmd:
        "B=$(for d in /sys/class/power_supply/*; do " +
        "  [ \"$(cat \"$d/type\" 2>/dev/null)\" = Battery ] && echo \"$d\" && break; done); " +
        "[ -n \"$B\" ] && cat \"$B/uevent\" 2>/dev/null; " +
        "echo \"HP_CHARGE_START=$(cat \"$B/charge_control_start_threshold\" 2>/dev/null)\"; " +
        "echo \"HP_CHARGE_END=$(cat \"$B/charge_control_end_threshold\" 2>/dev/null)\"; " +
        "echo \"HP_CHARGE_BEHAVIOUR=$(cat \"$B/charge_behaviour\" 2>/dev/null)\""

    P5S.DataSource {
        id: probe
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            battery.applyRawOutput(data["stdout"] || "")
            disconnectSource(source)
        }
    }

    // ---- system probe: two snapshots 0.5s apart, marker-delimited ----
    readonly property string _sysProbeCmd:
        "echo '===T1==='; date +%s.%N; " +
        "echo '===STAT1==='; cat /proc/stat; " +
        "echo '===NET1==='; cat /proc/net/dev; " +
        "echo '===DISK1==='; cat /proc/diskstats; " +
        "echo '===RAPL1==='; cat /sys/class/powercap/intel-rapl:0/energy_uj 2>/dev/null; " +
        "sleep 0.5; " +
        "echo '===T2==='; date +%s.%N; " +
        "echo '===STAT2==='; cat /proc/stat; " +
        "echo '===NET2==='; cat /proc/net/dev; " +
        "echo '===DISK2==='; cat /proc/diskstats; " +
        "echo '===RAPL2==='; cat /sys/class/powercap/intel-rapl:0/energy_uj 2>/dev/null; " +
        "echo '===RAPLMAX==='; cat /sys/class/powercap/intel-rapl:0/max_energy_range_uj 2>/dev/null; " +
        "echo '===MEM==='; cat /proc/meminfo; " +
        "echo '===CORES==='; for c in /sys/devices/system/cpu/cpu[0-9]*; do echo \"$(basename $c) $(cat $c/topology/core_id 2>/dev/null)\"; done; " +
        "echo '===DF==='; df -B1 --output=source,used,size / | tail -1; " +
        "echo '===TEMPS==='; for h in /sys/class/hwmon/hwmon*; do echo \"$(cat $h/name 2>/dev/null) $(cat $h/temp1_input 2>/dev/null)\"; done; " +
        "echo '===SMART==='; cat /var/lib/healthpanel/smart.json 2>/dev/null; " +
        "echo '===GPU==='; for c in /sys/class/drm/card*/device; do " +
        "if [ -e \"$c/gpu_busy_percent\" ]; then echo \"BUSY=$(cat $c/gpu_busy_percent)\"; " +
        "echo \"VRAMUSED=$(cat $c/mem_info_vram_used 2>/dev/null)\"; " +
        "echo \"VRAMTOTAL=$(cat $c/mem_info_vram_total 2>/dev/null)\"; break; fi; done; " +
        "echo '===POWER==='; " +
        "HB=0; for b in /sys/class/power_supply/*; do [ \"$(cat \"$b/type\" 2>/dev/null)\" = Battery ] && HB=1 && break; done; echo \"HASBATTERY=$HB\"; " +
        "for c in /sys/class/drm/card[0-9]*/device; do " +
        "  ph=\"$c/hwmon\"; [ -d \"$ph\" ] || continue; " +
        "  for hw in \"$ph\"/hwmon*; do [ -e \"$hw/power1_input\" ] || continue; " +
        "    drv=$(basename \"$(readlink -f \"$c/driver\" 2>/dev/null)\" 2>/dev/null); " +
        "    bv=$(cat \"$c/boot_vga\" 2>/dev/null || echo 0); " +
        "    echo \"CARD=$(basename $(dirname $c)) BOOTVGA=${bv:-0} DRIVER=${drv:-unknown} PPT=$(cat \"$hw/power1_input\" 2>/dev/null || echo 0)\"; " +
        "  done; done; " +
        "echo '===FANS==='; for h in /sys/class/hwmon/hwmon*; do n=$(cat \"$h/name\" 2>/dev/null); " +
        "  for f in \"$h\"/fan[0-9]*_input; do [ -e \"$f\" ] || continue; " +
        "    v=$(cat \"$f\" 2>/dev/null); [ -n \"$v\" ] || continue; " +
        "    echo \"$n $(basename \"$f\" | sed 's/_input//')=$v\"; done; done; " +
        "echo '===VOLTS==='; for h in /sys/class/hwmon/hwmon*; do " +
        "  [ \"$(cat \"$h/name\" 2>/dev/null)\" = amdgpu ] || continue; " +
        "  for v in \"$h\"/in[0-9]*_input; do [ -e \"$v\" ] || continue; " +
        "    lbl=$(cat \"${v%_input}_label\" 2>/dev/null); [ -n \"$lbl\" ] || continue; " +
        "    echo \"$lbl=$(awk -v x=$(cat \"$v\") 'BEGIN{printf \"%d\", x}')\"; done; done; " +
        "echo '===TEMPSX==='; for h in /sys/class/hwmon/hwmon*; do n=$(cat \"$h/name\" 2>/dev/null); " +
        "  for t in \"$h\"/temp[0-9]*_input; do [ -e \"$t\" ] || continue; " +
        "    v=$(cat \"$t\" 2>/dev/null); [ -n \"$v\" ] || continue; " +
        "    lbl=$(cat \"${t%_input}_label\" 2>/dev/null | tr -d ' '); [ -n \"$lbl\" ] || continue; " +
        "    echo \"$n:$lbl=$v\"; done; done"

    readonly property string _profileGetCmd:
        "busctl --system get-property net.hadess.PowerProfiles " +
        "/net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile 2>/dev/null"

    P5S.DataSource {
        id: sysProbe
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            systemData.applyProbe(data["stdout"] || "")
            disconnectSource(source)
        }
    }

    P5S.DataSource {
        id: profileProbe
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            systemData.applyProfile(data["stdout"] || "")
            disconnectSource(source)
        }
    }

    P5S.DataSource {
        id: profileSetter
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            profileProbe.connectSource(root._profileGetCmd)   // re-read to confirm
        }
    }

    function setPowerProfile(name) {
        var cmd = "busctl --system set-property net.hadess.PowerProfiles " +
                  "/net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s '" + name + "'"
        profileSetter.connectSource(cmd)
    }

    // ---- controllable settings: read current screen/keyboard brightness + volume ----
    readonly property string _ctrlProbeCmd:
        "echo '===SCREEN==='; " +
        "D=$(busctl --user get-property org.kde.ScreenBrightness /org/kde/ScreenBrightness " +
        "org.kde.ScreenBrightness DisplaysDBusNames 2>/dev/null | grep -oE 'display[0-9]+' | head -1); " +
        "if [ -n \"$D\" ]; then echo \"DISPLAY=$D\"; " +
        "busctl --user get-property org.kde.ScreenBrightness /org/kde/ScreenBrightness/$D org.kde.ScreenBrightness.Display Brightness 2>/dev/null; " +
        "busctl --user get-property org.kde.ScreenBrightness /org/kde/ScreenBrightness/$D org.kde.ScreenBrightness.Display MaxBrightness 2>/dev/null; fi; " +
        "echo '===KBD==='; " +
        "busctl --system call org.freedesktop.UPower /org/freedesktop/UPower/KbdBacklight org.freedesktop.UPower.KbdBacklight GetBrightness 2>/dev/null; " +
        "busctl --system call org.freedesktop.UPower /org/freedesktop/UPower/KbdBacklight org.freedesktop.UPower.KbdBacklight GetMaxBrightness 2>/dev/null; " +
        "echo '===VOL==='; wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"

    P5S.DataSource {
        id: ctrlProbe
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            controlData.applyControlProbe(data["stdout"] || "")
            disconnectSource(source)
        }
    }

    P5S.DataSource {
        id: ctrlSetter
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            ctrlProbe.connectSource(root._ctrlProbeCmd)   // re-read after a change
        }
    }

    // long-running systemd-inhibit while the toggle is on
    P5S.DataSource {
        id: inhibitor
        engine: "executable"
        connectedSources: []
    }

    function setScreenBrightness(raw) {
        if (!control.hasScreen || control.screenDisplay === "") return
        ctrlSetter.connectSource("busctl --user call org.kde.ScreenBrightness " +
            "/org/kde/ScreenBrightness/" + control.screenDisplay +
            " org.kde.ScreenBrightness.Display SetBrightness iu " + Math.round(raw) + " 1")
    }
    function setKbdBrightness(val) {
        ctrlSetter.connectSource("busctl --system call org.freedesktop.UPower " +
            "/org/freedesktop/UPower/KbdBacklight org.freedesktop.UPower.KbdBacklight SetBrightness i " + Math.round(val))
    }
    function setVolume(frac) {
        ctrlSetter.connectSource("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + frac.toFixed(2))
    }
    function toggleMute() {
        ctrlSetter.connectSource("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
    }
    function setInhibit(on) {
        if (on) {
            inhibitor.connectSource("systemd-inhibit --what=sleep:idle " +
                "--who=HealthPanel --why='Vom Nutzer aktiviert' sleep infinity")
            control.inhibited = true
        } else {
            var srcs = inhibitor.connectedSources.slice()
            for (var i = 0; i < srcs.length; i++) inhibitor.disconnectSource(srcs[i])
            control.inhibited = false
        }
    }

    // fire-and-forget launcher for external apps (system settings / monitor)
    P5S.DataSource {
        id: launcher
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) { disconnectSource(source) }
    }
    function launch(cmd) { launcher.connectSource(cmd) }

    Timer {
        id: probeTimer
        interval: Plasmoid.configuration.refreshSeconds * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            probe.connectSource(root._probeCmd)
            sysProbe.connectSource(root._sysProbeCmd)
            profileProbe.connectSource(root._profileGetCmd)
            ctrlProbe.connectSource(root._ctrlProbeCmd)
        }
    }

    // ---- presentation ----
    toolTipMainText: battery.present
        ? "Battery — " + battery.capacityPct + "%"
        : "Battery — n/a"
    toolTipSubText: battery.present
        ? "Health " + battery.fmtPct(battery.healthPct)
            + " · Cycles " + battery.cycleCount
            + (battery.status ? " · " + battery.status : "")
        : (battery.error || "kein Akku gefunden")

    compactRepresentation: Compact {
        battery: root.battery
        system: root.system
        lang: root.uiLang
        onToggleExpanded: root.expanded = !root.expanded
    }

    fullRepresentation: MonitorView {
        battery: root.battery
        system: root.system
        control: root.control
        lang: root.uiLang
        pinned: root.keepOpen
        onSetProfile: function(name) { root.setPowerProfile(name) }
        onTogglePin: root.keepOpen = !root.keepOpen
        onSetScreenBrightness: function(raw) { root.setScreenBrightness(raw) }
        onSetKbdBrightness: function(val) { root.setKbdBrightness(val) }
        onSetVolume: function(frac) { root.setVolume(frac) }
        onToggleMute: root.toggleMute()
        onSetInhibit: function(on) { root.setInhibit(on) }
        onOpenSystemSettings: root.launch("systemsettings")
        onOpenSystemMonitor: root.launch("plasma-systemmonitor")
        onOpenWidgetSettings: Plasmoid.internalAction("configure").trigger()
    }

    Plasmoid.icon: {
        if (!battery.present) return "battery-missing"
        var c = battery.capacityPct
        var charging = battery.status === "Charging"
        if (c >= 95) return charging ? "battery-full-charging" : "battery-full"
        if (c >= 60) return charging ? "battery-good-charging" : "battery-good"
        if (c >= 30) return charging ? "battery-low-charging"  : "battery-low"
        return charging ? "battery-caution-charging" : "battery-caution"
    }
}
