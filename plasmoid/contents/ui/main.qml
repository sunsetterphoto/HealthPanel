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

    Timer {
        id: probeTimer
        interval: Plasmoid.configuration.refreshSeconds * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.connectSource(root._probeCmd)
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
        onClicked: root.expanded = !root.expanded
    }

    fullRepresentation: BatteryCard {
        battery: root.battery
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
