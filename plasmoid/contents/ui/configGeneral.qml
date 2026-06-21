import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: form

    // --- refresh ---
    property alias cfg_refreshSeconds: refreshSlider.value
    property int   cfg_refreshSecondsDefault: 2

    // --- system-column section visibility (checkbox aliases) ---
    property alias cfg_showPowerMode: powerModeCheck.checked
    property bool  cfg_showPowerModeDefault: true
    property alias cfg_showCpu: cpuCheck.checked
    property bool  cfg_showCpuDefault: true
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
    property alias cfg_cpuCoresLogical: cpuLogicalCheck.checked
    property bool  cfg_cpuCoresLogicalDefault: false

    // --- per-metric styles (plain props; combos set them via onActivated) ---
    property string cfg_cpuStyle: "sparkline"
    property string cfg_cpuStyleDefault: "sparkline"
    property string cfg_ramStyle: "bar"
    property string cfg_ramStyleDefault: "bar"
    property string cfg_diskStyle: "bar"
    property string cfg_diskStyleDefault: "bar"
    property string cfg_netStyle: "sparkline"
    property string cfg_netStyleDefault: "sparkline"

    // --- battery-column section visibility ---
    property alias cfg_showBatCycles: batCyclesCheck.checked
    property bool  cfg_showBatCyclesDefault: true
    property alias cfg_showBatCapacity: batCapacityCheck.checked
    property bool  cfg_showBatCapacityDefault: true
    property alias cfg_showBatLive: batLiveCheck.checked
    property bool  cfg_showBatLiveDefault: true
    property alias cfg_showBatSerial: batSerialCheck.checked
    property bool  cfg_showBatSerialDefault: false
    property alias cfg_showBatChargeLimit: batChargeCheck.checked
    property bool  cfg_showBatChargeLimitDefault: true

    readonly property var graphStyles: [
        { text: i18n("Balken"),    value: "bar" },
        { text: i18n("Ring"),      value: "ring" },
        { text: i18n("Sparkline"), value: "sparkline" }
    ]
    readonly property var netStyles: [
        { text: i18n("Text"),      value: "text" },
        { text: i18n("Sparkline"), value: "sparkline" }
    ]

    RowLayout {
        Kirigami.FormData.label: i18n("Aktualisierungsintervall:")
        Layout.fillWidth: true
        QQC2.Slider {
            id: refreshSlider
            from: 1; to: 30; stepSize: 1
            snapMode: QQC2.Slider.SnapAlways
            Layout.fillWidth: true
        }
        QQC2.Label {
            text: refreshSlider.value + " s"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 3
        }
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.CheckBox {
        id: powerModeCheck
        Kirigami.FormData.label: i18n("System-Spalte zeigt:")
        text: i18n("Power-Modus")
    }
    QQC2.CheckBox { id: cpuCheck;   text: i18n("CPU + Kerne") }
    QQC2.CheckBox {
        id: cpuLogicalCheck
        text: i18n("CPU-Kernbalken: logische Kerne (Threads) statt physische")
        leftPadding: cpuCheck.indicator.width + Kirigami.Units.smallSpacing
    }
    QQC2.CheckBox { id: ramCheck;   text: i18n("RAM + Swap") }
    QQC2.CheckBox { id: diskCheck;  text: i18n("Festplatte") }
    QQC2.CheckBox { id: netCheck;   text: i18n("Netzwerk") }
    QQC2.CheckBox { id: smartCheck; text: i18n("SSD-SMART (Health / Stunden / TBW)") }
    QQC2.CheckBox { id: tempsCheck; text: i18n("Temperaturen (CPU / Festplatte)") }

    Item { Kirigami.FormData.isSection: true }

    QQC2.ComboBox {
        id: cpuStyleBox
        Kirigami.FormData.label: i18n("Stil — CPU:")
        textRole: "text"; valueRole: "value"
        model: form.graphStyles
        onActivated: form.cfg_cpuStyle = currentValue
        Component.onCompleted: currentIndex = indexOfValue(form.cfg_cpuStyle)
    }
    QQC2.ComboBox {
        id: ramStyleBox
        Kirigami.FormData.label: i18n("Stil — RAM:")
        textRole: "text"; valueRole: "value"
        model: form.graphStyles
        onActivated: form.cfg_ramStyle = currentValue
        Component.onCompleted: currentIndex = indexOfValue(form.cfg_ramStyle)
    }
    QQC2.ComboBox {
        id: diskStyleBox
        Kirigami.FormData.label: i18n("Stil — Festplatte:")
        textRole: "text"; valueRole: "value"
        model: form.graphStyles
        onActivated: form.cfg_diskStyle = currentValue
        Component.onCompleted: currentIndex = indexOfValue(form.cfg_diskStyle)
    }
    QQC2.ComboBox {
        id: netStyleBox
        Kirigami.FormData.label: i18n("Stil — Netzwerk:")
        textRole: "text"; valueRole: "value"
        model: form.netStyles
        onActivated: form.cfg_netStyle = currentValue
        Component.onCompleted: currentIndex = indexOfValue(form.cfg_netStyle)
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.CheckBox {
        id: batCyclesCheck
        Kirigami.FormData.label: i18n("Akku-Spalte zeigt:")
        text: i18n("Ladezyklen")
    }
    QQC2.CheckBox { id: batCapacityCheck; text: i18n("Kapazität (Designed / Full / Remaining)") }
    QQC2.CheckBox { id: batLiveCheck;     text: i18n("Live-Werte (Status / Leistung / Spannung)") }
    QQC2.CheckBox { id: batSerialCheck;   text: i18n("Seriennummer") }
    QQC2.CheckBox { id: batChargeCheck;   text: i18n("Lenovo Ladeschwelle") }
}
