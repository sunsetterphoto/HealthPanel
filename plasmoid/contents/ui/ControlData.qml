// ControlData.qml — current state of the controllable settings (screen/keyboard
// brightness, volume, inhibit). main.qml feeds it the control-probe output via
// applyControlProbe(); the inhibit flag is tracked locally (set by the toggle).
import QtQuick

QtObject {
    id: data

    // screen brightness
    property string screenDisplay: ""
    property int screenBrightness: 0
    property int screenBrightnessMax: 0
    readonly property bool hasScreen: screenBrightnessMax > 0
    readonly property real screenPct: hasScreen ? (screenBrightness / screenBrightnessMax) * 100 : 0

    // keyboard backlight
    property int kbdBrightness: 0
    property int kbdBrightnessMax: 0
    readonly property bool hasKbd: kbdBrightnessMax > 0

    // audio
    property real volume: 0          // 0..1
    property bool muted: false
    property bool hasVolume: false
    readonly property int volumePct: Math.round(volume * 100)

    // idle/sleep inhibit — tracked locally (on while our systemd-inhibit runs)
    property bool inhibited: false

    function applyControlProbe(text) {
        if (!text) return
        var sec = {}, cur = null, buf = []
        text.split("\n").forEach(function (line) {
            var m = line.match(/^===(\w+)===$/)
            if (m) { if (cur !== null) sec[cur] = buf.join("\n"); cur = m[1]; buf = []; }
            else if (cur !== null) buf.push(line)
        })
        if (cur !== null) sec[cur] = buf.join("\n")

        if (sec.SCREEN) {
            var dm = sec.SCREEN.match(/DISPLAY=(\S+)/)
            if (dm) screenDisplay = dm[1]
            var sn = sec.SCREEN.match(/(?:^|\s)i (\d+)/g)   // "i <cur>", "i <max>"
            if (sn && sn.length >= 2) {
                screenBrightness = parseInt(sn[0].replace(/\D/g, ""), 10)
                screenBrightnessMax = parseInt(sn[1].replace(/\D/g, ""), 10)
            }
        }
        if (sec.KBD) {
            var kn = sec.KBD.match(/(?:^|\s)i (\d+)/g)
            if (kn && kn.length >= 2) {
                kbdBrightness = parseInt(kn[0].replace(/\D/g, ""), 10)
                kbdBrightnessMax = parseInt(kn[1].replace(/\D/g, ""), 10)
            }
        }
        if (sec.VOL) {
            var vm = sec.VOL.match(/Volume:\s*([\d.]+)/)
            if (vm) { volume = parseFloat(vm[1]); hasVolume = true }
            muted = /MUTED/.test(sec.VOL)
        }
    }
}
