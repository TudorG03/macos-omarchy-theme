import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons as Commons

Item {
  id: root

  property var shell: null

  // `match` finds a pinned app's windows by app id, for apps whose id differs from their desktop file.
  // Edit this list to change the Dock. Apps that are not installed are skipped.
  readonly property var pinCandidates: [
    { id: "org.gnome.Nautilus", match: "nautilus" },
    { match: "(?!)", name: "Launchpad", icon: "launchpad", command: ["omarchy-shell", "shell", "toggle", "cupertino.launchpad", "{}"] },
    { match: "(?!)", name: "Mission Control", icon: "mission-control", command: ["omarchy-shell", "shell", "toggle", "cupertino.mission-control", "{}"] },
    { id: "zen", match: "^zen" },
    { id: "chromium", match: "^chromium" },
    { id: "com.mitchellh.ghostty", match: "ghostty|org\\.omarchy\\.agent", icon: "com.mitchellh.ghostty" },
    { id: "spotify", match: "spotify" },
    { id: "obsidian", match: "obsidian" }
  ]
  readonly property var pins: {
    DesktopEntries.applications.values
    return pinCandidates.filter(function(pin) { return !pin.id || !!DesktopEntries.byId(pin.id) })
  }

  readonly property int iconBase: 36
  readonly property int iconGap: 5
  readonly property int padding: 7
  readonly property int edgeGap: 4
  readonly property int dividerWidth: 13
  readonly property real maxScale: 1.6
  readonly property real sigma: 56
  readonly property int dockHeight: iconBase + padding * 2
  readonly property int step: iconBase + iconGap

  readonly property var toplevels: ToplevelManager.toplevels.values

  function isPinned(appId) {
    return pins.some(function(pin) { return new RegExp(pin.match, "i").test(appId) })
  }

  // A plain string only notifies when the set of apps changes, so window churn keeps delegates alive.
  readonly property string extrasKey: {
    var seen = []
    for (var i = 0; i < toplevels.length; i++) {
      var appId = toplevels[i].appId
      if (appId && !isPinned(appId) && seen.indexOf(appId) < 0) seen.push(appId)
    }
    return seen.join("\n")
  }
  readonly property var extras: extrasKey === "" ? [] : extrasKey.split("\n")

  // Pins, divider, unpinned apps, then Trash.
  readonly property real extrasStart: pins.length * step + dividerWidth + iconGap
  readonly property real baseWidth: extrasStart + (extras.length + 1) * step - iconGap

  function workspaceOf(toplevel) {
    var hyprlandToplevels = Hyprland.toplevels.values
    for (var i = 0; i < hyprlandToplevels.length; i++) {
      if (hyprlandToplevels[i].wayland === toplevel) return hyprlandToplevels[i].workspace
    }
    return null
  }

  // Hyprland ignores foreign-toplevel activation across workspaces, so ask it to focus by address.
  function focusWindow(toplevel) {
    var hyprlandToplevels = Hyprland.toplevels.values
    for (var i = 0; i < hyprlandToplevels.length; i++) {
      if (hyprlandToplevels[i].wayland === toplevel) {
        var address = "address:0x" + hyprlandToplevels[i].address
        // Minimized windows wait on a hidden workspace; bring them back first.
        var workspace = hyprlandToplevels[i].workspace
        if (workspace && workspace.name === "special:minimized") {
          var current = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
          Hyprland.dispatch("hl.dsp.window.move({ workspace = \"" + current + "\", follow = false, window = \"" + address + "\" })")
        }
        Hyprland.dispatch("hl.dsp.focus({ window = \"" + address + "\" })")
        return
      }
    }
    toplevel.activate()
  }

  // Ordered by workspace, with special workspaces (negative ids) last, so cycling walks the desktops in order.
  function windowsFor(match) {
    var pattern = new RegExp(match, "i")
    function rank(toplevel) {
      var workspace = workspaceOf(toplevel)
      var id = workspace ? workspace.id : 0
      return id > 0 ? id : 100000 - id
    }
    return toplevels
      .filter(function(toplevel) { return pattern.test(toplevel.appId || "") })
      .map(function(toplevel, index) { return { toplevel: toplevel, rank: rank(toplevel), index: index } })
      .sort(function(a, b) { return a.rank - b.rank || a.index - b.index })
      .map(function(item) { return item.toplevel })
  }

  // Focused app: step to its next window. Otherwise prefer a window already on this desktop.
  function nextWindow(windows) {
    for (var i = 0; i < windows.length; i++) {
      if (windows[i].activated) return windows[(i + 1) % windows.length]
    }
    var current = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    for (var j = 0; j < windows.length; j++) {
      var workspace = workspaceOf(windows[j])
      if (workspace && workspace.id === current) return windows[j]
    }
    return windows[0]
  }

  function workspaceLabel(toplevel) {
    var workspace = workspaceOf(toplevel)
    if (!workspace) return ""
    if (workspace.name === "special:minimized") return "Minimized"
    return workspace.id > 0 ? "Desktop " + workspace.id : "Scratchpad"
  }

  property var menuIcon: null
  property var menuScreen: null
  property real menuCenterX: 0

  readonly property var menuWindows: menuIcon ? windowsFor(menuIcon.match) : []

  function openMenu(icon, screen, centerX) {
    Hyprland.refreshToplevels()
    menuIcon = icon
    menuScreen = screen
    menuCenterX = centerX
  }

  function closeMenu() {
    menuIcon = null
    menuScreen = null
  }

  onToplevelsChanged: Hyprland.refreshToplevels()
  Component.onCompleted: Hyprland.refreshToplevels()

  Variants {
    model: Quickshell.screens

    Item {
      id: screenDock
      required property var modelData

      PanelWindow {
        id: dockWindow
        screen: screenDock.modelData

        WlrLayershell.namespace: "omarchy-dock"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // Windows keep the full height; the Dock floats over them when it's revealed.
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        anchors { left: true; right: true; bottom: true }
        implicitHeight: root.dockHeight + root.edgeGap + root.iconBase * (root.maxScale - 1) + 44

        mask: Region {
          item: revealStrip
          Region { item: hitArea }
        }

        // Stays out while the pointer is on it or its menu is open, then tucks away after a moment.
        readonly property bool wanted: pointer.hovered || (root.menuIcon !== null && root.menuScreen === screenDock.modelData)
        property bool revealed: false
        property real shown: revealed ? 1 : 0
        Behavior on shown {
          NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
        }

        onWantedChanged: {
          if (wanted) {
            hideDelay.stop()
            revealed = true
          } else {
            hideDelay.restart()
          }
        }

        Timer {
          id: hideDelay
          interval: 350
          onTriggered: dockWindow.revealed = false
        }

        // Magnification keys off the unmagnified layout so growth never feeds back into the pointer position.
        readonly property real pointerBaseX: pointer.pointX - (width - root.baseWidth) / 2
        property real hoverAmount: pointer.hovered && !root.menuIcon ? 1 : 0
        Behavior on hoverAmount {
          NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        Item {
          id: stage
          anchors.fill: parent

          HoverHandler {
            id: pointer
            property real pointX: 0
            onPointChanged: if (hovered) pointX = point.position.x
          }

          // The bottom edge of the screen. It stops short of the corners, which belong to the hot corners.
          Item {
            id: revealStrip
            anchors.bottom: parent.bottom
            x: 8
            width: parent.width - 16
            height: 2
          }

          Item {
            id: hitArea
            anchors.bottom: parent.bottom
            x: dockBody.x
            width: dockBody.width
            height: dockWindow.revealed ? root.dockHeight + root.edgeGap + (pointer.hovered ? root.iconBase * (root.maxScale - 1) : 0) : 0
          }

          Rectangle {
            id: dockBody
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.edgeGap - (1 - dockWindow.shown) * (root.dockHeight + root.edgeGap + 6)
            visible: dockWindow.shown > 0
            width: iconRow.width + root.padding * 2
            height: root.dockHeight
            radius: 15
            color: Qt.rgba(Commons.Color.background.r, Commons.Color.background.g, Commons.Color.background.b, 0.45)
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1

            Row {
              id: iconRow
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: root.padding
              spacing: root.iconGap

              Repeater {
                model: root.pins
                DockIcon {
                  required property var modelData
                  required property int index
                  dock: root
                  screen: screenDock.modelData
                  desktopId: modelData.id || ""
                  iconName: modelData.icon || ""
                  launchCommand: modelData.command || []
                  match: modelData.match
                  nameOverride: modelData.name || ""
                  baseCenter: index * root.step + root.iconBase / 2
                  pointerX: dockWindow.pointerBaseX
                  hoverAmount: dockWindow.hoverAmount
                }
              }

              Item {
                width: root.dividerWidth
                height: root.iconBase
                Rectangle {
                  anchors.centerIn: parent
                  width: 1
                  height: parent.height - 6
                  color: Qt.rgba(1, 1, 1, 0.25)
                }
              }

              Repeater {
                model: root.extras
                DockIcon {
                  required property var modelData
                  required property int index
                  dock: root
                  screen: screenDock.modelData
                  appId: modelData
                  match: "^" + modelData.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$"
                  baseCenter: root.extrasStart + index * root.step + root.iconBase / 2
                  pointerX: dockWindow.pointerBaseX
                  hoverAmount: dockWindow.hoverAmount
                }
              }

              DockIcon {
                dock: root
                screen: screenDock.modelData
                match: "(?!)"
                nameOverride: "Trash"
                iconName: "user-trash"
                launchCommand: ["nautilus", "--new-window", "trash:///"]
                baseCenter: root.extrasStart + root.extras.length * root.step + root.iconBase / 2
                pointerX: dockWindow.pointerBaseX
                hoverAmount: dockWindow.hoverAmount
              }
            }
          }
        }
      }

      PanelWindow {
        id: menuWindow
        screen: screenDock.modelData
        visible: root.menuIcon !== null && root.menuScreen === screenDock.modelData

        WlrLayershell.namespace: "omarchy-dock-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }

        onVisibleChanged: if (visible) menuKeys.forceActiveFocus()

        Item {
          id: menuKeys
          anchors.fill: parent
          focus: true
          Keys.onEscapePressed: root.closeMenu()
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          onClicked: root.closeMenu()
        }

        Rectangle {
          id: menuCard
          width: 340
          height: menuColumn.implicitHeight + 12
          x: Math.max(8, Math.min(parent.width - width - 8, root.menuCenterX - width / 2))
          anchors.bottom: parent.bottom
          anchors.bottomMargin: root.dockHeight + root.edgeGap + 10
          radius: 12
          color: Qt.rgba(Commons.Color.background.r, Commons.Color.background.g, Commons.Color.background.b, 0.72)
          border.color: Qt.rgba(1, 1, 1, 0.18)
          border.width: 1

          // Swallow clicks on the card itself so they don't dismiss the menu.
          MouseArea { anchors.fill: parent }

          Column {
            id: menuColumn
            x: 6
            y: 6
            width: parent.width - 12

            Text {
              x: 10
              height: 26
              verticalAlignment: Text.AlignVCenter
              textFormat: Text.PlainText
              text: root.menuIcon ? root.menuIcon.label : ""
              color: Commons.Color.foreground
              opacity: 0.6
              font.family: "Adwaita Sans"
              font.pixelSize: 12
              font.weight: Font.DemiBold
            }

            Repeater {
              model: root.menuWindows
              MenuRow {
                required property var modelData
                width: menuColumn.width
                text: modelData.title || modelData.appId || ""
                detail: root.workspaceLabel(modelData)
                checked: modelData.activated
                onActivated: {
                  // Closing the menu destroys this row and its scope, so it has to come last.
                  root.focusWindow(modelData)
                  root.closeMenu()
                }
              }
            }

            Rectangle {
              visible: root.menuWindows.length > 0
              x: 10
              width: parent.width - 20
              height: visible ? 9 : 0
              color: "transparent"
              Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.14)
              }
            }

            MenuRow {
              visible: root.menuWindows.length > 0
              width: menuColumn.width
              text: "Show All Windows"
              onActivated: {
                var match = root.menuIcon.match
                root.closeMenu()
                Quickshell.execDetached(["omarchy-shell", "shell", "summon", "cupertino.mission-control", JSON.stringify({ app: match })])
              }
            }

            MenuRow {
              width: menuColumn.width
              text: root.menuWindows.length > 0 ? "New Window" : "Open"
              onActivated: {
                var icon = root.menuIcon
                root.closeMenu()
                icon.launch()
              }
            }
          }
        }
      }
    }
  }
}
