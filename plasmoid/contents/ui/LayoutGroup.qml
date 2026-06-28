// LayoutGroup.qml — a reusable reorder + show/hide list for ONE layout config
// string (system sections / battery blocks / columns). Each row: a drag-handle
// glyph + a checkbox (the label, toggles visibility) + ↑/↓ move buttons. Emits
// changed(newJson) whenever the order or visibility changes; the host page binds
// that back to its cfg_* string. Reused by configSystem/configBattery/configGeneral.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layoutmeta.js" as LayoutMeta
import "i18n.js" as I18n

ColumnLayout {
    id: grp

    property string title: ""
    property var    meta: []      // LayoutMeta.systemSections() / batteryBlocks() / columns()
    property string json: ""      // the current cfg_* string
    property string lang: "en"
    signal changed(string newJson)

    function tr(s) { return I18n.tr(grp.lang, s) }
    readonly property var items: LayoutMeta.parseOrder(grp.json, grp.meta)
    function _label(id) {
        for (var i = 0; i < grp.meta.length; i++)
            if (grp.meta[i].id === id) return grp.tr(grp.meta[i].label)
        return id
    }

    spacing: Kirigami.Units.smallSpacing
    Layout.fillWidth: true

    Kirigami.Heading {
        level: 4
        text: grp.title
        visible: grp.title.length > 0
        Layout.topMargin: Kirigami.Units.smallSpacing
    }

    Repeater {
        model: grp.items
        delegate: RowLayout {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            QQC2.Label { text: "☰"; opacity: 0.4 }
            QQC2.CheckBox {
                text: grp._label(modelData.id)
                checked: modelData.v
                Layout.fillWidth: true
                onToggled: {
                    var a = grp.items.slice()
                    a[index] = { id: modelData.id, v: checked }
                    grp.changed(LayoutMeta.serialize(a))
                }
            }
            QQC2.ToolButton {
                icon.name: "go-up"; enabled: index > 0
                onClicked: {
                    var a = grp.items.slice(), t = a[index]
                    a[index] = a[index - 1]; a[index - 1] = t
                    grp.changed(LayoutMeta.serialize(a))
                }
            }
            QQC2.ToolButton {
                icon.name: "go-down"; enabled: index < grp.items.length - 1
                onClicked: {
                    var a = grp.items.slice(), t = a[index]
                    a[index] = a[index + 1]; a[index + 1] = t
                    grp.changed(LayoutMeta.serialize(a))
                }
            }
        }
    }
}
