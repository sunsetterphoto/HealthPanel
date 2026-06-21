import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "panelmeta.js" as PanelMeta

ColumnLayout {
    id: page

    property string cfg_panelLayout: '[{"type":"battery","texts":["charge"]}]'
    property string cfg_panelLayoutDefault: '[{"type":"battery","texts":["charge"]}]'

    // working copy of the icon list; commit() writes it back to the config string
    property var items: PanelMeta.parseLayout(cfg_panelLayout)
    readonly property var typeList: PanelMeta.types()

    function commit(a) { items = a; cfg_panelLayout = PanelMeta.serialize(a); }
    function typeIndex(t) { for (var i = 0; i < typeList.length; i++) if (typeList[i].type === t) return i; return 0; }

    spacing: Kirigami.Units.smallSpacing

    Kirigami.Heading { level: 3; text: i18n("Panel-Icons") }
    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: i18n("Lege fest, welche Icons in der Leiste / Kompaktansicht erscheinen und welche Werte als Text daneben stehen. Reihenfolge per ↑ ↓.")
    }

    Repeater {
        model: page.items
        delegate: Kirigami.AbstractCard {
            id: iconCard
            required property var modelData
            required property int index
            readonly property string cfgType: modelData.type
            readonly property var cfgTexts: modelData.texts || []
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing

            contentItem: ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    QQC2.Label { text: i18n("Icon:") }
                    QQC2.ComboBox {
                        id: typeBox
                        textRole: "label"
                        valueRole: "type"
                        model: page.typeList
                        currentIndex: page.typeIndex(iconCard.cfgType)
                        onActivated: {
                            var a = page.items.slice()
                            a[iconCard.index] = { type: currentValue, texts: [] }
                            page.commit(a)
                        }
                    }
                    Item { Layout.fillWidth: true }
                    QQC2.ToolButton {
                        icon.name: "go-up"; enabled: iconCard.index > 0
                        onClicked: {
                            var a = page.items.slice(), t = a[iconCard.index]
                            a[iconCard.index] = a[iconCard.index - 1]; a[iconCard.index - 1] = t
                            page.commit(a)
                        }
                    }
                    QQC2.ToolButton {
                        icon.name: "go-down"; enabled: iconCard.index < page.items.length - 1
                        onClicked: {
                            var a = page.items.slice(), t = a[iconCard.index]
                            a[iconCard.index] = a[iconCard.index + 1]; a[iconCard.index + 1] = t
                            page.commit(a)
                        }
                    }
                    QQC2.ToolButton {
                        icon.name: "list-remove"; enabled: page.items.length > 1
                        onClicked: {
                            var a = page.items.slice(); a.splice(iconCard.index, 1); page.commit(a)
                        }
                    }
                }

                QQC2.Label {
                    text: i18n("Text daneben:")
                    opacity: 0.7
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: PanelMeta.typeMeta(iconCard.cfgType).texts
                        delegate: QQC2.Button {
                            required property var modelData
                            text: modelData.l
                            checkable: true
                            checked: iconCard.cfgTexts.indexOf(modelData.k) >= 0
                            onClicked: {
                                var a = page.items.slice()
                                var texts = (a[iconCard.index].texts || []).slice()
                                var pos = texts.indexOf(modelData.k)
                                if (pos >= 0) texts.splice(pos, 1); else texts.push(modelData.k)
                                a[iconCard.index] = { type: iconCard.cfgType, texts: texts }
                                page.commit(a)
                            }
                        }
                    }
                }
            }
        }
    }

    QQC2.Button {
        text: i18n("Icon hinzufügen")
        icon.name: "list-add"
        Layout.topMargin: Kirigami.Units.smallSpacing
        onClicked: {
            var a = page.items.slice()
            a.push({ type: "cpu", texts: ["load"] })
            page.commit(a)
        }
    }

    Item { Layout.fillHeight: true }
}
