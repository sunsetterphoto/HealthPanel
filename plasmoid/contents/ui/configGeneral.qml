import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: form

    // The cfg_<name>Default properties mirror the kcfg defaults — Plasma sets them
    // on this page for the "Defaults" button and otherwise logs a warning.
    property alias cfg_refreshSeconds: refreshSlider.value
    property int   cfg_refreshSecondsDefault: 2
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

    RowLayout {
        Kirigami.FormData.label: i18n("Aktualisierungsintervall:")
        Layout.fillWidth: true

        QQC2.Slider {
            id: refreshSlider
            from: 1
            to: 30
            stepSize: 1
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
    QQC2.CheckBox { id: ramCheck;   text: i18n("RAM + Swap") }
    QQC2.CheckBox { id: diskCheck;  text: i18n("Festplatte") }
    QQC2.CheckBox { id: netCheck;   text: i18n("Netzwerk") }
    QQC2.CheckBox { id: smartCheck; text: i18n("SSD-SMART (Health / Stunden / TBW)") }
    QQC2.CheckBox { id: tempsCheck; text: i18n("Temperaturen (CPU / Festplatte)") }
}
