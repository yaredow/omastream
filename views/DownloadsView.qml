import QtQuick
import qs.Commons
import qs.Ui

import "../components"

Item {
  id: root

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
    spacing: Style.gapsOut

    // Top Header & Actions
    Rectangle {
      width: parent.width
      height: Style.space(42)
      radius: 0
      color: Color.menu.background
      border.color: Color.menu.border
      border.width: 0

      Row {
        anchors.fill: parent
        anchors.leftMargin: Style.gapsOut
        anchors.rightMargin: Style.gapsOut
        spacing: Style.gapsOut

        // Filter Tabs
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.gapsOut / 2

          Button {
            text: "All"
            selected: root.filterState === "all"
            active: root.filterState === "all"
            onClicked: root.filterState = "all"
          }

          Button {
            text: "Active" + (root.downloadService && root.downloadService.activeCount > 0 ? " (" + root.downloadService.activeCount + ")" : "")
            selected: root.filterState === "active"
            active: root.filterState === "active"
            onClicked: root.filterState = "active"
          }

          Button {
            text: "Completed"
            selected: root.filterState === "completed"
            active: root.filterState === "completed"
            onClicked: root.filterState = "completed"
          }

          Button {
            text: "Failed"
            selected: root.filterState === "failed"
            active: root.filterState === "failed"
            onClicked: root.filterState = "failed"
          }
        }

        Item { width: Style.space(16); height: 1 }

        // Right action buttons
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.gapsOut / 2

          Button {
            text: "Open Folder"
            iconText: "\uf07b"
            tooltipText: "Open ~/Downloads in File Manager"
            onClicked: if (root.downloadService) root.downloadService.revealInFileManager("")
          }

          Button {
            text: "Clear Finished"
            iconText: "\uf1f8"
            tooltipText: "Clear completed and failed downloads"
            onClicked: if (root.downloadService) root.downloadService.clearCompleted()
          }
        }
      }
    }

    // Main Downloads List
    Rectangle {
      width: parent.width
      height: parent.height - Style.space(42) - Style.gapsOut
      radius: 0
      color: Color.menu.background
      border.color: Color.menu.border
      border.width: 0
      clip: true

      ListView {
        id: downloadListView
        anchors.fill: parent
        anchors.margins: Style.gapsOut
        spacing: Style.gapsOut / 2
        model: root.displayedJobs
        boundsBehavior: Flickable.StopAtBounds

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
          spacing: Style.gapsOut

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\uf019"
            font.pixelSize: Style.space(40)
            color: Color.muted
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.filterState === "active"
              ? "No active downloads in progress."
              : "No download history found. Download videos or audio from the Discover tab!"
            font.pixelSize: Style.font.body
            color: Color.muted
          }
        }
      }
    }
  }
}
