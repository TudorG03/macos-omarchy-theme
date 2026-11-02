import QtQuick
import Quickshell

Item {
  id: root

  property var shell: null

  Variants {
    model: Quickshell.screens

    Item {
      id: screenCorners
      required property var modelData

      Corner {
        shell: root.shell
        screen: screenCorners.modelData
        atLeft: true
        payload: "{}"
      }

      Corner {
        shell: root.shell
        screen: screenCorners.modelData
        atLeft: false
        payload: "{\"app\":\"current\"}"
      }
    }
  }
}
