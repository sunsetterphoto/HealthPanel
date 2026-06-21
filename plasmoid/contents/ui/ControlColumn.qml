// ControlColumn.qml — right column: quick controls. Inhibit standby/lock, screen
// and keyboard brightness, system volume + mute. Each row toggles via config, and
// only appears when the backend is actually available.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

ColumnLayout {
    id: col
    property var control
    property bool showInhibit: true
    property bool showScreenBrightness: true
    property bool showKbdBrightness: true
    property bool showVolume: true

    signal setScreenBrightness(real raw)
    signal setKbdBrightness(real val)
    signal setVolume(real frac)
    signal toggleMute()
    signal setInhibit(bool on)

    readonly property bool _ok: control !== null && control !== undefined
    spacing: Kirigami.Units.smallSpacing

    component MLabel: PC3.Label {
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        opacity: 0.62
    }

    MLabel { text: "Steuerung" }

    // ---- inhibit standby / lock ----
    RowLayout {
        Layout.fillWidth: true
        visible: col.showInhibit
        PC3.Label {
            text: "Standby & Sperre verhindern"
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        QQC2.Switch {
            checked: col._ok && col.control.inhibited
            onToggled: col.setInhibit(checked)
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true; Layout.topMargin: 2; Layout.bottomMargin: 2
        opacity: 0.6
        visible: col.showInhibit && (col.showScreenBrightness || col.showVolume)
    }

    // ---- screen brightness ----
    ColumnLayout {
        Layout.fillWidth: true
        visible: col.showScreenBrightness && col._ok && col.control.hasScreen
        spacing: 2
        MLabel { text: "Bildschirm" }
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
        visible: col.showKbdBrightness && col._ok && col.control.hasKbd
        spacing: 2
        MLabel { text: "Tastatur" }
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
        visible: col.showVolume && col._ok && col.control.hasVolume
            && (col.showScreenBrightness || col.showKbdBrightness || col.showInhibit)
    }

    // ---- volume + mute ----
    ColumnLayout {
        Layout.fillWidth: true
        visible: col.showVolume && col._ok && col.control.hasVolume
        spacing: 2
        MLabel { text: "Lautstärke" }
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
}
