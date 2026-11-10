pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5S
import org.kde.kirigami as Kirigami
import "sysparse.js" as Sys

PlasmoidItem {
    id: root

    // When pinned, the expanded popup stays open after losing focus.
    property bool keepOpen: false
    hideOnWindowDeactivate: !keepOpen

    // On the desktop: fall back to the compact view once the widget is dragged
    // smaller than the full view can usefully render.
    switchWidth: Kirigami.Units.gridUnit * 11
    switchHeight: Kirigami.Units.gridUnit * 9

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
    // Peripheral batteries (mouse, keyboard, headset: scope "Device") are skipped.
    readonly property string _probeCmd:
        "B=$(for d in /sys/class/power_supply/*; do " +
        "  [ \"$(cat \"$d/type\" 2>/dev/null)\" = Battery ] || continue; " +
        "  [ \"$(cat \"$d/scope\" 2>/dev/null)\" = Device ] && continue; echo \"$d\"; break; done); " +
        "[ -n \"$B\" ] && cat \"$B/uevent\" 2>/dev/null; " +
        "echo \"HP_CHARGE_START=$(cat \"$B/charge_control_start_threshold\" 2>/dev/null)\"; " +
        "echo \"HP_CHARGE_END=$(cat \"$B/charge_control_end_threshold\" 2>/dev/null)\"; " +
        "echo \"HP_CHARGE_BEHAVIOUR=$(cat \"$B/charge_behaviour\" 2>/dev/null)\""

    P5S.DataSource {
        id: probe
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)   // first: a throwing parser must not leave the source connected (= frozen widget)
            battery.applyRawOutput(data["stdout"] || "")
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
        // physical NICs only (bridges, VPN and container interfaces have no device link)
        "echo '===NETPHYS==='; for n in /sys/class/net/*; do [ -e \"$n/device\" ] && basename \"$n\"; done; " +
        // "cpuN <package*100000 + core_id>": unique per physical core, also multi-socket
        "echo '===CORES==='; for c in /sys/devices/system/cpu/cpu[0-9]*; do [ -r $c/topology/core_id ] || continue; " +
        "echo \"$(basename $c) $(( $(cat $c/topology/physical_package_id 2>/dev/null || echo 0) * 100000 + $(cat $c/topology/core_id) ))\"; done; " +
        "echo '===DF==='; df -B1 --output=source,used,size / | tail -1; " +
        // whole disk backing / (walks up through LUKS/LVM/partitions)
        "echo '===ROOTDEV==='; lsblk -nso KNAME,TYPE \"$(df --output=source / | tail -1)\" 2>/dev/null | awk '$2==\"disk\"{print $1; exit}'; " +
        // per-drive temperature (nvme hwmon, or SATA via the drivetemp module)
        "echo '===DISKTEMPS==='; for b in /sys/block/*; do " +
        "  for h in \"$b\"/device/hwmon* \"$b\"/device/hwmon/hwmon*; do [ -r \"$h/temp1_input\" ] || continue; " +
        "    echo \"DEV=$(basename \"$b\") T=$(cat \"$h/temp1_input\" 2>/dev/null) S1=$(cat \"$h/temp2_input\" 2>/dev/null)\"; break; done; done; " +
        "echo '===TEMPS==='; for h in /sys/class/hwmon/hwmon*; do echo \"$(cat $h/name 2>/dev/null) $(cat $h/temp1_input 2>/dev/null)\"; done; " +
        "echo '===SMART==='; cat /var/lib/healthpanel/smart.json 2>/dev/null; " +
        "echo '===GPU==='; for c in /sys/class/drm/card*/device; do " +
        "if [ -e \"$c/gpu_busy_percent\" ]; then echo \"BUSY=$(cat $c/gpu_busy_percent)\"; " +
        "echo \"DRV=$(basename \"$(readlink -f \"$c/driver\" 2>/dev/null)\" 2>/dev/null)\"; " +
        "echo \"VRAMUSED=$(cat $c/mem_info_vram_used 2>/dev/null)\"; " +
        "echo \"VRAMTOTAL=$(cat $c/mem_info_vram_total 2>/dev/null)\"; break; fi; done; " +
        // NVIDIA (proprietary driver) exposes nothing in sysfs/hwmon — ask nvidia-smi
        // — but never wake a runtime-suspended card (hybrid laptops) just to read it
        "echo '===NVGPU==='; NV=0; for d in /sys/bus/pci/drivers/nvidia/0000:*; do [ -e \"$d\" ] || continue; " +
        "[ \"$(cat \"$d/power/runtime_status\" 2>/dev/null)\" = suspended ] || NV=1; done; " +
        "[ $NV = 1 ] && command -v nvidia-smi >/dev/null 2>&1 && timeout 3 nvidia-smi " +
        "--query-gpu=index,pci.bus_id,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,fan.speed " +
        "--format=csv,noheader,nounits 2>/dev/null; " +
        "echo '===POWER==='; " +
        "HB=0; for b in /sys/class/power_supply/*; do [ \"$(cat \"$b/type\" 2>/dev/null)\" = Battery ] || continue; " +
        "  [ \"$(cat \"$b/scope\" 2>/dev/null)\" = Device ] && continue; HB=1; break; done; echo \"HASBATTERY=$HB\"; " +
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
        "    echo \"$n $(basename \"$f\" | sed 's/_input//')=$v $(cat \"${f%_input}_label\" 2>/dev/null)\"; done; done; " +
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
            disconnectSource(source)
            systemData.applyProbe(data["stdout"] || "")
        }
    }

    P5S.DataSource {
        id: profileProbe
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            systemData.applyProfile(data["stdout"] || "")
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
            disconnectSource(source)
            controlData.applyControlProbe(data["stdout"] || "")
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
        // data only arrives when the process ended (failed to start / was killed)
        onNewData: function(source, data) {
            disconnectSource(source)
            control.inhibited = false
        }
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
            // the quick controls are only visible in the open popup / desktop view
            if (root.expanded) ctrlProbe.connectSource(root._ctrlProbeCmd)
        }
    }
    onExpandedChanged: if (root.expanded) ctrlProbe.connectSource(root._ctrlProbeCmd)

    // ---- built-in updater (healthpanel-update; see README "Updates") ----
    // phase: "" idle | "busy" applying | "done" updated (restart pending) | "failed"
    property string updateState: "unknown"     // current | available | unsupported | error | unknown
    property string updatePhase: ""
    property string updateLocal: ""
    property string updateRemote: ""
    property int    updateCount: 0
    property string updateSubject: ""
    property string updateMessage: ""
    property bool   updateNeedsRoot: false
    readonly property bool updateAvailable: Plasmoid.configuration.checkUpdates
        && (updateState === "available" || updatePhase !== "")
    readonly property string _updater: "\"$HOME/.local/bin/healthpanel-update\""

    function _applyUpdateStatus(stdout) {
        var u = Sys.parseUpdate(stdout)
        if (u.state === "unknown") return u       // updater not installed / no output
        updateState = u.state
        updateLocal = u.local; updateRemote = u.remote
        updateCount = u.count; updateSubject = u.subject
        return u
    }
    P5S.DataSource {
        id: updateProbe
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            if (root.updatePhase === "") root._applyUpdateStatus(data["stdout"] || "")
        }
    }
    P5S.DataSource {
        id: updateRunner
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            var u = root._applyUpdateStatus(data["stdout"] || "")
            root.updateNeedsRoot = u.needsRoot
            root.updateMessage = u.message
            root.updatePhase = (u.result === "updated") ? "done" : "failed"
        }
    }
    function checkForUpdate(force) {
        if (!Plasmoid.configuration.checkUpdates || root.updatePhase === "busy") return
        updateProbe.connectSource("[ -x " + root._updater + " ] && " + root._updater
            + (force ? " check" : " status --max-age 21600"))
    }
    function applyUpdate() {
        if (root.updatePhase === "busy") return
        root.updatePhase = "busy"
        root.updateMessage = ""
        updateRunner.connectSource(root._updater + " apply")
    }
    function dismissUpdate() { root.updatePhase = ""; root.checkForUpdate(false) }
    // Plasma keeps widget QML in memory: new code only loads with a fresh shell.
    function restartShell() { root.launch("systemctl --user restart plasma-plasmashell.service") }
    Timer {
        interval: 30 * 60 * 1000       // the updater itself only asks the remote every 6 h
        running: Plasmoid.configuration.checkUpdates
        repeat: true
        triggeredOnStart: true
        onTriggered: root.checkForUpdate(false)
    }

    // ---- presentation ----
    // Machines without a battery (desktops/workstations) get a system summary.
    function _systemSummary() {
        var s = systemData
        if (!s.valid) return ""
        var parts = ["CPU " + s.fmtPct(s.cpuPct) + (s.hasCpuTemp ? " " + s.fmtTemp(s.cpuTempC) : "")]
        for (var i = 0; i < s.gpus.length; i++)
            parts.push((s.gpus.length > 1 ? "GPU" + (i + 1) : "GPU") + " " + s.fmtPct(s.gpus[i].busy)
                + (s.gpus[i].tempC !== null ? " " + s.fmtTemp(s.gpus[i].tempC) : ""))
        parts.push("RAM " + s.fmtPct(s.ramPct))
        return parts.join(" · ")
    }
    toolTipMainText: battery.present
        ? "Battery — " + battery.capacityPct + "%"
        : "HealthPanel"
    toolTipSubText: battery.present
        ? "Health " + battery.fmtPct(battery.healthPct)
            + " · Cycles " + battery.cycleCount
            + (battery.status ? " · " + battery.status : "")
            + (root.updateState === "available" && Plasmoid.configuration.checkUpdates ? "\n" + root._updateHint : "")
        : root._systemSummary()
            + (root.updateState === "available" && Plasmoid.configuration.checkUpdates ? "\n" + root._updateHint : "")
    readonly property string _updateHint: root.uiLang === "de" ? "Update verfügbar" : "Update available"

    compactRepresentation: Compact {
        battery: root.battery
        system: root.system
        lang: root.uiLang
        updateAvailable: root.updateState === "available" && Plasmoid.configuration.checkUpdates
        onToggleExpanded: root.expanded = !root.expanded
    }

    fullRepresentation: MonitorView {
        battery: root.battery
        system: root.system
        control: root.control
        lang: root.uiLang
        pinned: root.keepOpen
        updateVisible: root.updateAvailable
        updatePhase: root.updatePhase
        updateLocal: root.updateLocal
        updateRemote: root.updateRemote
        updateCount: root.updateCount
        updateSubject: root.updateSubject
        updateMessage: root.updateMessage
        updateNeedsRoot: root.updateNeedsRoot
        onApplyUpdate: root.applyUpdate()
        onDismissUpdate: root.dismissUpdate()
        onRestartShell: root.restartShell()
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
        if (!battery.present) return battery.probed ? "utilities-system-monitor" : "battery-missing"
        var c = battery.capacityPct
        var charging = battery.status === "Charging"
        if (c >= 95) return charging ? "battery-full-charging" : "battery-full"
        if (c >= 60) return charging ? "battery-good-charging" : "battery-good"
        if (c >= 30) return charging ? "battery-low-charging"  : "battery-low"
        return charging ? "battery-caution-charging" : "battery-caution"
    }
}
