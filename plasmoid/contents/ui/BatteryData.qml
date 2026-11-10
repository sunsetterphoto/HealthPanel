// BatteryData.qml — pure data + formatting helpers.
// main.qml feeds it the raw uevent text via applyRawOutput().
import QtQuick
import "batparse.js" as Bat

QtObject {
    id: data

    // ---- config ----
    property int refreshSeconds: 5

    // ---- state ----
    property bool present: false
    property bool probed: false        // true once the first probe result arrived
    property string error: ""

    // identity
    property string name: ""           // POWER_SUPPLY_NAME, e.g. "BAT0", "BAT1"
    property string manufacturer: ""
    property string model: ""
    property string serial: ""
    property string technology: ""

    // status / live
    property string status: ""
    property int capacityPct: 0
    property string capacityLevel: ""

    // energy (Wh; converted from µWh)
    property real energyFullDesignWh: 0
    property real energyFullWh: 0
    property real energyNowWh: 0

    // voltage / power
    property real voltageNowV: 0
    property real voltageMinDesignV: 0
    property real powerNowW: 0
    property bool hasPowerNow: false

    // wear
    property int cycleCount: 0
    property real healthPct: 0

    // vendor charge thresholds (ThinkPad, and any driver with charge_control_*)
    property bool hasChargeThreshold: false
    property int chargeStart: 0
    property int chargeEnd: 0
    property string chargeBehaviour: ""

    // ---- public API: feed raw text (uevent + vendor extras); parsing lives in
    // batparse.js (unit-tested) ----
    function applyRawOutput(text) {
        probed = true
        var r = Bat.parseBattery(text || "")
        name = r.name; manufacturer = r.manufacturer; model = r.model
        serial = r.serial; technology = r.technology
        status = r.status; capacityPct = r.capacityPct; capacityLevel = r.capacityLevel
        energyFullDesignWh = r.energyFullDesignWh
        energyFullWh = r.energyFullWh
        energyNowWh = r.energyNowWh
        voltageNowV = r.voltageNowV; voltageMinDesignV = r.voltageMinDesignV
        powerNowW = r.powerNowW; hasPowerNow = r.hasPowerNow
        cycleCount = r.cycleCount; healthPct = r.healthPct
        hasChargeThreshold = r.hasChargeThreshold
        chargeStart = r.chargeStart; chargeEnd = r.chargeEnd
        chargeBehaviour = r.chargeBehaviour
        present = r.present
        error = present ? "" : "battery not present"
    }

    // ---- display helpers ----
    function fmtWh(v)   { return (v > 0) ? v.toFixed(2) + " Wh" : "n/a" }
    function fmtV(v)    { return (v > 0) ? v.toFixed(2) + " V"  : "n/a" }
    function fmtW(v)    { return (v >= 0 && !isNaN(v)) ? v.toFixed(2) + " W" : "n/a" }
    function fmtPct(v, d) {
        d = (d === undefined) ? 1 : d
        return (v > 0) ? v.toFixed(d) + "%" : "n/a"
    }
    function statusGlyph() {
        if (status === "Charging") return "⚡"
        if (status === "Full") return "✓"
        if (status === "Discharging") return "↓"
        if (status === "Not charging") return "⏸"
        return ""
    }
    function healthColor() {
        if (healthPct <= 0) return "#888"
        if (healthPct >= 90) return "#2ecc71"
        if (healthPct >= 75) return "#f1c40f"
        return "#e74c3c"
    }
    function chargeColor() {
        if (status === "Charging") return "#3daee9"
        if (capacityPct >= 50) return "#2ecc71"
        if (capacityPct >= 20) return "#f1c40f"
        return "#e74c3c"
    }

    // Estimated time to empty (discharging) or to full (charging), in hours,
    // from energy_now / power_now. 0 when idle/full or power unknown.
    readonly property real timeRemainingHours: {
        if (powerNowW <= 0) return 0
        if (status === "Discharging") return energyNowWh / powerNowW
        if (status === "Charging") return Math.max(0, (energyFullWh - energyNowWh) / powerNowW)
        return 0
    }
    readonly property bool hasTimeRemaining: timeRemainingHours > 0
    function fmtDuration(h) {
        if (h <= 0) return ""
        var total = Math.round(h * 60)
        var hh = Math.floor(total / 60), mm = total % 60
        return hh + "h " + (mm < 10 ? "0" : "") + mm + "m"
    }
}
