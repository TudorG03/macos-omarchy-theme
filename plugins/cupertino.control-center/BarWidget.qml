import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Ui

BarWidget {
  id: root
  moduleName: "cupertino.control-center"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property bool panelOpen: false
  property bool wifiOn: false
  property string wifiName: ""
  property bool bluetoothOn: false
  property bool dndOn: false
  property bool nightOn: false
  property real volume: 0
  property real brightness: -1

  readonly property var player: {
    var players = Mpris.players.values.filter(function(player) { return !!player.trackTitle })
    for (var i = 0; i < players.length; i++) {
      if (players[i].isPlaying) return players[i]
    }
    return players.length > 0 ? players[0] : null
  }

  function run(args) {
    Quickshell.execDetached(args)
    refreshDelay.restart()
  }

  function openStock(pluginId) {
    panelOpen = false
    Quickshell.execDetached(["omarchy-shell", "shell", "toggle", pluginId, "{}"])
  }

  function applyStatus(text) {
    var values = {}
    text.split("\n").forEach(function(line) {
      var at = line.indexOf("=")
      if (at > 0) values[line.slice(0, at)] = line.slice(at + 1)
    })
    wifiOn = values.wifi === "enabled"
    wifiName = values.ssid || ""
    bluetoothOn = values.bluetooth === "yes"
    dndOn = values.dnd === "on"
    nightOn = (values.night || "").indexOf("\"enabled\":true") >= 0
    volume = Math.min(1, Number((values.volume || "").replace(/[^0-9.]/g, "")) || 0)
  }

  Process {
    id: status
    command: ["sh", "-c",
      "echo \"wifi=$(nmcli radio wifi)\"; echo \"ssid=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ':802-11-wireless$' | head -1 | cut -d: -f1)\"; " +
      "echo \"bluetooth=$(bluetoothctl show 2>/dev/null | awk '/Powered/{print $2; exit}')\"; echo \"dnd=$(omarchy-shell notifications dndState)\"; " +
      "echo \"night=$(omarchy toggle nightlight --status)\"; echo \"volume=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)\""]
    stdout: StdioCollector {
      onStreamFinished: root.applyStatus(text)
    }
  }

  // DDC/CI is slow, so brightness loads separately and doesn't hold up the rest.
  Process {
    id: brightnessProbe
    command: ["omarchy", "brightness", "display"]
    stdout: StdioCollector {
      onStreamFinished: {
        var value = Number(text.replace(/[^0-9.]/g, ""))
        root.brightness = isNaN(value) || text.trim() === "" ? -1 : value / 100
      }
    }
  }

  Timer {
    id: refreshDelay
    interval: 400
    onTriggered: if (!status.running) status.running = true
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    fontFamily: "JetBrainsMono Nerd Font"
    horizontalMargin: 7.5
    onPressed: {
      root.panelOpen = !root.panelOpen
      if (root.panelOpen) {
        status.running = true
        brightnessProbe.running = true
      }
    }
  }

  PanelWindow {
    screen: root.QsWindow.window ? root.QsWindow.window.screen : null
    visible: root.panelOpen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-control-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onVisibleChanged: if (visible) ccKeys.forceActiveFocus()

    Item {
      id: ccKeys
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.panelOpen = false
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: root.panelOpen = false
    }

    Rectangle {
      x: parent.width - width - 10
      y: root.barSize + 6
      width: 350
      height: panelColumn.implicitHeight + 24
      radius: 20
      color: Qt.rgba(0.12, 0.12, 0.12, 0.62)
      border.color: Qt.rgba(1, 1, 1, 0.16)

      MouseArea { anchors.fill: parent }

      Column {
        id: panelColumn
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Grid {
          columns: 2
          spacing: 8
          readonly property real tileWidth: (panelColumn.width - spacing) / 2

          CcTile {
            width: parent.tileWidth
            glyph: ""
            title: "Wi-Fi"
            detail: root.wifiOn ? (root.wifiName || "On") : "Off"
            active: root.wifiOn
            onToggled: root.run(["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"])
            onOpened: root.openStock("omarchy.network")
          }

          CcTile {
            width: parent.tileWidth
            glyph: ""
            title: "Bluetooth"
            detail: root.bluetoothOn ? "On" : "Off"
            active: root.bluetoothOn
            onToggled: root.run(["bluetoothctl", "power", root.bluetoothOn ? "off" : "on"])
            onOpened: root.openStock("omarchy.bluetooth")
          }

          CcTile {
            width: parent.tileWidth
            glyph: ""
            title: "Do Not Disturb"
            detail: root.dndOn ? "On" : "Off"
            active: root.dndOn
            onToggled: root.run(["omarchy-shell", "notifications", "toggleDnd"])
            onOpened: toggled()
          }

          CcTile {
            width: parent.tileWidth
            glyph: ""
            title: "Night Shift"
            detail: root.nightOn ? "On" : "Off"
            active: root.nightOn
            onToggled: root.run(["omarchy", "toggle", "nightlight"])
            onOpened: toggled()
          }
        }

        CcSlider {
          visible: root.brightness >= 0
          width: parent.width
          glyph: ""
          title: "Display"
          value: Math.max(0, root.brightness)
          onCommitted: function(value) {
            Quickshell.execDetached(["omarchy", "brightness", "display", "--no-osd", Math.round(value * 100) + "%"])
          }
        }

        CcSlider {
          width: parent.width
          glyph: ""
          title: "Sound"
          value: root.volume
          onMoved: function(value) {
            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", value.toFixed(2)])
          }
        }

        Rectangle {
          visible: root.player !== null
          width: parent.width
          height: 66
          radius: 14
          color: Qt.rgba(1, 1, 1, 0.09)

          ClippingRectangle {
            id: art
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            height: 46
            radius: 8
            color: "#3a3a3c"
            Image {
              anchors.fill: parent
              source: root.player ? (root.player.trackArtUrl || "") : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
            }
          }

          Column {
            anchors.left: art.right
            anchors.leftMargin: 10
            anchors.right: controls.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.player ? (root.player.trackTitle || "Not Playing") : ""
              elide: Text.ElideRight
              color: "#ffffff"
              font.family: "Adwaita Sans"
              font.pixelSize: 13
              font.weight: Font.DemiBold
            }
            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.player ? (root.player.trackArtist || "") : ""
              elide: Text.ElideRight
              color: "#c7c7cc"
              font.family: "Adwaita Sans"
              font.pixelSize: 12
            }
          }

          Row {
            id: controls
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Repeater {
              model: [
                { glyph: "", act: "previous" },
                { glyph: root.player && root.player.isPlaying ? "" : "", act: "toggle" },
                { glyph: "", act: "next" }
              ]
              Text {
                required property var modelData
                width: 28
                height: 30
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData.glyph
                color: "#ffffff"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (!root.player) return
                    if (modelData.act === "toggle") root.player.togglePlaying()
                    else if (modelData.act === "next") root.player.next()
                    else root.player.previous()
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
