import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "i18n.js" as I18n
import "layoutmeta.js" as LayoutMeta

ColumnLayout {
    id: page

    property alias cfg_refreshSeconds: refreshSlider.value
    property int   cfg_refreshSecondsDefault: 2
    property string cfg_language: "system"
    property string cfg_languageDefault: "system"

    // this tab owns the order/visibility of the three main columns
    property string cfg_columnOrder: ""
    property string cfg_columnOrderDefault: ""

    // config UI follows the chosen language live (cfg_language is reactive)
    function tr(s) { return I18n.tr(I18n.resolve(page.cfg_language), s) }

    spacing: Kirigami.Units.smallSpacing

    Kirigami.FormLayout {
        Layout.fillWidth: true

        RowLayout {
            Kirigami.FormData.label: page.tr("Refresh interval:")
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
            Kirigami.FormData.label: page.tr("Language:")
            textRole: "text"; valueRole: "value"
            model: [
                { text: page.tr("System default"), value: "system" },
                { text: "Deutsch", value: "de" },
                { text: "English", value: "en" }
            ]
            onActivated: page.cfg_language = currentValue
            Component.onCompleted: currentIndex = indexOfValue(page.cfg_language)
        }
    }

    Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

    // Order + visibility of the three main columns (System / Battery / Controls)
    LayoutGroup {
        Layout.fillWidth: true
        title: page.tr("Columns (order & visibility)")
        meta: LayoutMeta.columns()
        json: page.cfg_columnOrder
        lang: I18n.resolve(page.cfg_language)
        onChanged: page.cfg_columnOrder = newJson
    }

    Item { Layout.fillHeight: true }
}
