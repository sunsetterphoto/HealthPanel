// Compact representation — a configurable list of icons (battery/cpu/ram/disk/net),
// each optionally with one or more text values. Default: one battery icon (which
// also encodes the power profile) + charge %. Reports its size via Layout.* so the
// panel grants room for the labels.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "panelmeta.js" as PanelMeta

MouseArea {
    id: compact
    property var battery
    property var system
    property string lang: "en"
    signal toggleExpanded()

    readonly property bool _ready: compact.battery !== null && compact.battery !== undefined
    readonly property bool _ok: _ready && compact.battery.present === true
    readonly property bool _hasProfile: compact.system !== null && compact.system !== undefined
        && compact.system.hasPowerProfile === true
    readonly property bool _vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property var _layout: PanelMeta.parseLayout(Plasmoid.configuration.panelLayout)

    // Per-entry icons (modelData.icon !== false). When an entry has no icon, a thin
    // divider stands in for it — but only when the previous visible value is ALSO
    // icon-less, so a text value right after an icon isn't double-separated.
    function _dividerBefore(i) {
        var it = _layout[i]
        if (!it || it.icon !== false) return false        // entry has an icon → no divider
        if (textFor(it).length === 0) return false        // entry has no text → no divider
        for (var j = i - 1; j >= 0; j--) {
            if (textFor(_layout[j]).length > 0)            // nearest preceding visible value
                return _layout[j].icon === false           // divider only if it too is icon-less
        }
        return false                                       // first visible value → no divider
    }

    implicitWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
    implicitHeight: Math.max(row.implicitHeight, Kirigami.Units.iconSizes.small)
    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth

    hoverEnabled: true
    onClicked: compact.toggleExpanded()

    // KDE combines charge level + power profile into one battery icon.
    function batteryIconName() {
        if (!compact._ok) return "battery-missing"
        var b = compact.battery, c = b.capacityPct
        var charging = b.status === "Charging"
        if (compact._hasProfile) {
            var lvl = Math.max(0, Math.min(100, Math.round(c / 10) * 10))
            var lll = ("00" + lvl).slice(-3)
            var p = compact.system.powerProfile
            var mode = p === "performance" ? "performance" : (p === "power-saver" ? "powersave" : "balanced")
            return "battery-" + lll + (charging ? "-charging" : "") + "-profile-" + mode
        }
        if (c >= 95) return charging ? "battery-full-charging" : "battery-full"
        if (c >= 60) return charging ? "battery-good-charging" : "battery-good"
        if (c >= 30) return charging ? "battery-low-charging"  : "battery-low"
        return charging ? "battery-caution-charging" : "battery-caution"
    }
    function iconFor(type) {
        if (type === "battery") return batteryIconName()
        return PanelMeta.typeMeta(type).icon
    }
    function valueFor(type, key) {
        var b = compact.battery, s = compact.system
        if (type === "battery") {
            if (!compact._ok) return ""
            if (key === "charge") return b.capacityPct + "%"
            if (key === "health") return Math.round(b.healthPct) + "%"
            if (key === "power")  return b.hasPowerNow ? b.fmtW(b.powerNowW) : "n/a"
            return ""
        }
        if (s === null || s === undefined || s.valid !== true) return ""
        if (type === "cpu") {
            if (key === "load") return Math.round(s.cpuPct) + "%"
            if (key === "temp") return s.hasCpuTemp ? Math.round(s.cpuTempC) + "°" : ""
            if (key === "power")    return s.hasCpuPower ? s.fmtW(s.cpuPowerW) : ""
            if (key === "socpower") return s.hasSocPower ? "SoC " + s.fmtW(s.socPowerW) : ""
        } else if (type === "ram") {
            if (key === "usage") return Math.round(s.ramPct) + "%"
            if (key === "used")  return s.fmtGB(s.ramUsedGB)
            if (key === "swap")  return s.hasSwap ? Math.round(s.swapPct) + "%" : ""
        } else if (type === "disk") {
            if (key === "usage") return Math.round(s.diskPct) + "%"
            if (key === "temp")  return s.hasDiskTemp ? Math.round(s.diskTempC) + "°" : ""
            if (key === "tempSensor1") return s.hasDiskTempSensor1 ? "S1 " + Math.round(s.diskTempSensor1C) + "°" : ""
            if (key === "read")  return "↓" + s.fmtRate(s.diskReadMBps)
            if (key === "write") return "↑" + s.fmtRate(s.diskWriteMBps)
        } else if (type === "net") {
            if (key === "down") return "↓" + s.fmtRate(s.netDownMBps)
            if (key === "up")   return "↑" + s.fmtRate(s.netUpMBps)
        } else if (type === "gpu") {
            if (key === "load")    return s.hasGpu ? Math.round(s.gpuBusy) + "%" : ""
            if (key === "temp")    return s.hasGpuTemp ? Math.round(s.gpuTempC) + "°" : ""
            if (key === "power")   return s.hasGpuPower ? s.fmtW(s.gpuPowerW) : ""
            if (key === "vram")    return s.hasGpu ? Math.round(s.vramPct) + "%" : ""
            if (key === "voltage") return s.hasGpuVoltage ? s.fmtVolt(s.gpuVoltageV) : ""
        } else if (type === "fan") {
            if (key === "max")  return s.hasFan ? s.fmtRpm(s.fanMaxRpm) : ""
            if (key === "fan1") return (s.fanRpms.length > 0) ? s.fmtRpm(s.fanRpms[0]) : ""
            if (key === "fan2") return (s.fanRpms.length > 1) ? s.fmtRpm(s.fanRpms[1]) : ""
            if (key === "fan3") return (s.fanRpms.length > 2) ? s.fmtRpm(s.fanRpms[2]) : ""
            if (key === "fan4") return (s.fanRpms.length > 3) ? s.fmtRpm(s.fanRpms[3]) : ""
        }
        return ""
    }
    function textFor(cfg) {
        if (!cfg || !cfg.texts) return ""
        var parts = []
        for (var i = 0; i < cfg.texts.length; i++) {
            var v = valueFor(cfg.type, cfg.texts[i])
            if (v.length > 0) parts.push(v)
        }
        return parts.join(" ")
    }

    GridLayout {
        id: row
        anchors.centerIn: parent
        flow: compact._vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: compact._vertical ? Kirigami.Units.smallSpacing : 0
        columnSpacing: Kirigami.Units.largeSpacing

        Repeater {
            model: compact._layout
            delegate: RowLayout {
                id: itemRow
                required property var modelData
                required property int index
                readonly property string _txt: compact.textFor(modelData)
                spacing: Kirigami.Units.smallSpacing
                // divider standing in for a missing icon (vertical on a horizontal
                // panel, horizontal on a vertical panel)
                Rectangle {
                    visible: compact._dividerBefore(itemRow.index)
                    color: Kirigami.Theme.textColor
                    opacity: 0.3
                    Layout.alignment: Qt.AlignCenter
                    Layout.rightMargin: Kirigami.Units.smallSpacing
                    Layout.preferredWidth:  compact._vertical ? Kirigami.Units.iconSizes.small : 1
                    Layout.preferredHeight: compact._vertical ? 1 : Kirigami.Units.iconSizes.small
                }
                Kirigami.Icon {
                    visible: itemRow.modelData.icon !== false
                    source: compact.iconFor(modelData.type)
                    Layout.alignment: Qt.AlignCenter
                    implicitWidth:  Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }
                PC3.Label {
                    text: itemRow._txt
                    visible: text.length > 0
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                    Layout.alignment: Qt.AlignCenter
                }
            }
        }
    }
}
