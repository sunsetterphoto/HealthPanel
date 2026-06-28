// layoutmeta.js — ordered + visible layout lists for the customizable widget
// areas (system sections, battery blocks, main columns). Pure JS (NO
// `.pragma library`), shared by QML (import "layoutmeta.js" as LayoutMeta — NOT
// `as Layout`, which would clash with the QtQuick.Layouts attached property) and
// Node tests (require). English label strings; the UI translates them via i18n.js.

function systemSections() {
    return [
        { id: "powerMode", label: "Power mode" },
        { id: "cpu",       label: "CPU" },
        { id: "gpu",       label: "GPU" },
        { id: "ram",       label: "RAM" },
        { id: "disk",      label: "Disk" },
        { id: "fans",      label: "Fans" },
        { id: "net",       label: "Network" }
    ];
}

function batteryBlocks() {
    return [
        { id: "cycles",      label: "Cycles" },
        { id: "capacity",    label: "Capacity" },
        { id: "status",      label: "Status" },
        { id: "power",       label: "Power draw" },
        { id: "voltage",     label: "Voltage" },
        { id: "time",        label: "Remaining time" },
        { id: "serial",      label: "Serial", defaultVisible: false },
        { id: "chargeLimit", label: "Charge limit" }
    ];
}

function columns() {
    return [
        { id: "system",   label: "System column" },
        { id: "battery",  label: "Battery column" },
        { id: "controls", label: "Controls column" }
    ];
}

// Normalize a stored JSON order against a meta list. Tolerant: bad/empty JSON
// becomes the default order; only known ids survive (in stored order); known ids
// missing from the stored list are appended (visible) so new sections appear.
function parseOrder(json, metaList) {
    var known = {};
    for (var i = 0; i < metaList.length; i++) known[metaList[i].id] = true;
    var stored = [];
    try { var a = JSON.parse(json); if (Array.isArray(a)) stored = a; }
    catch (e) { stored = []; }
    var out = [], seen = {};
    for (var j = 0; j < stored.length; j++) {
        var e = stored[j];
        if (e && known[e.id] && !seen[e.id]) {
            out.push({ id: e.id, v: e.v !== false });
            seen[e.id] = true;
        }
    }
    for (var k = 0; k < metaList.length; k++) {
        if (!seen[metaList[k].id]) out.push({ id: metaList[k].id, v: true });
    }
    return out;
}

function serialize(arr) { return JSON.stringify(arr); }

// Default order for a meta list: visible unless the meta item sets
// defaultVisible:false. Used for config defaults and the Reset button.
function defaultOrder(metaList) {
    return metaList.map(function (m) {
        return { id: m.id, v: m.defaultVisible !== false };
    });
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { systemSections, batteryBlocks, columns, parseOrder, serialize, defaultOrder };
}
