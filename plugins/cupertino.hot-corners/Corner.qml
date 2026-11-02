import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Top layer on purpose: fullscreen windows cover it, so games can't trigger a corner.
PanelWindow {
  id: corner

  property var shell: null
  property bool atLeft: true
  property string payload: "{}"
  property bool suppressed: false

  readonly property int cornerSize: 3

  WlrLayershell.namespace: "omarchy-hot-corner"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  anchors { bottom: true; left: atLeft; right: !atLeft }
  implicitWidth: cornerSize
  implicitHeight: cornerSize

  Item {
    anchors.fill: parent

    HoverHandler {
      id: hover
      onHoveredChanged: {
        if (hovered && !corner.suppressed) dwell.restart()
        else dwell.stop()
      }
    }
  }

  Timer {
    id: dwell
    interval: 120
    onTriggered: {
      corner.suppressed = true
      Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "cupertino.mission-control", corner.payload])
    }
  }

  // Closing the overlay re-exposes this surface under a resting pointer, which must not reopen it.
  // So stay quiet until the overlay is closed and the pointer has really left the corner.
  Timer {
    interval: 250
    repeat: true
    running: corner.suppressed
    onTriggered: {
      if (corner.shell && corner.shell.isPluginOpen("cupertino.mission-control")) return
      if (!pointerProbe.running) pointerProbe.running = true
    }
  }

  Process {
    id: pointerProbe
    command: ["hyprctl", "cursorpos"]
    stdout: StdioCollector {
      onStreamFinished: {
        var parts = text.split(",")
        var x = Number(parts[0])
        var y = Number(parts[1])
        var screen = corner.screen
        var inCorner = y >= screen.y + screen.height - corner.cornerSize - 2
          && (corner.atLeft ? x <= screen.x + corner.cornerSize + 2 : x >= screen.x + screen.width - corner.cornerSize - 2)
        if (!inCorner) corner.suppressed = false
      }
    }
  }
}
