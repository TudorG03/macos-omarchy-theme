import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons as Commons
import "Layout.js" as Layout

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool closing: false
  property real progress: 0
  property var clients: []
  property string wallpaper: ""
  property var pendingAction: null
  property string selectedAddress: ""
  property var targetScreen: null

  property var dragClient: null
  property real dragX: 0
  property real dragY: 0
  property int dropDesktop: 0

  // App Expose: when set, only this app's windows show, from every desktop.
  property string appMatch: ""
  property string requestedApp: ""
  readonly property bool exposing: appMatch !== ""

  property int draggedDesktop: 0
  property real desktopDragX: 0
  property int desktopInsertSlot: 0

  readonly property int thumbHeight: 84
  readonly property int thumbGap: 16
  readonly property int thumbTop: 14
  readonly property int areaTop: exposing ? 72 : 150
  readonly property int areaMargin: 48
  readonly property int windowGap: 38

  readonly property real screenWidth: panel.width
  readonly property real screenHeight: panel.height
  readonly property real screenX: targetScreen ? targetScreen.x : 0
  readonly property real screenY: targetScreen ? targetScreen.y : 0
  readonly property int currentDesktop: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

  function windowsOn(desktop) {
    return clients.filter(function(client) {
      return client.workspace.id === desktop && client.mapped && !client.hidden
    })
  }

  readonly property var visibleClients: {
    if (!exposing) {
      return windowsOn(currentDesktop).sort(function(a, b) {
        return (a.at[1] - b.at[1]) || (a.at[0] - b.at[0])
      })
    }
    var pattern = new RegExp(appMatch, "i")
    return clients.filter(function(client) {
      return client.mapped && !client.hidden && pattern.test(client.class)
    }).sort(function(a, b) {
      return (a.workspace.id - b.workspace.id) || (a.at[1] - b.at[1]) || (a.at[0] - b.at[0])
    })
  }

  readonly property string exposeTitle: {
    if (!exposing || visibleClients.length === 0) return ""
    var client = visibleClients[0]
    var webApp = client.class.match(/^chrome-(?:www\.|web\.)?([^.]+)\./)
    var entry = DesktopEntries.heuristicLookup(client.class === "org.omarchy.agent" ? "com.mitchellh.ghostty" : (webApp ? webApp[1] : client.class))
    return entry ? entry.name : client.class
  }

  readonly property var rects: Layout.arrange(
    visibleClients.map(function(client) { return { width: client.size[0], height: client.size[1] } }),
    screenWidth - areaMargin * 2,
    screenHeight - areaTop - areaMargin,
    windowGap,
    0.8
  )

  // Desktops run from 1 to the highest in use, so empty ones in between stay reachable.
  readonly property int desktopCount: {
    var highest = Math.max(1, currentDesktop)
    clients.forEach(function(client) { highest = Math.max(highest, client.workspace.id) })
    return highest
  }

  readonly property real thumbWidth: {
    var ideal = thumbHeight * (screenWidth / Math.max(1, screenHeight))
    var available = (screenWidth - 40 - thumbGap * desktopCount) / (desktopCount + 0.5)
    return Math.min(ideal, available)
  }
  readonly property real addWidth: thumbWidth / 2
  readonly property real stripWidth: desktopCount * (thumbWidth + thumbGap) + addWidth
  readonly property real stripX: (screenWidth - stripWidth) / 2

  function desktopAt(x, y) {
    if (exposing) return 0
    if (y < thumbTop || y > thumbTop + thumbHeight + 24) return 0
    var offset = x - stripX
    if (offset < 0 || offset > stripWidth) return 0
    var slot = Math.floor(offset / (thumbWidth + thumbGap))
    return slot + 1
  }

  function toplevelFor(client) {
    var address = client.address.replace(/^0x/, "")
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      if (toplevels[i].address === address) return toplevels[i].wayland
    }
    return null
  }

  function iconFor(client) {
    var webApp = client.class.match(/^chrome-(?:www\.|web\.)?([^.]+)\./)
    var entry = DesktopEntries.heuristicLookup(client.class === "org.omarchy.agent" ? "com.mitchellh.ghostty" : (webApp ? webApp[1] : client.class))
    return Quickshell.iconPath(entry ? entry.icon : "application-x-executable", "application-x-executable")
  }

  function open(payloadJson) {
    if (opened && !closing) return
    var payload = {}
    try {
      payload = JSON.parse(payloadJson || "{}")
    } catch (error) {
      console.warn("mission control: bad payload", error)
    }
    requestedApp = payload.app || ""
    closeAnimation.stop()
    closing = false
    pendingAction = null
    dragClient = null
    dropDesktop = 0
    var monitor = Hyprland.focusedMonitor
    targetScreen = Quickshell.screens.find(function(screen) { return monitor && screen.name === monitor.name }) || Quickshell.screens[0]
    Hyprland.refreshToplevels()
    openAfterSnapshot = true
    refresh()
  }

  function close() {
    openAfterSnapshot = false
    if (!opened || closing) return
    openAnimation.stop()
    closing = true
    closeAnimation.from = progress
    closeAnimation.start()
  }

  function dismiss(action) {
    pendingAction = action || null
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "cupertino.mission-control")
    else close()
  }

  function focusClient(client) {
    dismiss(function() {
      Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + client.address + "\" })")
    })
  }

  function switchTo(desktop) {
    dismiss(function() {
      Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + desktop + "\" })")
    })
  }

  function moveClient(client, desktop) {
    if (client.workspace.id === desktop) return
    Hyprland.dispatch("hl.dsp.window.move({ workspace = \"" + desktop + "\", follow = false, window = \"address:" + client.address + "\" })")
    refreshDelay.restart()
  }

  function selectedClient() {
    var matches = visibleClients.filter(function(client) { return client.address === selectedAddress })
    return matches.length > 0 ? matches[0] : null
  }

  function moveSelection(dx, dy) {
    var index = visibleClients.findIndex(function(client) { return client.address === selectedAddress })
    if (index < 0) {
      if (visibleClients.length > 0) selectedAddress = visibleClients[0].address
      return
    }
    var from = rects[index]
    var bestIndex = -1
    var bestScore = Infinity
    rects.forEach(function(rect, candidate) {
      if (candidate === index) return
      var along = (rect.x + rect.width / 2 - from.x - from.width / 2) * dx + (rect.y + rect.height / 2 - from.y - from.height / 2) * dy
      var across = Math.abs((rect.x + rect.width / 2 - from.x - from.width / 2) * dy) + Math.abs((rect.y + rect.height / 2 - from.y - from.height / 2) * dx)
      if (along > 0 && along + across * 2 < bestScore) {
        bestScore = along + across * 2
        bestIndex = candidate
      }
    })
    if (bestIndex >= 0) selectedAddress = visibleClients[bestIndex].address
  }

  function resolveApp(request) {
    if (request !== "current") return request
    var focused = clients.filter(function(client) { return client.focusHistoryID === 0 })
    if (focused.length === 0) return ""
    if (/ghostty|org\.omarchy\.agent/.test(focused[0].class)) return "ghostty|org\\.omarchy\\.agent"
    return "^" + focused[0].class.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$"
  }

  // Applies old desktop -> new desktop to every window in one batch, then follows the current desktop.
  function remapDesktops(mapping) {
    var commands = []
    clients.forEach(function(client) {
      var target = mapping[client.workspace.id]
      if (target !== undefined && target !== client.workspace.id) {
        commands.push("dispatch hl.dsp.window.move({ workspace = \"" + target + "\", follow = false, window = \"address:" + client.address + "\" })")
      }
    })
    var current = mapping[currentDesktop]
    if (current !== undefined && current !== currentDesktop) {
      commands.push("dispatch hl.dsp.focus({ workspace = \"" + current + "\" })")
    }
    if (commands.length === 0) return
    Quickshell.execDetached(["hyprctl", "--batch", commands.join(" ; ")])
    refreshDelay.interval = 180
    refreshDelay.restart()
  }

  // Its windows join the desktop before it (or the next one, for Desktop 1), and later desktops close the gap.
  function deleteDesktop(desktop) {
    if (desktopCount <= 1) return
    var mapping = {}
    for (var old = 1; old <= desktopCount; old++) {
      if (old < desktop) mapping[old] = old
      else if (old === desktop) mapping[old] = Math.max(1, desktop - 1)
      else mapping[old] = old - 1
    }
    remapDesktops(mapping)
  }

  function reorderDesktop(desktop, slot) {
    var order = []
    for (var old = 1; old <= desktopCount; old++) {
      if (old !== desktop) order.push(old)
    }
    order.splice(slot, 0, desktop)
    var mapping = {}
    order.forEach(function(old, index) { mapping[old] = index + 1 })
    remapDesktops(mapping)
  }

  // Where a desktop's thumbnail sits while another one is being dragged.
  function displaySlot(desktop) {
    if (draggedDesktop === 0) return desktop - 1
    var order = []
    for (var old = 1; old <= desktopCount; old++) {
      if (old !== draggedDesktop) order.push(old)
    }
    order.splice(desktopInsertSlot, 0, draggedDesktop)
    return order.indexOf(desktop)
  }

  function applySnapshot(text) {
    var split = text.indexOf("\n")
    var path = text.slice(0, split).trim()
    if (path !== "") wallpaper = "file://" + path

    var parsed = []
    try {
      parsed = JSON.parse(text.slice(split + 1))
    } catch (error) {
      console.warn("mission control: bad client list", error)
    }
    clients = parsed.filter(function(client) { return client.workspace.id > 0 })

    if (openAfterSnapshot) {
      appMatch = resolveApp(requestedApp)
      selectedAddress = ""
    }

    if (!selectedClient()) {
      var recent = visibleClients.slice().sort(function(a, b) { return a.focusHistoryID - b.focusHistoryID })
      selectedAddress = recent.length > 0 ? recent[0].address : ""
    }

    if (openAfterSnapshot) {
      openAfterSnapshot = false
      opened = true
      openAnimation.from = progress
      openAnimation.start()
      Qt.callLater(function() { keys.forceActiveFocus() })
    }
  }

  property bool openAfterSnapshot: false
  property bool refreshAgain: false

  function refresh() {
    if (snapshot.running) refreshAgain = true
    else snapshot.running = true
  }

  Process {
    id: snapshot
    command: ["sh", "-c", "readlink -f \"$HOME/.local/state/omarchy/current/background\"; hyprctl -j clients"]
    stdout: StdioCollector {
      onStreamFinished: root.applySnapshot(text)
    }
    onExited: {
      if (!root.refreshAgain) return
      root.refreshAgain = false
      running = true
    }
  }

  Timer {
    id: refreshDelay
    interval: 60
    onTriggered: {
      interval = 60
      root.refresh()
    }
  }

  // Keeps the overview true when windows open or close underneath it.
  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() {
      if (root.opened) refreshDelay.restart()
    }
  }

  // Wait for the overlay to give up the keyboard, or Hyprland hands focus straight back.
  Timer {
    id: actionDelay
    interval: 80
    onTriggered: {
      var action = root.pendingAction
      root.pendingAction = null
      if (action) action()
    }
  }

  NumberAnimation {
    id: openAnimation
    target: root
    property: "progress"
    to: 1
    duration: 260
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: closeAnimation
    target: root
    property: "progress"
    to: 0
    duration: 200
    easing.type: Easing.OutCubic
    onFinished: {
      root.opened = false
      root.closing = false
      root.appMatch = ""
      actionDelay.restart()
    }
  }

  Component.onCompleted: refresh()

  PanelWindow {
    id: panel
    visible: root.opened
    screen: root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-mission-control"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Item {
      anchors.fill: parent
      opacity: root.progress

      Image {
        id: backdrop
        anchors.fill: parent
        source: root.wallpaper
        sourceSize: Qt.size(root.screenWidth, root.screenHeight)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.28)
      }
    }

    Item {
      id: keys
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        var digit = event.key - Qt.Key_0
        if (event.key === Qt.Key_Escape) {
          root.dismiss()
        } else if (event.key === Qt.Key_Left) {
          root.moveSelection(-1, 0)
        } else if (event.key === Qt.Key_Right) {
          root.moveSelection(1, 0)
        } else if (event.key === Qt.Key_Up) {
          root.moveSelection(0, -1)
        } else if (event.key === Qt.Key_Down) {
          root.moveSelection(0, 1)
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          var client = root.selectedClient()
          if (client) root.focusClient(client)
          else root.dismiss()
        } else if (digit >= 1 && digit <= 9) {
          if (event.modifiers & Qt.ControlModifier) {
            var selected = root.selectedClient()
            if (selected) root.moveClient(selected, digit)
          } else {
            root.switchTo(digit)
          }
        } else {
          return
        }
        event.accepted = true
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: root.dismiss()
    }

    Text {
      visible: root.visibleClients.length === 0 && root.opened
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.areaTop + (parent.height - root.areaTop) / 2 - 20
      text: "No windows on this desktop"
      opacity: 0.7 * root.progress
      color: "#ffffff"
      font.family: "Adwaita Sans"
      font.pixelSize: 18
    }

    Text {
      visible: root.exposing
      anchors.horizontalCenter: parent.horizontalCenter
      y: 22
      textFormat: Text.PlainText
      text: root.exposeTitle
      opacity: root.progress
      color: "#ffffff"
      font.family: "Adwaita Sans"
      font.pixelSize: 24
      font.weight: Font.DemiBold
    }

    Repeater {
      model: root.exposing ? 0 : root.desktopCount

      Item {
        required property int index
        readonly property int desktop: index + 1
        readonly property bool active: desktop === root.currentDesktop
        readonly property bool dropping: root.dropDesktop === desktop
        readonly property bool draggedThumb: root.draggedDesktop === desktop

        x: draggedThumb
          ? root.desktopDragX - width / 2
          : root.stripX + root.displaySlot(desktop) * (root.thumbWidth + root.thumbGap)
        y: root.thumbTop - (1 - root.progress) * 130
        z: draggedThumb ? 5 : 0
        width: root.thumbWidth
        height: root.thumbHeight + 24
        opacity: root.progress

        Behavior on x {
          enabled: root.draggedDesktop !== 0 && !draggedThumb
          NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        ClippingRectangle {
          id: thumb
          width: parent.width
          height: root.thumbHeight
          radius: 8
          color: "#1e1e1e"

          Image {
            anchors.fill: parent
            source: root.wallpaper
            sourceSize: Qt.size(320, 160)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
          }

          Repeater {
            model: root.opened ? root.windowsOn(desktop) : []

            ClippingRectangle {
              required property var modelData
              readonly property real thumbScale: root.thumbWidth / root.screenWidth

              x: (modelData.at[0] - root.screenX) * thumbScale
              y: (modelData.at[1] - root.screenY) * (root.thumbHeight / root.screenHeight)
              width: modelData.size[0] * thumbScale
              height: modelData.size[1] * (root.thumbHeight / root.screenHeight)
              radius: 2
              color: "#2c2c2e"

              Image {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.6
                height: width
                source: root.iconFor(modelData)
                sourceSize: Qt.size(48, 48)
              }

              ScreencopyView {
                anchors.fill: parent
                captureSource: root.toplevelFor(modelData)
                live: false
              }
            }
          }
        }

        Rectangle {
          width: thumb.width
          height: thumb.height
          radius: 8
          color: parent.dropping ? Qt.rgba(0.04, 0.52, 1, 0.3) : "transparent"
          border.width: parent.dropping || parent.active || thumbMouse.containsMouse ? 2 : 1
          border.color: parent.dropping ? "#0a84ff" : (parent.active ? "#ffffff" : Qt.rgba(1, 1, 1, thumbMouse.containsMouse ? 0.7 : 0.25))
        }

        Text {
          y: root.thumbHeight + 5
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: "Desktop " + parent.desktop
          color: "#ffffff"
          opacity: parent.active ? 1 : 0.75
          font.family: "Adwaita Sans"
          font.pixelSize: 12
          font.weight: parent.active ? Font.DemiBold : Font.Normal
        }

        MouseArea {
          id: thumbMouse
          anchors.fill: parent
          hoverEnabled: true
          preventStealing: true
          cursorShape: parent.draggedThumb ? Qt.ClosedHandCursor : Qt.PointingHandCursor
          property real pressX: 0
          property bool movedThumb: false

          onPressed: function(mouse) {
            pressX = mouse.x
            movedThumb = false
          }
          onPositionChanged: function(mouse) {
            if (!pressed) return
            if (!movedThumb && Math.abs(mouse.x - pressX) < 10) return
            movedThumb = true
            var point = mapToItem(keys, mouse.x, mouse.y)
            root.draggedDesktop = parent.desktop
            root.desktopDragX = point.x
            var slot = Math.floor((point.x - root.stripX) / (root.thumbWidth + root.thumbGap))
            root.desktopInsertSlot = Math.max(0, Math.min(root.desktopCount - 1, slot))
          }
          onReleased: {
            if (root.draggedDesktop === 0) return
            var desktop = root.draggedDesktop
            var slot = root.desktopInsertSlot
            root.draggedDesktop = 0
            root.reorderDesktop(desktop, slot)
          }
          onClicked: if (!movedThumb) root.switchTo(parent.desktop)

          // Delete button; windows move to a neighbouring desktop, so nothing is lost.
          Rectangle {
            visible: thumbMouse.containsMouse && root.desktopCount > 1 && root.draggedDesktop === 0
            x: -7
            y: -7
            width: 20
            height: 20
            radius: 10
            color: deleteMouse.containsMouse ? "#ff453a" : "#3a3a3c"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.4)

            Text {
              anchors.centerIn: parent
              text: "\u00d7"
              color: "#ffffff"
              font.family: "Adwaita Sans"
              font.pixelSize: 15
            }

            MouseArea {
              id: deleteMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.deleteDesktop(thumbMouse.parent.desktop)
            }
          }
        }
      }
    }

    Rectangle {
      visible: !root.exposing
      x: root.stripX + root.desktopCount * (root.thumbWidth + root.thumbGap)
      y: root.thumbTop - (1 - root.progress) * 130
      width: root.addWidth
      height: root.thumbHeight
      radius: 8
      opacity: root.progress
      readonly property bool dropping: root.dropDesktop === root.desktopCount + 1
      color: dropping ? Qt.rgba(0.04, 0.52, 1, 0.3) : Qt.rgba(1, 1, 1, addMouse.containsMouse ? 0.22 : 0.1)
      border.width: dropping ? 2 : 1
      border.color: dropping ? "#0a84ff" : Qt.rgba(1, 1, 1, 0.25)

      Text {
        anchors.centerIn: parent
        text: "+"
        color: "#ffffff"
        font.family: "Adwaita Sans"
        font.pixelSize: 28
        font.weight: Font.Light
      }

      MouseArea {
        id: addMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.switchTo(root.desktopCount + 1)
      }
    }

    Repeater {
      model: root.visibleClients

      Item {
        id: preview
        required property var modelData
        required property int index

        readonly property var rect: root.rects[index] || { x: 0, y: 0, width: 1, height: 1 }
        readonly property bool selected: root.selectedAddress === modelData.address
        readonly property bool dragged: root.dragClient !== null && root.dragClient.address === modelData.address
        readonly property real restX: root.areaMargin + rect.x
        readonly property real restY: root.areaTop + rect.y
        readonly property bool onCurrentDesktop: modelData.workspace.id === root.currentDesktop
        readonly property real restWidth: rect.width
        readonly property real restHeight: rect.height
        readonly property real startX: onCurrentDesktop ? modelData.at[0] - root.screenX : restX
        readonly property real startY: onCurrentDesktop ? modelData.at[1] - root.screenY : restY
        readonly property real startWidth: onCurrentDesktop ? modelData.size[0] : restWidth
        readonly property real startHeight: onCurrentDesktop ? modelData.size[1] : restHeight
        opacity: onCurrentDesktop ? 1 : root.progress

        x: dragged ? root.dragX - width / 2 : startX + (restX - startX) * root.progress
        y: dragged ? root.dragY - height / 2 : startY + (restY - startY) * root.progress
        // Shrinks near the strip so the desktop it's aimed at stays visible.
        width: dragged ? Math.min(rect.width, root.dragY < root.areaTop ? 96 : 360) : startWidth + (restWidth - startWidth) * root.progress
        height: dragged ? width * rect.height / rect.width : startHeight + (restHeight - startHeight) * root.progress
        z: dragged ? 10 : (selected ? 1 : 0)

        ClippingRectangle {
          anchors.fill: parent
          radius: 10
          color: "#1e1e1e"

          Image {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.3
            height: width
            source: root.iconFor(preview.modelData)
            sourceSize: Qt.size(128, 128)
          }

          ScreencopyView {
            anchors.fill: parent
            captureSource: root.toplevelFor(preview.modelData)
            live: root.opened
          }
        }

        Rectangle {
          anchors.fill: parent
          anchors.margins: -3
          radius: 13
          color: "transparent"
          visible: preview.selected && !root.closing
          border.width: 3
          border.color: "#0a84ff"
        }

        Rectangle {
          anchors.top: parent.bottom
          anchors.topMargin: 9
          anchors.horizontalCenter: parent.horizontalCenter
          visible: preview.selected && !root.closing && !preview.dragged
          width: Math.min(titleText.implicitWidth + 20, Math.max(parent.width, 200))
          height: titleText.implicitHeight + 8
          radius: 7
          color: Qt.rgba(0.12, 0.12, 0.12, 0.85)

          Text {
            id: titleText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 20)
            textFormat: Text.PlainText
            text: (preview.modelData.title || preview.modelData.class) + (root.exposing ? "  \u2014  Desktop " + preview.modelData.workspace.id : "")
            elide: Text.ElideRight
            color: "#ffffff"
            font.family: "Adwaita Sans"
            font.pixelSize: 13
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: root.dragClient ? Qt.ClosedHandCursor : Qt.PointingHandCursor
          property real pressX: 0
          property real pressY: 0

          onEntered: root.selectedAddress = preview.modelData.address
          onPressed: function(mouse) {
            pressX = mouse.x
            pressY = mouse.y
          }
          onPositionChanged: function(mouse) {
            if (!pressed) return
            var point = mapToItem(keys, mouse.x, mouse.y)
            if (!root.dragClient && Math.hypot(mouse.x - pressX, mouse.y - pressY) < 10) return
            root.dragClient = preview.modelData
            root.dragX = point.x
            root.dragY = point.y
            root.dropDesktop = root.desktopAt(point.x, point.y)
          }
          onReleased: {
            if (!root.dragClient) return
            var client = root.dragClient
            var desktop = root.dropDesktop
            root.dragClient = null
            root.dropDesktop = 0
            if (desktop > 0) root.moveClient(client, desktop)
          }
          onClicked: if (Math.hypot(mouseX - pressX, mouseY - pressY) < 10) root.focusClient(preview.modelData)
        }
      }
    }
  }
}
