// Compact representation — used when widget lives in a panel.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

MouseArea {
    id: compact
    property var battery
    signal clicked()

    implicitWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
    implicitHeight: row.implicitHeight

    hoverEnabled: true
    onClicked: compact.clicked()

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: {
                if (!battery.present) return "battery-missing"
                var c = battery.capacityPct
                var charging = battery.status === "Charging"
                if (c >= 95) return charging ? "battery-full-charging" : "battery-full"
                if (c >= 60) return charging ? "battery-good-charging" : "battery-good"
                if (c >= 30) return charging ? "battery-low-charging"  : "battery-low"
                return charging ? "battery-caution-charging" : "battery-caution"
            }
            implicitWidth:  Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
        }

        PC3.Label {
            text: battery.present ? battery.capacityPct + "%" : "—"
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
        }

        PC3.Label {
            text: battery.present ? "· " + battery.fmtPct(battery.healthPct, 0) : ""
            opacity: 0.7
            visible: battery.present
        }
    }
}
