import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "cupertino.app-name"

  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property string appId: toplevel ? (toplevel.appId || "") : ""
  readonly property var entry: appId !== "" ? DesktopEntries.heuristicLookup(appId === "org.omarchy.agent" ? "com.mitchellh.ghostty" : appId) : null
  // Without a desktop entry, name the app from its id: chrome-web.example.com__-Default, org.omarchy.agent.
  readonly property var webApp: appId.match(/^chrome-(?:.*\.)?([^.]+)\.[^.]+__/)
  readonly property string idName: webApp ? webApp[1] : appId.split(".").pop()
  readonly property string appName: entry ? entry.name : idName.charAt(0).toUpperCase() + idName.slice(1)

  visible: appName !== "" && !vertical
  implicitWidth: visible ? Math.min(240, label.implicitWidth) + Style.space(16) : 0
  implicitHeight: barSize

  Text {
    id: label
    anchors.fill: parent
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(8)
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    text: root.appName
    color: root.bar ? root.bar.barForeground : Commons.Color.foreground
    font.family: "Adwaita Sans"
    font.pixelSize: Style.font.body + 1
    font.weight: Font.Bold
    elide: Text.ElideRight
  }
}
