import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool loading: false
  property bool commitPending: false
  property int pendingSteps: 0
  property var apps: []
  property int selected: 0
  property string pendingAddress: ""

  readonly property int iconSize: Math.min(92, (panel.width - 120) / Math.max(1, apps.length) - 28)

  function iconFor(appClass) {
    var webApp = appClass.match(/^chrome-(?:www\.|web\.)?([^.]+)\./)
    var entry = DesktopEntries.heuristicLookup(webApp ? webApp[1] : appClass)
    var icon = entry ? entry.icon : ""
    if (icon.indexOf("/") === 0) return "file://" + icon
    return Quickshell.iconPath(icon !== "" ? icon : "application-x-executable", "application-x-executable")
  }

  function nameFor(appClass) {
    var webApp = appClass.match(/^chrome-(?:www\.|web\.)?([^.]+)\./)
    var entry = DesktopEntries.heuristicLookup(webApp ? webApp[1] : appClass)
    if (entry) return entry.name
    var id = webApp ? webApp[1] : appClass.split(".").pop()
    return id.charAt(0).toUpperCase() + id.slice(1)
  }

  // Called on every Super+Tab: the first press opens, later presses step through the apps.
  function open(payloadJson) {
    var direction = 1
    try {
      direction = JSON.parse(payloadJson || "{}").direction || 1
    } catch (error) {
      console.warn("app switcher: bad payload", error)
    }
    if (opened) {
      step(direction)
      return
    }
    pendingSteps += direction
    if (loading) return
    loading = true
    commitPending = false
    snapshot.running = true
  }

  function close() {
    opened = false
    loading = false
    commitPending = false
    pendingSteps = 0
  }

  function dismiss() {
    close()
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "cupertino.app-switcher")
  }

  function step(direction) {
    if (apps.length === 0) return
    selected = (selected + direction + apps.length) % apps.length
  }

  // Super was released. A fast tap can get here before the window list arrives.
  function commit(argument) {
    if (loading) {
      commitPending = true
      return
    }
    if (!opened) return
    choose(selected)
  }

  function choose(index) {
    var app = apps[index]
    dismiss()
    if (!app) return
    pendingAddress = app.address
    focusDelay.restart()
  }

  function applySnapshot(text) {
    var clients = []
    try {
      clients = JSON.parse(text)
    } catch (error) {
      console.warn("app switcher: bad client list", error)
    }
    var groups = []
    clients
      .filter(function(client) { return client.mapped && !client.hidden && client.workspace.id > 0 })
      .sort(function(a, b) { return a.focusHistoryID - b.focusHistoryID })
      .forEach(function(client) {
        var appClass = client.class === "org.omarchy.agent" ? "com.mitchellh.ghostty" : client.class
        if (!groups.some(function(group) { return group.appClass === appClass })) {
          groups.push({ appClass: appClass, address: client.address })
        }
      })
    apps = groups
    var steps = pendingSteps
    pendingSteps = 0
    selected = 0
    step(steps)
    loading = false

    if (commitPending) {
      commitPending = false
      choose(selected)
      return
    }
    if (groups.length === 0) {
      dismiss()
      return
    }
    opened = true
    Qt.callLater(function() { keys.forceActiveFocus() })
  }

  Process {
    id: snapshot
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      onStreamFinished: root.applySnapshot(text)
    }
  }

  // Focus has to wait for this overlay to give up the keyboard.
  Timer {
    id: focusDelay
    interval: 80
    onTriggered: Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + root.pendingAddress + "\" })")
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-app-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Item {
      id: keys
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) root.dismiss()
        else if (event.key === Qt.Key_Right) root.step(1)
        else if (event.key === Qt.Key_Left) root.step(-1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.choose(root.selected)
        else return
        event.accepted = true
      }
    }

    Rectangle {
      anchors.centerIn: parent
      width: iconRow.width + 24
      height: root.iconSize + 62
      radius: 22
      color: Qt.rgba(0.12, 0.12, 0.12, 0.6)
      border.color: Qt.rgba(1, 1, 1, 0.18)

      Row {
        id: iconRow
        x: 12
        y: 12
        spacing: 4

        Repeater {
          model: root.apps

          Item {
            required property var modelData
            required property int index
            readonly property bool isSelected: index === root.selected
            width: root.iconSize + 20
            height: root.iconSize + 38

            Rectangle {
              x: 0
              y: 0
              width: parent.width
              height: root.iconSize + 18
              radius: 14
              visible: parent.isSelected
              color: Qt.rgba(1, 1, 1, 0.16)
            }

            Image {
              x: 10
              y: 9
              width: root.iconSize
              height: root.iconSize
              source: root.iconFor(modelData.appClass)
              sourceSize: Qt.size(128, 128)
              fillMode: Image.PreserveAspectFit
              smooth: true
              mipmap: true
            }

            Text {
              visible: parent.isSelected
              anchors.horizontalCenter: parent.horizontalCenter
              y: root.iconSize + 21
              textFormat: Text.PlainText
              text: root.nameFor(modelData.appClass)
              color: "#ffffff"
              font.family: "Adwaita Sans"
              font.pixelSize: 13
              font.weight: Font.DemiBold
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.selected = index
              onClicked: root.choose(index)
            }
          }
        }
      }
    }
  }
}
