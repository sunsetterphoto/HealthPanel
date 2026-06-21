// Compact representation — shown in a panel or as a small desktop icon.
// Default: a single battery icon that also encodes the power profile (leaf for
// power-saver, plain for balanced, overlay for performance), plus the charge %.
// Reports its size via Layout.* so the panel grants room for the label.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

MouseArea {
    id: compact
    property var battery
    property var system
    signal toggleExpanded()

    readonly property bool _ready: compact.battery !== null && compact.battery !== undefined
    readonly property bool _ok: _ready && compact.battery.present === true
    readonly property bool _hasProfile: compact.system !== null && compact.system !== undefined
        && compact.system.hasPowerProfile === true
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
                // KDE combines charge level + power profile into one icon:
                // battery-<000..100>-[charging-]profile-<powersave|balanced|performance>
                if (compact._hasProfile) {
                    var lvl = Math.max(0, Math.min(100, Math.round(c / 10) * 10))
                    var lll = ("00" + lvl).slice(-3)
                    var p = compact.system.powerProfile
                    var mode = p === "performance" ? "performance"
                             : (p === "power-saver" ? "powersave" : "balanced")
                    return "battery-" + lll + (charging ? "-charging" : "") + "-profile-" + mode
                }
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
    }
}
