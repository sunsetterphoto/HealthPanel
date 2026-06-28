import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "i18n.js" as I18n

Kirigami.FormLayout {
    id: form

    property string cfg_language: "system"
    function tr(s) { return I18n.tr(I18n.resolve(form.cfg_language), s) }

    QQC2.Label {
        text: form.tr("Battery layout is configured in the Layout tab.")
        wrapMode: Text.WordWrap
    }
}
