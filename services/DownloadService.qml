import QtQuick
import Quickshell
import Quickshell.Io

import "DownloadModel.js" as DownloadModel

Item {
  id: root

  property var jobs: []
  property string activeJobId: ""
  readonly property bool isDownloading: downloadProcess.running
  readonly property int activeCount: {
    var count = 0
    for (var i = 0; i < root.jobs.length; i++) {
      if (root.jobs[i].state === "downloading" || root.jobs[i].state === "merging" || root.jobs[i].state === "preparing" || root.jobs[i].state === "queued") {
        count++
      }
    }
    return count
  }

  readonly property string downloadScriptPath: Qt.resolvedUrl("../scripts/omastream-download").toString().replace(/^file:\/\//, "")
  readonly property string historyPath: {
    var home = Quickshell.env("HOME") || "/home/yada"
    return home + "/.local/share/omastream/download_history.json"
  }

  signal jobUpdated(string jobId)

  function startDownload(item, options) {
    if (!item) return null
    var job = DownloadModel.createJob(item, options)
    var updated = [job].concat(root.jobs)
    root.jobs = updated
    saveHistory()
    Qt.callLater(root.processQueue)
    return job
  }

  function cancelDownload(jobId) {
    if (!jobId) return
    if (root.activeJobId === jobId && downloadProcess.running) {
      downloadProcess.running = false
    }
    updateJob(jobId, { state: "cancelled" })
    saveHistory()
    Qt.callLater(root.processQueue)
  }

  function retryDownload(jobId) {
    if (!jobId) return
    updateJob(jobId, {
      state: "queued",
      percent: 0,
      downloadedBytes: 0,
      speed: 0,
      eta: 0,
      error: ""
    })
    saveHistory()
    Qt.callLater(root.processQueue)
  }

  function pauseDownload(jobId) {
    if (root.activeJobId !== jobId || !downloadProcess.running) return
    downloadProcess.running = false
    updateJob(jobId, { state: "paused" })
    saveHistory()
  }

  function resumeDownload(jobId) {
    var job = root.getJob(jobId)
    if (!job || job.state !== "paused") return
    updateJob(jobId, { state: "queued" })
    saveHistory()
    Qt.callLater(root.processQueue)
  }

  function removeDownload(jobId) {
    if (!jobId) return
    if (root.activeJobId === jobId && downloadProcess.running) {
      downloadProcess.running = false
    }
    var next = []
    for (var i = 0; i < root.jobs.length; i++) {
      if (root.jobs[i].jobId !== jobId) {
        next.push(root.jobs[i])
      }
    }
    root.jobs = next
    saveHistory()
  }

  function clearCompleted() {
    var next = []
    for (var i = 0; i < root.jobs.length; i++) {
      var s = root.jobs[i].state
      if (s === "downloading" || s === "merging" || s === "preparing" || s === "queued") {
        next.push(root.jobs[i])
      }
    }
    root.jobs = next
    saveHistory()
  }

  function revealInFileManager(path) {
    if (!path) path = (Quickshell.env("HOME") || "/home/yada") + "/Downloads"
    openFolderProcess.command = ["xdg-open", path]
    openFolderProcess.running = true
  }

  function getJob(jobId) {
    for (var i = 0; i < root.jobs.length; i++) {
      if (root.jobs[i].jobId === jobId) return root.jobs[i]
    }
    return null
  }

  function updateJob(jobId, fields) {
    var copy = []
    var found = false
    for (var i = 0; i < root.jobs.length; i++) {
      var item = Object.assign({}, root.jobs[i])
      if (item.jobId === jobId) {
        Object.assign(item, fields)
        found = true
      }
      copy.push(item)
    }
    if (found) {
      root.jobs = copy
      root.jobUpdated(jobId)
    }
  }

  function processQueue() {
    if (downloadProcess.running) return

    var queuedJob = null
    for (var i = 0; i < root.jobs.length; i++) {
      if (root.jobs[i].state === "queued") {
        queuedJob = root.jobs[i]
        break
      }
    }

    if (!queuedJob) {
      root.activeJobId = ""
      return
    }

    root.activeJobId = queuedJob.jobId
    updateJob(queuedJob.jobId, { state: "preparing" })

    var args = [
      root.downloadScriptPath,
      "--job-id", queuedJob.jobId,
      "--url", queuedJob.videoId,
      "--dest", queuedJob.destination,
      "--format-mode", queuedJob.formatMode || "video_audio",
      "--format-id", queuedJob.formatId || "best",
      "--container", queuedJob.container || "mp4"
    ]

    downloadProcess.command = args
    downloadProcess.running = true
  }

  function handleEvent(jsonLine) {
    if (!jsonLine || jsonLine.trim() === "") return
    try {
      var ev = JSON.parse(jsonLine)
      if (!ev || !ev.jobId) return

      if (ev.type === "started") {
        updateJob(ev.jobId, { state: "downloading" })
      } else if (ev.type === "progress") {
        updateJob(ev.jobId, {
          state: "downloading",
          percent: Number(ev.percent) || 0,
          downloadedBytes: Number(ev.downloadedBytes) || 0,
          totalBytes: Number(ev.totalBytes) || 0,
          speed: Number(ev.speed) || 0,
          eta: Number(ev.eta) || 0
        })
      } else if (ev.type === "status") {
        updateJob(ev.jobId, { state: ev.state || "downloading" })
      } else if (ev.type === "completed") {
        updateJob(ev.jobId, {
          state: "completed",
          percent: 100.0,
          outputPath: ev.path || "",
          completedAt: Date.now()
        })
        saveHistory()
      } else if (ev.type === "failed") {
        updateJob(ev.jobId, {
          state: "failed",
          error: ev.error || "Download failed."
        })
        saveHistory()
      }
    } catch (err) {
      // ignore non-json lines
    }
  }

  function loadHistory() {
    loadHistoryProcess.command = ["cat", root.historyPath]
    loadHistoryProcess.running = true
  }

  function saveHistory() {
    var toSave = root.jobs.slice(0, 50)
    var jsonText = JSON.stringify(toSave)
    saveHistoryProcess.command = [
      "bash", "-c",
      "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"",
      "_",
      root.historyPath,
      jsonText
    ]
    saveHistoryProcess.running = true
  }

  Component.onCompleted: {
    loadHistory()
  }

  Process {
    id: downloadProcess
    command: []
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        root.handleEvent(line)
      }
    }
    stderr: StdioCollector {
      id: downloadStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      var jId = root.activeJobId
      root.activeJobId = ""
      if (jId) {
        var j = root.getJob(jId)
        if (j && (j.state === "downloading" || j.state === "preparing" || j.state === "merging")) {
          if (exitCode === 0) {
            root.updateJob(jId, { state: "completed", percent: 100.0, completedAt: Date.now() })
          } else {
            var errMsg = String(downloadStderr.text || "").trim() || "Download exited with code " + exitCode
            root.updateJob(jId, { state: "failed", error: errMsg })
          }
          root.saveHistory()
        }
      }
      Qt.callLater(root.processQueue)
    }
  }

  Process {
    id: loadHistoryProcess
    command: []
    stdout: StdioCollector {
      id: historyCollector
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode === 0 && historyCollector.text) {
        try {
          var parsed = JSON.parse(historyCollector.text)
          if (Array.isArray(parsed)) {
            var restored = parsed.map(function(item) {
              if (item.state === "downloading" || item.state === "preparing" || item.state === "merging") {
                item.state = "cancelled"
              }
              return item
            })
            root.jobs = restored
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: saveHistoryProcess
    command: []
  }

  Process {
    id: openFolderProcess
    command: []
  }
}
