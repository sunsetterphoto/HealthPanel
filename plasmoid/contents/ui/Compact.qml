// Compact representation — used when widget lives in a panel.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

MouseArea {
    id: compact
    property var battery
    signal clicked()

    readonly property bool _ready: compact.battery !== null && compact.battery !== undefined
    readonly property bool _ok: _ready && compact.battery.present === true

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
                if (!compact._ok) return "battery-missing"
                var c = compact.battery.capacityPct
                var charging = compact.battery.status === "Charging"
                if (c >= 95) return charging ? "battery-full-charging" : "battery-full"
                if (c >= 60) return charging ? "battery-good-charging" : "battery-good"
                if (c >= 30) return charging ? "battery-low-charging"  : "battery-low"
                return charging ? "battery-caution-charging" : "battery-caution"
            }
            implicitWidth:  Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
        }

        PC3.Label {
            text: compact._ok ? compact.battery.capacityPct + "%" : "—"
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
        }

        PC3.Label {
            text: compact._ok ? "· " + compact.battery.fmtPct(compact.battery.healthPct, 0) : ""
            opacity: 0.7
            visible: compact._ok
        }
    }
}
