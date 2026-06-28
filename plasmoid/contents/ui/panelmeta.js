// panelmeta.js — metadata for the configurable panel icons.
// Each icon has a type and a list of text-parameter keys to show next to it.
// Shared by Compact.qml (rendering) and configPanel.qml (settings UI).
// Labels are English source strings; the settings UI translates them via i18n.js.

function types() {
    return [
        { type: "battery", label: "Battery", icon: "battery", texts: [
            { k: "charge", l: "Charge %" },
            { k: "health", l: "Wear/Health %" },
            { k: "power",  l: "Power (W)" }
        ] },
        { type: "cpu", label: "CPU", icon: "cpu", texts: [
            { k: "load", l: "Load %" },
            { k: "temp", l: "Temperature" },
            { k: "power",    l: "CPU power (W)" },
            { k: "socpower", l: "SoC power (W)" }
        ] },
        { type: "gpu", label: "GPU", icon: "video-card", texts: [
            { k: "load",    l: "Load %" },
            { k: "temp",    l: "Temperature" },
            { k: "power",   l: "GPU power (W)" },
            { k: "vram",    l: "VRAM %" },
            { k: "voltage", l: "GPU voltage (V)" }
        ] },
        { type: "fan", label: "Fan", icon: "sensors", texts: [
            { k: "max",  l: "Speed (rpm)" },
            { k: "fan1", l: "Fan 1" },
            { k: "fan2", l: "Fan 2" },
            { k: "fan3", l: "Fan 3" },
            { k: "fan4", l: "Fan 4" }
        ] },
        { type: "ram", label: "RAM", icon: "memory", texts: [
            { k: "usage", l: "Usage %" },
            { k: "used",  l: "Used (GB)" },
            { k: "swap",  l: "Swap %" }
        ] },
        { type: "disk", label: "Disk", icon: "drive-harddisk", texts: [
            { k: "usage", l: "Usage %" },
            { k: "temp",  l: "Temperature" },
            { k: "tempSensor1", l: "NVMe Sensor 1" },
            { k: "read",  l: "Read" },
            { k: "write", l: "Write" }
        ] },
        { type: "net", label: "Network", icon: "network-wireless", texts: [
            { k: "down", l: "Download" },
            { k: "up",   l: "Upload" }
        ] }
    ];
}

function typeMeta(t) {
    var ts = types();
    for (var i = 0; i < ts.length; i++) if (ts[i].type === t) return ts[i];
    return ts[0];
}

function textLabel(type, key) {
    var m = typeMeta(type);
    for (var i = 0; i < m.texts.length; i++) if (m.texts[i].k === key) return m.texts[i].l;
    return key;
}

// Parse the JSON layout string; always returns a valid non-empty array.
function parseLayout(json) {
    try {
        var a = JSON.parse(json);
        if (Array.isArray(a) && a.length > 0) return a;
    } catch (e) {}
    return [{ type: "battery", texts: ["charge"] }];
}

function serialize(arr) {
    return JSON.stringify(arr);
}
