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

function parseProfile(text) {
    var m = (text || "").match(/(performance|balanced|power-saver)/);
    return m ? m[1] : "";
}

function parseTemps(text) {
    var cpu = null, disk = null;
    text.split("\n").forEach(function (line) {
        var mm = line.match(/^(\S+)\s+(\d+)\s*$/);
        if (!mm) return;
        var name = mm[1], c = parseInt(mm[2], 10) / 1000;
        if (cpu === null && (name === "k10temp" || name === "coretemp" || name === "zenpower" || name === "cpu_thermal" || name === "soc_thermal")) cpu = c;
        if (disk === null && name === "nvme") disk = c;
    });
    return { cpuTempC: cpu, diskTempC: disk };
}

function parseSmart(text) {
    try {
        var o = JSON.parse((text || "").trim());
        if (!o || o.valid !== true) return { valid: false };
        return { valid: true, healthPct: o.healthPct, powerOnHours: o.powerOnHours, tbwTB: o.tbwTB };
    } catch (e) { return { valid: false }; }
}

function _sections(stdout) {
    var out = {}, cur = null, buf = [];
    (stdout || "").split("\n").forEach(function (line) {
        var m = line.match(/^===(\w+)===$/);
        if (m) { if (cur !== null) out[cur] = buf.join("\n"); cur = m[1]; buf = []; }
        else if (cur !== null) buf.push(line);
    });
    if (cur !== null) out[cur] = buf.join("\n");
    return out;
}

function parseProbe(stdout) {
    var s = _sections(stdout);
    if (!s.STAT1 || !s.STAT2 || !s.MEM) return { valid: false };

    var dt = parseFloat(s.T2) - parseFloat(s.T1);
    if (!(dt > 0)) dt = 0.5;

    var cpu = cpuPct(parseCpuStat(s.STAT1), parseCpuStat(s.STAT2));
    var phys = physicalCoreLoads(cpu.cores, parseCoreIds(s.CORES || ""));
    var mem = memStats(parseMeminfo(s.MEM));
    var n1 = parseNetDev(s.NET1 || ""), n2 = parseNetDev(s.NET2 || "");
    var df = parseDfLine(s.DF || "");
    var dev = deviceBase(df.source || "");
    var d1 = parseDiskstats(s.DISK1 || "", dev), d2 = parseDiskstats(s.DISK2 || "", dev);
    var temps = parseTemps(s.TEMPS || "");
    var smart = parseSmart(s.SMART || "");

    return {
        valid: true,
        cpuPct: cpu.total,
        coreLoads: phys,
        coreLoadsLogical: cpu.cores,
        ramPct: mem.pct, ramUsedGB: mem.usedGB, ramTotalGB: mem.totalGB,
        swapPct: mem.swapPct, swapUsedGB: mem.swapUsedGB, swapTotalGB: mem.swapTotalGB,
        diskPct: df.sizeBytes > 0 ? (df.usedBytes / df.sizeBytes) * 100 : 0,
        diskUsedGB: df.usedBytes / 1073741824,
        diskTotalGB: df.sizeBytes / 1073741824,
        diskReadMBps: sectorsRateMBps(d1.readSectors, d2.readSectors, dt),
        diskWriteMBps: sectorsRateMBps(d1.writeSectors, d2.writeSectors, dt),
        netDownMBps: rateMBps(n1.rxBytes, n2.rxBytes, dt),
        netUpMBps: rateMBps(n1.txBytes, n2.txBytes, dt),
        cpuTempC: temps.cpuTempC,
        diskTempC: temps.diskTempC,
        smartValid: smart.valid === true,
        smartHealthPct: smart.healthPct,
        smartPowerOnHours: smart.powerOnHours,
        smartTbwTB: smart.tbwTB
    };
}

// ---- UMD export (Node only; ignored by QML) ----
if (typeof module !== "undefined" && module.exports) {
    module.exports = { parseMeminfo, memStats, parseCpuStat, cpuPct, parseCoreIds,
        physicalCoreLoads, parseNetDev, rateMBps, sectorsRateMBps, parseDiskstats,
        deviceBase, parseDfLine, parseProfile, parseTemps, parseSmart, parseProbe };
}
