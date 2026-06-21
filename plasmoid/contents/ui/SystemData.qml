// SystemData.qml — thin QML wrapper around sysparse.js.
// main.qml feeds raw probe stdout via applyProbe(); power profile via applyProfile().
import QtQuick
import "sysparse.js" as Sys

QtObject {
    id: data

    // ---- state ----
    property bool valid: false

    property real cpuPct: 0
    property var  coreLoads: []         // physical-core percentages
    property var  coreLoadsLogical: [] // logical-core (thread) percentages
    property real cpuTempC: 0
    property bool hasCpuTemp: false

    property real ramPct: 0
    property real ramUsedGB: 0
    property real ramTotalGB: 0
    property real swapPct: 0
    property real swapUsedGB: 0
    property real swapTotalGB: 0
    property bool hasSwap: swapTotalGB > 0

    property real diskPct: 0
    property real diskUsedGB: 0
    property real diskTotalGB: 0
    property real diskReadMBps: 0
    property real diskWriteMBps: 0
    property real diskTempC: 0
    property bool hasDiskTemp: false

    // GPU
    property bool hasGpu: false
    property real gpuBusy: 0
    property real vramPct: 0
    property real vramUsedGB: 0
    property real vramTotalGB: 0
    property real gpuTempC: 0
    property bool hasGpuTemp: false

    property real netDownMBps: 0
    property real netUpMBps: 0

    // power profile
    property string powerProfile: ""    // "performance" | "balanced" | "power-saver" | ""
    property bool hasPowerProfile: powerProfile !== ""

    // SSD SMART (from the root-timer cache)
    property bool smartValid: false
    property real smartHealthPct: 0
    property int  smartPowerOnHours: 0
    property real smartTbwTB: 0

    // history ring-buffers for sparklines (newest at end)
    readonly property int histLen: 40
    property var cpuHist: []        // CPU % (0..100)
    property var ramHist: []        // RAM % (0..100)
    property var diskIoHist: []     // disk read+write MB/s (raw)
    property var netHist: []        // net down+up MB/s (raw)
    property var gpuHist: []        // GPU busy % (0..100)

    function _push(arr, v) {
        var a = arr.slice();       // copy so the property reassignment triggers bindings
        a.push(v);
        if (a.length > histLen) a.shift();
        return a;
    }

    // ---- public API ----
    function applyProbe(stdout) {
        var r = Sys.parseProbe(stdout);
        valid = r.valid === true;
        if (!valid) return;
        cpuPct = r.cpuPct;
        coreLoads = r.coreLoads;
        coreLoadsLogical = r.coreLoadsLogical;
        ramPct = r.ramPct; ramUsedGB = r.ramUsedGB; ramTotalGB = r.ramTotalGB;
        swapPct = r.swapPct; swapUsedGB = r.swapUsedGB; swapTotalGB = r.swapTotalGB;
        diskPct = r.diskPct; diskUsedGB = r.diskUsedGB; diskTotalGB = r.diskTotalGB;
        diskReadMBps = r.diskReadMBps; diskWriteMBps = r.diskWriteMBps;
        netDownMBps = r.netDownMBps; netUpMBps = r.netUpMBps;
        hasCpuTemp = (r.cpuTempC !== null && r.cpuTempC !== undefined);
        cpuTempC = hasCpuTemp ? r.cpuTempC : 0;
        hasDiskTemp = (r.diskTempC !== null && r.diskTempC !== undefined);
        diskTempC = hasDiskTemp ? r.diskTempC : 0;
        hasGpu = r.gpuValid === true;
        if (hasGpu) {
            gpuBusy = r.gpuBusy; vramPct = r.vramPct;
            vramUsedGB = r.vramUsedGB; vramTotalGB = r.vramTotalGB;
        }
        hasGpuTemp = (r.gpuTempC !== null && r.gpuTempC !== undefined);
        gpuTempC = hasGpuTemp ? r.gpuTempC : 0;
        smartValid = r.smartValid === true;
        if (smartValid) {
            smartHealthPct = r.smartHealthPct;
            smartPowerOnHours = r.smartPowerOnHours;
            smartTbwTB = r.smartTbwTB;
        }
        cpuHist    = _push(cpuHist, cpuPct);
        ramHist    = _push(ramHist, ramPct);
        diskIoHist = _push(diskIoHist, diskReadMBps + diskWriteMBps);
        netHist    = _push(netHist, netDownMBps + netUpMBps);
        if (hasGpu) gpuHist = _push(gpuHist, gpuBusy);
    }

    function applyProfile(stdout) {
        powerProfile = Sys.parseProfile(stdout);
    }

    // ---- display helpers ----
    function fmtPct(v)   { return Math.round(v) + "%"; }
    function fmtGB(v)    { return v.toFixed(v < 10 ? 1 : 0) + " GB"; }
    function fmtRate(v)  { return (v >= 10 ? v.toFixed(0) : v.toFixed(1)) + " MB/s"; }
    function fmtTemp(c)  { return Math.round(c) + "°C"; }
    function fmtTbw(t)   { return (t >= 100 ? t.toFixed(0) : t.toFixed(1)) + " TBW"; }
    function fmtHours(h) { return String(h).replace(/\B(?=(\d{3})+(?!\d))/g, ".") + " h"; }
    function clampW(v)   { return Math.max(0, Math.min(100, v)); }   // bar widths
    function profileLabel(p) {
        if (p === "performance") return "Leistung";
        if (p === "balanced")    return "Ausgewogen";
        if (p === "power-saver") return "Sparen";
        return "—";
    }
}
