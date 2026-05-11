import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: form

    property alias cfg_refreshSeconds: refreshSlider.value

    RowLayout {
        Kirigami.FormData.label: i18n("Refresh interval:")
        Layout.fillWidth: true

        QQC2.Slider {
            id: refreshSlider
            from: 2
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
}
