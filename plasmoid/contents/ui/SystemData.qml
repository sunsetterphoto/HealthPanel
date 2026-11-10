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
    property real gpuFanPct: 0          // NVIDIA reports fan duty in %, not rpm
    property bool hasGpuFanPct: false
    // All GPUs (sysfs card first, then NVIDIA via nvidia-smi). Entries:
    // {name, busy, vramUsedGB, vramTotalGB, vramPct, tempC, powerW, fanPct, voltageV}
    // with null for values the card does not report. The scalar gpu* properties
    // above mirror gpus[0].
    property var  gpus: []
    property var  gpuHists: []          // one load history per entry of gpus

    // power draw (auto-detected; null in parser -> has*=false)
    property real cpuPowerW: 0
    property bool hasCpuPower: false
    property real socPowerW: 0
    property bool hasSocPower: false
    property real gpuPowerW: 0
    property bool hasGpuPower: false

    // fans
    property var  fanRpms: []
    property var  fanLabels: []         // same length as fanRpms; "" when unlabelled
    property real ambientTempC: 0       // chassis/ambient sensor, when one exists
    property bool hasAmbientTemp: false
    property int  fanMaxRpm: 0
    property bool hasFan: false

    // GPU voltage
    property real gpuVoltageV: 0
    property bool hasGpuVoltage: false

    // extra NVMe temperature (Sensor 1)
    property real diskTempSensor1C: 0
    property bool hasDiskTempSensor1: false
    // temperatures of the drives other than the one backing "/": [{dev, tempC}]
    property var  otherDiskTemps: []

    property real netDownMBps: 0
    property real netUpMBps: 0

    // power profile
    property string powerProfile: ""    // "performance" | "balanced" | "power-saver" | ""
    property bool hasPowerProfile: powerProfile !== ""

    // SSD SMART (from the root-timer cache)
    property bool smartValid: false
    property real smartHealthPct: 0
    property bool hasSmartHealth: false     // a drive may not report every field
    property int  smartPowerOnHours: 0
    property bool hasSmartHours: false
    property real smartTbwTB: 0
    property bool hasSmartTbw: false

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
        var gl = r.gpus || [], hs = [];
        for (var i = 0; i < gl.length; i++) hs.push(_push(gpuHists[i] || [], gl[i].busy));
        gpuHists = hs;
        gpus = gl;
        hasGpuFanPct = (r.gpuFanPct !== null && r.gpuFanPct !== undefined);
        gpuFanPct = hasGpuFanPct ? r.gpuFanPct : 0;
        hasGpuTemp = (r.gpuTempC !== null && r.gpuTempC !== undefined);
        gpuTempC = hasGpuTemp ? r.gpuTempC : 0;
        hasCpuPower = (r.cpuPowerW !== null && r.cpuPowerW !== undefined);
        cpuPowerW = hasCpuPower ? r.cpuPowerW : 0;
        hasSocPower = (r.socPowerW !== null && r.socPowerW !== undefined);
        socPowerW = hasSocPower ? r.socPowerW : 0;
        hasGpuPower = (r.gpuPowerW !== null && r.gpuPowerW !== undefined);
        gpuPowerW = hasGpuPower ? r.gpuPowerW : 0;
        fanRpms = r.fanRpms || [];
        fanLabels = r.fanLabels || [];
        hasAmbientTemp = (r.ambientTempC !== null && r.ambientTempC !== undefined);
        ambientTempC = hasAmbientTemp ? r.ambientTempC : 0;
        otherDiskTemps = r.otherDiskTemps || [];
        fanMaxRpm = r.fanMaxRpm || 0;
        hasFan = fanRpms.length > 0 && fanMaxRpm > 0;
        hasGpuVoltage = (r.gpuVoltageV !== null && r.gpuVoltageV !== undefined);
        gpuVoltageV = hasGpuVoltage ? r.gpuVoltageV : 0;
        hasDiskTempSensor1 = (r.diskTempSensor1C !== null && r.diskTempSensor1C !== undefined);
        diskTempSensor1C = hasDiskTempSensor1 ? r.diskTempSensor1C : 0;
        smartValid = r.smartValid === true;
        hasSmartHealth = smartValid && r.smartHealthPct !== null;
        hasSmartHours  = smartValid && r.smartPowerOnHours !== null;
        hasSmartTbw    = smartValid && r.smartTbwTB !== null;
        smartHealthPct    = hasSmartHealth ? r.smartHealthPct : 0;
        smartPowerOnHours = hasSmartHours ? r.smartPowerOnHours : 0;
        smartTbwTB        = hasSmartTbw ? r.smartTbwTB : 0;
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
    function fmtW(v)    { return v.toFixed(1) + " W"; }
    function fmtRpm(v)  { return Math.round(v) + " rpm"; }
    function fmtVolt(v) { return v.toFixed(3) + " V"; }
    function fmtTbw(t)   { return (t >= 100 ? t.toFixed(0) : t.toFixed(1)) + " TBW"; }
    function fmtHours(h) { return Number(h).toLocaleString(Qt.locale(), "f", 0) + " h"; }
    function clampW(v)   { return Math.max(0, Math.min(100, v)); }   // bar widths
}
