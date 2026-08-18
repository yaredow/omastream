import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

Item {
  id: root

  property var formats: ({ streamable: [], downloadVideo: [], downloadAudio: [] })
  property string activeFormatId: "auto"
  property bool showDownloadFormats: false

  signal qualitySelected(var formatItem)

  implicitWidth: menuButton.implicitWidth
  implicitHeight: menuButton.implicitHeight

  Button {
    id: menuButton
    anchors.fill: parent
    text: getActiveLabel()
    iconText: "\uf013"
    tooltipText: "Select Playback Quality"
    onClicked: qualityPopup.open()
  }

  function getActiveLabel() {
    if (root.activeFormatId === "auto") return "Auto"
    if (root.formats && root.formats.streamable) {
      for (var i = 0; i < root.formats.streamable.length; i++) {
        if (root.formats.streamable[i].id === root.activeFormatId) {
          return root.formats.streamable[i].label
        }
      }
    }
    return root.activeFormatId
  }

  QQC.Popup {
    id: qualityPopup
    y: menuButton.height + Style.gapsOut
    width: Style.space(260)
    padding: Style.gapsOut
    modal: true
    focus: true
    closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside

    background: BorderSurface {
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.normalBorderWidth))
      radius: Style.cornerRadius
    }

    contentItem: Column {
      spacing: Style.gapsOut / 2
      width: parent.width

      Text {
        text: "STREAM QUALITY"
        font.pixelSize: Style.font.caption
        font.bold: true
        color: Color.muted
        leftPadding: Style.gapsOut
        topPadding: Style.gapsOut / 2
      }

      Repeater {
        model: (root.formats && root.formats.streamable && root.formats.streamable.length > 0)
          ? root.formats.streamable
          : [{ id: "auto", label: "Auto (Recommended)", detail: "Best direct stream" }]

        delegate: Rectangle {
          width: parent.width
          height: Style.space(36)
          radius: 2
          color: itemMouse.containsMouse
            ? Color.menu.selectedBackground
            : (modelData.id === root.activeFormatId ? Color.menu.selectedBackground : "transparent")

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.gapsOut
            anchors.rightMargin: Style.gapsOut
            spacing: Style.gapsOut

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.id === root.activeFormatId ? "\uf00c" : " "
              color: Color.accent
              font.pixelSize: Style.font.body
              width: Style.space(16)
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1

              Text {
                text: modelData.label || "Auto"
                font.pixelSize: Style.font.body
                font.bold: modelData.id === root.activeFormatId
                color: Color.menu.text
              }

              Text {
                text: modelData.detail || ""
                font.pixelSize: Style.font.caption
                color: Color.muted
                visible: (modelData.detail || "") !== ""
              }
            }
          }

          MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.qualitySelected(modelData)
              qualityPopup.close()
            }
          }
        }
      }
    }
  }
}
