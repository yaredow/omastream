# omaStream

An embedded YouTube search, playback, and download plugin for the Omarchy shell.

## Features

- **Discover**: Bounded search with rich metadata, filtering (Videos, Live, Duration brackets), and sorting (Relevance, Views, Newest).
- **Player**: Dedicated player surface with inline & fullscreen playback, audio-only mode, playback rate control, volume slider, and dynamic stream quality inspection.
- **Downloads Manager**: Observable transfer queue and persistent history surviving overlay close, real-time speed, ETA, percent progress, retry, cancellation, and folder reveal.
- **Custom Download Flow**: Select container (MP4, MKV, WebM, MP3, M4A), audio-only extraction, or specific video resolutions merged via FFmpeg.
- **Persistent Service**: Shared playback and download queue state between the overlay and bar widget.

## Dependencies

- Omarchy with the Quattro shell plugin runtime
- `yt-dlp`
- `ffmpeg`
- `jq`
- Python 3
- Qt 6 Multimedia with FFmpeg backend

## Controls & Keybindings

- `Space`: Play or pause
- `Left` / `Right`: Seek backward or forward 10 seconds
- `Up` / `Down`: Change volume
- `M`: Mute or unmute
- `F`: Enter or leave fullscreen video
- `/`: Focus search in Discover mode
- `Escape`: Leave fullscreen, clear search focus, or close the overlay

The bar widget uses middle click for play/pause, right click to stop, and the mouse wheel for volume.

## Architecture

```text
services/
  PlaybackService.qml       # Long-lived playback singleton & download service host
  DownloadService.qml       # Transfer queue, event parser, and JSON history persistence
  MediaModel.js             # Metadata normalization, formatting, filtering, sorting
  DownloadModel.js          # Job normalization, status badges, byte/speed formatters
  ProviderRegistry.js       # Provider capabilities abstraction
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
  omastream-search          # Bounded yt-dlp JSON search adapter
  omastream-formats         # Machine-readable format extractor
  omastream-download        # NDJSON event-streaming download process with process-group cleanup
```

## Validate

```sh
omarchy plugin validate ~/.config/omarchy/plugins/user.omastream
qmllint -I "$OMARCHY_PATH/shell" \
  PlaybackService.qml \
  OmaStreamOverlay.qml \
  BarWidget.qml \
  services/DownloadService.qml \
  views/DiscoverView.qml \
  views/PlayerView.qml \
  views/DownloadsView.qml \
  components/QualityMenu.qml \
  components/DownloadRow.qml \

```
