import QtQuick
import QtQuick.Controls as QQC
import QtMultimedia
import qs.Commons
import qs.Ui

import "../components"

Item {
  id: root

  property var service: null
  property alias videoOutput: videoOutputItem

  signal fullscreenRequested()
  signal qualityChanged(var formatItem)

  property color foreground: Color.menu.text
  property color accent: Color.accent
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.56)
  property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

  function formatTime(milliseconds) {
    var total = Math.max(0, Math.floor(milliseconds / 1000))
    var hours = Math.floor(total / 3600)
    var minutes = Math.floor((total % 3600) / 60)
    var seconds = total % 60
    var secondText = seconds < 10 ? "0" + seconds : String(seconds)
    if (hours > 0)
      return hours + ":" + (minutes < 10 ? "0" + minutes : minutes) + ":" + secondText
    return minutes + ":" + secondText
  }

  Column {
    anchors.fill: parent
    spacing: Style.gapsOut

    // Main Video Surface
    Rectangle {
      width: parent.width
      height: parent.height - controlsArea.height - Style.gapsOut
      radius: Style.cornerRadius
      color: "#000000"
      clip: true

      VideoOutput {
        id: videoOutputItem
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
        visible: root.service && root.service.mode === "video"
      }

      // Audio Mode Visualization
      Item {
        anchors.fill: parent
        visible: root.service && root.service.mode === "audio"

        Image {
          anchors.centerIn: parent
          width: Style.space(160)
          height: Style.space(160)
          source: (root.service && root.service.currentItem && root.service.currentItem.artworkUrl) || ""
          fillMode: Image.PreserveAspectCrop
        }
      }

      // Loading spinner
      Rectangle {
        id: loadingOverlay
        anchors.centerIn: parent
        width: Style.space(52)
        height: width
        radius: width / 2
        color: "#cc000000"
        visible: root.service && root.service.showLoadingOverlay

        Text {
          anchors.centerIn: parent
          text: "\uf110"
          color: Color.accent
          font.pixelSize: Style.font.title
          transformOrigin: Item.Center

          RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: loadingOverlay.visible
          }
        }
      }

      // Top Overlay Header (Title, Quality, Fullscreen)
      Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Style.space(48)
        color: "#99000000"

        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.gapsOut
          anchors.rightMargin: Style.gapsOut
          spacing: Style.gapsOut

          Column {
            width: parent.width - topActions.width - Style.gapsOut
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
              text: (root.service && root.service.currentItem && root.service.currentItem.title) || "No media playing"
              font.pixelSize: Style.font.body
              font.bold: true
              color: root.foreground
              elide: Text.ElideRight
              width: parent.width
              textFormat: Text.PlainText
            }

            Text {
              text: (root.service && root.service.currentItem && root.service.currentItem.author) || ""
              font.pixelSize: Style.font.caption
              color: root.dim
              elide: Text.ElideRight
              width: parent.width
              textFormat: Text.PlainText
            }
          }

          Row {
            id: topActions
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.gapsOut / 2

            QualityMenu {
              formats: root.service ? root.service.currentFormats : ({})
              activeFormatId: root.service ? root.service.activeFormatId : "auto"
              onQualitySelected: function(item) {
                root.qualityChanged(item)
              }
            }

            Button {
              iconText: "\uf065"
              tooltipText: "Fullscreen"
              onClicked: root.fullscreenRequested()
            }
          }
        }
      }
    }

    // Bottom Playback Controls
    Rectangle {
      id: controlsArea
      width: parent.width
      height: Style.space(80)
      radius: 0
      color: Color.menu.background
      border.width: 0

      Column {
        anchors.fill: parent
        anchors.margins: Style.gapsOut
        spacing: Style.gapsOut / 2

        // Scrubber & Time Bar
        Row {
          width: parent.width
          spacing: Style.gapsOut

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.formatTime(root.service ? root.service.position : 0)
            font.pixelSize: Style.font.caption
            color: Color.muted
            width: Style.space(45)
          }

          // Seek Slider Bar
          Rectangle {
            id: seekTrack
            width: parent.width - Style.space(90) - Style.gapsOut * 2
            height: Style.space(8)
            radius: height / 2
            color: Color.menu.border
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: {
                var dur = root.service ? root.service.duration : 0
                var pos = root.service ? root.service.position : 0
                if (dur <= 0) return 0
                return Math.max(height, parent.width * (pos / dur))
              }
              radius: height / 2
              color: Color.accent
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onPositionChanged: function(mouse) {
                if (!root.service || !root.service.duration || !pressed) return
                var ratio = Math.max(0, Math.min(1, mouse.x / width))
                var targetMs = ratio * root.service.duration
                root.service.seek(targetMs)
              }
              onClicked: function(mouse) {
                if (!root.service || !root.service.duration) return
                var ratio = Math.max(0, Math.min(1, mouse.x / width))
                var targetMs = ratio * root.service.duration
                root.service.seek(targetMs)
              }
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.formatTime(root.service ? root.service.duration : 0)
            font.pixelSize: Style.font.caption
            color: Color.muted
            width: Style.space(45)
            horizontalAlignment: Text.AlignRight
          }
        }

        // Action Buttons Row
        Row {
          width: parent.width
          spacing: Style.gapsOut

          // Left transport controls
          Row {
            spacing: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter

            Button {
              iconText: "\uf04a"
              tooltipText: "Seek -10s"
              foreground: root.foreground
              accent: root.accent
              onClicked: if (root.service) root.service.seekRelative(-10000)
            }

            Button {
              iconText: (root.service && root.service.running && !root.service.paused) ? "\uf04c" : "\uf04b"
              tooltipText: (root.service && root.service.running && !root.service.paused) ? "Pause" : "Play"
              foreground: root.foreground
              accent: root.accent
              onClicked: if (root.service) root.service.togglePlayback()
            }

            Button {
              iconText: "\uf04e"
              tooltipText: "Seek +10s"
              foreground: root.foreground
              accent: root.accent
              onClicked: if (root.service) root.service.seekRelative(10000)
            }

            Button {
              iconText: "\uf04d"
              tooltipText: "Stop"
              foreground: root.foreground
              accent: root.accent
              onClicked: if (root.service) root.service.stop()
            }
          }

          Item { width: Style.spacing.md; height: 1 }

          // Right volume & speed controls
          Row {
            spacing: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter

            Button {
              text: ((root.service ? root.service.playbackRate : 1.0) + "x")
              tooltipText: "Cycle Playback Speed"
              foreground: root.foreground
              accent: root.accent
              onClicked: {
                if (!root.service) return
                var r = root.service.playbackRate
                if (r === 1.0) root.service.setPlaybackRate(1.25)
                else if (r === 1.25) root.service.setPlaybackRate(1.5)
                else if (r === 1.5) root.service.setPlaybackRate(2.0)
                else if (r === 2.0) root.service.setPlaybackRate(0.75)
                else root.service.setPlaybackRate(1.0)
              }
            }

            Row {
              spacing: Style.spacing.sm
              anchors.verticalCenter: parent.verticalCenter

              Button {
                iconText: (root.service && root.service.muted) ? "\uf6a9" : "\uf028"
                foreground: root.foreground
                accent: root.accent
                onClicked: if (root.service) root.service.toggleMute()
              }

              Rectangle {
                width: Style.space(80)
                height: Style.space(6)
                radius: height / 2
                color: root.faint
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: Math.max(height, parent.width * ((root.service ? root.service.volume : 70) / 100.0))
                  radius: height / 2
                  color: root.accent
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onPositionChanged: function(mouse) {
                    if (!root.service || !pressed) return
                    var vol = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                    root.service.setVolume(vol)
                  }
                  onClicked: function(mouse) {
                    if (!root.service) return
                    var vol = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                    root.service.setVolume(vol)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
