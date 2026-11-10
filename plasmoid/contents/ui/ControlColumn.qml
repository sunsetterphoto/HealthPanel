// ControlColumn.qml — right column: quick controls. Inhibit standby/lock, screen
// and keyboard brightness, system volume + mute. Each row toggles via config, and
// only appears when the backend is actually available.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import "i18n.js" as I18n

ColumnLayout {
    id: col
    property var control
    property string lang: "en"
    function tr(s) { return I18n.tr(col.lang, s) }
    property bool showInhibit: true
    property bool showScreenBrightness: true
    property bool showKbdBrightness: true
    property bool showVolume: true
    // true while the surrounding view scrolls: the sliders then leave the mouse
    // wheel to the scroll view instead of changing brightness/volume in passing
    property bool inScroll: false

    // which rows are actually on screen (config toggle AND backend available)
    readonly property bool _vScreen: col.showScreenBrightness && col._ok && col.control.hasScreen
    readonly property bool _vKbd: col.showKbdBrightness && col._ok && col.control.hasKbd
    readonly property bool _vVolume: col.showVolume && col._ok && col.control.hasVolume

    signal setScreenBrightness(real raw)
    signal setKbdBrightness(real val)
    signal setVolume(real frac)
    signal toggleMute()
    signal setInhibit(bool on)
    signal openSystemSettings()
    signal openSystemMonitor()
    signal openWidgetSettings()

    readonly property bool _ok: control !== null && control !== undefined
    spacing: Kirigami.Units.smallSpacing

    component MLabel: PC3.Label {
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        opacity: 0.62
    }

    MLabel { text: col.tr("Controls") }

    // ---- inhibit standby / lock ----
    RowLayout {
        Layout.fillWidth: true
        visible: col.showInhibit
        PC3.Label {
            text: col.tr("Prevent standby & lock")
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        QQC2.Switch {
            id: inhibitSwitch
            // toggling replaces the binding with a plain value — re-bind so the
            // switch keeps following the real state (e.g. when the inhibitor dies)
            function _bind() { checked = Qt.binding(function () { return col._ok && col.control.inhibited }) }
            Component.onCompleted: _bind()
            onToggled: { col.setInhibit(checked); _bind() }
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true; Layout.topMargin: 2; Layout.bottomMargin: 2
        opacity: 0.6
        visible: col.showInhibit && (col._vScreen || col._vKbd || col._vVolume)
    }

    // ---- screen brightness ----
    ColumnLayout {
        Layout.fillWidth: true
        visible: col._vScreen
        spacing: 2
        MLabel { text: col.tr("Screen") }
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: "video-display-brightness"
                implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: Kirigami.Units.iconSizes.small
            }
            QQC2.Slider {
                id: scrSlider
                Layout.fillWidth: true
                wheelEnabled: !col.inScroll
                from: 1
                to: col._ok ? Math.max(1, col.control.screenBrightnessMax) : 1
                Component.onCompleted: if (col._ok) value = col.control.screenBrightness
                onMoved: col.setScreenBrightness(value)
                Connections {
                    target: col.control
                    enabled: col._ok
                    function onScreenBrightnessChanged() { if (!scrSlider.pressed) scrSlider.value = col.control.screenBrightness }
                }
            }
            PC3.Label {
                text: col._ok ? Math.round(col.control.screenPct) + "%" : ""
                Layout.minimumWidth: Kirigami.Units.gridUnit * 2
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // ---- keyboard backlight ----
    ColumnLayout {
        Layout.fillWidth: true
        visible: col._vKbd
        spacing: 2
        MLabel { text: col.tr("Keyboard") }
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: "input-keyboard"
                implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: Kirigami.Units.iconSizes.small
            }
            QQC2.Slider {
                id: kbdSlider
                Layout.fillWidth: true
                wheelEnabled: !col.inScroll
                from: 0
                to: col._ok ? Math.max(1, col.control.kbdBrightnessMax) : 1
                stepSize: 1
                snapMode: QQC2.Slider.SnapAlways
                Component.onCompleted: if (col._ok) value = col.control.kbdBrightness
                onMoved: col.setKbdBrightness(value)
                Connections {
                    target: col.control
                    enabled: col._ok
                    function onKbdBrightnessChanged() { if (!kbdSlider.pressed) kbdSlider.value = col.control.kbdBrightness }
                }
            }
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true; Layout.topMargin: 2; Layout.bottomMargin: 2
        opacity: 0.6
        visible: col._vVolume && (col._vScreen || col._vKbd)
    }

    // ---- volume + mute ----
    ColumnLayout {
        Layout.fillWidth: true
        visible: col._vVolume
        spacing: 2
        MLabel { text: col.tr("Volume") }
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            QQC2.ToolButton {
                icon.name: (col._ok && col.control.muted) ? "audio-volume-muted" : "audio-volume-high"
                flat: true
                onClicked: col.toggleMute()
            }
            QQC2.Slider {
                id: volSlider
                Layout.fillWidth: true
                wheelEnabled: !col.inScroll
                from: 0; to: 1
                opacity: (col._ok && col.control.muted) ? 0.5 : 1
                Component.onCompleted: if (col._ok) value = col.control.volume
                onMoved: col.setVolume(value)
                Connections {
                    target: col.control
                    enabled: col._ok
                    function onVolumeChanged() { if (!volSlider.pressed) volSlider.value = col.control.volume }
                }
            }
            PC3.Label {
                text: col._ok ? col.control.volumePct + "%" : ""
                Layout.minimumWidth: Kirigami.Units.gridUnit * 2
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    Item { Layout.fillHeight: true }

    // ---- jump-offs to KDE tools ----
    Kirigami.Separator { Layout.fillWidth: true; opacity: 0.6 }
    QQC2.Button {
        Layout.fillWidth: true
        icon.name: "configure"
        text: col.tr("System Settings")
        onClicked: col.openSystemSettings()
    }
    QQC2.Button {
        Layout.fillWidth: true
        icon.name: "org.kde.plasma-systemmonitor"
        text: col.tr("System Monitor")
        onClicked: col.openSystemMonitor()
    }
    QQC2.Button {
        Layout.fillWidth: true
        icon.name: "configure"
        text: col.tr("Widget Settings")
        onClicked: col.openWidgetSettings()
    }
}
