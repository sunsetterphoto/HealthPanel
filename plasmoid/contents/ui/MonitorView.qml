// MonitorView.qml — full representation: system column │ separator │ battery card.
// Section visibility comes from Plasmoid.configuration; sizing is responsive
// (both columns fill available width, with minimums that keep all text readable).
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

RowLayout {
    id: view
    property var battery
    property var system
    signal setProfile(string name)

    Layout.minimumWidth: Kirigami.Units.gridUnit * 28
    Layout.minimumHeight: Kirigami.Units.gridUnit * 17
    Layout.preferredWidth: Kirigami.Units.gridUnit * 31
    Layout.preferredHeight: Kirigami.Units.gridUnit * 20
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
    }
}
