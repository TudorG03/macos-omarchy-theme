import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "cupertino.clock"

  property date now: new Date()
  property bool centerOpen: false
  property real slide: 0
  property date shownMonth: new Date()
  property var notifications: []

  readonly property string historyDir: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/history"
  readonly property int panelWidth: 380

  implicitWidth: label.implicitWidth + 16
  implicitHeight: barSize

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }

  function toggle() {
    if (centerOpen) {
      closeSlide.start()
      return
    }
    shownMonth = new Date()
    history.running = true
    centerOpen = true
    openSlide.start()
  }

  function ago(timestamp) {
    var minutes = Math.floor((Date.now() - timestamp) / 60000)
    if (minutes < 1) return "now"
    if (minutes < 60) return minutes + "m ago"
    if (minutes < 1440) return Math.floor(minutes / 60) + "h ago"
    return Qt.formatDate(new Date(timestamp), "MMM d")
  }

  function plain(text) {
    return String(text || "").replace(/<a\b[^>]*>.*?<\/a>/g, "").replace(/<[^>]*>/g, "").replace(/\s*\n\s*/g, " ").trim()
  }

  function monthCells() {
    var first = new Date(shownMonth.getFullYear(), shownMonth.getMonth(), 1)
    var days = new Date(shownMonth.getFullYear(), shownMonth.getMonth() + 1, 0).getDate()
    var cells = []
    for (var blank = 0; blank < first.getDay(); blank++) cells.push(0)
    for (var day = 1; day <= days; day++) cells.push(day)
    return cells
  }

  Process {
    id: history
    command: ["sh", "-c", "cat \"$1\"/*.json 2>/dev/null", "--", root.historyDir]
    stdout: StdioCollector {
      onStreamFinished: {
        var rows = []
        text.split("\n").forEach(function(line) {
          if (line.trim() === "") return
          try {
            rows.push(JSON.parse(line))
          } catch (error) {
            console.warn("notification center: skipped a bad history row", error)
          }
        })
        rows.sort(function(a, b) { return b.timestamp - a.timestamp })
        root.notifications = rows
      }
    }
  }

  NumberAnimation {
    id: openSlide
    target: root
    property: "slide"
    to: 1
    duration: 240
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: closeSlide
    target: root
    property: "slide"
    to: 0
    duration: 180
    easing.type: Easing.InCubic
    onFinished: root.centerOpen = false
  }

  Text {
    id: label
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: Qt.formatDateTime(root.now, "ddd MMM d  HH:mm")
    color: root.bar ? root.bar.barForeground : Commons.Color.foreground
    font.family: "Adwaita Sans"
    font.pixelSize: 13
    font.weight: Font.Medium
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggle()
  }

  PanelWindow {
    screen: root.QsWindow.window ? root.QsWindow.window.screen : null
    visible: root.centerOpen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onVisibleChanged: if (visible) centerKeys.forceActiveFocus()

    Item {
      id: centerKeys
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.toggle()
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: root.toggle()
    }

    Rectangle {
      x: parent.width - (root.panelWidth + 10) * root.slide
      y: root.barSize + 6
      width: root.panelWidth
      height: parent.height - y - 8
      radius: 18
      color: Qt.rgba(0.12, 0.12, 0.12, 0.62)
      border.color: Qt.rgba(1, 1, 1, 0.16)

      MouseArea { anchors.fill: parent }

      Column {
        id: top
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 12

        Rectangle {
          width: parent.width
          height: calendar.implicitHeight + 24
          radius: 14
          color: Qt.rgba(1, 1, 1, 0.07)

          Column {
            id: calendar
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 6

            Item {
              width: parent.width
              height: 22
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(root.shownMonth, "MMMM yyyy")
                color: "#ffffff"
                font.family: "Adwaita Sans"
                font.pixelSize: 14
                font.weight: Font.Bold
              }
              Row {
                anchors.right: parent.right
                spacing: 4
                Repeater {
                  model: [-1, 1]
                  Text {
                    required property int modelData
                    width: 24
                    height: 22
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData < 0 ? "‹" : "›"
                    color: "#0a84ff"
                    font.family: "Adwaita Sans"
                    font.pixelSize: 19
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.shownMonth = new Date(root.shownMonth.getFullYear(), root.shownMonth.getMonth() + modelData, 1)
                    }
                  }
                }
              }
            }

            Grid {
              columns: 7
              readonly property real cell: parent.width / 7
              Repeater {
                model: ["S", "M", "T", "W", "T", "F", "S"]
                Text {
                  required property string modelData
                  width: parent.cell
                  height: 20
                  horizontalAlignment: Text.AlignHCenter
                  text: modelData
                  color: "#98989d"
                  font.family: "Adwaita Sans"
                  font.pixelSize: 11
                  font.weight: Font.DemiBold
                }
              }
              Repeater {
                model: root.monthCells()
                Item {
                  required property int modelData
                  readonly property bool today: modelData === root.now.getDate()
                    && root.shownMonth.getMonth() === root.now.getMonth()
                    && root.shownMonth.getFullYear() === root.now.getFullYear()
                  width: parent.cell
                  height: 26
                  Rectangle {
                    anchors.centerIn: parent
                    width: 23
                    height: 23
                    radius: 12
                    visible: parent.today
                    color: "#ff453a"
                  }
                  Text {
                    anchors.centerIn: parent
                    visible: parent.modelData > 0
                    text: parent.modelData
                    color: "#ffffff"
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                    font.weight: parent.today ? Font.Bold : Font.Normal
                  }
                }
              }
            }
          }
        }

        Item {
          width: parent.width
          height: 22
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: "#ffffff"
            font.family: "Adwaita Sans"
            font.pixelSize: 14
            font.weight: Font.Bold
          }
          Text {
            visible: root.notifications.length > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Clear All"
            color: "#0a84ff"
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            MouseArea {
              anchors.fill: parent
              anchors.margins: -5
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                Quickshell.execDetached(["omarchy-shell", "notifications", "clear"])
                root.notifications = []
              }
            }
          }
        }
      }

      Text {
        visible: root.notifications.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: top.y + top.height + 30
        text: "No Notifications"
        color: "#98989d"
        font.family: "Adwaita Sans"
        font.pixelSize: 13
      }

      ListView {
        x: 16
        y: top.y + top.height + 10
        width: parent.width - 32
        height: parent.height - y - 14
        clip: true
        spacing: 8
        model: root.notifications
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
          required property var modelData
          width: ListView.view.width
          height: Math.max(58, textColumn.implicitHeight + 20)
          radius: 14
          color: Qt.rgba(1, 1, 1, 0.09)

          Image {
            id: noteIcon
            x: 11
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            source: modelData.appIcon && modelData.appIcon.indexOf("file:") === 0
              ? modelData.appIcon
              : Quickshell.iconPath(modelData.appIcon || "preferences-system-notifications", "preferences-system-notifications")
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            smooth: true
          }

          Column {
            id: textColumn
            anchors.left: noteIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Item {
              width: parent.width
              height: 16
              Text {
                anchors.left: parent.left
                anchors.right: when.left
                anchors.rightMargin: 8
                textFormat: Text.PlainText
                text: modelData.summary || modelData.app || ""
                elide: Text.ElideRight
                color: "#ffffff"
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                font.weight: Font.DemiBold
              }
              Text {
                id: when
                anchors.right: parent.right
                text: root.ago(modelData.timestamp)
                color: "#98989d"
                font.family: "Adwaita Sans"
                font.pixelSize: 11
              }
            }

            Text {
              visible: text !== ""
              width: parent.width
              textFormat: Text.PlainText
              text: root.plain(modelData.body)
              wrapMode: Text.Wrap
              maximumLineCount: 3
              elide: Text.ElideRight
              color: "#d1d1d6"
              font.family: "Adwaita Sans"
              font.pixelSize: 12
            }
          }
        }
      }
    }
  }
}
