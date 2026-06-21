// MonitorView.qml — full representation: system column │ separator │ battery card.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: view
    property var battery
    property var system
    signal setProfile(string name)

    Layout.preferredWidth: Kirigami.Units.gridUnit * 30
    Layout.preferredHeight: Kirigami.Units.gridUnit * 16
    spacing: Kirigami.Units.largeSpacing

    SystemColumn {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 13
        Layout.fillHeight: true
        Layout.margins: Kirigami.Units.gridUnit * 0.75
        system: view.system
        onSetProfile: function(name) { view.setProfile(name) }
    }

    Kirigami.Separator { Layout.fillHeight: true; Layout.topMargin: Kirigami.Units.gridUnit; Layout.bottomMargin: Kirigami.Units.gridUnit }

    BatteryCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        battery: view.battery
    }
}
