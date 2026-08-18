import QtQuick
import qs.Commons
import qs.Ui

import "../services/DownloadModel.js" as DownloadModel

Rectangle {
  id: root

  property var job: null

  signal cancelClicked(string jobId)
  signal pauseClicked(string jobId)
  signal resumeClicked(string jobId)
  signal retryClicked(string jobId)
  signal removeClicked(string jobId)
  signal revealClicked(string path)

  height: Style.space(72)
  color: rowHover.hovered ? Color.menu.selectedBackground : "transparent"
  radius: 0
  border.color: Color.menu.border
  border.width: 0

  HoverHandler {
    id: rowHover
  }

  Row {
    anchors.fill: parent
    anchors.margins: Style.gapsOut
    spacing: Style.gapsOut

    // Thumbnail
    Rectangle {
      width: Style.space(80)
      height: parent.height
      radius: 2
      color: "#000000"
      clip: true

      Image {
        anchors.fill: parent
        source: (root.job && root.job.thumbnailUrl) || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }
    }

    // Info Column
    Column {
      width: parent.width - Style.space(80) - actionButtons.width - Style.gapsOut * 2
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2

      // Title & Format Badge
      Row {
        width: parent.width
        spacing: Style.gapsOut

        Text {
          text: (root.job && root.job.title) || "Untitled"
          font.pixelSize: Style.font.body
          font.bold: true
          color: Color.menu.text
          elide: Text.ElideRight
          width: Math.min(implicitWidth, parent.width - formatBadge.width - Style.gapsOut)
        }

        Rectangle {
          id: formatBadge
          height: Style.space(18)
          width: formatBadgeText.implicitWidth + Style.space(8)
          radius: 2
          color: Color.accent
          opacity: 0.15
          anchors.verticalCenter: parent.verticalCenter

          Text {
            id: formatBadgeText
            anchors.centerIn: parent
            text: (root.job && root.job.formatSummary) || "MP4"
            font.pixelSize: Style.font.caption
            font.bold: true
            color: Color.accent
          }
        }
      }

      // Progress Bar or Status message
      Item {
        width: parent.width
        height: Style.space(16)

        // Progress Bar Track
        Rectangle {
          id: progressTrack
          anchors.fill: parent
          radius: height / 2
          color: Color.menu.border
          visible: root.job && (root.job.state === "downloading" || root.job.state === "merging" || root.job.state === "preparing")

          Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(height, parent.width * (Math.min(100, (root.job ? root.job.percent : 0)) / 100.0))
            radius: height / 2
            color: Color.accent
          }
        }

        // Subtitle status line
        Row {
          anchors.fill: parent
          spacing: Style.gapsOut

          Text {
            text: {
              if (!root.job) return ""
              var badge = DownloadModel.getStatusBadge(root.job.state)
              if (root.job.state === "downloading") {
                return (root.job.percent > 0 ? root.job.percent.toFixed(1) + "% · " : "")
                  + DownloadModel.formatBytes(root.job.downloadedBytes)
                  + (root.job.totalBytes > 0 ? " / " + DownloadModel.formatBytes(root.job.totalBytes) : "")
                  + (root.job.speed > 0 ? " · " + DownloadModel.formatSpeed(root.job.speed) : "")
                  + (root.job.eta > 0 ? " · ETA: " + DownloadModel.formatEta(root.job.eta) : "")
              } else if (root.job.state === "merging") {
                return "Merging video and audio streams (ffmpeg)..."
              } else if (root.job.state === "preparing") {
                return "Preparing download..."
              } else if (root.job.state === "completed") {
                return "Completed · Saved to " + (root.job.outputPath || root.job.destination)
              } else if (root.job.state === "failed") {
                return "Failed: " + (root.job.error || "Unknown error")
              } else if (root.job.state === "cancelled") {
                return "Cancelled"
              }
              return badge.label
            }
            font.pixelSize: Style.font.caption
            color: {
              if (!root.job) return Color.muted
              return root.job.state === "failed" ? "#ef4444" : (root.job.state === "completed" ? "#10b981" : Color.muted)
            }
            elide: Text.ElideRight
            width: parent.width
          }
        }
      }
    }

    // Action Buttons
    Row {
      id: actionButtons
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.gapsOut / 2

      Button {
        visible: root.job && root.job.state === "downloading"
        iconText: "\uf04c"
        tooltipText: "Pause Download"
        onClicked: if (root.job) root.pauseClicked(root.job.jobId)
      }

      Button {
        visible: root.job && root.job.state === "paused"
        iconText: "\uf04b"
        tooltipText: "Resume Download"
        onClicked: if (root.job) root.resumeClicked(root.job.jobId)
      }

      Button {
        visible: root.job && (root.job.state === "downloading" || root.job.state === "preparing" || root.job.state === "merging" || root.job.state === "queued" || root.job.state === "paused")
        iconText: "\uf00d"
        tooltipText: "Cancel Download"
        onClicked: if (root.job) root.cancelClicked(root.job.jobId)
      }

      Button {
        visible: root.job && (root.job.state === "failed" || root.job.state === "cancelled")
        iconText: "\uf01e"
        tooltipText: "Retry Download"
        onClicked: if (root.job) root.retryClicked(root.job.jobId)
      }

      Button {
        visible: root.job && root.job.state === "completed"
        iconText: "\uf07b"
        tooltipText: "Open in File Manager"
        onClicked: if (root.job) root.revealClicked(root.job.outputPath || root.job.destination)
      }

      Button {
        visible: root.job && (root.job.state === "completed" || root.job.state === "failed" || root.job.state === "cancelled")
        iconText: "\uf1f8"
        tooltipText: "Remove from History"
        onClicked: if (root.job) root.removeClicked(root.job.jobId)
      }
    }
  }
}
