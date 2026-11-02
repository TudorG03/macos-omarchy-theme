import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property real progress: 0
  property string query: ""
  property int page: 0

  readonly property int cellWidth: 158
  readonly property int cellHeight: 146
  readonly property int columns: Math.max(4, Math.min(9, Math.floor((panel.width - 160) / cellWidth)))
  readonly property int rows: Math.max(2, Math.floor((panel.height - 210) / cellHeight))
  readonly property int perPage: columns * rows

  function displayName(entry) {
    return entry.name
  }

  readonly property var apps: {
    var needle = query.trim().toLowerCase()
    return DesktopEntries.applications.values
      .filter(function(entry) {
        return !entry.noDisplay && (needle === "" || displayName(entry).toLowerCase().indexOf(needle) >= 0)
      })
      .sort(function(a, b) { return displayName(a).localeCompare(displayName(b)) })
  }
  readonly property int pageCount: Math.max(1, Math.ceil(apps.length / perPage))

  onQueryChanged: page = 0
  onPageCountChanged: page = Math.min(page, pageCount - 1)

  function open(payloadJson) {
    query = ""
    page = 0
    opened = true
    closeAnimation.stop()
    openAnimation.start()
    Qt.callLater(function() { search.forceActiveFocus() })
  }

  function close() {
    if (!opened) return
    openAnimation.stop()
    closeAnimation.start()
  }

  function dismiss() {
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "cupertino.launchpad")
    else close()
  }

  function launch(entry) {
    Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", entry.id + ".desktop"])
    dismiss()
  }

  function turn(delta) {
    page = Math.max(0, Math.min(pageCount - 1, page + delta))
  }

  NumberAnimation {
    id: openAnimation
    target: root
    property: "progress"
    to: 1
    duration: 200
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: closeAnimation
    target: root
    property: "progress"
    to: 0
    duration: 160
    easing.type: Easing.OutCubic
    onFinished: root.opened = false
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-launchpad"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.5 * root.progress)
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: root.dismiss()
      onWheel: function(wheel) {
        if (!pagedWheel.running) {
          root.turn(wheel.angleDelta.y < 0 ? 1 : -1)
          pagedWheel.start()
        }
      }
      Timer {
        id: pagedWheel
        interval: 280
      }
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      y: 34
      width: 260
      height: 32
      radius: 9
      opacity: root.progress
      color: Qt.rgba(1, 1, 1, 0.14)
      border.color: Qt.rgba(1, 1, 1, 0.2)

      Text {
        x: 10
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        text: ""
        color: "#c7c7cc"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
      }

      TextInput {
        id: search
        x: 32
        width: parent.width - 42
        height: parent.height
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        focus: true
        color: "#ffffff"
        selectionColor: "#0a84ff"
        font.family: "Adwaita Sans"
        font.pixelSize: 14
        text: root.query
        onTextEdited: root.query = text

        Text {
          anchors.fill: parent
          verticalAlignment: Text.AlignVCenter
          visible: search.text === ""
          text: "Search"
          color: "#c7c7cc"
          font: search.font
        }

        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.query !== "") root.query = ""
            else root.dismiss()
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.apps.length > 0) root.launch(root.apps[root.page * root.perPage])
          } else if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown) {
            root.turn(1)
          } else if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp) {
            root.turn(-1)
          } else {
            return
          }
          event.accepted = true
        }
      }
    }

    Item {
      id: pages
      anchors.horizontalCenter: parent.horizontalCenter
      y: 92
      width: root.columns * root.cellWidth
      height: root.rows * root.cellHeight
      opacity: root.progress
      scale: 1.06 - 0.06 * root.progress
      clip: true

      Item {
        x: -root.page * pages.width
        Behavior on x {
          NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        // QIcon isn't safe off the GUI thread, so these load synchronously and only exist while open.
        Repeater {
          model: root.opened ? root.apps : []

          Item {
            required property var modelData
            required property int index
            readonly property int pageIndex: Math.floor(index / root.perPage)
            readonly property int slot: index % root.perPage

            x: pageIndex * pages.width + (slot % root.columns) * root.cellWidth
            y: Math.floor(slot / root.columns) * root.cellHeight
            width: root.cellWidth
            height: root.cellHeight

            Image {
              anchors.horizontalCenter: parent.horizontalCenter
              y: 10
              width: appMouse.containsMouse ? 92 : 86
              height: width
              source: {
                var icon = modelData.icon || ""
                if (icon.indexOf("/") === 0) return "file://" + icon
                return Quickshell.iconPath(icon !== "" ? icon : "application-x-executable", "application-x-executable")
              }
              sourceSize: Qt.size(128, 128)
              fillMode: Image.PreserveAspectFit
              smooth: true
              mipmap: true
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              y: 106
              width: parent.width - 14
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: root.displayName(modelData)
              elide: Text.ElideRight
              color: "#ffffff"
              font.family: "Adwaita Sans"
              font.pixelSize: 13
              style: Text.Raised
              styleColor: Qt.rgba(0, 0, 0, 0.4)
            }

            MouseArea {
              id: appMouse
              anchors.fill: parent
              anchors.margins: 6
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.launch(modelData)
            }
          }
        }
      }
    }

    Row {
      visible: root.pageCount > 1
      anchors.horizontalCenter: parent.horizontalCenter
      y: pages.y + pages.height + 14
      spacing: 10
      opacity: root.progress

      Repeater {
        model: root.pageCount
        Rectangle {
          required property int index
          width: 8
          height: 8
          radius: 4
          color: index === root.page ? "#ffffff" : Qt.rgba(1, 1, 1, 0.35)
          MouseArea {
            anchors.fill: parent
            anchors.margins: -5
            cursorShape: Qt.PointingHandCursor
            onClicked: root.page = index
          }
        }
      }
    }
  }
}
