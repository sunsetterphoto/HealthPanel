import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "i18n.js" as I18n

Kirigami.FormLayout {
    id: form

    property string cfg_language: "system"
    function tr(s) { return I18n.tr(I18n.resolve(form.cfg_language), s) }

    property alias cfg_showBatteryColumn: batteryColCheck.checked
    property bool  cfg_showBatteryColumnDefault: true
    property alias cfg_showBatCycles: batCyclesCheck.checked
    property bool  cfg_showBatCyclesDefault: true
    property alias cfg_showBatCapacity: batCapacityCheck.checked
    property bool  cfg_showBatCapacityDefault: true
    property alias cfg_showBatLive: batLiveCheck.checked
    property bool  cfg_showBatLiveDefault: true
    property alias cfg_showBatSerial: batSerialCheck.checked
    property bool  cfg_showBatSerialDefault: false
    property alias cfg_showBatTime: batTimeCheck.checked
    property bool  cfg_showBatTimeDefault: true
    property alias cfg_showBatChargeLimit: batChargeCheck.checked
    property bool  cfg_showBatChargeLimitDefault: true

    QQC2.CheckBox {
        id: batteryColCheck
        Kirigami.FormData.label: form.tr("Battery column (middle):")
        text: form.tr("Show column")
    }
    QQC2.CheckBox {
        id: batCyclesCheck
        Kirigami.FormData.label: form.tr("Shows:")
        text: form.tr("Battery cycles")
        enabled: batteryColCheck.checked
    }
    QQC2.CheckBox { id: batCapacityCheck; text: form.tr("Capacity (designed / full / remaining)"); enabled: batteryColCheck.checked }
    QQC2.CheckBox { id: batLiveCheck;     text: form.tr("Live values (status / power / voltage)"); enabled: batteryColCheck.checked }
    QQC2.CheckBox { id: batTimeCheck;     text: form.tr("Estimated remaining time (hours)"); enabled: batteryColCheck.checked }
    QQC2.CheckBox { id: batSerialCheck;   text: form.tr("Serial number"); enabled: batteryColCheck.checked }
    QQC2.CheckBox { id: batChargeCheck;   text: form.tr("Vendor charge thresholds"); enabled: batteryColCheck.checked }
}
