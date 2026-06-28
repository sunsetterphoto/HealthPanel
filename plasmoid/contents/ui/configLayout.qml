import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layoutmeta.js" as LayoutMeta
import "i18n.js" as I18n

ColumnLayout {
    id: page
    property string cfg_systemLayout: ""
    property string cfg_systemLayoutDefault: ""
    property string cfg_batteryLayout: ""
    property string cfg_batteryLayoutDefault: ""
    property string cfg_columnOrder: ""
    property string cfg_columnOrderDefault: ""
    property string cfg_language: "system"
    function tr(s) { return I18n.tr(I18n.resolve(page.cfg_language), s) }
    function labelFor(meta, id) {
        for (var i = 0; i < meta.length; i++) if (meta[i].id === id) return page.tr(meta[i].label)
        return id
    }
    spacing: Kirigami.Units.largeSpacing

    Kirigami.Heading { level: 3; text: page.tr("Layout") }
    QQC2.Label {
        Layout.fillWidth: true; wrapMode: Text.WordWrap; opacity: 0.7
        text: page.tr("Reorder and show/hide the parts of the expanded view. Use ↑ ↓ to move.")
    }

    // one group: a Heading + a Repeater of rows editing one config string
    component Group : ColumnLayout {
        id: grp
        property string title: ""
        property var meta: []
        property string json: ""
        signal changed(string newJson)
        readonly property var items: LayoutMeta.parseOrder(grp.json, grp.meta)
        Layout.fillWidth: true
        Kirigami.Heading { level: 4; text: grp.title; Layout.topMargin: Kirigami.Units.smallSpacing }
        Repeater {
            model: grp.items
            delegate: RowLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                QQC2.Label { text: "≡"; opacity: 0.4 }
                QQC2.CheckBox {
                    text: page.labelFor(grp.meta, modelData.id)
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
                    onClicked: { var a = grp.items.slice(); var t = a[index]; a[index] = a[index-1]; a[index-1] = t; grp.changed(LayoutMeta.serialize(a)) }
                }
                QQC2.ToolButton {
                    icon.name: "go-down"; enabled: index < grp.items.length - 1
                    onClicked: { var a = grp.items.slice(); var t = a[index]; a[index] = a[index+1]; a[index+1] = t; grp.changed(LayoutMeta.serialize(a)) }
                }
            }
        }
    }

    Group { title: page.tr("System column"); meta: LayoutMeta.systemSections(); json: page.cfg_systemLayout; onChanged: page.cfg_systemLayout = newJson }
    Group { title: page.tr("Battery column"); meta: LayoutMeta.batteryBlocks(); json: page.cfg_batteryLayout; onChanged: page.cfg_batteryLayout = newJson }
    Group { title: page.tr("Columns"); meta: LayoutMeta.columns(); json: page.cfg_columnOrder; onChanged: page.cfg_columnOrder = newJson }

    QQC2.Button {
        text: page.tr("Reset to defaults")
        icon.name: "edit-reset"
        Layout.topMargin: Kirigami.Units.largeSpacing
        onClicked: {
            page.cfg_systemLayout = LayoutMeta.serialize(LayoutMeta.defaultOrder(LayoutMeta.systemSections()))
            page.cfg_batteryLayout = LayoutMeta.serialize(LayoutMeta.defaultOrder(LayoutMeta.batteryBlocks()))
            page.cfg_columnOrder = LayoutMeta.serialize(LayoutMeta.defaultOrder(LayoutMeta.columns()))
        }
    }
    Item { Layout.fillHeight: true }
}
