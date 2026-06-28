import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "i18n.js" as I18n
import "layoutmeta.js" as LayoutMeta

ColumnLayout {
    id: page

    property string cfg_language: "system"
    function tr(s) { return I18n.tr(I18n.resolve(page.cfg_language), s) }

    // --- layout keys (this tab owns the System-section order/visibility) ---
    property string cfg_systemLayout: ""
    property string cfg_systemLayoutDefault: ""
    property string cfg_batteryLayout: ""
    property string cfg_batteryLayoutDefault: ""
    property string cfg_columnOrder: ""
    property string cfg_columnOrderDefault: ""

    // --- detail toggles (rows that appear only when hardware has the sensor) ---
    property alias cfg_cpuCoresLogical: cpuLogicalCheck.checked
    property bool  cfg_cpuCoresLogicalDefault: false
    property alias cfg_showSmart: smartCheck.checked
    property bool  cfg_showSmartDefault: true
    property alias cfg_showTemps: tempsCheck.checked
    property bool  cfg_showTempsDefault: true
    property alias cfg_showPower: powerCheck.checked
    property bool  cfg_showPowerDefault: true
    property alias cfg_showVoltage: voltageCheck.checked
    property bool  cfg_showVoltageDefault: true
    property alias cfg_showDiskSensor1: diskSensor1Check.checked
    property bool  cfg_showDiskSensor1Default: true

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
        { text: page.tr("Bar"),       value: "bar" },
        { text: page.tr("Ring"),      value: "ring" },
        { text: page.tr("Sparkline"), value: "sparkline" }
    ]
    readonly property var netStyles: [
        { text: page.tr("Text"),      value: "text" },
        { text: page.tr("Sparkline"), value: "sparkline" }
    ]

    spacing: Kirigami.Units.smallSpacing

    // System-section order + visibility (drag-order with ↑↓, checkbox = show/hide)
    LayoutGroup {
        Layout.fillWidth: true
        title: page.tr("Sections (order & visibility)")
        meta: LayoutMeta.systemSections()
        json: page.cfg_systemLayout
        lang: I18n.resolve(page.cfg_language)
        onChanged: page.cfg_systemLayout = newJson
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        QQC2.CheckBox {
            id: cpuLogicalCheck
            Kirigami.FormData.label: page.tr("Details:")
            text: page.tr("Show logical cores (threads) instead of physical")
        }
        QQC2.CheckBox { id: smartCheck;       text: page.tr("SSD SMART (health / hours / TBW)") }
        QQC2.CheckBox { id: tempsCheck;       text: page.tr("Temperatures (CPU / disk / GPU)") }
        QQC2.CheckBox { id: powerCheck;       text: page.tr("Power draw (CPU / SoC / GPU)") }
        QQC2.CheckBox { id: voltageCheck;     text: page.tr("GPU voltage") }
        QQC2.CheckBox { id: diskSensor1Check; text: page.tr("NVMe Sensor 1 temperature") }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            id: cpuStyleBox
            Kirigami.FormData.label: page.tr("Style — CPU:")
            textRole: "text"; valueRole: "value"
            model: page.graphStyles
            onActivated: page.cfg_cpuStyle = currentValue
            Component.onCompleted: currentIndex = indexOfValue(page.cfg_cpuStyle)
        }
        QQC2.ComboBox {
            id: gpuStyleBox
            Kirigami.FormData.label: page.tr("Style — GPU load:")
            textRole: "text"; valueRole: "value"
            model: page.graphStyles
            onActivated: page.cfg_gpuStyle = currentValue
            Component.onCompleted: currentIndex = indexOfValue(page.cfg_gpuStyle)
        }
        QQC2.ComboBox {
            id: vramStyleBox
            Kirigami.FormData.label: page.tr("Style — VRAM:")
            textRole: "text"; valueRole: "value"
            model: [{ text: page.tr("Bar"), value: "bar" }, { text: page.tr("Text only"), value: "text" }]
            onActivated: page.cfg_vramStyle = currentValue
            Component.onCompleted: currentIndex = indexOfValue(page.cfg_vramStyle)
        }
        QQC2.ComboBox {
            id: ramStyleBox
            Kirigami.FormData.label: page.tr("Style — RAM:")
            textRole: "text"; valueRole: "value"
            model: page.graphStyles
            onActivated: page.cfg_ramStyle = currentValue
            Component.onCompleted: currentIndex = indexOfValue(page.cfg_ramStyle)
        }
        QQC2.ComboBox {
            id: diskStyleBox
            Kirigami.FormData.label: page.tr("Style — Disk:")
            textRole: "text"; valueRole: "value"
            model: page.graphStyles
            onActivated: page.cfg_diskStyle = currentValue
            Component.onCompleted: currentIndex = indexOfValue(page.cfg_diskStyle)
        }
        QQC2.ComboBox {
            id: netStyleBox
            Kirigami.FormData.label: page.tr("Style — Network:")
            textRole: "text"; valueRole: "value"
            model: page.netStyles
            onActivated: page.cfg_netStyle = currentValue
            Component.onCompleted: currentIndex = indexOfValue(page.cfg_netStyle)
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.Button {
            text: page.tr("Reset to defaults")
            icon.name: "edit-reset"
            onClicked: {
                page.cfg_systemLayout  = LayoutMeta.serialize(LayoutMeta.defaultOrder(LayoutMeta.systemSections()))
                page.cfg_batteryLayout = LayoutMeta.serialize(LayoutMeta.defaultOrder(LayoutMeta.batteryBlocks()))
                page.cfg_columnOrder   = LayoutMeta.serialize(LayoutMeta.defaultOrder(LayoutMeta.columns()))
            }
        }
    }
}
