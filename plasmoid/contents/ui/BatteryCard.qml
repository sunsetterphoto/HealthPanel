// BatteryCard — full representation, shown on the desktop or in popup.
// Defensive: only evaluates content bindings once `battery` is actually bound
// (Plasmoid representations get instantiated with their own scope, and at
// load time `battery` may be undefined for a tick).
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import "i18n.js" as I18n
import "layoutmeta.js" as LayoutMeta

Item {
    id: card
    property var battery
    property string lang: "en"
    function tr(s) { return I18n.tr(card.lang, s) }

    // layout-driven order + visibility (bound to batteryLayout config in Task 6)
    property string layoutJson: ""
    readonly property var _order: LayoutMeta.parseOrder(card.layoutJson, LayoutMeta.batteryBlocks())

    Layout.preferredWidth:  Kirigami.Units.gridUnit * 18
    Layout.preferredHeight: contentLoader.active
        ? contentLoader.implicitHeight + Kirigami.Units.gridUnit * 1.5
        : Kirigami.Units.gridUnit * 8

    readonly property bool _ready: card.battery !== null && card.battery !== undefined
    readonly property bool _ok: _ready && card.battery.present === true

    // --- empty / loading state ---
    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 2
        visible: !card._ok
        iconName: "battery-missing"
        text: card._ready ? card.tr("no battery found") : "…"
        explanation: card._ready && card.battery.error
            ? card.battery.error
            : ""
    }

    // ---- Block Components ----

    Component {
        id: cyclesBlock
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: 2
            PC3.Label { text: card.tr("Cycles"); opacity: 0.8 }
            PC3.Label { text: card.battery.cycleCount; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
        }
    }

    Component {
        id: capacityBlock
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: 2
            PC3.Label { text: card.tr("Designed"); opacity: 0.8 }
            PC3.Label { text: card.battery.fmtWh(card.battery.energyFullDesignWh); Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
            PC3.Label { text: card.tr("Full (now)"); opacity: 0.8 }
            PC3.Label { text: card.battery.fmtWh(card.battery.energyFullWh); Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
            PC3.Label { text: card.tr("Remaining"); opacity: 0.8 }
            PC3.Label {
                text: card.battery.fmtWh(card.battery.energyNowWh) + "  (" + card.battery.capacityPct + "%)"
                Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
            }
        }
    }

    Component {
        id: statusBlock
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: 2
            PC3.Label { text: card.tr("Status"); opacity: 0.8 }
            PC3.Label {
                text: card.battery.statusGlyph() + " " + (card.battery.status || "—")
                Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
            }
        }
    }

    Component {
        id: powerBlock
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: 2
            PC3.Label { text: card.tr("Power draw"); opacity: 0.8 }
            PC3.Label { text: card.battery.hasPowerNow ? card.battery.fmtW(card.battery.powerNowW) : "n/a"; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
        }
    }

    Component {
        id: voltageBlock
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: 2
            PC3.Label { text: card.tr("Voltage"); opacity: 0.8 }
            PC3.Label {
                text: card.battery.fmtV(card.battery.voltageNowV) + "  (" + card.tr("design min") + " " + card.battery.fmtV(card.battery.voltageMinDesignV) + ")"
                Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
            }
        }
    }

    Component {
        id: timeBlock
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: 2
            visible: card.battery.hasTimeRemaining
            PC3.Label { text: card.tr("Remaining time"); opacity: 0.8 }
            PC3.Label {
                text: card.battery.fmtDuration(card.battery.timeRemainingHours) + " " + (card.battery.status === "Charging" ? card.tr("to full") : card.tr("left"))
                Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
            }
        }
    }

    Component {
        id: serialBlock
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: 2
            PC3.Label { text: card.tr("Serial"); opacity: 0.8 }
            PC3.Label { text: card.battery.serial || "n/a"; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
        }
    }

    Component {
        id: chargeLimitBlock
        ColumnLayout {
            Layout.fillWidth: true
            visible: card.battery.hasChargeThreshold
            spacing: Kirigami.Units.smallSpacing
            PC3.Label {
                text: "Lenovo"
                opacity: 0.6
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: 2
                PC3.Label { text: card.tr("Charge limit"); opacity: 0.8 }
                PC3.Label {
                    text: card.battery.chargeStart + "% – " + card.battery.chargeEnd + "%"
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                }
                PC3.Label { text: card.tr("Charge mode"); opacity: 0.8 }
                PC3.Label { text: card.battery.chargeBehaviour || "auto"; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
            }
        }
    }

    // ---- id→component map (used by the Repeater in cardContent) ----
    readonly property var _blockMap: ({
        "cycles": cyclesBlock, "capacity": capacityBlock, "status": statusBlock,
        "power": powerBlock, "voltage": voltageBlock, "time": timeBlock,
        "serial": serialBlock, "chargeLimit": chargeLimitBlock
    })

    // --- real content (only mounted when battery is ready+present) ---
    Loader {
        id: contentLoader
        anchors.fill: parent
        active: card._ok
        sourceComponent: cardContent
    }

    Component {
        id: cardContent
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.gridUnit * 0.75
            spacing: Kirigami.Units.smallSpacing

            // --- Header (fixed) ---
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
                        text: card.battery.manufacturer + " " + card.battery.model
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    PC3.Label {
                        text: (card.battery.name || card.tr("Battery")) + " · " + card.battery.technology
                        opacity: 0.7
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

            // --- Remaining charge + bar (fixed) ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    PC3.Label { text: card.tr("Charge"); opacity: 0.8 }
                    Item { Layout.fillWidth: true }
                    PC3.Label {
                        leftPadding: Kirigami.Units.smallSpacing
                        text: card.battery.capacityPct + "%"
                        color: card.battery.chargeColor()
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, card.battery.capacityPct / 100))
                        height: parent.height
                        radius: 3
                        color: card.battery.chargeColor()
                        Behavior on width { NumberAnimation { duration: 400 } }
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

            // --- Health + bar (fixed) ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    PC3.Label { text: card.tr("Health"); opacity: 0.8 }
                    Item { Layout.fillWidth: true }
                    PC3.Label {
                        text: card.battery.fmtPct(card.battery.healthPct)
                        color: card.battery.healthColor()
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, card.battery.healthPct / 100))
                        height: parent.height
                        radius: 3
                        color: card.battery.healthColor()
                        Behavior on width { NumberAnimation { duration: 400 } }
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

            // --- Data-driven detail blocks (order + visibility from layoutJson) ---
            Repeater {
                model: card._order
                delegate: Loader {
                    required property var modelData
                    Layout.fillWidth: true
                    active: modelData.v
                    visible: active
                    sourceComponent: card._blockMap[modelData.id]
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
