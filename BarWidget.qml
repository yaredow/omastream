import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "user.omastream"

  readonly property var playbackService: bar && bar.shell
    ? bar.shell.serviceFor(root.moduleName)
    : null
  readonly property bool playerRunning: playbackService ? playbackService.running : false
  readonly property bool playerPaused: playbackService ? playbackService.paused : false
  readonly property string playerTitle: playbackService && playbackService.currentItem
    ? playbackService.currentItem.title || ""
    : ""
  readonly property string playerAuthor: playbackService && playbackService.currentItem
    ? playbackService.currentItem.author || ""
    : ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf144"
    active: root.playerRunning && !root.playerPaused
    tooltipText: root.playerRunning
      ? (root.playerPaused ? "Paused: " : "Playing: ") + root.playerTitle
        + (root.playerAuthor ? " · " + root.playerAuthor : "")
      : "omaStream (YouTube Stream & Search)"

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) {
        if (root.playbackService && root.playerRunning) root.playbackService.stop()
        return
      }
      if (mouseButton === Qt.MiddleButton) {
        if (root.playbackService && root.playerRunning) root.playbackService.togglePlayback()
        return
      }
      if (root.bar && root.bar.shell) root.bar.shell.toggle(root.moduleName, "{}")
    }

    onWheelMoved: function(delta) {
      if (!root.playbackService || !root.playerRunning) return
      var nextVolume = root.playbackService.volume + (delta > 0 ? 5 : -5)
      root.playbackService.setVolume(nextVolume)
    }
  }
}
