// BatteryCard — full representation, shown on the desktop or in popup.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

Item {
    id: card
    property var battery

    Layout.preferredWidth:  Kirigami.Units.gridUnit * 18
    Layout.preferredHeight: contentColumn.implicitHeight + Kirigami.Units.gridUnit * 1.5

    // --- error / no-battery state ---
    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 2
        visible: !battery.present
        iconName: "battery-missing"
        text: "Kein Akku gefunden"
        explanation: battery.error || "Stelle sicher, dass /sys/class/power_supply/BAT0 existiert."
    }

    ColumnLayout {
        id: contentColumn
        visible: battery.present
        anchors.fill: parent
        anchors.margins: Kirigami.Units.gridUnit * 0.75
        spacing: Kirigami.Units.smallSpacing

        // --- Header ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "battery"
                implicitWidth:  Kirigami.Units.iconSizes.medium
                implicitHeight: Kirigami.Units.iconSizes.medium
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PC3.Label {
                    text: battery.manufacturer + " " + battery.model
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PC3.Label {
                    text: "BAT0 · " + battery.technology
                    opacity: 0.7
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

        // --- Health (the headline) ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                PC3.Label { text: "Health"; opacity: 0.8 }
                Item { Layout.fillWidth: true }
                PC3.Label {
                    text: battery.fmtPct(battery.healthPct)
                    color: battery.healthColor()
                    font.bold: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.08)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, battery.healthPct / 100))
                    height: parent.height
                    radius: 3
                    color: battery.healthColor()
                    Behavior on width { NumberAnimation { duration: 400 } }
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

        // --- Capacity grid ---
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: 2

            PC3.Label { text: "Cycles"; opacity: 0.8 }
            PC3.Label { text: battery.cycleCount; Layout.alignment: Qt.AlignRight }

            PC3.Label { text: "Designed"; opacity: 0.8 }
            PC3.Label { text: battery.fmtWh(battery.energyFullDesignWh); Layout.alignment: Qt.AlignRight }

            PC3.Label { text: "Full (now)"; opacity: 0.8 }
            PC3.Label { text: battery.fmtWh(battery.energyFullWh); Layout.alignment: Qt.AlignRight }

            PC3.Label { text: "Remaining"; opacity: 0.8 }
            PC3.Label {
                text: battery.fmtWh(battery.energyNowWh) + "  (" + battery.capacityPct + "%)"
                Layout.alignment: Qt.AlignRight
            }
        }

        Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

        // --- Live ---
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: 2

            PC3.Label { text: "Status"; opacity: 0.8 }
            PC3.Label {
                text: battery.statusGlyph() + " " + (battery.status || "—")
                Layout.alignment: Qt.AlignRight
            }

            PC3.Label { text: "Power draw"; opacity: 0.8 }
            PC3.Label { text: battery.fmtW(battery.powerNowW); Layout.alignment: Qt.AlignRight }

            PC3.Label { text: "Voltage"; opacity: 0.8 }
            PC3.Label {
                text: battery.fmtV(battery.voltageNowV) + "  (min " + battery.fmtV(battery.voltageMinDesignV) + ")"
                Layout.alignment: Qt.AlignRight
            }

            PC3.Label { text: "Serial"; opacity: 0.8 }
            PC3.Label { text: battery.serial || "n/a"; Layout.alignment: Qt.AlignRight }
        }

        // --- Lenovo ---
        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: battery.hasChargeThreshold
        }
        PC3.Label {
            visible: battery.hasChargeThreshold
            text: "Lenovo"
            opacity: 0.6
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
        GridLayout {
            visible: battery.hasChargeThreshold
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: 2

            PC3.Label { text: "Charge limit"; opacity: 0.8 }
            PC3.Label {
                text: battery.chargeStart + "% – " + battery.chargeEnd + "%"
                Layout.alignment: Qt.AlignRight
            }

            PC3.Label { text: "Charge mode"; opacity: 0.8 }
            PC3.Label { text: battery.chargeBehaviour || "auto"; Layout.alignment: Qt.AlignRight }
        }

        Item { Layout.fillHeight: true }
    }
}
