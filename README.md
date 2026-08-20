# omaStream

**YouTube search, playback, and download in Quickshell.**

omaStream brings YouTube Discovery, an embedded player, and a fully-featured download manager directly into the Omarchy shell. Videos play locally through Qt Multimedia and **yt-dlp**, skipping the heavy browser client entirely.

## Why you will love it

- **Lightweight by design.** Playback is natively integrated into Quickshell, not an Electron YouTube client.
- **Discover.** Bounded search with exact date hydration, filtering, and timestamp-aware sorting.
- **Player.** Dedicated player surface with inline & fullscreen playback, audio-only mode, playback rate control, volume slider, and dynamic stream quality inspection.
- **Downloads Manager.** Observable transfer queue, persistent history, real-time speed, ETA, and cancellation.
- **Custom Download Flow.** Select container (MP4, MKV, WebM, MP3, M4A), audio-only extraction, or specific video resolutions merged via FFmpeg.
- **Persistent Service.** Shared playback and download queue state between the overlay and bar widget.

## Familiar from the first click

| Shortcut | What it does |
| --- | --- |
| `Space` | Play or pause |
| `Left` / `Right` | Seek backward or forward 10 seconds |
| `Up` / `Down` | Change volume |
| `M` | Mute or unmute |
| `F` | Enter or leave fullscreen video |
| `/` | Focus search in Discover mode |
| `Escape` | Leave fullscreen, clear search focus, or close the overlay |

The bar widget uses middle click for play/pause, right click to stop, and the mouse wheel for volume.

## Install

```bash
omarchy plugin add https://github.com/USERNAME/omastream.git --enable
```

Requires **Omarchy 4**, **Python 3**, **ffmpeg**, **jq**, and **yt-dlp**:

```bash
omarchy pkg add ffmpeg yt-dlp python jq
```

From a local checkout:

```bash
omarchy plugin clone user.omastream --edit
```

## Remove

To completely remove this plugin from your system:

```bash
omarchy plugin remove user.omastream
```

This will also delete your downloads history. To keep your downloaded media, ensure your configured downloads folder is outside of the plugin directory (the default is `~/Downloads`).

## Architecture

```text
services/
  PlaybackService.qml       # Long-lived playback singleton & download service host
  DownloadService.qml       # Transfer queue, event parser, and JSON history persistence
  MediaModel.js             # Metadata normalization, formatting, filtering, sorting
  DownloadModel.js          # Job normalization, status badges, byte/speed formatters
providers/
  YoutubeProvider.js        # Format normalization & yt-dlp arguments
views/
  DiscoverView.qml          # Search toolbar, filter chips, list & detail preview
  PlayerView.qml            # Video output, transport controls, quality menu, scrub bar
  DownloadsView.qml         # Queue & history lists, filter tabs, folder actions
components/
  QualityMenu.qml           # Stream quality selection menu
  DownloadRow.qml           # Transfer progress bar, speed, ETA, and actions

scripts/
  omastream-search          # Fast two-stage relative time search adapter
  omastream-upload-time     # NDJSON streaming exact date hydration worker
  omastream-formats         # Machine-readable format extractor
  omastream-download        # NDJSON event-streaming download process with process-group cleanup
```
