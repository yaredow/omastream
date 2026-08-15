import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  function open(payloadJson) {
    opened = true
  }

  function close() {
    opened = false
    if (shell) shell.toggle("user.omastream")
  }

  Rectangle {
    anchors.centerIn: parent
    width: 600
    height: 400
    radius: 12
    color: Color.menu.background
    border.color: Color.menu.border
    border.width: 1

    Column {
      anchors.fill: parent
      anchors.margins: 20
      spacing: 15

      Text {
        text: "omaStream Downloader"
        font.pixelSize: 20
        font.bold: true
        color: Color.menu.text
      }

      Text {
        text: "yt-dlp Quickshell Overlay Skeleton"
        font.pixelSize: 14
        color: Color.menu.text
      }
    }
  }
}
