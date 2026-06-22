import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "i18n.js" as I18n

Kirigami.FormLayout {
    id: form

    property alias cfg_refreshSeconds: refreshSlider.value
    property int   cfg_refreshSecondsDefault: 2
    property string cfg_language: "system"
    property string cfg_languageDefault: "system"

    // config UI follows the chosen language live (cfg_language is reactive)
    function tr(s) { return I18n.tr(I18n.resolve(form.cfg_language), s) }

    RowLayout {
        Kirigami.FormData.label: form.tr("Refresh interval:")
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

    QQC2.ComboBox {
        id: languageBox
        Kirigami.FormData.label: form.tr("Language:")
        textRole: "text"; valueRole: "value"
        model: [
            { text: form.tr("System default"), value: "system" },
            { text: "Deutsch", value: "de" },
            { text: "English", value: "en" }
        ]
        onActivated: form.cfg_language = currentValue
        Component.onCompleted: currentIndex = indexOfValue(form.cfg_language)
    }
}
