// BatteryData.qml — pure data + formatting helpers.
// main.qml feeds it the raw uevent text via applyRawOutput().
import QtQuick

QtObject {
    id: data

    // ---- config ----
    property int refreshSeconds: 5

    // ---- state ----
    property bool present: false
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

    // wear
    property int cycleCount: 0
    property real healthPct: 0

    // Lenovo
    property bool hasChargeThreshold: false
    property int chargeStart: 0
    property int chargeEnd: 0
    property string chargeBehaviour: ""

    // ---- internal helpers ----
    function _toFloat(v) { var n = parseFloat(v); return isNaN(n) ? 0 : n }
    function _toInt(v)   { var n = parseInt(v, 10); return isNaN(n) ? 0 : n }
    function _selectedToken(s) {
        if (!s) return ""
        var m = s.match(/\[([^\]]+)\]/)
        return m ? m[1] : s.trim()
    }
    function _parseKV(text) {
        var out = {}
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            var eq = line.indexOf("=")
            if (eq <= 0) continue
            out[line.substring(0, eq)] = line.substring(eq + 1)
        }
        return out
    }

    // ---- public API: feed raw text (uevent + lenovo extras) ----
    function applyRawOutput(text) {
        if (!text) {
            present = false
            error = "no data"
            return
        }
        var p = _parseKV(text)

        name               = p["POWER_SUPPLY_NAME"] || ""
        manufacturer       = p["POWER_SUPPLY_MANUFACTURER"] || ""
        model              = p["POWER_SUPPLY_MODEL_NAME"] || ""
        serial             = (p["POWER_SUPPLY_SERIAL_NUMBER"] || "").trim()
        technology         = p["POWER_SUPPLY_TECHNOLOGY"] || ""
        status             = p["POWER_SUPPLY_STATUS"] || ""
        capacityPct        = _toInt(p["POWER_SUPPLY_CAPACITY"])
        capacityLevel      = p["POWER_SUPPLY_CAPACITY_LEVEL"] || ""

        energyFullDesignWh = _toFloat(p["POWER_SUPPLY_ENERGY_FULL_DESIGN"]) / 1e6
        energyFullWh       = _toFloat(p["POWER_SUPPLY_ENERGY_FULL"]) / 1e6
        energyNowWh        = _toFloat(p["POWER_SUPPLY_ENERGY_NOW"]) / 1e6

        voltageNowV        = _toFloat(p["POWER_SUPPLY_VOLTAGE_NOW"]) / 1e6
        voltageMinDesignV  = _toFloat(p["POWER_SUPPLY_VOLTAGE_MIN_DESIGN"]) / 1e6
        powerNowW          = _toFloat(p["POWER_SUPPLY_POWER_NOW"]) / 1e6

        cycleCount         = _toInt(p["POWER_SUPPLY_CYCLE_COUNT"])
        healthPct = energyFullDesignWh > 0
            ? (energyFullWh / energyFullDesignWh) * 100
            : 0

        // Lenovo (printed by the shell command in main.qml as BATTINFO_* lines)
        var cs = p["HP_CHARGE_START"]
        var ce = p["HP_CHARGE_END"]
        var cb = p["HP_CHARGE_BEHAVIOUR"]
        hasChargeThreshold = false
        if (cs && cs.length > 0) { chargeStart = _toInt(cs); hasChargeThreshold = true }
        if (ce && ce.length > 0) { chargeEnd   = _toInt(ce); hasChargeThreshold = true }
        chargeBehaviour = cb ? _selectedToken(cb) : ""

        present = (p["POWER_SUPPLY_PRESENT"] || "0") === "1"
        error = present ? "" : "battery not present"
    }

    // ---- display helpers ----
    function fmtWh(v)   { return (v > 0) ? v.toFixed(2) + " Wh" : "n/a" }
    function fmtV(v)    { return (v > 0) ? v.toFixed(2) + " V"  : "n/a" }
    function fmtW(v)    { return (v > 0) ? v.toFixed(2) + " W"  : "n/a" }
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
}
