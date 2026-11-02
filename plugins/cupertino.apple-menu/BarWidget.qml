import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui

BarWidget {
  id: root
  moduleName: "cupertino.apple-menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property string mode: ""
  property var confirm: null
  property var about: ({})

  readonly property var items: [
    { title: "About This Mac", run: function() { root.showAbout() } },
    { separator: true },
    { title: "System Settings…", command: "omarchy-menu toggle setup" },
    { title: "App Store…", command: "omarchy-menu toggle install" },
    { title: "Advanced…", command: "omarchy-menu toggle root" },
    { separator: true },
    { title: "Force Quit…", run: function() {
      var focused = ToplevelManager.activeToplevel
      root.ask("Force quit " + (focused ? (focused.title || focused.appId) : "the active window") + "?", "Unsaved changes will be lost.", "Force Quit", function() {
        Hyprland.dispatch("hl.dsp.window.kill()")
      })
    } },
    { separator: true },
    { title: "Sleep", command: "systemctl suspend" },
    { title: "Restart…", run: function() {
      root.ask("Are you sure you want to restart your computer now?", "Open windows will be closed.", "Restart", function() { root.exec("omarchy system reboot") })
    } },
    { title: "Shut Down…", run: function() {
      root.ask("Are you sure you want to shut down your computer now?", "Open windows will be closed.", "Shut Down", function() { root.exec("omarchy system shutdown") })
    } },
    { separator: true },
    { title: "Lock Screen", command: "omarchy system lock" },
    { title: "Log Out…", run: function() {
      root.ask("Are you sure you want to log out now?", "Open windows will be closed.", "Log Out", function() { root.exec("omarchy system logout") })
    } }
  ]

  function exec(command) {
    Quickshell.execDetached(["sh", "-c", command])
  }

  function ask(title, detail, action, run) {
    confirm = { title: title, detail: detail, action: action, run: run }
    mode = "confirm"
  }

  function showAbout() {
    mode = "about"
    aboutProbe.running = true
  }

  function choose(item) {
    if (item.run) {
      item.run()
      return
    }
    mode = ""
    exec(item.command)
  }

  Process {
    id: aboutProbe
    command: ["sh", "-c",
      "echo \"version=$(omarchy version | cut -d- -f1)\"; echo \"chip=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/ [0-9]*-Core Processor//; s/^ //')\"; " +
      "echo \"graphics=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)\"; echo \"memory=$(free -g | awk '/Mem/{print $2+1}') GB\"; true"]
    stdout: StdioCollector {
      onStreamFinished: {
        var values = {}
        text.split("\n").forEach(function(line) {
          var at = line.indexOf("=")
          if (at > 0) values[line.slice(0, at)] = line.slice(at + 1)
        })
        root.about = values
      }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    fontFamily: "JetBrainsMono Nerd Font"
    horizontalMargin: 7.5
    onPressed: function(button) {
      if (button === Qt.RightButton) root.exec("xdg-terminal-exec")
      else root.mode = root.mode === "" ? "menu" : ""
    }
  }

  PanelWindow {
    id: overlay
    screen: root.QsWindow.window ? root.QsWindow.window.screen : null
    visible: root.mode !== ""
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-apple-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onVisibleChanged: if (visible) keys.forceActiveFocus()

    Item {
      id: keys
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.mode = ""
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: root.mode = ""
    }

    Rectangle {
      visible: root.mode === "menu"
      x: 8
      y: root.barSize + 4
      width: 250
      height: menuColumn.implicitHeight + 12
      radius: 10
      color: Qt.rgba(0.12, 0.12, 0.12, 0.72)
      border.color: Qt.rgba(1, 1, 1, 0.18)

      MouseArea { anchors.fill: parent }

      Column {
        id: menuColumn
        x: 6
        y: 6
        width: parent.width - 12

        Repeater {
          model: root.items
          Item {
            required property var modelData
            width: menuColumn.width
            height: modelData.separator ? 9 : 26

            Rectangle {
              visible: !!modelData.separator
              anchors.centerIn: parent
              width: parent.width - 16
              height: 1
              color: Qt.rgba(1, 1, 1, 0.14)
            }

            Rectangle {
              visible: !modelData.separator
              anchors.fill: parent
              radius: 5
              color: rowMouse.containsMouse ? "#0058d0" : "transparent"

              Text {
                x: 10
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: modelData.title || ""
                color: "#ffffff"
                font.family: "Adwaita Sans"
                font.pixelSize: 13
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.choose(modelData)
              }
            }
          }
        }
      }
    }

    Rectangle {
      visible: root.mode === "about"
      anchors.centerIn: parent
      width: 400
      height: aboutColumn.implicitHeight + 56
      radius: 14
      color: Qt.rgba(0.14, 0.14, 0.15, 0.88)
      border.color: Qt.rgba(1, 1, 1, 0.18)

      MouseArea { anchors.fill: parent }

      Rectangle {
        x: 13
        y: 13
        width: 12
        height: 12
        radius: 6
        color: "#ff5f57"
        MouseArea {
          anchors.fill: parent
          anchors.margins: -5
          cursorShape: Qt.PointingHandCursor
          onClicked: root.mode = ""
        }
      }

      Column {
        id: aboutColumn
        y: 34
        width: parent.width
        spacing: 3

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: ""
          color: "#e5e5e7"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 76
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          topPadding: 8
          text: "Mac"
          color: "#ffffff"
          font.family: "Adwaita Sans"
          font.pixelSize: 21
          font.weight: Font.Bold
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          bottomPadding: 14
          text: "macOS Cupertino " + (root.about.version || "")
          color: "#98989d"
          font.family: "Adwaita Sans"
          font.pixelSize: 12
        }

        Repeater {
          model: [
            ["Chip", root.about.chip],
            ["Graphics", root.about.graphics],
            ["Memory", root.about.memory]
          ]
          Item {
            required property var modelData
            visible: !!modelData[1]
            width: aboutColumn.width
            height: visible ? 21 : 0
            Text {
              anchors.right: parent.horizontalCenter
              anchors.rightMargin: 58
              text: modelData[0]
              color: "#e5e5e7"
              font.family: "Adwaita Sans"
              font.pixelSize: 12
              font.weight: Font.DemiBold
            }
            Text {
              anchors.left: parent.horizontalCenter
              anchors.leftMargin: -48
              anchors.right: parent.right
              anchors.rightMargin: 14
              text: modelData[1] || ""
              elide: Text.ElideRight
              color: "#98989d"
              font.family: "Adwaita Sans"
              font.pixelSize: 12
            }
          }
        }
      }
    }

    Rectangle {
      visible: root.mode === "confirm"
      anchors.centerIn: parent
      width: 290
      height: confirmColumn.implicitHeight + 36
      radius: 14
      color: Qt.rgba(0.16, 0.16, 0.17, 0.92)
      border.color: Qt.rgba(1, 1, 1, 0.18)

      MouseArea { anchors.fill: parent }

      Column {
        id: confirmColumn
        x: 18
        y: 18
        width: parent.width - 36
        spacing: 12

        Text {
          width: parent.width
          wrapMode: Text.Wrap
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: root.confirm ? root.confirm.title : ""
          color: "#ffffff"
          font.family: "Adwaita Sans"
          font.pixelSize: 14
          font.weight: Font.DemiBold
        }

        Text {
          width: parent.width
          wrapMode: Text.Wrap
          horizontalAlignment: Text.AlignHCenter
          text: root.confirm ? root.confirm.detail : ""
          color: "#c7c7cc"
          font.family: "Adwaita Sans"
          font.pixelSize: 12
        }

        Row {
          spacing: 10
          anchors.horizontalCenter: parent.horizontalCenter

          Repeater {
            model: [
              { label: "Cancel", primary: false },
              { label: root.confirm ? root.confirm.action : "", primary: true }
            ]
            Rectangle {
              required property var modelData
              width: 122
              height: 28
              radius: 7
              color: modelData.primary ? "#0a84ff" : Qt.rgba(1, 1, 1, 0.14)
              Text {
                anchors.centerIn: parent
                text: modelData.label
                color: "#ffffff"
                font.family: "Adwaita Sans"
                font.pixelSize: 13
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var run = modelData.primary && root.confirm ? root.confirm.run : null
                  root.mode = ""
                  if (run) run()
                }
              }
            }
          }
        }
      }
    }
  }
}
