import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  signal searchRequested(string query)

  height: Style.space(46)
  radius: Style.space(23)
  color: input.activeFocus ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.1) : Qt.rgba(Color.menu.background.r, Color.menu.background.g, Color.menu.background.b, 0.8)
  border.color: input.activeFocus ? Color.accent : Qt.rgba(Color.menu.border.r, Color.menu.border.g, Color.menu.border.b, 0.4)
  border.width: 1

  Behavior on color { ColorAnimation { duration: 150 } }
  Behavior on border.color { ColorAnimation { duration: 150 } }

  Row {
    anchors.fill: parent
    anchors.leftMargin: Style.space(16)
    anchors.rightMargin: Style.space(16)
    spacing: Style.space(12)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "\uf002" // NerdFont Search
      font.family: Style.font.family
      font.pixelSize: 14
      color: Color.menu.text
      opacity: input.activeFocus ? 1.0 : 0.6
    }

    TextInput {
      id: input
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - Style.space(70)
      color: Color.menu.text
      font.family: Style.font.family
      font.pixelSize: 13
      clip: true

      Text {
        text: "Search YouTube videos without tracking or ads..."
        color: Color.menu.text
        font.family: Style.font.family
        opacity: 0.4
        font.pixelSize: 13
        visible: input.text.length === 0 && !input.activeFocus
        anchors.verticalCenter: parent.verticalCenter
      }

      onAccepted: {
        root.searchRequested(input.text)
      }
    }

    Text {
      id: clearBtn
      visible: input.text.length > 0
      anchors.verticalCenter: parent.verticalCenter
      text: "\uf00d" // NerdFont Times/Close
      font.family: Style.font.family
      font.pixelSize: 13
      color: Color.menu.text
      opacity: 0.6

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          input.text = ""
          root.searchRequested("")
        }
      }
    }
  }
}
