pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5S

PlasmoidItem {
    id: root

    // Expose the data object as a root property so the representation
    // Components (which sit in their own scope) can reference it via root.battery.
    property alias battery: batteryData

    BatteryData {
        id: batteryData
        refreshSeconds: Plasmoid.configuration.refreshSeconds
    }

    property alias system: systemData

    SystemData { id: systemData }

    // ---- data probe via executable DataSource ----
    // We cat the uevent file (contains almost everything) plus three optional
    // Lenovo files; missing files become empty BATTINFO_* values which the
    // parser treats as "not supported".
    readonly property string _probeCmd:
        "cat /sys/class/power_supply/BAT0/uevent 2>/dev/null; " +
        "echo \"BATTINFO_CHARGE_START=$(cat /sys/class/power_supply/BAT0/charge_control_start_threshold 2>/dev/null)\"; " +
        "echo \"BATTINFO_CHARGE_END=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null)\"; " +
        "echo \"BATTINFO_CHARGE_BEHAVIOUR=$(cat /sys/class/power_supply/BAT0/charge_behaviour 2>/dev/null)\""

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
        "sleep 0.5; " +
        "echo '===T2==='; date +%s.%N; " +
        "echo '===STAT2==='; cat /proc/stat; " +
        "echo '===NET2==='; cat /proc/net/dev; " +
        "echo '===DISK2==='; cat /proc/diskstats; " +
        "echo '===MEM==='; cat /proc/meminfo; " +
        "echo '===CORES==='; for c in /sys/devices/system/cpu/cpu[0-9]*; do echo \"$(basename $c) $(cat $c/topology/core_id 2>/dev/null)\"; done; " +
        "echo '===DF==='; df -B1 --output=source,used,size / | tail -1; " +
        "echo '===TEMPS==='; for h in /sys/class/hwmon/hwmon*; do echo \"$(cat $h/name 2>/dev/null) $(cat $h/temp1_input 2>/dev/null)\"; done; " +
        "echo '===SMART==='; cat /var/lib/battinfo/smart.json 2>/dev/null"

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
        onToggleExpanded: root.expanded = !root.expanded
    }

    fullRepresentation: MonitorView {
        battery: root.battery
        system: root.system
        onSetProfile: function(name) { root.setPowerProfile(name) }
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
