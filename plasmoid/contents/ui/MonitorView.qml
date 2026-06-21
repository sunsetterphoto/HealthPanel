// MonitorView.qml — full representation: system load (left) │ battery (middle) │
// quick controls (right), with a pin button (top-right). Section visibility,
// styles and detail toggles come from Plasmoid.configuration.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.plasmoid

Item {
    id: view
    property var battery
    property var system
    property var control
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

    readonly property bool _showSystem: Plasmoid.configuration.showSystemColumn
    readonly property bool _showBattery: Plasmoid.configuration.showBatteryColumn
    readonly property bool _showControls: Plasmoid.configuration.showControls
    readonly property int _cols: (_showSystem ? 1 : 0) + (_showBattery ? 1 : 0) + (_showControls ? 1 : 0)

    Layout.minimumWidth: Kirigami.Units.gridUnit * Math.max(13, _cols * 13)
    Layout.minimumHeight: Kirigami.Units.gridUnit * 17
    Layout.preferredWidth: Kirigami.Units.gridUnit * Math.max(15, _cols * 15)
    Layout.preferredHeight: Kirigami.Units.gridUnit * 20

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        SystemColumn {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 13
            Layout.margins: Kirigami.Units.gridUnit * 0.75
            visible: view._showSystem
            system: view.system
            showPowerMode: Plasmoid.configuration.showPowerMode
            showCpu:       Plasmoid.configuration.showCpu
            showRam:       Plasmoid.configuration.showRam
            showDisk:      Plasmoid.configuration.showDisk
            showNet:       Plasmoid.configuration.showNet
            showSmart:     Plasmoid.configuration.showSmart
            showTemps:     Plasmoid.configuration.showTemps
            showGpu:       Plasmoid.configuration.showGpu
            cpuCoresLogical: Plasmoid.configuration.cpuCoresLogical
            cpuStyle:      Plasmoid.configuration.cpuStyle
            gpuStyle:      Plasmoid.configuration.gpuStyle
            vramStyle:     Plasmoid.configuration.vramStyle
            ramStyle:      Plasmoid.configuration.ramStyle
            diskStyle:     Plasmoid.configuration.diskStyle
            netStyle:      Plasmoid.configuration.netStyle
            onSetProfile: function(name) { view.setProfile(name) }
        }

        Kirigami.Separator {
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.gridUnit
            Layout.bottomMargin: Kirigami.Units.gridUnit
            visible: view._showSystem && (view._showBattery || view._showControls)
        }

        BatteryCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 13
            visible: view._showBattery
            battery: view.battery
            showCycles:      Plasmoid.configuration.showBatCycles
            showCapacity:    Plasmoid.configuration.showBatCapacity
            showLive:        Plasmoid.configuration.showBatLive
            showSerial:      Plasmoid.configuration.showBatSerial
            showChargeLimit: Plasmoid.configuration.showBatChargeLimit
            showTime:        Plasmoid.configuration.showBatTime
        }

        Kirigami.Separator {
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.gridUnit
            Layout.bottomMargin: Kirigami.Units.gridUnit
            visible: view._showBattery && view._showControls
        }

        ControlColumn {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 11
            Layout.margins: Kirigami.Units.gridUnit * 0.75
            visible: view._showControls
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
        PC3.ToolTip.text: view.pinned ? i18n("Angeheftet — bleibt offen") : i18n("Anheften")
        PC3.ToolTip.visible: hovered
        PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
        onClicked: view.togglePin()
    }
}
