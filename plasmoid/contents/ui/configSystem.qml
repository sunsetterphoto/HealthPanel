import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "i18n.js" as I18n

Kirigami.FormLayout {
    id: form

    property string cfg_language: "system"
    function tr(s) { return I18n.tr(I18n.resolve(form.cfg_language), s) }

    // --- master toggle + section visibility ---
    property alias cfg_showSystemColumn: systemColCheck.checked
    property bool  cfg_showSystemColumnDefault: true
    property alias cfg_showPowerMode: powerModeCheck.checked
    property bool  cfg_showPowerModeDefault: true
    property alias cfg_showCpu: cpuCheck.checked
    property bool  cfg_showCpuDefault: true
    property alias cfg_cpuCoresLogical: cpuLogicalCheck.checked
    property bool  cfg_cpuCoresLogicalDefault: false
    property alias cfg_showGpu: gpuCheck.checked
    property bool  cfg_showGpuDefault: true
    property alias cfg_showRam: ramCheck.checked
    property bool  cfg_showRamDefault: true
    property alias cfg_showDisk: diskCheck.checked
    property bool  cfg_showDiskDefault: true
    property alias cfg_showNet: netCheck.checked
    property bool  cfg_showNetDefault: true
    property alias cfg_showSmart: smartCheck.checked
    property bool  cfg_showSmartDefault: true
    property alias cfg_showTemps: tempsCheck.checked
    property bool  cfg_showTempsDefault: true

    // --- per-metric styles (plain props; combos set them via onActivated) ---
    property string cfg_cpuStyle: "sparkline"
    property string cfg_cpuStyleDefault: "sparkline"
    property string cfg_ramStyle: "bar"
    property string cfg_ramStyleDefault: "bar"
    property string cfg_diskStyle: "bar"
    property string cfg_diskStyleDefault: "bar"
    property string cfg_netStyle: "sparkline"
    property string cfg_netStyleDefault: "sparkline"
    property string cfg_gpuStyle: "sparkline"
    property string cfg_gpuStyleDefault: "sparkline"
    property string cfg_vramStyle: "bar"
    property string cfg_vramStyleDefault: "bar"

    readonly property var graphStyles: [
        { text: form.tr("Bar"),       value: "bar" },
        { text: form.tr("Ring"),      value: "ring" },
        { text: form.tr("Sparkline"), value: "sparkline" }
    ]
    readonly property var netStyles: [
        { text: form.tr("Text"),      value: "text" },
        { text: form.tr("Sparkline"), value: "sparkline" }
    ]

    QQC2.CheckBox {
        id: systemColCheck
        Kirigami.FormData.label: form.tr("System column (left):")
        text: form.tr("Show column")
    }
    QQC2.CheckBox {
        id: powerModeCheck
        Kirigami.FormData.label: form.tr("Shows:")
        text: form.tr("Power mode")
        enabled: systemColCheck.checked
    }
    QQC2.CheckBox { id: cpuCheck; text: form.tr("CPU + cores"); enabled: systemColCheck.checked }
    QQC2.CheckBox {
        id: cpuLogicalCheck
        text: form.tr("Show logical cores (threads) instead of physical")
        enabled: systemColCheck.checked && cpuCheck.checked
        leftPadding: cpuCheck.indicator.width + Kirigami.Units.smallSpacing
    }
    QQC2.CheckBox { id: ramCheck;   text: form.tr("RAM + swap"); enabled: systemColCheck.checked }
    QQC2.CheckBox { id: gpuCheck;   text: form.tr("GPU + VRAM"); enabled: systemColCheck.checked }
    QQC2.CheckBox { id: diskCheck;  text: form.tr("Disk"); enabled: systemColCheck.checked }
    QQC2.CheckBox { id: netCheck;   text: form.tr("Network"); enabled: systemColCheck.checked }
    QQC2.CheckBox { id: smartCheck; text: form.tr("SSD SMART (health / hours / TBW)"); enabled: systemColCheck.checked }
    QQC2.CheckBox { id: tempsCheck; text: form.tr("Temperatures (CPU / disk / GPU)"); enabled: systemColCheck.checked }

    Item { Kirigami.FormData.isSection: true }

    QQC2.ComboBox {
        id: cpuStyleBox
        Kirigami.FormData.label: form.tr("Style — CPU:")
        textRole: "text"; valueRole: "value"
        model: form.graphStyles
        enabled: systemColCheck.checked && cpuCheck.checked
        onActivated: form.cfg_cpuStyle = currentValue
        Component.onCompleted: currentIndex = indexOfValue(form.cfg_cpuStyle)
    }
    QQC2.ComboBox {
        id: gpuStyleBox
        Kirigami.FormData.label: form.tr("Style — GPU load:")
        textRole: "text"; valueRole: "value"
        model: form.graphStyles
        enabled: systemColCheck.checked && gpuCheck.checked
        onActivated: form.cfg_gpuStyle = currentValue
        Component.onCompleted: currentIndex = indexOfValue(form.cfg_gpuStyle)
    }
    QQC2.ComboBox {
        id: vramStyleBox
        Kirigami.FormData.label: form.tr("Style — VRAM:")
        textRole: "text"; valueRole: "value"
        model: [{ text: form.tr("Bar"), value: "bar" }, { text: form.tr("Text only"), value: "text" }]
        enabled: systemColCheck.checked && gpuCheck.checked
        onActivated: form.cfg_vramStyle = currentValue
        Component.onCompleted: currentIndex = indexOfValue(form.cfg_vramStyle)
    }
    QQC2.ComboBox {
        id: ramStyleBox
        Kirigami.FormData.label: form.tr("Style — RAM:")
        textRole: "text"; valueRole: "value"
        model: form.graphStyles
        enabled: systemColCheck.checked && ramCheck.checked
        onActivated: form.cfg_ramStyle = currentValue
        Component.onCompleted: currentIndex = indexOfValue(form.cfg_ramStyle)
    }
    QQC2.ComboBox {
        id: diskStyleBox
        Kirigami.FormData.label: form.tr("Style — Disk:")
        textRole: "text"; valueRole: "value"
        model: form.graphStyles
        enabled: systemColCheck.checked && diskCheck.checked
        onActivated: form.cfg_diskStyle = currentValue
        Component.onCompleted: currentIndex = indexOfValue(form.cfg_diskStyle)
    }
    QQC2.ComboBox {
        id: netStyleBox
        Kirigami.FormData.label: form.tr("Style — Network:")
        textRole: "text"; valueRole: "value"
        model: form.netStyles
        enabled: systemColCheck.checked && netCheck.checked
        onActivated: form.cfg_netStyle = currentValue
        Component.onCompleted: currentIndex = indexOfValue(form.cfg_netStyle)
    }
}
