import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "i18n.js" as I18n

Kirigami.FormLayout {
    id: form

    property string cfg_language: "system"
    function tr(s) { return I18n.tr(I18n.resolve(form.cfg_language), s) }

    property alias cfg_showControls: controlsCheck.checked
    property bool  cfg_showControlsDefault: true
    property alias cfg_showInhibit: inhibitCheck.checked
    property bool  cfg_showInhibitDefault: true
    property alias cfg_showScreenBrightness: screenCheck.checked
    property bool  cfg_showScreenBrightnessDefault: true
    property alias cfg_showKbdBrightness: kbdCheck.checked
    property bool  cfg_showKbdBrightnessDefault: true
    property alias cfg_showVolume: volumeCheck.checked
    property bool  cfg_showVolumeDefault: true

    QQC2.CheckBox {
        id: controlsCheck
        Kirigami.FormData.label: form.tr("Controls column (right):")
        text: form.tr("Show controls")
    }
    QQC2.CheckBox {
        id: inhibitCheck
        Kirigami.FormData.label: form.tr("Shows:")
        text: form.tr("Prevent standby & lock screen")
        enabled: controlsCheck.checked
    }
    QQC2.CheckBox { id: screenCheck; text: form.tr("Screen brightness"); enabled: controlsCheck.checked }
    QQC2.CheckBox { id: kbdCheck;    text: form.tr("Keyboard backlight"); enabled: controlsCheck.checked }
    QQC2.CheckBox { id: volumeCheck; text: form.tr("Volume + mute"); enabled: controlsCheck.checked }
}
