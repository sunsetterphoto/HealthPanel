// SystemColumn.qml — left column of the monitor: power-mode + CPU/RAM/disk/net.
// Per-metric display style (bar | ring | sparkline; net: text | sparkline) and
// per-section visibility are driven by layoutJson (parsed order) and detail
// sub-row properties bound to the widget config.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import "i18n.js" as I18n
import "layoutmeta.js" as Layout

ColumnLayout {
    id: col
    property var system
    property string lang: "en"
    function tr(s) { return I18n.tr(col.lang, s) }
    signal setProfile(string name)

    // detail sub-row toggles (gate sub-rows, not whole sections)
    property bool showSmart: true
    property bool showTemps: true
    property bool cpuCoresLogical: false   // false = physical cores, true = threads
    property bool showPower: true          // CPU/SoC/GPU power-draw rows
    property bool showVoltage: true        // GPU voltage row
    property bool showDiskSensor1: true    // NVMe "Sensor 1" temperature

    // per-metric display style
    property string cpuStyle: "bar"        // bar | ring | sparkline
    property string ramStyle: "bar"
    property string diskStyle: "bar"
    property string netStyle: "text"       // text | sparkline
    property string gpuStyle: "sparkline"  // bar | ring | sparkline (GPU load)
    property string vramStyle: "bar"       // bar | text (VRAM usage)

    // layout-driven order + visibility
    property string layoutJson: ""   // systemLayout config string; empty -> all default
    readonly property var _order: Layout.parseOrder(col.layoutJson, Layout.systemSections())

    readonly property bool _ok: system !== null && system !== undefined && system.valid === true
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

    // ---- Section components ----

    // ---- Power-Mode ----
    Component {
        id: powerModeSection
        ColumnLayout {
            Layout.fillWidth: true
            visible: col._ok && col.system.hasPowerProfile
            spacing: Kirigami.Units.smallSpacing
            QQC2.ButtonGroup { id: pmGroup }
            MLabel { text: col.tr("Power mode") }
            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: [
                        { id: "performance", label: "Performance" },
                        { id: "balanced",    label: "Balanced" },
                        { id: "power-saver", label: "Power Saver" }
                    ]
                    delegate: QQC2.Button {
                        required property var modelData
                        Layout.fillWidth: true
                        flat: true
                        checkable: true
                        QQC2.ButtonGroup.group: pmGroup
                        checked: col._ok && col.system.powerProfile === modelData.id
                        text: col.tr(modelData.label)
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        onClicked: col.setProfile(modelData.id)
                    }
                }
            }
        }
    }

    // ---- CPU ----
    Component {
        id: cpuSection
        ColumnLayout {
            Layout.fillWidth: true
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
            RowLayout {
                Layout.fillWidth: true
                visible: col._ok && col.showPower && (col.system.hasCpuPower || col.system.hasSocPower)
                MLabel { text: col.tr("Power draw") }
                Item { Layout.fillWidth: true }
                PC3.Label {
                    text: {
                        if (!col._ok) return ""
                        var parts = []
                        if (col.system.hasCpuPower) parts.push("CPU " + col.system.fmtW(col.system.cpuPowerW))
                        if (col.system.hasSocPower) parts.push("SoC " + col.system.fmtW(col.system.socPowerW))
                        return parts.join("   ")
                    }
                    opacity: 0.7; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
        }
    }

    // ---- GPU + VRAM ----
    Component {
        id: gpuSection
        ColumnLayout {
            Layout.fillWidth: true
            visible: col._ok && col.system.hasGpu
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    MLabel { text: "GPU" }
                    PC3.Label {
                        visible: col._ok && col.showTemps && col.system.hasGpuTemp
                        text: col._ok ? col.system.fmtTemp(col.system.gpuTempC) : ""
                        opacity: 0.5; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                }
                Item { Layout.fillWidth: true }
                Ring {
                    visible: col.gpuStyle === "ring"
                    fraction: col._ok ? col.system.gpuBusy / 100 : 0
                    fill: "#e67e22"
                    centerText: col._ok ? Math.round(col.system.gpuBusy) + "" : "—"
                }
                PC3.Label {
                    visible: col.gpuStyle !== "ring"
                    text: col._ok ? col.system.fmtPct(col.system.gpuBusy) : "—"
                    font.bold: true; font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                }
            }
            Bar { visible: col.gpuStyle === "bar"; fraction: col._ok ? col.system.gpuBusy / 100 : 0; fill: "#e67e22" }
            Spark { visible: col.gpuStyle === "sparkline"; points: col._ok ? col.system.gpuHist : []; maxValue: 100; fill: "#e67e22" }

            RowLayout {
                Layout.fillWidth: true
                MLabel { text: "VRAM" }
                Item { Layout.fillWidth: true }
                PC3.Label { text: col._ok ? col.system.fmtPct(col.system.vramPct) : "—"; font.bold: true }
            }
            PC3.Label {
                text: col._ok ? col.system.fmtGB(col.system.vramUsedGB) + " / " + col.system.fmtGB(col.system.vramTotalGB) : ""
                opacity: 0.55; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
            Bar { visible: col.vramStyle === "bar"; fraction: col._ok ? col.system.vramPct / 100 : 0; fill: "#d35400" }
            RowLayout {
                Layout.fillWidth: true
                visible: col._ok && col.showPower && col.system.hasGpuPower
                MLabel { text: col.tr("Power draw") }
                Item { Layout.fillWidth: true }
                PC3.Label {
                    text: col._ok ? col.system.fmtW(col.system.gpuPowerW) : ""
                    opacity: 0.7; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: col._ok && col.showVoltage && col.system.hasGpuVoltage
                MLabel { text: col.tr("Voltage") }
                Item { Layout.fillWidth: true }
                PC3.Label {
                    text: col._ok ? col.system.fmtVolt(col.system.gpuVoltageV) : ""
                    opacity: 0.7; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
        }
    }

    // ---- RAM + swap ----
    Component {
        id: ramSection
        ColumnLayout {
            Layout.fillWidth: true
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
    }

    // ---- Disk + temp + SMART ----
    Component {
        id: diskSection
        ColumnLayout {
            Layout.fillWidth: true
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
                PC3.Label {
                    visible: col._ok && col.showDiskSensor1 && col.system.hasDiskTempSensor1
                    text: col._ok ? "S1 " + col.system.fmtTemp(col.system.diskTempSensor1C) : ""
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
                PC3.Label { text: col.tr("Health"); opacity: 0.55; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
                PC3.Label { text: "·"; opacity: 0.3; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
                PC3.Label { text: col._ok ? col.system.fmtHours(col.system.smartPowerOnHours) : ""; opacity: 0.55; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
                PC3.Label { text: "·"; opacity: 0.3; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
                PC3.Label { text: col._ok ? col.system.fmtTbw(col.system.smartTbwTB) : ""; opacity: 0.55; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
                Item { Layout.fillWidth: true }
            }
        }
    }

    // ---- Fans ----
    Component {
        id: fansSection
        ColumnLayout {
            Layout.fillWidth: true
            visible: col._ok && col.system.hasFan
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                MLabel { text: col.tr("Fans") }
                Item { Layout.fillWidth: true }
                PC3.Label {
                    text: {
                        if (!col._ok) return ""
                        var parts = []
                        for (var i = 0; i < col.system.fanRpms.length; i++)
                            parts.push(col.system.fmtRpm(col.system.fanRpms[i]))
                        return parts.join("   ")
                    }
                    font.bold: true; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
        }
    }

    // ---- Netz ----
    Component {
        id: netSection
        ColumnLayout {
            Layout.fillWidth: true
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
                    PC3.Label { text: col.tr("Down"); opacity: 0.5; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
                }
                ColumnLayout {
                    spacing: 0
                    PC3.Label { text: col._ok ? "↑ " + col.system.fmtRate(col.system.netUpMBps) : "—"; font.bold: true; font.pixelSize: Kirigami.Theme.defaultFont.pixelSize }
                    PC3.Label { text: col.tr("Up"); opacity: 0.5; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
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
    }

    // ---- id→component map and layout-driven Repeater ----
    readonly property var _sectionMap: ({
        "powerMode": powerModeSection, "cpu": cpuSection, "gpu": gpuSection,
        "ram": ramSection, "disk": diskSection, "fans": fansSection, "net": netSection
    })

    // sections whose existence depends on a hardware source; others are always present
    function _hwPresent(id) {
        if (!col._ok) return false
        if (id === "gpu") return col.system.hasGpu
        if (id === "fans") return col.system.hasFan
        if (id === "powerMode") return col.system.hasPowerProfile
        return true
    }

    Repeater {
        model: col._order
        delegate: ColumnLayout {
            id: secWrap
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            // section is visible only when its v flag is on AND its hardware source
            // exists — hiding the whole wrapper (divider + loader) avoids a stray
            // SectionRule when a section is enabled but its hardware is absent.
            visible: secWrap.modelData.v && col._hwPresent(secWrap.modelData.id)
            SectionRule { visible: secWrap.index > 0 }
            Loader { Layout.fillWidth: true; sourceComponent: col._sectionMap[secWrap.modelData.id] }
        }
    }

    Item { Layout.fillHeight: true }
}
