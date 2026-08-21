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

  property string activeSort: "relevance" 
  property string activeFilter: "all" 
  property string activeSource: "youtube"
  property bool controlsVisible: true
  readonly property bool qualityPopupOpen: discoverQualityMenu && discoverQualityMenu.popupOpen
  readonly property bool playingUnpaused: root.playerService
    && root.playerService.running
    && !root.playerService.paused

  function revealPlayerControls() {
    root.controlsVisible = true
    if (!root.playingUnpaused || root.qualityPopupOpen || root.playerErrorText)
      playerControlsTimer.stop()
    else
      playerControlsTimer.restart()
  }

  Timer {
    id: playerControlsTimer
    interval: 3000
    running: false
    repeat: false
    onTriggered: {
      if (!root.playingUnpaused) return
      if (root.qualityPopupOpen) return
      if (root.playerErrorText) return
      if (playerSurfaceHover && playerSurfaceHover.hovered) return
      root.controlsVisible = false
    }
  }

  Connections {
    target: root.playerService
    ignoreUnknownSignals: true
    function onPausedChanged() {
      root.revealPlayerControls()
    }
  }

  Connections {
    target: discoverQualityMenu
    ignoreUnknownSignals: true
    function onPopupOpenChanged() {
      if (discoverQualityMenu.popupOpen)
        root.revealPlayerControls()
    }
  }
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.56)
  property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
  property var playerService: null
  property bool playerActive: false
  readonly property bool isCurrentPlayerItem: root.playerService
    && root.playerService.currentItem
    && root.selectedVideo
    && root.playerService.currentItem.id === root.selectedVideo.id
  readonly property bool isCurrentPlaybackActive: root.isCurrentPlayerItem && root.playerActive
  readonly property bool isCurrentVideoPlaying: root.isCurrentPlaybackActive
  readonly property string playerErrorText: root.isCurrentPlayerItem && root.playerService
    ? (root.playerService.errorMessage || "")
    : ""
  readonly property string playerStatusText: root.isCurrentPlayerItem && root.playerService
    ? (root.playerService.statusMessage || "")
    : ""
  property alias playerVideoOutput: embeddedVideoOutput

  signal playRequested(var item, var options)
  signal fullscreenRequested()
  signal qualityChanged(var formatItem)
  signal quickDownloadRequested(var item)
  signal customDownloadRequested(var item, var options)
  signal searchTriggered(string query)
  signal clearSearchRequested()

  function focusSearch() {
    searchInput.forceActiveFocus()
  }

  function clearSearch() {
    searchInput.text = ""
    root.clearSearchRequested()
  }

  function updateFilteredList() {
    var filtered = MediaModel.filterResults(root.rawVideoList, root.activeFilter)
    var sorted = MediaModel.sortResults(filtered, root.activeSort)
    root.filteredVideoList = sorted

    var playingId = root.playerService && root.playerService.currentItem
      ? root.playerService.currentItem.id : ""
    var nextIndex = -1
    var preferredId = root.selectedVideo ? root.selectedVideo.id : playingId

    if (preferredId) {
      for (var i = 0; i < sorted.length; i++) {
        if (sorted[i].id === preferredId) {
          nextIndex = i
          break
        }
      }
    }

    if (nextIndex === -1 && playingId) {
      for (var j = 0; j < sorted.length; j++) {
        if (sorted[j].id === playingId) {
          nextIndex = j
          break
        }
      }
    }

    if (nextIndex === -1 && playingId && root.playerService.currentItem) {
      root.selectedIndex = -1
      root.selectedVideo = root.playerService.currentItem
      return
    }

    if (nextIndex === -1 && sorted.length > 0)
      nextIndex = 0

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
      id: topBar
      width: parent.width
      height: Style.space(56)

      // Results Count
      Text {
        anchors.left: parent.left
        anchors.leftMargin: Style.spacing.panelPadding
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
        anchors.rightMargin: Style.spacing.panelPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacing.sm

        // Search Input
        TextField {
          id: searchInput
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(Style.space(340), root.width * 0.48)
          placeholderText: "Search or paste a URL (YouTube, X, Twitch...)"
          maximumLength: 256
          foreground: root.foreground
          accent: root.accent
          onAccepted: {
            var q = String(text || "").trim()
            if (q.length > 0) {
              root.searchTriggered(q)
            }
          }
          onTextEdited: {
            if (!String(text || "").trim() && root.rawVideoList.length > 0) {
              root.clearSearch()
            }
          }

          // Clear Button INSIDE search field
          Button {
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.xs
            anchors.verticalCenter: parent.verticalCenter
            visible: String(searchInput.text || "").length > 0 || (root.rawVideoList && root.rawVideoList.length > 0)
            iconText: "\uf00d"
            tooltipText: "Clear search"
            fontSize: Style.font.caption
            foreground: root.dim
            accent: root.accent
            onClicked: root.clearSearch()
          }
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
            parent: root
            x: Math.max(0, (root.width - width) / 2)
            y: Math.max(0, (root.height - height) / 2)
            width: Math.min(Style.space(600), root.width * 0.9)
            height: Math.min(Style.space(280), root.height * 0.9)
            modal: true
            dim: true
            closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside
            
            // Nice padding for the modal
            padding: Style.spacing.panelPadding
            
            // State for the two-pane UI
            property string activeCategory: "sort"

            background: Rectangle {
              color: Color.menu.background
              border.color: root.faint
              border.width: 1
              radius: Style.cornerRadius
            }

            contentItem: Item {
              anchors.fill: parent
              
              Row {
                anchors.fill: parent
                anchors.margins: Style.space(24)
                spacing: Style.space(24)

                // Left Pane: Categories
                Rectangle {
                  width: (parent.width - Style.space(24) * 2 - 1) * 0.4
                  height: parent.height
                  color: "transparent"

                  Column {
                    anchors.fill: parent
                    spacing: Style.spacing.sm

                    Repeater {
                      model: [
                        { id: "sort", label: "Sort by" },
                        { id: "type", label: "Type" },
                        { id: "duration", label: "Duration" }
                      ]
                      delegate: Rectangle {
                        width: parent.width
                        height: Style.space(32)
                        color: "transparent"
                        border.color: filterPopup.activeCategory === modelData.id ? root.foreground : "transparent"
                        border.width: 1
                        radius: 2

                        Text {
                          anchors.fill: parent
                          anchors.leftMargin: Style.spacing.sm
                          verticalAlignment: Text.AlignVCenter
                          text: modelData.label
                          color: root.foreground
                          font.pixelSize: Style.font.body
                          textFormat: Text.PlainText
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: filterPopup.activeCategory = modelData.id
                        }
                      }
                    }

                    Item { width: 1; height: Style.spacing.md } // Spacer

                    Rectangle {
                      width: parent.width
                      height: Style.space(32)
                      color: "transparent"
                      Text {
                        anchors.fill: parent
                        anchors.leftMargin: Style.spacing.sm
                        verticalAlignment: Text.AlignVCenter
                        text: "Reset filters"
                        color: root.dim
                        font.pixelSize: Style.font.body
                        textFormat: Text.PlainText
                      }
                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.activeFilter = "all"
                          root.activeSort = "relevance"
                          filterPopup.close()
                        }
                      }
                    }
                  }
                }

                // Vertical Divider
                Rectangle {
                  width: 1
                  height: parent.height
                  color: root.faint
                }

                // Right Pane: Options
                Rectangle {
                  width: (parent.width - Style.space(24) * 2 - 1) * 0.6
                  height: parent.height
                  color: "transparent"

                  Column {
                    anchors.fill: parent
                    spacing: Style.spacing.sm

                    // Sort Options
                    Repeater {
                      model: filterPopup.activeCategory === "sort" ? [
                        { id: "relevance", label: "Relevance" },
                        { id: "views", label: "View count" },
                        { id: "newest", label: "Upload date" },
                        { id: "oldest", label: "Oldest" },
                        { id: "shortest", label: "Shortest" },
                        { id: "longest", label: "Longest" }
                      ] : []
                      delegate: Rectangle {
                        width: parent.width
                        height: Style.space(32)
                        color: "transparent"
                        border.color: root.activeSort === modelData.id ? root.accent : "transparent"
                        border.width: 1
                        radius: 2

                        Text {
                          anchors.fill: parent
                          anchors.leftMargin: Style.spacing.sm
                          verticalAlignment: Text.AlignVCenter
                          text: modelData.label
                          color: root.foreground
                          font.pixelSize: Style.font.body
                          textFormat: Text.PlainText
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.activeSort = modelData.id
                            filterPopup.close()
                          }
                        }
                      }
                    }

                    // Type Options
                    Repeater {
                      model: filterPopup.activeCategory === "type" ? [
                        { id: "all", label: "All" },
                        { id: "videos", label: "Videos" },
                        { id: "live", label: "Live" }
                      ] : []
                      delegate: Rectangle {
                        width: parent.width
                        height: Style.space(32)
                        color: "transparent"
                        border.color: root.activeFilter === modelData.id ? root.accent : "transparent"
                        border.width: 1
                        radius: 2

                        Text {
                          anchors.fill: parent
                          anchors.leftMargin: Style.spacing.sm
                          verticalAlignment: Text.AlignVCenter
                          text: modelData.label
                          color: root.foreground
                          font.pixelSize: Style.font.body
                          textFormat: Text.PlainText
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.activeFilter = modelData.id
                            filterPopup.close()
                          }
                        }
                      }
                    }

                    // Duration Options
                    Repeater {
                      model: filterPopup.activeCategory === "duration" ? [
                        { id: "short", label: "Under 4 minutes" },
                        { id: "medium", label: "4-20 minutes" },
                        { id: "long", label: "Over 20 minutes" }
                      ] : []
                      delegate: Rectangle {
                        width: parent.width
                        height: Style.space(32)
                        color: "transparent"
                        border.color: root.activeFilter === modelData.id ? root.accent : "transparent"
                        border.width: 1
                        radius: 2

                        Text {
                          anchors.fill: parent
                          anchors.leftMargin: Style.spacing.sm
                          verticalAlignment: Text.AlignVCenter
                          text: modelData.label
                          color: root.foreground
                          font.pixelSize: Style.font.body
                          textFormat: Text.PlainText
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.activeFilter = modelData.id
                            filterPopup.close()
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
      }

      // Bottom separator for Top Bar
      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: root.faint
      }
    }

    // Main Split View
    Row {
      width: parent.width
      height: parent.height - (topBar.height + Style.spacing.md)
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
          anchors.leftMargin: Style.spacing.panelPadding
          anchors.rightMargin: Style.spacing.sm
          anchors.topMargin: Style.spacing.sm
          anchors.bottomMargin: Style.spacing.panelPadding
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
                  sourceSize: Qt.size(Style.space(192), Style.space(108))
                }

                Rectangle {
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  anchors.margins: Style.spacing.sm
                  width: durText.contentWidth + Style.space(12)
                  height: durText.contentHeight + Style.space(4)
                  radius: Style.cornerRadius
                  color: modelData.liveNow ? "#ef4444" : Color.menu.background

                  Text {
                    id: durText
                    anchors.centerIn: parent
                    text: modelData.durationText || ""
                    font.pixelSize: 10
                    font.bold: true
                    color: modelData.liveNow ? "#ffffff" : root.foreground
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
                    text: (modelData.viewCountText ? "· " : "") + (modelData.publishedText || "")
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

            // Spinning search loader
            Text {
              visible: root.isSearching
              anchors.horizontalCenter: parent.horizontalCenter
              text: "\uf110"
              font.pixelSize: Style.space(32)
              color: root.dim
              textFormat: Text.PlainText
              transformOrigin: Item.Center

              NumberAnimation on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: root.isSearching
              }
            }

            // Static search / error icon
            Text {
              visible: !root.isSearching
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.errorMessage ? "\uf071" : "\uf002"
              font.pixelSize: Style.space(32)
              color: root.dim
              textFormat: Text.PlainText
              rotation: 0
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
          anchors.leftMargin: Style.spacing.lg
          anchors.rightMargin: Style.spacing.panelPadding
          anchors.topMargin: Style.spacing.lg
          anchors.bottomMargin: Style.spacing.panelPadding
          spacing: Style.spacing.md
          visible: root.selectedVideo !== null

          // Player / Preview Surface
          Rectangle {
            width: parent.width
            height: Math.max(10, parent.height - metaColumn.height - actionRow.height - spacer.height - (Style.spacing.md * 3))
            radius: Style.cornerRadius
            color: "#000000"
            clip: true

            HoverHandler {
              id: playerSurfaceHover
              onHoveredChanged: {
                if (hovered) {
                  root.revealPlayerControls()
                } else if (root.playingUnpaused) {
                  playerControlsTimer.restart()
                }
              }
            }

            // Embedded Video Output (when playing video)
            VideoOutput {
              id: embeddedVideoOutput
              anchors.fill: parent
              fillMode: VideoOutput.PreserveAspectFit
              visible: root.isCurrentVideoPlaying && root.playerService.mode === "video"
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              visible: root.isCurrentVideoPlaying && !root.playerErrorText
              cursorShape: Qt.ArrowCursor
              onPositionChanged: root.revealPlayerControls()
              onClicked: {
                if (!root.controlsVisible) {
                  root.revealPlayerControls()
                  return
                }
                if (root.playerService) root.playerService.togglePlayback()
              }
            }

            // Audio Mode Visualization (owned item in audio mode, including loading/error)
            Item {
              anchors.fill: parent
              visible: root.isCurrentPlayerItem && root.playerService && root.playerService.mode === "audio"

              Image {
                anchors.fill: parent
                source: (root.playerService && root.playerService.currentItem && root.playerService.currentItem.artworkUrl) || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.28
                sourceSize: Qt.size(Style.space(640), Style.space(360))
              }

              Rectangle {
                anchors.fill: parent
                color: "#99000000"
              }

              Column {
                anchors.centerIn: parent
                spacing: Style.spacing.md
                width: parent.width * 0.8

                Image {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: Math.min(parent.parent.width * 0.32, parent.parent.height * 0.65)
                  height: width
                  source: (root.playerService && root.playerService.currentItem && root.playerService.currentItem.artworkUrl) || ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  sourceSize: Qt.size(Style.space(480), Style.space(480))
                }

                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: audioModeBadge.implicitWidth + Style.space(16)
                  height: Style.space(24)
                  radius: height / 2
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)

                  Text {
                    id: audioModeBadge
                    anchors.centerIn: parent
                    text: "Audio Mode"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.accent
                    textFormat: Text.PlainText
                  }
                }
              }
            }

            // Static Preview Thumbnail (when this item does not own the player)
            Image {
              anchors.fill: parent
              source: (root.selectedVideo && root.selectedVideo.artworkUrl) || ""
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              visible: !root.isCurrentPlayerItem
            }

            // Buffering Indicator
            Rectangle {
              id: bufferingOverlay
              anchors.centerIn: parent
              width: Style.space(52)
              height: Style.space(52)
              radius: height / 2
              color: "#cc000000"
              visible: root.isCurrentPlayerItem
                && !root.playerErrorText
                && root.playerService
                && root.playerService.showLoadingOverlay

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

            // Soft status while resolving fallbacks
            Text {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.margins: Style.spacing.md
              anchors.bottomMargin: root.controlsVisible && root.isCurrentVideoPlaying
                ? Style.space(100) : Style.spacing.md
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              text: root.playerStatusText
              visible: root.isCurrentPlayerItem && !!root.playerStatusText && !root.playerErrorText
              color: "#dddddd"
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
              z: 3
            }

            // Playback error overlay (owned item, terminal failure)
            Rectangle {
              anchors.fill: parent
              color: "#cc000000"
              visible: root.isCurrentPlayerItem && !!root.playerErrorText
              z: 4

              Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - Style.spacing.lg * 2, Style.space(360))
                spacing: Style.spacing.md

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "\uf071"
                  font.pixelSize: Style.space(28)
                  color: "#f59e0b"
                  textFormat: Text.PlainText
                }

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  text: (root.playerService && root.playerService.mode === "audio")
                    ? "Unable to play audio"
                    : "Unable to play media"
                  font.pixelSize: Style.font.body
                  font.bold: true
                  color: root.foreground
                  textFormat: Text.PlainText
                  wrapMode: Text.WordWrap
                }

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  text: root.playerErrorText
                  font.pixelSize: Style.font.caption
                  color: "#cccccc"
                  textFormat: Text.PlainText
                  wrapMode: Text.WordWrap
                }

                Button {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "Retry"
                  iconText: "\uf01e"
                  tooltipText: "Retry playback"
                  foreground: root.foreground
                  accent: root.accent
                  onClicked: {
                    if (root.playerService && root.playerService.retryCurrentRequest)
                      root.playerService.retryCurrentRequest()
                  }
                }
              }
            }

            // Play button overlay (only when this item does not own the player)
            Rectangle {
              anchors.fill: parent
              color: Qt.rgba(Color.menu.background.r, Color.menu.background.g, Color.menu.background.b, 0.5)
              visible: !root.isCurrentPlayerItem && root.selectedVideo !== null

              Text {
                anchors.centerIn: parent
                text: "\uf04b"
                font.pixelSize: Style.font.title
                color: root.foreground
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
              color: Qt.rgba(Color.menu.background.r, Color.menu.background.g, Color.menu.background.b, 0.8)
              visible: root.isCurrentVideoPlaying && root.controlsVisible && !root.playerErrorText

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.spacing.md
                anchors.rightMargin: Style.spacing.md
                spacing: Style.spacing.sm

                Text {
                  width: parent.width - playerTopActions.width - Style.spacing.md
                  anchors.verticalCenter: parent.verticalCenter
                  text: (root.playerService && root.playerService.currentItem && root.playerService.currentItem.title) || "Now Playing"
                  font.pixelSize: Style.font.body
                  font.bold: true
                  color: root.foreground
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                }

                Row {
                  id: playerTopActions
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.spacing.sm
                  visible: root.playerService && root.playerService.mode === "video"

                  QualityMenu {
                    id: discoverQualityMenu
                    formats: root.playerService ? root.playerService.currentFormats : ({})
                    formatsLoading: root.playerService ? root.playerService.formatsLoading : false
                    activeFormatId: root.playerService ? root.playerService.activeFormatId : "auto"
                    onQualitySelected: function(item) {
                      root.qualityChanged(item)
                    }
                  }

                  Button {
                    iconText: "\uf065"
                    tooltipText: "Fullscreen (f)"
                    onClicked: root.fullscreenRequested()
                  }
                }
              }
            }

            // Bottom Overlay Footer (when playing)
            Rectangle {
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              height: Style.space(88)
              color: "#cc000000"
              visible: root.isCurrentVideoPlaying && root.controlsVisible && !root.playerErrorText

              Column {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Style.spacing.panelPadding
                anchors.rightMargin: Style.spacing.panelPadding
                anchors.bottomMargin: Style.spacing.md
                spacing: Style.spacing.lg

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
                    opacity: (root.playerService && root.playerService.seekable) ? 1.0 : 0.45

                    Rectangle {
                      anchors.left: parent.left
                      anchors.top: parent.top
                      anchors.bottom: parent.bottom
                      width: {
                        var dur = root.playerService ? root.playerService.duration : 0
                        var buf = root.playerService ? root.playerService.bufferProgress : 0
                        if (dur <= 0) return 0
                        return Math.max(0, parent.width * buf)
                      }
                      radius: height / 2
                      color: "#66ffffff"
                    }

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
                      enabled: root.playerService && root.playerService.seekable && root.playerService.duration > 0
                      cursorShape: Qt.PointingHandCursor
                      function seekAt(mouseX) {
                        if (!root.playerService || !root.playerService.duration) return
                        var ratio = Math.max(0, Math.min(1, mouseX / width))
                        root.playerService.seek(ratio * root.playerService.duration)
                        root.revealPlayerControls()
                      }
                      onClicked: function(mouse) { seekAt(mouse.x) }
                      onPositionChanged: function(mouse) {
                        if (pressed) seekAt(mouse.x)
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
                      foreground: root.foreground
                      accent: root.accent
                      onClicked: if (root.playerService) root.playerService.seekRelative(-10000)
                    }

                    Button {
                      iconText: (root.playerService && root.playerService.running && !root.playerService.paused) ? "\uf04c" : "\uf04b"
                      selected: true
                      tooltipText: (root.playerService && root.playerService.running && !root.playerService.paused) ? "Pause" : "Play"
                      foreground: root.foreground
                      accent: root.accent
                      onClicked: if (root.playerService) root.playerService.togglePlayback()
                    }

                    Button {
                      iconText: "\uf04e"
                      tooltipText: "Seek +10s"
                      foreground: root.foreground
                      accent: root.accent
                      onClicked: if (root.playerService) root.playerService.seekRelative(10000)
                    }

                    Button {
                      iconText: "\uf04d"
                      tooltipText: "Stop"
                      foreground: root.foreground
                      accent: root.accent
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
                      foreground: root.foreground
                      accent: root.accent
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
                        iconText: (root.playerService && root.playerService.muted) ? "\uf026" : "\uf028"
                        tooltipText: (root.playerService && root.playerService.muted) ? "Unmute" : "Mute"
                        foreground: root.foreground
                        accent: root.accent
                        onClicked: if (root.playerService) root.playerService.toggleMute()
                      }

                      Rectangle {
                        width: Style.space(80)
                        height: Style.space(6)
                        radius: height / 2
                        color: "transparent"
                        border.color: "#333333"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                          anchors.fill: parent
                          color: "#222222"
                          radius: height / 2
                        }

                        Rectangle {
                          anchors.left: parent.left
                          anchors.top: parent.top
                          anchors.bottom: parent.bottom
                          width: Math.max(height, parent.width * ((root.playerService ? ((root.playerService.muted) ? 0 : root.playerService.volume) : 70) / 100.0))
                          radius: height / 2
                          color: (root.playerService && root.playerService.muted) ? "#777777" : Color.accent
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          function setVol(mouseX) {
                            if (!root.playerService) return
                            var vol = Math.max(0, Math.min(100, Math.round((mouseX / width) * 100)))
                            root.playerService.setVolume(vol)
                            if (root.playerService.muted) root.playerService.toggleMute()
                          }
                          onClicked: function(mouse) { setVol(mouse.x) }
                          onPositionChanged: function(mouse) {
                            if (pressed) setVol(mouse.x)
                          }
                        }
                      }
                      
                      Text {
                        text: root.playerService ? (root.playerService.muted ? "Muted" : Math.round(root.playerService.volume) + "%") : "70%"
                        font.pixelSize: Style.font.caption
                        color: (root.playerService && root.playerService.muted) ? "#777777" : root.dim
                        anchors.verticalCenter: parent.verticalCenter
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
              wrapMode: Text.Wrap
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
                visible: !!(root.selectedVideo && root.selectedVideo.publishedText)
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

          Item { id: spacer; width: 1; height: 1 }

          // Action Toolbar
          Flow {
            id: actionRow
            width: parent.width
            spacing: Style.spacing.xs

            Button {
              text: "Audio Mode"
              iconText: "\uf028"
              tooltipText: "Play in Audio-only stream mode"
              foreground: root.foreground
              accent: root.accent
              onClicked: root.playRequested(root.selectedVideo, { mode: "audio" })
            }

            Button {
              text: "Download"
              iconText: "\uf019"
              tooltipText: "Select quality and download"
              foreground: root.foreground
              accent: root.accent
              onClicked: {
                if (root.playerService && root.selectedVideo) {
                  root.playerService.fetchFormats(root.selectedVideo)
                }
                downloadPicker.item = root.selectedVideo
                downloadPicker.open()
              }
            }
          }

          DownloadPicker {
            id: downloadPicker
            parent: root
            formats: (root.playerService && root.playerService.currentFormats) || ({ playback: [], downloadVideo: [], downloadAudio: [] })
            onDownloadRequested: function(item, opts) {
              root.customDownloadRequested(item, opts)
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
              text: "\uf144"
              font.pixelSize: Style.space(40)
              color: root.dim
              textFormat: Text.PlainText
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "Select a video from the list to preview and play."
              font.pixelSize: Style.font.body
              color: root.dim
              textFormat: Text.PlainText
            }
          }
        }
      }
    }
  }
}
