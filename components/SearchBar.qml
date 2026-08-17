import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  signal searchRequested(string query)

  height: Style.space(48)
  radius: Style.space(8)
  color: Color.menu.background
  border.color: input.activeFocus ? Color.accent : Color.menu.border
  border.width: 1

  Row {
    anchors.fill: parent
    anchors.leftMargin: Style.space(12)
    anchors.rightMargin: Style.space(12)
    spacing: Style.space(10)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "\uf002"
      font.pixelSize: 16
      color: Color.menu.text
      opacity: 0.6
    }

    TextInput {
      id: input
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - Style.space(70)
      color: Color.menu.text
      font.pixelSize: 14
      clip: true

      Text {
        text: "Search YouTube via Invidious..."
        color: Color.menu.text
        opacity: 0.4
        font.pixelSize: 14
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
      text: "\uf00d"
      font.pixelSize: 14
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
