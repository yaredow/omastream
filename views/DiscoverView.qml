import QtQuick
import QtQuick.Controls as QQC
import QtMultimedia
import qs.Commons
import qs.Ui

import "../services/MediaModel.js" as MediaModel
import "../components"

Item {
  id: root

  property var service: null
  property var rawVideoList: []
  property var filteredVideoList: []
  property int selectedIndex: -1
  property var selectedVideo: null
  property bool isSearching: false
  property string errorMessage: ""
  property string currentQuery: ""

  property string activeSort: "relevance" // relevance, newest, oldest, views, shortest, longest
  property string activeFilter: "all" // all, videos, live, short, medium, long
  property string activeSource: "youtube"
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.56)
  property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
  property var playerService: null
  property bool playerActive: false
  property alias playerVideoOutput: embeddedVideoOutput

  signal playRequested(var item, var options)
  signal fullscreenRequested()
  signal qualityChanged(var formatItem)
  signal quickDownloadRequested(var item)
  signal customDownloadRequested(var item)
  signal searchTriggered(string query)

  function updateFilteredList() {
    var filtered = MediaModel.filterResults(root.rawVideoList, root.activeFilter)
    var sorted = MediaModel.sortResults(filtered, root.activeSort)
    root.filteredVideoList = sorted

    var nextIndex = -1
    if (root.selectedVideo) {
      for (var i = 0; i < sorted.length; i++) {
        if (sorted[i].id === root.selectedVideo.id) {
          nextIndex = i
          break
        }
      }
    }
    if (nextIndex === -1 && sorted.length > 0) {
      nextIndex = 0
    }
    root.selectIndex(nextIndex)
  }

  function selectIndex(index) {
    if (index >= 0 && index < root.filteredVideoList.length) {
      root.selectedIndex = index
      root.selectedVideo = root.filteredVideoList[index]
    } else {
      root.selectedIndex = -1
      root.selectedVideo = null
    }
  }

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

  onRawVideoListChanged: updateFilteredList()
  onActiveSortChanged: updateFilteredList()
  onActiveFilterChanged: updateFilteredList()

  Column {
    anchors.fill: parent
    spacing: Style.spacing.md

    // Minimalist Top Bar
    Item {
      width: parent.width
      height: Style.space(42)

      // Results Count
      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: (!root.isSearching && root.filteredVideoList.length > 0) ? root.filteredVideoList.length + " results" : ""
        font.pixelSize: Style.font.caption
        font.bold: true
        color: root.dim
        textFormat: Text.PlainText
      }

      // Search & Filter Container
      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacing.md

        // Search Input
        TextField {
          id: searchInput
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(Style.space(340), root.width * 0.5)
          placeholderText: "Search YouTube videos..."
          maximumLength: 256
          foreground: root.foreground
          accent: root.accent
          onAccepted: if (text.trim()) root.searchTriggered(text.trim())
        }

        // Filter & Sort Button
        Button {
          id: filterBtn
          anchors.verticalCenter: parent.verticalCenter
          iconText: "\uf141"
          tooltipText: "Filters & Sorting"
          foreground: root.foreground
          accent: root.accent
          onClicked: filterPopup.open()

          QQC.Popup {
            id: filterPopup
            y: filterBtn.height + Style.spacing.sm
            padding: Style.spacing.md
            background: BorderSurface {
              color: Color.menu.background
              borderSpec: Border.controlSpec("normal", root.foreground, root.accent)
              radius: Style.cornerRadius
            }

            Column {
              spacing: Style.spacing.sm

              Text {
                text: "TYPE"
                color: root.dim
                font.pixelSize: Style.font.caption
                font.bold: true
                textFormat: Text.PlainText
              }

              Dropdown {
                width: Style.space(160)
                showLabel: false
                value: root.activeFilter
                options: [
                  { value: "all", label: "All types" },
                  { value: "videos", label: "Videos" },
                  { value: "live", label: "Live" },
                  { value: "short", label: "Under 4 min" },
                  { value: "medium", label: "4 to 20 min" },
                  { value: "long", label: "Over 20 min" }
                ]
                onChanged: function(value) { root.activeFilter = value; filterPopup.close() }
              }

              Text {
                text: "SORT BY"
                color: root.dim
                font.pixelSize: Style.font.caption
                font.bold: true
                textFormat: Text.PlainText
                topPadding: Style.spacing.sm
              }

              Dropdown {
                width: Style.space(160)
                showLabel: false
                value: root.activeSort
                options: [
                  { value: "relevance", label: "Relevance" },
                  { value: "views", label: "Most viewed" },
                  { value: "newest", label: "Newest" },
                  { value: "oldest", label: "Oldest" },
                  { value: "shortest", label: "Shortest" },
                  { value: "longest", label: "Longest" }
                ]
                onChanged: function(value) { root.activeSort = value; filterPopup.close() }
              }
            }
          }
        }
      }
    }

    // Top separator
    Rectangle {
      width: parent.width
      height: 1
      color: root.faint
    }

    // Main Split View
    Row {
      width: parent.width
      height: parent.height - Style.space(42) - Style.space(32) - 1 - Style.spacing.md * 3
      spacing: 0

      // Left Column: Results List
      Rectangle {
        width: parent.width * 0.35
        height: parent.height
        color: "transparent"
        clip: true

        ListView {
          id: resultListView
          anchors.fill: parent
          anchors.margins: Style.spacing.sm
          spacing: Style.spacing.xxs
          model: root.filteredVideoList
          boundsBehavior: Flickable.StopAtBounds
          QQC.ScrollBar.vertical: QQC.ScrollBar {}

          delegate: Rectangle {
            width: resultListView.width
            height: Style.space(68)
            radius: 2
            color: index === root.selectedIndex
              ? Style.selectedFillFor(root.foreground, root.accent)
              : (itemHover.hovered ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")

            HoverHandler {
              id: itemHover
            }

            MouseArea {
              anchors.fill: parent
              onClicked: root.selectIndex(index)
              onDoubleClicked: {
                root.selectIndex(index)
                root.playRequested(modelData, { mode: "video" })
              }
            }

            Row {
              anchors.fill: parent
              anchors.margins: Style.spacing.sm
              spacing: Style.spacing.md

              Rectangle {
                width: Style.space(96)
                height: parent.height
                radius: 2
                color: "#000000"
                clip: true

                Image {
                  anchors.fill: parent
                  source: modelData.thumbnailUrl || ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                }

                Rectangle {
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  anchors.margins: 4
                  height: Style.space(16)
                  width: durText.implicitWidth + 8
                  radius: 3
                  color: modelData.liveNow ? "#ef4444" : "#cc000000"

                  Text {
                    id: durText
                    anchors.centerIn: parent
                    text: modelData.durationText || ""
                    font.pixelSize: 10
                    font.bold: true
                    color: "#ffffff"
                  }
                }
              }

              Column {
                width: parent.width - Style.space(96) - Style.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                  text: modelData.title || ""
                  font.pixelSize: Style.font.body
                  font.bold: index === root.selectedIndex
                  color: root.foreground
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: modelData.author || ""
                  font.pixelSize: Style.font.caption
                  color: root.dim
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  width: parent.width
                }

                Row {
                  spacing: Style.spacing.sm
                  Text {
                    text: modelData.viewCountText || ""
                    font.pixelSize: Style.font.caption
                    color: root.dim
                    textFormat: Text.PlainText
                    visible: (modelData.viewCountText || "") !== ""
                  }
                  Text {
                    text: "· " + modelData.publishedText
                    font.pixelSize: Style.font.caption
                    color: root.dim
                    textFormat: Text.PlainText
                    visible: (modelData.publishedText || "") !== ""
                  }
                }
              }
            }

            // Active selection indicator
            Rectangle {
              visible: index === root.selectedIndex
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: 2
              color: root.accent
            }

            // Bottom separator
            Rectangle {
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              height: 1
              color: root.faint
            }
          }
        }

        // Empty state / Error state in list
        Item {
          anchors.fill: parent
          visible: root.filteredVideoList.length === 0 || root.isSearching

          Column {
            anchors.centerIn: parent
            spacing: Style.spacing.md

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.isSearching ? "\uf110" : (root.errorMessage ? "\uf071" : "\uf002")
              font.pixelSize: Style.space(32)
              color: root.dim
              textFormat: Text.PlainText
              transformOrigin: Item.Center

              RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: root.isSearching
              }
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.isSearching ? "Searching YouTube..." : (root.errorMessage || "Search for videos to get started.")
              font.pixelSize: Style.font.body
              color: root.dim
              textFormat: Text.PlainText
            }
          }
        }
      }

      // Vertical pane divider
      Rectangle {
        width: 1
        height: parent.height
        color: root.faint
      }

      // Right Column: Detail & Actions Preview Pane
      Rectangle {
        width: parent.width * 0.65 - 1
        height: parent.height
        color: "transparent"
        clip: true

        Column {
          anchors.fill: parent
          anchors.margins: Style.spacing.lg
          spacing: Style.spacing.md
          visible: root.selectedVideo !== null

          // Player / Preview Surface
          Rectangle {
            width: parent.width
            height: parent.height - metaColumn.height - actionRow.height - Style.spacing.panelPadding * 2
            radius: Style.cornerRadius
            color: "#000000"
            clip: true

            // Embedded Video Output (when playing video)
            VideoOutput {
              id: embeddedVideoOutput
              anchors.fill: parent
              fillMode: VideoOutput.PreserveAspectFit
              visible: root.playerActive && root.playerService && root.playerService.mode === "video"
            }

            // Audio Mode Visualization (when playing audio)
            Item {
              anchors.fill: parent
              visible: root.playerActive && root.playerService && root.playerService.mode === "audio"

              Image {
                anchors.centerIn: parent
                width: Style.space(120)
                height: Style.space(120)
                source: (root.playerService && root.playerService.currentItem && root.playerService.currentItem.artworkUrl) || ""
                fillMode: Image.PreserveAspectCrop
              }
            }

            // Static Preview Thumbnail (when not playing)
            Image {
              anchors.fill: parent
              source: (root.selectedVideo && root.selectedVideo.artworkUrl) || ""
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              visible: !root.playerActive
            }

            // Buffering Indicator
            Rectangle {
              id: bufferingOverlay
              anchors.centerIn: parent
              width: Style.space(52)
              height: Style.space(52)
              radius: height / 2
              color: "#cc000000"
              visible: root.playerActive && root.playerService && (root.playerService.resolving || root.playerService.buffering)

              Text {
                anchors.centerIn: parent
                text: "\uf110"
                color: Color.accent
                font.pixelSize: Style.space(24)
                textFormat: Text.PlainText
                transformOrigin: Item.Center

                RotationAnimation on rotation {
                  from: 0
                  to: 360
                  duration: 900
                  loops: Animation.Infinite
                  running: bufferingOverlay.visible
                }
              }
            }

            // Play button overlay (only when not playing)
            Rectangle {
              anchors.centerIn: parent
              width: Style.space(52)
              height: Style.space(52)
              radius: height / 2
              color: playHover.hovered ? Color.accent : "#88000000"
              visible: !root.playerActive && root.selectedVideo !== null

              HoverHandler {
                id: playHover
              }

              Text {
                anchors.centerIn: parent
                text: "\uf04b"
                font.pixelSize: Style.font.title
                color: "#ffffff"
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.playRequested(root.selectedVideo, { mode: "video" })
              }
            }

            // Top Overlay Header (when playing)
            Rectangle {
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              height: Style.space(40)
              color: "#99000000"
              visible: root.playerActive

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.spacing.md
                anchors.rightMargin: Style.spacing.md
                spacing: Style.spacing.md

                Text {
                  width: parent.width - playerTopActions.width - Style.spacing.md
                  anchors.verticalCenter: parent.verticalCenter
                  text: (root.playerService && root.playerService.currentItem && root.playerService.currentItem.title) || "Now Playing"
                  font.pixelSize: Style.font.body
                  font.bold: true
                  color: "#ffffff"
                  elide: Text.ElideRight
                }

                Row {
                  id: playerTopActions
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.spacing.sm

                  QualityMenu {
                    formats: root.playerService ? root.playerService.currentFormats : ({})
                    activeFormatId: root.playerService ? root.playerService.activeFormatId : "auto"
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

            // Bottom Transport Controls Overlay (when playing)
            Rectangle {
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              height: Style.space(72)
              color: "#cc000000"
              visible: root.playerActive

              Column {
                anchors.fill: parent
                anchors.margins: Style.spacing.sm
                spacing: Style.spacing.sm

                // Scrubber & Time Bar
                Row {
                  width: parent.width
                  spacing: Style.spacing.sm

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.formatTime(root.playerService ? root.playerService.position : 0)
                    font.pixelSize: Style.font.caption
                    color: "#cccccc"
                    width: Style.space(40)
                  }

                  Rectangle {
                    width: parent.width - Style.space(80) - Style.spacing.md
                    height: Style.space(6)
                    radius: height / 2
                    color: "#44ffffff"
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                      anchors.left: parent.left
                      anchors.top: parent.top
                      anchors.bottom: parent.bottom
                      width: {
                        var dur = root.playerService ? root.playerService.duration : 0
                        var pos = root.playerService ? root.playerService.position : 0
                        if (dur <= 0) return 0
                        return Math.max(height, parent.width * (pos / dur))
                      }
                      radius: height / 2
                      color: Color.accent
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: function(mouse) {
                        if (!root.playerService || !root.playerService.duration) return
                        var ratio = mouse.x / width
                        var targetMs = ratio * root.playerService.duration
                        root.playerService.seek(targetMs)
                      }
                    }
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.formatTime(root.playerService ? root.playerService.duration : 0)
                    font.pixelSize: Style.font.caption
                    color: "#cccccc"
                    width: Style.space(40)
                    horizontalAlignment: Text.AlignRight
                  }
                }

                // Transport Buttons
                Row {
                  width: parent.width
                  spacing: Style.spacing.sm

                  Row {
                    spacing: Style.spacing.sm
                    anchors.verticalCenter: parent.verticalCenter

                    Button {
                      iconText: "\uf04a"
                      tooltipText: "Seek -10s"
                      onClicked: if (root.playerService) root.playerService.seekRelative(-10000)
                    }

                    Button {
                      iconText: (root.playerService && root.playerService.running && !root.playerService.paused) ? "\uf04c" : "\uf04b"
                      selected: true
                      active: true
                      tooltipText: (root.playerService && root.playerService.running && !root.playerService.paused) ? "Pause" : "Play"
                      onClicked: if (root.playerService) root.playerService.togglePlayback()
                    }

                    Button {
                      iconText: "\uf04e"
                      tooltipText: "Seek +10s"
                      onClicked: if (root.playerService) root.playerService.seekRelative(10000)
                    }

                    Button {
                      iconText: "\uf04d"
                      tooltipText: "Stop"
                      onClicked: if (root.playerService) root.playerService.stop()
                    }
                  }

                  Item { width: Style.space(8); height: 1 }

                  Row {
                    spacing: Style.spacing.sm
                    anchors.verticalCenter: parent.verticalCenter

                    Button {
                      text: ((root.playerService ? root.playerService.playbackRate : 1.0) + "x")
                      tooltipText: "Cycle Speed"
                      onClicked: {
                        if (!root.playerService) return
                        var r = root.playerService.playbackRate
                        if (r === 1.0) root.playerService.setPlaybackRate(1.25)
                        else if (r === 1.25) root.playerService.setPlaybackRate(1.5)
                        else if (r === 1.5) root.playerService.setPlaybackRate(2.0)
                        else if (r === 2.0) root.playerService.setPlaybackRate(0.75)
                        else root.playerService.setPlaybackRate(1.0)
                      }
                    }

                    Row {
                      spacing: Style.spacing.sm
                      anchors.verticalCenter: parent.verticalCenter

                      Button {
                        iconText: (root.playerService && root.playerService.muted) ? "\uf6a9" : "\uf028"
                        onClicked: if (root.playerService) root.playerService.toggleMute()
                      }

                      Rectangle {
                        width: Style.space(60)
                        height: Style.space(6)
                        radius: height / 2
                        color: "#44ffffff"
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                          anchors.left: parent.left
                          anchors.top: parent.top
                          anchors.bottom: parent.bottom
                          width: Math.max(height, parent.width * ((root.playerService ? root.playerService.volume : 70) / 100.0))
                          radius: height / 2
                          color: Color.accent
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: function(mouse) {
                            if (!root.playerService) return
                            var vol = Math.round((mouse.x / width) * 100)
                            root.playerService.setVolume(vol)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          Column {
            id: metaColumn
            width: parent.width
            spacing: Style.spacing.sm

            Text {
              text: (root.selectedVideo && root.selectedVideo.title) || ""
              font.pixelSize: Style.font.title
              font.bold: true
              color: root.foreground
              textFormat: Text.PlainText
              elide: Text.ElideRight
              width: parent.width
            }

            Row {
              spacing: Style.spacing.md
              Text {
                text: (root.selectedVideo && root.selectedVideo.author) || ""
                font.pixelSize: Style.font.body
                font.bold: true
                color: root.accent
                textFormat: Text.PlainText
              }
              Text {
                text: "· " + ((root.selectedVideo && root.selectedVideo.viewCountText) || "")
                font.pixelSize: Style.font.body
                color: root.dim
                textFormat: Text.PlainText
              }
              Text {
                text: "· " + ((root.selectedVideo && root.selectedVideo.publishedText) || "")
                font.pixelSize: Style.font.body
                color: root.dim
                textFormat: Text.PlainText
              }
            }

            Text {
              text: (root.selectedVideo && root.selectedVideo.description) || ""
              font.pixelSize: Style.font.caption
              color: root.dim
              textFormat: Text.PlainText
              elide: Text.ElideRight
              maximumLineCount: 3
              width: parent.width
            }
          }

          Item { width: 1; height: 1 }

          // Action Toolbar
          Row {
            id: actionRow
            width: parent.width
            spacing: Style.spacing.xs

            Button {
              text: "Play Video"
              iconText: "\uf04b"
              selected: true
              active: true
              foreground: root.foreground
              accent: root.accent
              onClicked: root.playRequested(root.selectedVideo, { mode: "video" })
            }

            Button {
              text: "Audio Mode"
              iconText: "\uf028"
              tooltipText: "Play in Audio-only stream mode"
              foreground: root.foreground
              accent: root.accent
              onClicked: root.playRequested(root.selectedVideo, { mode: "audio" })
            }

            Button {
              text: "Quick Download"
              iconText: "\uf019"
              tooltipText: "Download Best Quality to ~/Downloads"
              foreground: root.foreground
              accent: root.accent
              onClicked: root.quickDownloadRequested(root.selectedVideo)
            }

            Button {
              text: "Custom"
              iconText: "\uf013"
              tooltipText: "Choose Resolution, Audio-only, Container..."
              foreground: root.foreground
              accent: root.accent
              onClicked: root.customDownloadRequested(root.selectedVideo)
            }
          }

        }

        Item {
          anchors.fill: parent
          visible: root.selectedVideo === null

          Column {
            anchors.centerIn: parent
            spacing: Style.spacing.md

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "\uf03d"
              font.pixelSize: Style.space(40)
              color: root.dim
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "Select a video from the list to preview and play."
              font.pixelSize: Style.font.body
              color: root.dim
            }
          }
        }
      }
    }
  }
}
