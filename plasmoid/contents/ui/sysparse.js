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

function parseCpuStat(text) {
    var total = null, cores = [];
    text.split("\n").forEach(function (line) {
        var mm = line.match(/^cpu(\d*)\s+(.+)/);
        if (!mm) return;
        var nums = mm[2].trim().split(/\s+/).map(function (x) { return parseInt(x, 10) || 0; });
        var idle = (nums[3] || 0) + (nums[4] || 0);          // idle + iowait
        var tot = nums.reduce(function (a, b) { return a + b; }, 0);
        var entry = { idle: idle, total: tot };
        if (mm[1] === "") total = entry;
        else cores[parseInt(mm[1], 10)] = entry;
    });
    return { total: total, cores: cores };
}

function _pctFromDelta(prev, cur) {
    if (!prev || !cur) return 0;
    var dt = cur.total - prev.total;
    var di = cur.idle - prev.idle;
    if (dt <= 0) return 0;
    var p = (1 - di / dt) * 100;
    return p < 0 ? 0 : (p > 100 ? 100 : p);
}

function cpuPct(prev, cur) {
    var cores = [];
    for (var i = 0; i < cur.cores.length; i++)
        cores[i] = _pctFromDelta(prev.cores[i], cur.cores[i]);
    return { total: _pctFromDelta(prev.total, cur.total), cores: cores };
}

function parseCoreIds(text) {
    var pairs = [];
    text.split("\n").forEach(function (line) {
        var mm = line.match(/^cpu(\d+)\s+(\d+)/);
        if (mm) pairs.push([parseInt(mm[1], 10), parseInt(mm[2], 10)]);
    });
    pairs.sort(function (a, b) { return a[0] - b[0]; });
    return pairs.map(function (p) { return p[1]; });
}

function physicalCoreLoads(logicalLoads, coreIds) {
    var groups = {};
    for (var i = 0; i < logicalLoads.length; i++) {
        var cid = (coreIds && coreIds[i] !== undefined) ? coreIds[i] : i;
        if (!groups[cid]) groups[cid] = [];
        groups[cid].push(logicalLoads[i]);
    }
    return Object.keys(groups)
        .map(Number).sort(function (a, b) { return a - b; })
        .map(function (id) {
            var arr = groups[id];
            return arr.reduce(function (a, b) { return a + b; }, 0) / arr.length;
        });
}

// ---- UMD export (Node only; ignored by QML) ----
if (typeof module !== "undefined" && module.exports) {
    module.exports = { parseMeminfo, memStats, parseCpuStat, cpuPct, parseCoreIds, physicalCoreLoads };
}
