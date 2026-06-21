// Compact representation — shown when the widget lives in a panel or as a small
// desktop icon. Reports its size via Layout.* so the panel grants room for the
// label (a bare MouseArea would otherwise be squeezed to an icon-only square).
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

MouseArea {
    id: compact
    property var battery
    signal toggleExpanded()

    readonly property bool _ready: compact.battery !== null && compact.battery !== undefined
    readonly property bool _ok: _ready && compact.battery.present === true
    // vertical panel → stack icon over text; horizontal panel / desktop → side by side
    readonly property bool _vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    implicitWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
    implicitHeight: Math.max(row.implicitHeight, Kirigami.Units.iconSizes.small)
    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth

    hoverEnabled: true
    onClicked: compact.toggleExpanded()

    GridLayout {
        id: row
        anchors.centerIn: parent
        flow: compact._vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 0
        columnSpacing: Kirigami.Units.smallSpacing

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
            Layout.alignment: Qt.AlignCenter
            implicitWidth:  Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
        }

        PC3.Label {
            text: compact._ok ? compact.battery.capacityPct + "%" : "—"
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            Layout.alignment: Qt.AlignCenter
        }

        PC3.Label {
            text: compact._ok ? "· " + compact.battery.fmtPct(compact.battery.healthPct, 0) : ""
            opacity: 0.7
            visible: compact._ok && !compact._vertical
            Layout.alignment: Qt.AlignCenter
        }
    }
}
