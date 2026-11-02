import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "OsdModel.js" as OsdModel

// macOS-style status card: top right under the menu bar, styled to match
// cupertino.control-center.
Item {
  id: root

  property bool opened: false
  property string icon: ""
  property string message: ""
  property string iconKey: ""
  property int value: 0
  property int maxValue: 100
  property bool hasProgress: true
  property int duration: 1200

  readonly property bool mediaOsd: iconKey.indexOf("media") === 0 || iconKey.indexOf("player") === 0
  readonly property bool muted: iconKey === "volume-muted" || iconKey === "volume-mute" || iconKey === "muted" || iconKey === "mute"
  readonly property string title: {
    if (muted || iconKey.indexOf("volume") === 0) return "Sound"
    if (iconKey === "brightness" || iconKey === "display") return "Display"
    if (iconKey === "keyboard") return "Keyboard"
    return ""
  }

  function show(iconName, rawMessage, rawValue, rawMax, rawProgressText, rawDuration) {
    var next = OsdModel.stateForShow(iconName, rawMessage, rawValue, rawMax, rawProgressText, rawDuration)
    iconKey = next.iconKey
    maxValue = next.maxValue
    hasProgress = next.hasProgress
    value = next.value
    message = next.message
    icon = next.icon
    duration = next.duration
    opened = true
    if (duration > 0) hideTimer.restart()
    else hideTimer.stop()
  }

  function open(payloadJson) {
    try {
      var p = JSON.parse(payloadJson || "{}")
      show(p.icon || "", p.message || "", p.value === undefined ? "" : String(p.value), p.max === undefined ? "100" : String(p.max), p.progressText || "", p.duration === undefined ? "1200" : String(p.duration))
    } catch (e) {}
  }

  function close() { opened = false }

  Timer {
    id: hideTimer
    interval: root.duration
    onTriggered: root.opened = false
  }

  IpcHandler {
    target: "osd"
    function show(payloadJson: string): string {
      root.open(payloadJson)
      return "ok"
    }
    function close(): string { root.close(); return "ok" }
    function state(): string { return root.opened ? "open" : "closed" }
    function ping(): string { return "ok" }
  }

  PanelWindow {
    id: panel
    visible: root.opened || card.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Visual-only surface: keep the layer-shell input region empty so the OSD
    // never blocks clicks to the desktop below it.
    mask: Region {}

    Rectangle {
      id: card
      x: parent.width - width - 10
      y: Style.bar.sizeHorizontal + 6
      width: root.hasProgress ? 300 : messageRow.implicitWidth + 28
      height: root.hasProgress ? progressColumn.implicitHeight + 24 : messageRow.implicitHeight + 24
      radius: 20
      // The theme's omarchy-osd layer rule blurs what's behind this.
      color: Qt.rgba(0.12, 0.12, 0.12, 0.62)
      border.color: Qt.rgba(1, 1, 1, 0.16)
      opacity: root.opened ? 1 : 0

      Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
      }

      Column {
        id: progressColumn
        visible: root.hasProgress
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Text {
          visible: root.title !== ""
          textFormat: Text.PlainText
          text: root.title
          color: "#ffffff"
          font.family: Style.font.family
          font.pixelSize: 13
          font.weight: Font.DemiBold
        }

        Rectangle {
          id: track
          width: parent.width
          height: 22
          radius: 11
          color: Qt.rgba(1, 1, 1, 0.14)
          clip: true

          Rectangle {
            width: Math.max(track.height, track.width * (root.muted ? 0 : root.value / root.maxValue))
            height: parent.height
            radius: 11
            color: "#f2f2f7"

            Behavior on width {
              enabled: root.opened
              NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
          }

          Text {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.icon
            color: "#3a3a3c"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
          }
        }
      }

      Row {
        id: messageRow
        visible: !root.hasProgress
        x: 14
        y: 12
        spacing: 10

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.icon
          color: "#ffffff"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 16
        }

        Text {
          visible: root.message !== ""
          width: Math.min(implicitWidth, root.mediaOsd ? 325 : 260)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.message
          color: "#ffffff"
          font.family: Style.font.family
          font.pixelSize: 13
          font.weight: Font.DemiBold
          elide: Text.ElideRight
          maximumLineCount: 1
        }
      }
    }
  }
}
