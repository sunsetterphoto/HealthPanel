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

function parseNetDev(text) {
    var rx = 0, tx = 0;
    text.split("\n").forEach(function (line) {
        var mm = line.match(/^\s*([\w@.-]+):\s+(.+)/);
        if (!mm || mm[1] === "lo") return;
        var nums = mm[2].trim().split(/\s+/);
        rx += parseInt(nums[0], 10) || 0;    // rx bytes
        tx += parseInt(nums[8], 10) || 0;    // tx bytes
    });
    return { rxBytes: rx, txBytes: tx };
}

function rateMBps(prevBytes, curBytes, dtSec) {
    if (dtSec <= 0) return 0;
    var d = curBytes - prevBytes;
    if (d < 0) d = 0;
    return (d / dtSec) / 1048576;
}

function sectorsRateMBps(prevSec, curSec, dtSec) {
    return rateMBps(prevSec * 512, curSec * 512, dtSec);
}

function parseDiskstats(text, dev) {
    var out = { readSectors: 0, writeSectors: 0 };
    text.split("\n").forEach(function (line) {
        var f = line.trim().split(/\s+/);
        if (f[2] === dev) {
            out.readSectors = parseInt(f[5], 10) || 0;
            out.writeSectors = parseInt(f[9], 10) || 0;
        }
    });
    return out;
}

function deviceBase(source) {
    var name = source.replace(/^\/dev\//, "");
    if (/^(nvme\d+n\d+|mmcblk\d+)p\d+$/.test(name)) return name.replace(/p\d+$/, "");
    return name.replace(/\d+$/, "");
}

function parseDfLine(line) {
    var f = line.trim().split(/\s+/);
    // df -B1 --output=source,used,size  -> "<source> <used> <size>"
    return {
        source: f[0] || "",
        usedBytes: parseInt(f[1], 10) || 0,
        sizeBytes: parseInt(f[2], 10) || 0
    };
}

// ---- UMD export (Node only; ignored by QML) ----
if (typeof module !== "undefined" && module.exports) {
    module.exports = { parseMeminfo, memStats, parseCpuStat, cpuPct, parseCoreIds,
        physicalCoreLoads, parseNetDev, rateMBps, sectorsRateMBps, parseDiskstats,
        deviceBase, parseDfLine };
}
