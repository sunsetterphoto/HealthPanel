// MonitorView.qml — full representation: system load (left) │ battery (middle) │
// quick controls (right), with a pin button (top-right). Section visibility,
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

    readonly property var _colOrder: LayoutMeta.parseOrder(Plasmoid.configuration.columnOrder, LayoutMeta.columns())
    function _colVisible(id) {
        for (var i = 0; i < _colOrder.length; i++) if (_colOrder[i].id === id) return _colOrder[i].v;
        return false;
    }
    readonly property bool _showSystem: _colVisible("system")
    readonly property bool _showBattery: _colVisible("battery")
    readonly property bool _showControls: _colVisible("controls")
    readonly property int _cols: (_showSystem ? 1 : 0) + (_showBattery ? 1 : 0) + (_showControls ? 1 : 0)

    // Per-column minimum widths (grid units). The widget's resize floor is the sum of
    // the *visible* columns plus the gap a separator+spacing eats between each pair, so
    // the minimum always fits the real content and columns can never be squeezed into
    // one another. Keep these in sync with the per-column Layout.minimumWidth values on
    // the column items below.
    readonly property real _sysMinGu: 13
    readonly property real _batMinGu: 13
    readonly property real _ctlMinGu: 11
    readonly property real _gapGu: 2.5   // largeSpacing + separator + largeSpacing per column boundary

    readonly property real _contentMinGu:
        (_showSystem ? _sysMinGu : 0) +
        (_showBattery ? _batMinGu : 0) +
        (_showControls ? _ctlMinGu : 0) +
        Math.max(0, _cols - 1) * _gapGu

    Layout.minimumWidth: Kirigami.Units.gridUnit * Math.max(_ctlMinGu, _contentMinGu)
    Layout.minimumHeight: Kirigami.Units.gridUnit * 17
    Layout.preferredWidth: Kirigami.Units.gridUnit * Math.max(15, _contentMinGu + _cols * 2)
    Layout.preferredHeight: Kirigami.Units.gridUnit * 20

    readonly property var _colMap: ({"system": systemCol, "battery": batteryCol, "controls": controlsCol})

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing
        Repeater {
            model: view._colOrder
            delegate: RowLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: modelData.v
                Layout.fillHeight: true
                visible: modelData.v
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Separator {
                    Layout.fillHeight: true
                    Layout.topMargin: Kirigami.Units.gridUnit
                    Layout.bottomMargin: Kirigami.Units.gridUnit
                    visible: { for (var i = 0; i < index; i++) if (view._colOrder[i].v) return true; return false }
                }
                Loader { Layout.fillWidth: true; Layout.fillHeight: true; sourceComponent: view._colMap[modelData.id] }
            }
        }
    }

    Component {
        id: systemCol
        SystemColumn {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 13
            Layout.margins: Kirigami.Units.gridUnit * 0.75
            clip: true
            visible: view._showSystem
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
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 13
            clip: true
            visible: view._showBattery
            lang: view.lang
            battery: view.battery
            layoutJson: Plasmoid.configuration.batteryLayout
        }
    }

    Component {
        id: controlsCol
        ControlColumn {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 11
            Layout.margins: Kirigami.Units.gridUnit * 0.75
            clip: true
            visible: view._showControls
            lang: view.lang
            control: view.control
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
        anchors.top: parent.top
        anchors.right: parent.right
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
