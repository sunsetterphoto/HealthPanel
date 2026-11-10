// batparse.js — pure parsing of a power_supply `uevent` dump (plus the HP_* extra
// lines main.qml appends) into plain numbers. Shared by QML
// (import "batparse.js" as Bat) and Node tests (require). NO `.pragma library`.
//
// Handles both kinds of fuel gauges the kernel exposes:
//   energy-based  POWER_SUPPLY_ENERGY_* (µWh) + POWER_NOW (µW)   — e.g. ThinkPads
//   charge-based  POWER_SUPPLY_CHARGE_* (µAh) + CURRENT_NOW (µA) — many Dell/HP/ASUS
// Charge values are converted to Wh/W with the design (or current) voltage.

function _kv(text) {
    var out = {};
    (text || "").split("\n").forEach(function (line) {
        var eq = line.indexOf("=");
        if (eq > 0) out[line.substring(0, eq)] = line.substring(eq + 1);
    });
    return out;
}
function _num(v) { var n = parseFloat(v); return isNaN(n) ? 0 : n; }
function _has(v) { return v !== undefined && v !== ""; }

function parseBattery(text) {
    var p = _kv(text);
    var name = p.POWER_SUPPLY_NAME || "";
    var r = {
        // some drivers omit PRESENT entirely: a named battery then counts as present
        present: name !== "" && (p.POWER_SUPPLY_PRESENT === undefined || p.POWER_SUPPLY_PRESENT === "1"),
        name: name,
        manufacturer: p.POWER_SUPPLY_MANUFACTURER || "",
        model: p.POWER_SUPPLY_MODEL_NAME || "",
        serial: (p.POWER_SUPPLY_SERIAL_NUMBER || "").trim(),
        technology: p.POWER_SUPPLY_TECHNOLOGY || "",
        status: p.POWER_SUPPLY_STATUS || "",
        capacityPct: Math.round(_num(p.POWER_SUPPLY_CAPACITY)),
        capacityLevel: p.POWER_SUPPLY_CAPACITY_LEVEL || "",
        cycleCount: Math.round(_num(p.POWER_SUPPLY_CYCLE_COUNT)),
        voltageNowV: _num(p.POWER_SUPPLY_VOLTAGE_NOW) / 1e6,
        voltageMinDesignV: _num(p.POWER_SUPPLY_VOLTAGE_MIN_DESIGN) / 1e6
    };

    var refV = r.voltageMinDesignV > 0 ? r.voltageMinDesignV : r.voltageNowV;   // for µAh -> Wh
    function energyWh(eKey, cKey) {
        if (_has(p[eKey])) return _num(p[eKey]) / 1e6;
        if (_has(p[cKey])) return _num(p[cKey]) / 1e6 * refV;
        return 0;
    }
    r.energyFullDesignWh = energyWh("POWER_SUPPLY_ENERGY_FULL_DESIGN", "POWER_SUPPLY_CHARGE_FULL_DESIGN");
    r.energyFullWh       = energyWh("POWER_SUPPLY_ENERGY_FULL", "POWER_SUPPLY_CHARGE_FULL");
    r.energyNowWh        = energyWh("POWER_SUPPLY_ENERGY_NOW", "POWER_SUPPLY_CHARGE_NOW");
    r.healthPct = r.energyFullDesignWh > 0 ? (r.energyFullWh / r.energyFullDesignWh) * 100 : 0;

    // power: some drivers report a negative value while discharging
    r.hasPowerNow = false; r.powerNowW = 0;
    if (_has(p.POWER_SUPPLY_POWER_NOW)) {
        r.powerNowW = Math.abs(_num(p.POWER_SUPPLY_POWER_NOW)) / 1e6; r.hasPowerNow = true;
    } else if (_has(p.POWER_SUPPLY_CURRENT_NOW) && r.voltageNowV > 0) {
        r.powerNowW = Math.abs(_num(p.POWER_SUPPLY_CURRENT_NOW)) / 1e6 * r.voltageNowV; r.hasPowerNow = true;
    }

    // vendor charge thresholds (printed by the probe as HP_* lines; empty = unsupported)
    r.hasChargeThreshold = _has(p.HP_CHARGE_START) || _has(p.HP_CHARGE_END);
    r.chargeStart = Math.round(_num(p.HP_CHARGE_START));
    r.chargeEnd = _has(p.HP_CHARGE_END) ? Math.round(_num(p.HP_CHARGE_END)) : 100;
    var cb = p.HP_CHARGE_BEHAVIOUR || "";
    var sel = cb.match(/\[([^\]]+)\]/);       // "[auto] inhibit-charge force-discharge"
    r.chargeBehaviour = sel ? sel[1] : cb.trim();
    return r;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { parseBattery };
}
