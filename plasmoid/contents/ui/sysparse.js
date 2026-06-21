// sysparse.js — pure parsing/maths for the system monitor.
// Shared by QML (import "sysparse.js" as Sys) and Node tests (require).
// NO `.pragma library` here — that would not be valid Node JS.

function parseMeminfo(text) {
    var m = {};
    text.split("\n").forEach(function (line) {
        var mm = line.match(/^(\w+):\s+(\d+)/);
        if (mm) m[mm[1]] = parseInt(mm[2], 10);
    });
    return {
        memTotalKb: m.MemTotal || 0,
        memAvailKb: m.MemAvailable || 0,
        swapTotalKb: m.SwapTotal || 0,
        swapFreeKb: m.SwapFree || 0
    };
}

function memStats(mi) {
    var usedKb = mi.memTotalKb - mi.memAvailKb;
    var swapUsedKb = mi.swapTotalKb - mi.swapFreeKb;
    return {
        usedGB: usedKb / 1048576,
        totalGB: mi.memTotalKb / 1048576,
        pct: mi.memTotalKb > 0 ? (usedKb / mi.memTotalKb) * 100 : 0,
        swapUsedGB: swapUsedKb / 1048576,
        swapTotalGB: mi.swapTotalKb / 1048576,
        swapPct: mi.swapTotalKb > 0 ? (swapUsedKb / mi.swapTotalKb) * 100 : 0
    };
}

// ---- UMD export (Node only; ignored by QML) ----
if (typeof module !== "undefined" && module.exports) {
    module.exports = { parseMeminfo, memStats };
}
