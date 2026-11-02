import QtQuick

Rectangle {
  id: root

  property string glyph: ""
  property string title: ""
  property real value: 0
  signal moved(real value)
  signal committed(real value)

  height: 62
  radius: 14
  color: Qt.rgba(1, 1, 1, 0.09)

  Text {
    x: 12
    y: 8
    text: root.title
    color: "#ffffff"
    font.family: "Adwaita Sans"
    font.pixelSize: 12
    font.weight: Font.DemiBold
  }

  Rectangle {
    id: track
    x: 12
    y: 30
    width: parent.width - 24
    height: 22
    radius: 11
    color: Qt.rgba(1, 1, 1, 0.14)
    clip: true

    Rectangle {
      width: Math.max(track.height, track.width * root.value)
      height: parent.height
      radius: 11
      color: "#f2f2f7"
    }

    Text {
      x: 7
      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph
      color: "#3a3a3c"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 12
    }

    MouseArea {
      anchors.fill: parent
      preventStealing: true
      cursorShape: Qt.PointingHandCursor
      function valueAt(x) { return Math.max(0, Math.min(1, x / track.width)) }
      onPressed: function(mouse) {
        root.value = valueAt(mouse.x)
        root.moved(root.value)
      }
      onPositionChanged: function(mouse) {
        if (!pressed) return
        root.value = valueAt(mouse.x)
        root.moved(root.value)
      }
      onReleased: root.committed(root.value)
    }
  }
}
