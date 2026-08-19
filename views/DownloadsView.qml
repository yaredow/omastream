import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

import "../components"

Item {
  id: root

  property color foreground: Color.menu.text
  property color accent: Color.accent
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.56)
  property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

  property var downloadService: null
  property string filterState: "all" // all, active, completed, failed

  readonly property var displayedJobs: {
    if (!root.downloadService || !root.downloadService.jobs) return []
    var all = root.downloadService.jobs
    if (root.filterState === "all") return all

    return all.filter(function(j) {
      if (root.filterState === "active") {
        return j.state === "downloading" || j.state === "merging" || j.state === "preparing" || j.state === "queued" || j.state === "paused"
      } else if (root.filterState === "completed") {
        return j.state === "completed"
      } else if (root.filterState === "failed") {
        return j.state === "failed" || j.state === "cancelled"
      }
      return true
    })
  }

  Column {
    anchors.fill: parent
    spacing: Style.spacing.md

    // Top Header & Actions
    Item {
      width: parent.width
      height: Style.space(42)

      Row {
        anchors.fill: parent
        anchors.leftMargin: Style.spacing.panelPadding
        anchors.rightMargin: Style.spacing.panelPadding
        spacing: Style.spacing.md

        // Filter Tabs
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.xs

          Button {
            text: "All"
            selected: root.filterState === "all"
            fontSize: Style.font.caption
            foreground: root.foreground
            accent: root.accent
            onClicked: root.filterState = "all"
          }

          Button {
            text: "Active" + (root.downloadService && root.downloadService.activeCount > 0 ? " (" + root.downloadService.activeCount + ")" : "")
            selected: root.filterState === "active"
            fontSize: Style.font.caption
            foreground: root.foreground
            accent: root.accent
            onClicked: root.filterState = "active"
          }

          Button {
            text: "Completed"
            selected: root.filterState === "completed"
            fontSize: Style.font.caption
            foreground: root.foreground
            accent: root.accent
            onClicked: root.filterState = "completed"
          }

          Button {
            text: "Failed"
            selected: root.filterState === "failed"
            fontSize: Style.font.caption
            foreground: root.foreground
            accent: root.accent
            onClicked: root.filterState = "failed"
          }
        }

        Item { width: Style.spacing.md; height: 1 }

        // Right action buttons
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.xs

          Button {
            text: "Open Folder"
            iconText: "\uf07b"
            fontSize: Style.font.caption
            tooltipText: "Open ~/Downloads in File Manager"
            foreground: root.foreground
            accent: root.accent
            onClicked: if (root.downloadService) root.downloadService.revealInFileManager("")
          }

          Button {
            text: "Clear Finished"
            iconText: "\uf1f8"
            fontSize: Style.font.caption
            tooltipText: "Clear completed and failed downloads"
            foreground: root.foreground
            accent: root.accent
            onClicked: if (root.downloadService) root.downloadService.clearCompleted()
          }
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: root.faint
        anchors.bottom: parent.bottom
      }
    }

    // Main Downloads List
    Item {
      width: parent.width
      height: parent.height - Style.space(42) - Style.spacing.md
      clip: true

      ListView {
        id: downloadListView
        anchors.fill: parent
        anchors.margins: Style.spacing.md
        spacing: 0
        model: root.displayedJobs
        boundsBehavior: Flickable.StopAtBounds
        QQC.ScrollBar.vertical: QQC.ScrollBar {}

        delegate: DownloadRow {
          width: downloadListView.width
          job: modelData

          onCancelClicked: function(jobId) {
            if (root.downloadService) root.downloadService.cancelDownload(jobId)
          }

          onPauseClicked: function(jobId) {
            if (root.downloadService) root.downloadService.pauseDownload(jobId)
          }

          onResumeClicked: function(jobId) {
            if (root.downloadService) root.downloadService.resumeDownload(jobId)
          }

          onRetryClicked: function(jobId) {
            if (root.downloadService) root.downloadService.retryDownload(jobId)
          }

          onRemoveClicked: function(jobId) {
            if (root.downloadService) root.downloadService.removeDownload(jobId)
          }

          onRevealClicked: function(path) {
            if (root.downloadService) root.downloadService.revealInFileManager(path)
          }
        }
      }

      // Empty state
      Item {
        anchors.fill: parent
        visible: root.displayedJobs.length === 0

        Column {
          anchors.centerIn: parent
          spacing: Style.spacing.md

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\uf019"
            font.pixelSize: Style.space(40)
            color: root.dim
            textFormat: Text.PlainText
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.filterState === "active"
              ? "No active downloads in progress."
              : "No download history found. Download videos or audio from the Discover tab!"
            font.pixelSize: Style.font.body
            color: root.dim
            textFormat: Text.PlainText
          }
        }
      }
    }
  }
}
