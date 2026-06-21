// SystemColumn.qml — left column of the monitor: power-mode + CPU/RAM/disk/net.
// Per-metric display style (bar | ring | sparkline; net: text | sparkline) and
// per-section visibility are driven by properties bound to the widget config.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

ColumnLayout {
    id: col
    property var system
    signal setProfile(string name)

    // section visibility
    property bool showPowerMode: true
    property bool showCpu: true
    property bool showRam: true
    property bool showDisk: true
    property bool showNet: true
    property bool showSmart: true
    property bool showTemps: true
    property bool cpuCoresLogical: false   // false = physical cores, true = threads

    // per-metric display style
    property string cpuStyle: "bar"     // bar | ring | sparkline
    property string ramStyle: "bar"
    property string diskStyle: "bar"
    property string netStyle: "text"    // text | sparkline

    readonly property bool _ok: system !== null && system !== undefined && system.valid === true
    readonly property bool _pm: _ok && showPowerMode && system.hasPowerProfile
    spacing: Kirigami.Units.smallSpacing

    // A thin section divider that only appears when something visible sits above it.
    component SectionRule: Kirigami.Separator {
        Layout.fillWidth: true
        Layout.topMargin: 2
        Layout.bottomMargin: 2
        opacity: 0.6
    }

    // ---- reusable visualisations ----
    component Bar: Rectangle {
        property real fraction: 0
        property color fill: "#3daee9"
        Layout.fillWidth: true
        Layout.preferredHeight: 5
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.09)
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.fraction))
            height: parent.height; radius: 3; color: parent.fill
            Behavior on width { NumberAnimation { duration: 350 } }
        }
    }
    component Ring: Item {
        id: ring
        property real fraction: 0
        property color fill: "#3daee9"
        property string centerText: ""
        implicitWidth: Kirigami.Units.gridUnit * 2.4
        implicitHeight: Kirigami.Units.gridUnit * 2.4
        onFractionChanged: cv.requestPaint()
        onFillChanged: cv.requestPaint()
        Canvas {
            id: cv
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d"); ctx.reset();
                var cx = width / 2, cy = height / 2, rr = Math.min(width, height) / 2 - 4;
                ctx.lineWidth = 4; ctx.lineCap = "round";
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12);
                ctx.beginPath(); ctx.arc(cx, cy, rr, 0, 2 * Math.PI); ctx.stroke();
                var f = Math.max(0, Math.min(1, ring.fraction));
                if (f > 0) {
                    ctx.strokeStyle = ring.fill;
                    ctx.beginPath();
                    ctx.arc(cx, cy, rr, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * f);
                    ctx.stroke();
                }
            }
            Component.onCompleted: requestPaint()
        }
        PC3.Label {
            anchors.centerIn: parent
            text: ring.centerText
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            font.bold: true
        }
    }
    component Spark: Canvas {
        id: spark
        property var points: []
        property real maxValue: 100      // 0 → auto-scale to window max
        property color fill: "#3daee9"
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
        onPointsChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d"); ctx.reset();
            var pts = spark.points;
            if (!pts || pts.length < 2) return;
            var mx = spark.maxValue;
            if (mx <= 0) { mx = 0.0001; for (var k = 0; k < pts.length; k++) if (pts[k] > mx) mx = pts[k]; }
            ctx.strokeStyle = spark.fill; ctx.lineWidth = 1.5; ctx.lineJoin = "round";
            ctx.beginPath();
            for (var i = 0; i < pts.length; i++) {
                var x = width * i / (pts.length - 1);
                var y = height * (1 - Math.max(0, Math.min(1, pts[i] / mx)));
                i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
            }
            ctx.stroke();
        }
    }
    component MLabel: PC3.Label {
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        opacity: 0.62
    }

    // ---- Power-Mode ----
    QQC2.ButtonGroup { id: pmGroup }
    ColumnLayout {
        Layout.fillWidth: true
        visible: col._ok && col.showPowerMode && col.system.hasPowerProfile
        spacing: Kirigami.Units.smallSpacing
        MLabel { text: "Power-Mode" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
                model: [
                    { id: "performance", label: "Leistung" },
                    { id: "balanced",    label: "Ausgewogen" },
                    { id: "power-saver", label: "Sparen" }
                ]
                delegate: QQC2.Button {
                    required property var modelData
                    Layout.fillWidth: true
                    flat: true
                    checkable: true
                    QQC2.ButtonGroup.group: pmGroup
                    checked: col._ok && col.system.powerProfile === modelData.id
                    text: modelData.label
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    onClicked: col.setProfile(modelData.id)
                }
            }
        }
    }
    // ---- CPU ----
    SectionRule { visible: col._ok && col.showCpu && col._pm }
    ColumnLayout {
        Layout.fillWidth: true
        visible: col._ok && col.showCpu
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                MLabel { text: "CPU" }
                PC3.Label {
                    visible: col._ok && col.showTemps && col.system.hasCpuTemp
                    text: col._ok ? col.system.fmtTemp(col.system.cpuTempC) : ""
                    opacity: 0.5; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
            Item { Layout.fillWidth: true }
            Row {
                spacing: 2
                Repeater {
                    model: col._ok ? (col.cpuCoresLogical ? col.system.coreLoadsLogical : col.system.coreLoads) : []
                    delegate: Rectangle {
                        required property var modelData
                        width: 3; height: 15; radius: 1
                        color: Qt.rgba(1, 1, 1, 0.12)
                        Rectangle {
                            width: parent.width; radius: 1; color: "#3daee9"; opacity: 0.85
                            height: parent.height * Math.max(0.04, Math.min(1, parent.modelData / 100))
                            anchors.bottom: parent.bottom
                        }
                    }
                }
            }
            Ring {
                visible: col.cpuStyle === "ring"
                fraction: col._ok ? col.system.cpuPct / 100 : 0
                fill: "#3daee9"
                centerText: col._ok ? Math.round(col.system.cpuPct) + "" : "—"
            }
            PC3.Label {
                visible: col.cpuStyle !== "ring"
                leftPadding: Kirigami.Units.smallSpacing
                text: col._ok ? col.system.fmtPct(col.system.cpuPct) : "—"
                font.bold: true; font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            }
        }
        Bar { visible: col.cpuStyle === "bar"; fraction: col._ok ? col.system.cpuPct / 100 : 0; fill: "#3daee9" }
        Spark { visible: col.cpuStyle === "sparkline"; points: col._ok ? col.system.cpuHist : []; maxValue: 100; fill: "#3daee9" }
    }

    // ---- RAM + swap ----
    SectionRule { visible: col._ok && col.showRam && (col._pm || col.showCpu) }
    ColumnLayout {
        Layout.fillWidth: true
        visible: col._ok && col.showRam
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            MLabel { text: "RAM" }
            Item { Layout.fillWidth: true }
            Ring {
                visible: col.ramStyle === "ring"
                fraction: col._ok ? col.system.ramPct / 100 : 0
                fill: "#9b6dff"
                centerText: col._ok ? Math.round(col.system.ramPct) + "" : "—"
            }
            PC3.Label {
                visible: col.ramStyle !== "ring"
                text: col._ok ? col.system.fmtPct(col.system.ramPct) : "—"; font.bold: true
            }
        }
        PC3.Label {
            text: col._ok ? col.system.fmtGB(col.system.ramUsedGB) + " / " + col.system.fmtGB(col.system.ramTotalGB) : ""
            opacity: 0.55; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
        Bar { visible: col.ramStyle === "bar"; fraction: col._ok ? col.system.ramPct / 100 : 0; fill: "#9b6dff" }
        Spark { visible: col.ramStyle === "sparkline"; points: col._ok ? col.system.ramHist : []; maxValue: 100; fill: "#9b6dff" }
        PC3.Label {
            visible: col._ok && col.system.hasSwap
            text: col._ok ? "Swap  " + col.system.fmtGB(col.system.swapUsedGB) + " / " + col.system.fmtGB(col.system.swapTotalGB) + "  " + col.system.fmtPct(col.system.swapPct) : ""
            opacity: 0.55; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            Layout.topMargin: 4
        }
        Bar {
            visible: col._ok && col.system.hasSwap
            Layout.preferredHeight: 3
            fraction: col._ok ? col.system.swapPct / 100 : 0; fill: "#7d5bbe"
        }
    }

    // ---- Disk + temp + SMART ----
    SectionRule { visible: col._ok && col.showDisk && (col._pm || col.showCpu || col.showRam) }
    ColumnLayout {
        Layout.fillWidth: true
        visible: col._ok && col.showDisk
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            MLabel { text: "DISK" }
            PC3.Label {
                leftPadding: Kirigami.Units.smallSpacing
                text: col._ok ? "↓ " + col.system.fmtRate(col.system.diskReadMBps) + "  ↑ " + col.system.fmtRate(col.system.diskWriteMBps) : ""
                opacity: 0.45; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
            PC3.Label {
                visible: col._ok && col.showTemps && col.system.hasDiskTemp
                text: col._ok ? col.system.fmtTemp(col.system.diskTempC) : ""
                opacity: 0.5; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
            Item { Layout.fillWidth: true }
            Ring {
                visible: col.diskStyle === "ring"
                fraction: col._ok ? col.system.diskPct / 100 : 0
                fill: "#f1c40f"
                centerText: col._ok ? Math.round(col.system.diskPct) + "" : "—"
            }
            PC3.Label {
                visible: col.diskStyle !== "ring"
                text: col._ok ? col.system.fmtPct(col.system.diskPct) : "—"; font.bold: true
            }
        }
        PC3.Label {
            text: col._ok ? col.system.fmtGB(col.system.diskUsedGB) + " / " + col.system.fmtGB(col.system.diskTotalGB) : ""
            opacity: 0.55; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
        Bar { visible: col.diskStyle === "bar"; fraction: col._ok ? col.system.diskPct / 100 : 0; fill: "#f1c40f" }
        // sparkline shows disk I/O activity (occupancy barely moves)
        Spark { visible: col.diskStyle === "sparkline"; points: col._ok ? col.system.diskIoHist : []; maxValue: 0; fill: "#f1c40f" }
        RowLayout {
            Layout.fillWidth: true
            visible: col._ok && col.showSmart && col.system.smartValid
            spacing: Kirigami.Units.smallSpacing
            PC3.Label {
                text: col._ok ? col.system.fmtPct(col.system.smartHealthPct) : ""
                color: "#2ecc71"; font.bold: true; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
            PC3.Label { text: "Health"; opacity: 0.55; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
            PC3.Label { text: "·"; opacity: 0.3; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
            PC3.Label { text: col._ok ? col.system.fmtHours(col.system.smartPowerOnHours) : ""; opacity: 0.55; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
            PC3.Label { text: "·"; opacity: 0.3; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
            PC3.Label { text: col._ok ? col.system.fmtTbw(col.system.smartTbwTB) : ""; opacity: 0.55; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
            Item { Layout.fillWidth: true }
        }
    }

    // ---- Netz ----
    SectionRule { visible: col._ok && col.showNet && (col._pm || col.showCpu || col.showRam || col.showDisk) }
    ColumnLayout {
        Layout.fillWidth: true
        visible: col._ok && col.showNet
        spacing: 2
        MLabel { text: "NETZ" }
        // text style: prominent down/up blocks
        RowLayout {
            visible: col.netStyle === "text"
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            ColumnLayout {
                spacing: 0
                PC3.Label { text: col._ok ? "↓ " + col.system.fmtRate(col.system.netDownMBps) : "—"; font.bold: true; font.pixelSize: Kirigami.Theme.defaultFont.pixelSize }
                PC3.Label { text: "Down"; opacity: 0.5; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
            }
            ColumnLayout {
                spacing: 0
                PC3.Label { text: col._ok ? "↑ " + col.system.fmtRate(col.system.netUpMBps) : "—"; font.bold: true; font.pixelSize: Kirigami.Theme.defaultFont.pixelSize }
                PC3.Label { text: "Up"; opacity: 0.5; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
            }
        }
        // sparkline style: compact current line + activity graph
        PC3.Label {
            visible: col.netStyle === "sparkline"
            text: col._ok ? "↓ " + col.system.fmtRate(col.system.netDownMBps) + "   ↑ " + col.system.fmtRate(col.system.netUpMBps) : "—"
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
        Spark { visible: col.netStyle === "sparkline"; points: col._ok ? col.system.netHist : []; maxValue: 0; fill: "#2ecc71" }
    }

    Item { Layout.fillHeight: true }
}
