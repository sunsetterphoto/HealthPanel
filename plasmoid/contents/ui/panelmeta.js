// panelmeta.js — metadata for the configurable panel icons.
// Each icon has a type and a list of text-parameter keys to show next to it.
// Shared by Compact.qml (rendering) and configPanel.qml (settings UI).

function types() {
    return [
        { type: "battery", label: "Akku", icon: "battery", texts: [
            { k: "charge", l: "Ladung %" },
            { k: "health", l: "Wear/Health %" },
            { k: "power",  l: "Leistung (W)" }
        ] },
        { type: "cpu", label: "CPU", icon: "cpu", texts: [
            { k: "load", l: "Last %" },
            { k: "temp", l: "Temperatur" }
        ] },
        { type: "ram", label: "RAM", icon: "memory", texts: [
            { k: "usage", l: "Belegung %" },
            { k: "used",  l: "Benutzt (GB)" },
            { k: "swap",  l: "Swap %" }
        ] },
        { type: "disk", label: "Festplatte", icon: "drive-harddisk", texts: [
            { k: "usage", l: "Belegung %" },
            { k: "temp",  l: "Temperatur" },
            { k: "read",  l: "Lesen" },
            { k: "write", l: "Schreiben" }
        ] },
        { type: "net", label: "Netzwerk", icon: "network-wireless", texts: [
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
