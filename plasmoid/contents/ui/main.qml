import QtQuick
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    BatteryData {
        id: battery
        refreshSeconds: Plasmoid.configuration.refreshSeconds
    }

    toolTipMainText: battery.present
        ? "Battery — " + battery.capacityPct + "%"
        : "Battery — n/a"
    toolTipSubText: battery.present
        ? "Health " + battery.fmtPct(battery.healthPct)
            + " · Cycles " + battery.cycleCount
            + (battery.status ? " · " + battery.status : "")
        : (battery.error || "kein Akku gefunden")

    compactRepresentation: Compact {
        battery: battery
        onClicked: root.expanded = !root.expanded
    }

    fullRepresentation: BatteryCard {
        battery: battery
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
