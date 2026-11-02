import QtQuick
import Quickshell
import qs.Commons as Commons

Item {
  id: root

  property var dock: null
  property var screen: null
  property string desktopId: ""
  property string appId: ""
  property string match: ""
  property string nameOverride: ""
  property string iconName: ""
  property var launchCommand: []
  property real baseCenter: 0
  property real pointerX: 0
  property real hoverAmount: 0

  readonly property int iconBase: dock.iconBase
  readonly property int maxDots: 4

  // Web app ids hold the site, not the desktop file: chrome-gemini.google.com__-Default is Gemini.
  readonly property var webAppMatch: appId.match(/^chrome-(?:www\.|web\.)?([^.]+)\./)
  readonly property string webAppName: webAppMatch ? webAppMatch[1] : ""

  // Reading applications.values re-runs this when desktop files change, since old entries get replaced.
  readonly property var entry: {
    DesktopEntries.applications.values
    if (desktopId !== "") return DesktopEntries.byId(desktopId)
    return appId !== "" ? DesktopEntries.heuristicLookup(webAppName !== "" ? webAppName : appId) : null
  }
  readonly property var windows: dock.windowsFor(match)
  readonly property bool running: windows.length > 0
  readonly property string label: nameOverride !== "" ? nameOverride
    : (entry ? entry.name : (running ? (windows[0].title || appId) : desktopId))

  readonly property string iconSource: {
    var icon = iconName !== "" ? iconName : (entry ? entry.icon : "")
    if (icon.indexOf("/") === 0) return "file://" + icon
    if (icon.indexOf("file:") === 0) return icon
    return Quickshell.iconPath(icon !== "" ? icon : "application-x-executable", "application-x-executable")
  }

  readonly property real distance: pointerX - baseCenter
  readonly property real size: iconBase * (1 + (dock.maxScale - 1) * hoverAmount * Math.exp(-(distance * distance) / (2 * dock.sigma * dock.sigma)))

  width: size
  height: iconBase

  function activate() {
    if (running) dock.focusWindow(dock.nextWindow(windows))
    else launch()
  }

  function launch() {
    if (launchCommand.length > 0) {
      Quickshell.execDetached(launchCommand)
      return
    }
    if (!entry) return
    bounce.restart()
    Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", entry.id + ".desktop"])
  }

  onRunningChanged: if (running) bounce.stop()

  Image {
    id: icon
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.size
    height: root.size
    source: root.iconSource
    sourceSize: Qt.size(128, 128)
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    transform: Translate { id: jump }
  }

  SequentialAnimation {
    id: bounce
    loops: 3
    onStopped: jump.y = 0
    NumberAnimation { target: jump; property: "y"; to: -22; duration: 220; easing.type: Easing.OutQuad }
    NumberAnimation { target: jump; property: "y"; to: 0; duration: 260; easing.type: Easing.OutBounce }
  }

  // One dot per open window, however many desktops they're spread over.
  Row {
    anchors.top: parent.bottom
    anchors.topMargin: 2
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 3

    Repeater {
      model: Math.min(root.windows.length, root.maxDots)
      Rectangle {
        width: 4
        height: 4
        radius: 2
        color: Commons.Color.foreground
      }
    }
  }

  Rectangle {
    anchors.bottom: icon.top
    anchors.bottomMargin: 8
    anchors.horizontalCenter: parent.horizontalCenter
    visible: mouse.containsMouse && !root.dock.menuIcon
    width: name.implicitWidth + 20
    height: name.implicitHeight + 10
    radius: 8
    color: Qt.rgba(Commons.Color.background.r, Commons.Color.background.g, Commons.Color.background.b, 0.9)
    border.color: Qt.rgba(1, 1, 1, 0.18)
    border.width: 1

    Text {
      id: name
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: root.label
      color: Commons.Color.foreground
      font.family: "Adwaita Sans"
      font.pixelSize: 13
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: icon
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(event) {
      if (event.button === Qt.MiddleButton) root.launch()
      else if (event.button === Qt.RightButton) {
        if (root.launchCommand.length === 0) root.dock.openMenu(root, root.screen, root.mapToGlobal(root.width / 2, 0).x)
      }
      else root.activate()
    }
  }
}
