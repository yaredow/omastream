import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

Column {
  id: root

  property string activeInstanceUrl: "https://inv.tux.pizza"
  property var defaultInstances: [
    "https://inv.tux.pizza",
    "https://invidious.nerdvpn.de",
    "https://invidious.privacydev.net"
  ]
  property var customInstances: []

  signal instanceSelected(string url)
  signal customInstanceAdded(string url)

  spacing: Style.space(18)
  width: parent.width

  // Active Instance Header Banner
  Rectangle {
    width: parent.width
    height: Style.space(56)
    radius: Style.space(12)
    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
    border.color: Color.accent
    border.width: 1

    Row {
      anchors.fill: parent
      anchors.margins: 14
      spacing: 10

      Text {
        text: "⚡"
        font.pixelSize: 16
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
          text: "Active Invidious Server"
          font.bold: true
          font.pixelSize: 11
          color: Color.accent
        }

        Text {
          text: root.activeInstanceUrl
          font.pixelSize: 13
          font.bold: true
          color: Color.menu.text
        }
      }
    }
  }

  Text {
    text: "Public Server Swarm"
    font.pixelSize: 14
    font.bold: true
    color: Color.menu.text
  }

  Column {
    width: parent.width
    spacing: Style.space(8)

    Repeater {
      model: root.defaultInstances

      delegate: Rectangle {
        required property string modelData

        width: parent.width
        height: Style.space(42)
        radius: Style.space(8)
        color: modelData === root.activeInstanceUrl ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18) : Qt.rgba(Color.menu.background.r, Color.menu.background.g, Color.menu.background.b, 0.5)
        border.color: modelData === root.activeInstanceUrl ? Color.accent : Qt.rgba(Color.menu.border.r, Color.menu.border.g, Color.menu.border.b, 0.3)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.instanceSelected(modelData)
        }

        Row {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          spacing: 12

          Text {
            text: modelData === root.activeInstanceUrl ? "●" : "○"
            font.pixelSize: 14
            color: modelData === root.activeInstanceUrl ? Color.accent : Color.menu.text
            opacity: modelData === root.activeInstanceUrl ? 1.0 : 0.4
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: modelData
            font.pixelSize: 13
            font.bold: modelData === root.activeInstanceUrl
            color: Color.menu.text
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }

  Text {
    text: "Custom Server Endpoint"
    font.pixelSize: 14
    font.bold: true
    color: Color.menu.text
  }

  Row {
    width: parent.width
    spacing: Style.space(10)

    Rectangle {
      width: parent.width - Style.space(100)
      height: Style.space(40)
      radius: Style.space(20)
      color: customInput.activeFocus ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.1) : Qt.rgba(Color.menu.background.r, Color.menu.background.g, Color.menu.background.b, 0.6)
      border.color: customInput.activeFocus ? Color.accent : Qt.rgba(Color.menu.border.r, Color.menu.border.g, Color.menu.border.b, 0.4)
      border.width: 1

      TextInput {
        id: customInput
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        color: Color.menu.text
        font.pixelSize: 12
        clip: true

        Text {
          text: "https://my-invidious.example.com"
          color: Color.menu.text
          opacity: 0.4
          font.pixelSize: 12
          visible: customInput.text.length === 0 && !customInput.activeFocus
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    Rectangle {
      width: Style.space(90)
      height: Style.space(40)
      radius: Style.space(20)
      color: Color.accent

      Text {
        anchors.centerIn: parent
        text: "+ Add Server"
        color: "#ffffff"
        font.bold: true
        font.pixelSize: 11
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (customInput.text.trim().length > 0) {
            root.customInstanceAdded(customInput.text.trim())
            customInput.text = ""
          }
        }
      }
    }
  }
}
