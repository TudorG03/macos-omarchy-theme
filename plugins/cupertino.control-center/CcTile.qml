import QtQuick

Rectangle {
  id: root

  property string glyph: ""
  property string title: ""
  property string detail: ""
  property bool active: false
  signal toggled()
  signal opened()

  height: 62
  radius: 14
  color: Qt.rgba(1, 1, 1, 0.09)

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.opened()
  }

  Rectangle {
    id: circle
    x: 11
    anchors.verticalCenter: parent.verticalCenter
    width: 34
    height: 34
    radius: 17
    color: root.active ? "#0a84ff" : Qt.rgba(1, 1, 1, 0.16)

    Text {
      anchors.centerIn: parent
      text: root.glyph
      color: "#ffffff"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 15
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggled()
    }
  }

  Column {
    anchors.left: circle.right
    anchors.leftMargin: 9
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter

    Text {
      width: parent.width
      text: root.title
      elide: Text.ElideRight
      color: "#ffffff"
      font.family: "Adwaita Sans"
      font.pixelSize: 12
      font.weight: Font.DemiBold
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: root.detail
      elide: Text.ElideRight
      color: "#c7c7cc"
      font.family: "Adwaita Sans"
      font.pixelSize: 11
    }
  }
}
