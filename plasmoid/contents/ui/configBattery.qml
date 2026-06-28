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

    // this tab owns the Battery-block order/visibility
    property string cfg_batteryLayout: ""
    property string cfg_batteryLayoutDefault: ""

    spacing: Kirigami.Units.smallSpacing

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: page.tr("Reorder and show/hide the battery details. The charge bar and health always stay on top.")
    }

    LayoutGroup {
        Layout.fillWidth: true
        meta: LayoutMeta.batteryBlocks()
        json: page.cfg_batteryLayout
        lang: I18n.resolve(page.cfg_language)
        onChanged: page.cfg_batteryLayout = newJson
    }

    Item { Layout.fillHeight: true }
}
