import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

Item {
  id: root

  property var formats: ({ playback: [], downloadVideo: [], downloadAudio: [] })
  property string activeFormatId: "auto"
  property bool formatsLoading: false
  readonly property bool popupOpen: qualityPopup.visible

  signal qualitySelected(var formatItem)

  property color foreground: Color.menu.text
  property color accent: Color.accent
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.56)
  property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

  implicitWidth: menuButton.implicitWidth
  implicitHeight: menuButton.implicitHeight

  function closePopup() {
    qualityPopup.close()
  }

  Button {
    id: menuButton
    anchors.fill: parent
    text: getActiveLabel()
    iconText: "\uf013"
    tooltipText: "Select Playback Quality"
    foreground: root.foreground
    accent: root.accent
    onClicked: qualityPopup.open()
  }

  function getActiveLabel() {
    if (root.activeFormatId === "auto") return "Auto"
    if (root.formats && root.formats.playback) {
      for (var i = 0; i < root.formats.playback.length; i++) {
        if (root.formats.playback[i].id === root.activeFormatId) {
          return root.formats.playback[i].label
        }
      }
    }
    return root.activeFormatId
  }

  QQC.Popup {
    id: qualityPopup
    x: menuButton.width - width
    y: menuButton.height + Style.spacing.xs
    width: Style.space(200)
    padding: Style.spacing.sm
    modal: true
    focus: true
    closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside

    background: BorderSurface {
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.normalBorderWidth))
      radius: Style.cornerRadius
    }

    contentItem: Column {
      spacing: Style.spacing.xs
      width: parent.width

      Text {
        text: root.formatsLoading ? "DETECTING QUALITIES..." : "STREAM QUALITY"
        font.pixelSize: Style.font.caption
        font.bold: true
        color: root.dim
        leftPadding: Style.spacing.sm
        topPadding: Style.spacing.xs
        textFormat: Text.PlainText
      }

      Repeater {
        model: {
          var list = (root.formats && root.formats.playback && root.formats.playback.length > 0)
            ? root.formats.playback
            : [{ id: "auto", label: "Auto", detail: "" }]
          // Ensure Auto is always present
          if (list.length > 0 && list[0].id !== "auto") {
             list = [{ id: "auto", label: "Auto", detail: "" }].concat(list)
          }
          return list
        }

        delegate: Rectangle {
          width: parent.width
          height: Style.space(32)
          radius: 2
          color: modelData.id === root.activeFormatId
            ? Style.selectedFillFor(root.foreground, root.accent)
            : (itemMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.spacing.sm
            anchors.rightMargin: Style.spacing.sm
            spacing: Style.spacing.sm

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.id === root.activeFormatId ? "\uf00c" : " "
              color: root.accent
              font.pixelSize: Style.font.body
              width: Style.space(16)
              textFormat: Text.PlainText
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label || "Auto"
              font.pixelSize: Style.font.body
              font.bold: modelData.id === root.activeFormatId
              color: root.foreground
              textFormat: Text.PlainText
            }

            Item { width: Math.max(1, parent.width - parent.children[0].width - parent.children[1].implicitWidth - parent.children[3].implicitWidth - Style.spacing.sm * 3); height: 1 }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.detail || ""
              font.pixelSize: Style.font.caption
              color: root.dim
              visible: (modelData.detail || "") !== ""
              textFormat: Text.PlainText
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
