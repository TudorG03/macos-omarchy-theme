import QtQuick
import qs.Commons

// Only the shell changes: terminals and apps keep their own fonts. Icon glyphs fall back to the Nerd Font.
Item {
  property var shell: null

  Component.onCompleted: Style.fontFamily = "Adwaita Sans"
  Component.onDestruction: Style.fontFamily = "monospace"
}
