import QtQuick
import qs.Commons as Commons

Rectangle {
  id: root

  property string text: ""
  property string detail: ""
  property bool checked: false
  signal activated()

  height: 30
  radius: 6
  color: mouse.containsMouse ? "#0058d0" : "transparent"

  Text {
    id: check
    x: 8
    width: 14
    height: parent.height
    verticalAlignment: Text.AlignVCenter
    text: root.checked ? "✓" : ""
    color: mouse.containsMouse ? "#ffffff" : Commons.Color.foreground
    font.family: "Adwaita Sans"
    font.pixelSize: 13
  }

  Text {
    anchors.left: check.right
    anchors.leftMargin: 4
    anchors.right: detailText.left
    anchors.rightMargin: 12
    height: parent.height
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    text: root.text
    elide: Text.ElideRight
    color: mouse.containsMouse ? "#ffffff" : Commons.Color.foreground
    font.family: "Adwaita Sans"
    font.pixelSize: 13
  }

  Text {
    id: detailText
    anchors.right: parent.right
    anchors.rightMargin: 10
    height: parent.height
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    text: root.detail
    opacity: mouse.containsMouse ? 0.9 : 0.55
    color: mouse.containsMouse ? "#ffffff" : Commons.Color.foreground
    font.family: "Adwaita Sans"
    font.pixelSize: 12
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: root.activated()
  }
}
