// BatteryData.qml — reads /sys/class/power_supply/BAT0 via XMLHttpRequest
// and exposes all battery fields as properties. Refreshes on a timer.
import QtQuick

QtObject {
    id: data

    // ---- config ----
    property int refreshSeconds: 5
    readonly property string batDir: "/sys/class/power_supply/BAT0/"

    // ---- state ----
    property bool present: false
    property string error: ""

    // identity
    property string manufacturer: ""
    property string model: ""
    property string serial: ""
    property string technology: ""

    // status / live
    property string status: ""          // Charging / Discharging / Full / Not charging
    property int capacityPct: 0         // 0..100
    property string capacityLevel: ""

    // energy (µWh raw; *Wh exposed in Wh)
    property real energyFullDesignWh: 0
    property real energyFullWh: 0
    property real energyNowWh: 0

    // voltage / power
    property real voltageNowV: 0
    property real voltageMinDesignV: 0
    property real powerNowW: 0

    // wear
    property int cycleCount: 0
    property real healthPct: 0   // energyFull / energyFullDesign * 100

    // Lenovo
    property bool hasChargeThreshold: false
    property int chargeStart: 0
    property int chargeEnd: 0
    property string chargeBehaviour: ""

    // ---- helpers ----
    function _fetchFile(path, cb) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file://" + path)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 0 || xhr.status === 200) {
                    cb(xhr.responseText, null)
                } else {
                    cb(null, "HTTP " + xhr.status)
                }
            }
        }
        try { xhr.send() } catch (e) { cb(null, e.toString()) }
    }

    function _parseUevent(text) {
        var out = {}
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            var eq = line.indexOf("=")
            if (eq <= 0) continue
            var key = line.substring(0, eq)
            var val = line.substring(eq + 1)
            out[key] = val
        }
        return out
    }

    function _toFloat(v) { var n = parseFloat(v); return isNaN(n) ? 0 : n }
    function _toInt(v)   { var n = parseInt(v, 10); return isNaN(n) ? 0 : n }
    function _selectedToken(s) {
        // "[auto] inhibit-charge force-discharge" -> "auto"
        if (!s) return ""
        var m = s.match(/\[([^\]]+)\]/)
        return m ? m[1] : s.trim()
    }

    function refresh() {
        _fetchFile(batDir + "uevent", function(text, err) {
            if (err || !text) {
                present = false
                error = err || "no data"
                return
            }
            var p = _parseUevent(text)

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

            present = (p["POWER_SUPPLY_PRESENT"] || "0") === "1"
            error = ""
        })

        // Lenovo-specials (separate small files); silently skip if missing
        _fetchFile(batDir + "charge_control_start_threshold", function(v, e) {
            if (!e && v !== null && v !== "") {
                chargeStart = _toInt(v); hasChargeThreshold = true
            }
        })
        _fetchFile(batDir + "charge_control_end_threshold", function(v, e) {
            if (!e && v !== null && v !== "") {
                chargeEnd = _toInt(v); hasChargeThreshold = true
            }
        })
        _fetchFile(batDir + "charge_behaviour", function(v, e) {
            if (!e && v !== null && v !== "") {
                chargeBehaviour = _selectedToken(v)
            }
        })
    }

    // ---- derived display helpers ----
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
        if (healthPct >= 90) return "#2ecc71"   // green
        if (healthPct >= 75) return "#f1c40f"   // yellow
        return "#e74c3c"                         // red
    }

    // ---- timer ----
    property Timer _timer: Timer {
        interval: data.refreshSeconds * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: data.refresh()
    }
}
