// MonitorView.qml — full representation: the system / battery / controls columns
// in a responsive grid (side by side when there is room, wrapped and scrollable
// when not), an update banner, and a pin button (top-right). Section visibility,
// styles and detail toggles come from Plasmoid.configuration.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.plasmoid
import "i18n.js" as I18n
import "layoutmeta.js" as LayoutMeta

Item {
    id: view
    property var battery
    property var system
    property var control
    property string lang: "en"
    property bool pinned: false
    signal setProfile(string name)
    signal togglePin()
    signal setScreenBrightness(real raw)
    signal setKbdBrightness(real val)
    signal setVolume(real frac)
    signal toggleMute()
    signal setInhibit(bool on)
    signal openSystemSettings()
    signal openSystemMonitor()
    signal openWidgetSettings()
    function tr(s) { return I18n.tr(view.lang, s) }

    // The battery column hides itself on machines without a battery.
    readonly property bool _noBattery: view.battery !== null && view.battery !== undefined
        && view.battery.probed === true && view.battery.present !== true
    readonly property var _colOrder: {
        var o = LayoutMeta.parseOrder(Plasmoid.configuration.columnOrder, LayoutMeta.columns())
        if (view._noBattery)
            for (var i = 0; i < o.length; i++) if (o[i].id === "battery") o[i].v = false
        return o
    }
    function _colVisible(id) {
        for (var i = 0; i < _colOrder.length; i++) if (_colOrder[i].id === id) return _colOrder[i].v;
        return false;
    }
    readonly property bool _showSystem: _colVisible("system")
    readonly property bool _showBattery: _colVisible("battery")
    readonly property bool _showControls: _colVisible("controls")
    readonly property int _cols: (_showSystem ? 1 : 0) + (_showBattery ? 1 : 0) + (_showControls ? 1 : 0)

    // ---- responsive layout ----
    // Each column needs a minimum width. As many columns as fit sit side by side;
    // the rest wrap below, and whatever does not fit vertically scrolls. So the
    // view works from a narrow one-column strip up to the full three-column popup.
    readonly property real _colMinGu: 13
    readonly property real _gap: Kirigami.Units.largeSpacing * 2 + 1      // spacing + separator
    readonly property var _visibleCols: _colOrder.filter(function (c) { return c.v })
    readonly property int _perRow: Math.max(1, Math.min(_cols,
        Math.floor((view.width + _gap) / (Kirigami.Units.gridUnit * _colMinGu + _gap))))
    readonly property bool scrollable: flick.contentHeight > flick.height + 1

    Layout.minimumWidth: Kirigami.Units.gridUnit * _colMinGu
    Layout.minimumHeight: Kirigami.Units.gridUnit * 9
    // preferred = everything side by side, tall enough to show the tallest column
    // (several GPUs, labelled fans, …) — capped so it never outgrows a small screen.
    // A size the user dragged manually still wins.
    Layout.preferredWidth: Kirigami.Units.gridUnit * (Math.max(1, _cols) * (_colMinGu + 3)) + Math.max(0, _cols - 1) * _gap
    Layout.preferredHeight: Math.min(Kirigami.Units.gridUnit * 45,
        Math.max(Kirigami.Units.gridUnit * 20, grid.implicitHeight + banner.height + Kirigami.Units.smallSpacing))

    readonly property var _colMap: ({"system": systemCol, "battery": batteryCol, "controls": controlsCol})

    // The pin button floats in the top-right corner. Only the controls column has
    // free room there; with any other column in that spot, reserve a strip.
    readonly property bool _pinNeedsStrip: _visibleCols.length > 0
        && _visibleCols[Math.min(_perRow, _visibleCols.length) - 1].id !== "controls"

    // ---- update banner ----
    property bool updateVisible: false
    property string updatePhase: ""       // "" | busy | done | failed
    property string updateLocal: ""
    property string updateRemote: ""
    property int updateCount: 0
    property string updateSubject: ""
    property string updateMessage: ""
    property bool updateNeedsRoot: false
    signal applyUpdate()
    signal dismissUpdate()
    signal restartShell()

    Rectangle {
        id: banner
        visible: view.updateVisible
        anchors { top: parent.top; left: parent.left; right: parent.right
                  rightMargin: pinBtn.width + pinBtn.anchors.rightMargin + Kirigami.Units.smallSpacing }
        height: visible ? bannerRow.implicitHeight + Kirigami.Units.smallSpacing * 2 : 0
        radius: Kirigami.Units.cornerRadius
        color: {
            var c = view.updatePhase === "failed" ? Kirigami.Theme.negativeTextColor
                  : view.updatePhase === "done" ? Kirigami.Theme.positiveTextColor
                  : Kirigami.Theme.highlightColor
            return Qt.rgba(c.r, c.g, c.b, 0.18)
        }
        RowLayout {
            id: bannerRow
            anchors { fill: parent; margins: Kirigami.Units.smallSpacing; leftMargin: Kirigami.Units.largeSpacing }
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: view.updatePhase === "failed" ? "dialog-warning"
                      : view.updatePhase === "done" ? "emblem-ok-symbolic" : "update-none"
                implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: Kirigami.Units.iconSizes.small
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PC3.Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.bold: true
                    text: view.updatePhase === "busy" ? view.tr("Updating…")
                        : view.updatePhase === "done" ? view.tr("Updated — restart Plasma to load the new version")
                        : view.updatePhase === "failed" ? view.tr("Update failed")
                        : view.tr("Update available") + (view.updateLocal && view.updateRemote
                            ? "  " + view.updateLocal + " → " + view.updateRemote : "")
                }
                PC3.Label {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    elide: Text.ElideRight
                    opacity: 0.75
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    text: view.updatePhase === "failed" ? view.updateMessage
                        : view.updatePhase === "done"
                            ? (view.updateNeedsRoot ? view.tr("Root-side files changed too: run ./install.sh once in a terminal") : "")
                        : view.updatePhase === "busy" ? ""
                        : view.updateSubject
                }
            }
            PC3.BusyIndicator {
                visible: view.updatePhase === "busy"
                running: visible
                implicitWidth: Kirigami.Units.iconSizes.smallMedium; implicitHeight: Kirigami.Units.iconSizes.smallMedium
            }
            PC3.Button {
                visible: view.updatePhase === ""
                text: view.tr("Update")
                icon.name: "download"
                onClicked: view.applyUpdate()
            }
            PC3.Button {
                visible: view.updatePhase === "done"
                text: view.tr("Restart Plasma")
                icon.name: "view-refresh"
                onClicked: view.restartShell()
            }
            PC3.ToolButton {
                visible: view.updatePhase === "done" || view.updatePhase === "failed"
                icon.name: "dialog-close"
                display: PC3.AbstractButton.IconOnly
                onClicked: view.dismissUpdate()
            }
        }
    }

    PC3.ScrollView {
        id: scroll
        anchors {
            fill: parent
            topMargin: banner.visible ? banner.height + Kirigami.Units.smallSpacing
                     : (view._pinNeedsStrip ? pinBtn.height * 0.8 : 0)
        }
        PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff

        Flickable {
            id: flick
            clip: true
            contentWidth: width
            contentHeight: grid.height
            boundsBehavior: Flickable.StopAtBounds

            GridLayout {
                id: grid
                width: flick.width
                // at least the viewport: side-by-side columns stretch to full height
                height: Math.max(implicitHeight, flick.height)
                columns: view._perRow
                columnSpacing: view._gap
                rowSpacing: view._gap

                Repeater {
                    model: view._visibleCols
                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property int colIdx: cell.index % view._perRow
                        readonly property int rowIdx: Math.floor(cell.index / view._perRow)
                        readonly property bool last: cell.index === view._visibleCols.length - 1
                        // the battery card brings its own inner margin
                        readonly property real pad: cell.modelData.id === "battery" ? 0 : Kirigami.Units.gridUnit * 0.75

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        // a lone last column takes the rest of its row
                        Layout.columnSpan: cell.last ? view._perRow - cell.colIdx : 1
                        Layout.minimumWidth: Math.min(Kirigami.Units.gridUnit * view._colMinGu, flick.width)
                        Layout.preferredWidth: Kirigami.Units.gridUnit * view._colMinGu
                        implicitHeight: cellLoader.implicitHeight + cell.pad * 2

                        Loader {
                            id: cellLoader
                            anchors.fill: parent
                            anchors.margins: cell.pad
                            sourceComponent: view._colMap[cell.modelData.id]
                        }
                        Kirigami.Separator {       // between columns
                            visible: cell.colIdx > 0
                            x: -Math.round(view._gap / 2)
                            y: Kirigami.Units.gridUnit
                            width: 1
                            height: parent.height - Kirigami.Units.gridUnit * 2
                        }
                        Kirigami.Separator {       // between wrapped rows
                            visible: cell.rowIdx > 0
                            y: -Math.round(view._gap / 2)
                            width: parent.width
                            height: 1
                        }
                    }
                }
            }
        }
    }

    Component {
        id: systemCol
        SystemColumn {
            clip: true
            lang: view.lang
            system: view.system
            layoutJson: Plasmoid.configuration.systemLayout
            showSmart:       Plasmoid.configuration.showSmart
            showTemps:       Plasmoid.configuration.showTemps
            showPower:       Plasmoid.configuration.showPower
            showVoltage:     Plasmoid.configuration.showVoltage
            showDiskSensor1: Plasmoid.configuration.showDiskSensor1
            cpuCoresLogical: Plasmoid.configuration.cpuCoresLogical
            cpuStyle:        Plasmoid.configuration.cpuStyle
            gpuStyle:        Plasmoid.configuration.gpuStyle
            vramStyle:       Plasmoid.configuration.vramStyle
            ramStyle:        Plasmoid.configuration.ramStyle
            diskStyle:       Plasmoid.configuration.diskStyle
            netStyle:        Plasmoid.configuration.netStyle
            onSetProfile: function(name) { view.setProfile(name) }
        }
    }

    Component {
        id: batteryCol
        BatteryCard {
            clip: true
            lang: view.lang
            battery: view.battery
            layoutJson: Plasmoid.configuration.batteryLayout
        }
    }

    Component {
        id: controlsCol
        ControlColumn {
            clip: true
            lang: view.lang
            control: view.control
            inScroll: view.scrollable
            showInhibit:          Plasmoid.configuration.showInhibit
            showScreenBrightness: Plasmoid.configuration.showScreenBrightness
            showKbdBrightness:    Plasmoid.configuration.showKbdBrightness
            showVolume:           Plasmoid.configuration.showVolume
            onSetScreenBrightness: function(raw) { view.setScreenBrightness(raw) }
            onSetKbdBrightness: function(val) { view.setKbdBrightness(val) }
            onSetVolume: function(frac) { view.setVolume(frac) }
            onToggleMute: view.toggleMute()
            onSetInhibit: function(on) { view.setInhibit(on) }
            onOpenSystemSettings: view.openSystemSettings()
            onOpenSystemMonitor: view.openSystemMonitor()
            onOpenWidgetSettings: view.openWidgetSettings()
        }
    }

    PC3.ToolButton {
        id: pinBtn
        anchors.top: parent.top
        anchors.right: parent.right
        // stay clear of the scrollbar while the view scrolls
        anchors.rightMargin: view.scrollable ? scroll.PC3.ScrollBar.vertical.width : 0
        icon.name: view.pinned ? "window-unpin" : "window-pin"
        checkable: true
        checked: view.pinned
        flat: true
        display: PC3.AbstractButton.IconOnly
        opacity: hovered || view.pinned ? 1 : 0.4
        PC3.ToolTip.text: view.pinned ? view.tr("Pinned — stays open") : view.tr("Pin")
        PC3.ToolTip.visible: hovered
        PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
        onClicked: view.togglePin()
    }
}
