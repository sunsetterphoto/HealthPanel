// MonitorView.qml — full representation: system column │ separator │ battery card,
// with a pin button (top-right) to keep the popup open. Section visibility, styles
// and battery-detail visibility come from Plasmoid.configuration; sizing is
// responsive (both columns fill width).
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
    property bool pinned: false
    signal setProfile(string name)
    signal togglePin()

    Layout.minimumWidth: Kirigami.Units.gridUnit * 28
    Layout.minimumHeight: Kirigami.Units.gridUnit * 17
    Layout.preferredWidth: Kirigami.Units.gridUnit * 31
    Layout.preferredHeight: Kirigami.Units.gridUnit * 20

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        SystemColumn {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 13
            Layout.margins: Kirigami.Units.gridUnit * 0.75
            system: view.system
            showPowerMode: Plasmoid.configuration.showPowerMode
            showCpu:       Plasmoid.configuration.showCpu
            showRam:       Plasmoid.configuration.showRam
            showDisk:      Plasmoid.configuration.showDisk
            showNet:       Plasmoid.configuration.showNet
            showSmart:     Plasmoid.configuration.showSmart
            showTemps:     Plasmoid.configuration.showTemps
            cpuCoresLogical: Plasmoid.configuration.cpuCoresLogical
            cpuStyle:      Plasmoid.configuration.cpuStyle
            ramStyle:      Plasmoid.configuration.ramStyle
            diskStyle:     Plasmoid.configuration.diskStyle
            netStyle:      Plasmoid.configuration.netStyle
            onSetProfile: function(name) { view.setProfile(name) }
        }

        Kirigami.Separator {
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.gridUnit
            Layout.bottomMargin: Kirigami.Units.gridUnit
        }

        BatteryCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 13
            battery: view.battery
            showCycles:      Plasmoid.configuration.showBatCycles
            showCapacity:    Plasmoid.configuration.showBatCapacity
            showLive:        Plasmoid.configuration.showBatLive
            showSerial:      Plasmoid.configuration.showBatSerial
            showChargeLimit: Plasmoid.configuration.showBatChargeLimit
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
