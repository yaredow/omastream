.pragma library

function normalizeFormats(rawFormats) {
    if (!Array.isArray(rawFormats)) return { playback: [], downloadVideo: [], downloadAudio: [] };

    var playback = [
        {
            id: "auto",
            label: "Auto",
            detail: "Best available (HD when possible)",
            resolution: "Auto",
            height: 0,
            hasVideo: true,
            hasAudio: true,
            isDirectStreamable: true,
            playbackSelector: "best[ext=mp4][protocol^=http]/best"
        }
    ];

    var downloadResolutions = {};
    var adaptivePlayback = {};
    var audioMap = {};
    var audioFormats = [];

    for (var i = 0; i < rawFormats.length; i++) {
        var f = rawFormats[i];
        if (!f || !f.format_id) continue;

        var vcodec = f.vcodec || "none";
        var acodec = f.acodec || "none";
        var hasVideo = vcodec !== "none";
        var hasAudio = acodec !== "none";
        var height = Number(f.height) || 0;
        var ext = f.ext || "mp4";
        var proto = f.protocol || "";
        var fps = f.fps || 30;
        var filesize = f.filesize || f.filesize_approx || 0;
        var resLabel = (f.format_note && f.format_note.indexOf("p") !== -1) ? f.format_note : (height ? height + "p" : "Audio");

        // Collect best audio formats for muxing (typically m4a/opus)
        if (!hasVideo && hasAudio) {
            audioFormats.push(f);
            if (!audioMap[acodec] || (f.abr || 0) > audioMap[acodec].abr) {
                audioMap[acodec] = f;
            }
        }

        // Progressive playback (both video and audio natively interleaved)
        if (hasVideo && hasAudio && height > 0 && proto !== "m3u8_native" && proto.indexOf("m3u8") === -1) {
            playback.push({
                id: String(f.format_id),
                label: resLabel,
                detail: "Progressive",
                resolution: resLabel,
                height: height,
                fps: fps,
                ext: ext,
                hasVideo: true,
                hasAudio: true,
                isDirectStreamable: true,
                transport: "direct",
                filesize: filesize,
                playbackSelector: f.format_id
            });
        } else if (hasVideo && height > 0) {
            // HLS or DASH Video streams requiring proxy multiplexing for stability
            // MUST be H.264 (avc) because ffmpeg -c copy -f mpegts does not support VP9/AV1
            if (vcodec.indexOf("avc") !== -1 || vcodec.indexOf("h264") !== -1) {
                if (!adaptivePlayback[height] || (f.tbr || 0) > adaptivePlayback[height].tbr) {
                    adaptivePlayback[height] = {
                        id: String(f.format_id),
                        height: height,
                        label: resLabel,
                        detail: "High Quality (Relay)",
                        resolution: resLabel,
                        hasVideo: true,
                        hasAudio: true,
                        isDirectStreamable: false,
                        transport: "relay",
                        tbr: f.tbr || 0,
                        ext: ext,
                        playbackSelector: f.format_id + "+bestaudio[ext=m4a]/" + f.format_id + "+bestaudio/best"
                    };
                }
            }
            
            // For downloads, we don't care about codec because yt-dlp merges them into mkv/mp4.
            if (!downloadResolutions[height] || (f.tbr || 0) > downloadResolutions[height].tbr) {
                downloadResolutions[height] = {
                    id: String(f.format_id),
                    height: height,
                    label: resLabel,
                    resolution: resLabel,
                    ext: ext,
                    tbr: f.tbr || 0,
                    downloadSelector: f.format_id + "+bestaudio/best"
                };
            }
        }
    }

    // Merge adaptive relay formats into playback
    var adaptiveKeys = Object.keys(adaptivePlayback).map(Number).sort(function(a, b) { return b - a; });
    for (var j = 0; j < adaptiveKeys.length; j++) {
        playback.push(adaptivePlayback[adaptiveKeys[j]]);
    }
    
    // Sort playback formats descending by height
    playback.sort(function(a, b) {
        if (a.id === "auto") return -1;
        if (b.id === "auto") return 1;
        return (b.height || 0) - (a.height || 0);
    });

    var downloadVideo = [];
    var dlKeys = Object.keys(downloadResolutions).map(Number).sort(function(a, b) { return b - a; });
    for (var k = 0; k < dlKeys.length; k++) {
        downloadVideo.push(downloadResolutions[dlKeys[k]]);
    }

    var downloadAudio = [];
    audioFormats.sort(function(a, b) { return (b.abr || 0) - (a.abr || 0); });
    for (var m = 0; m < audioFormats.length; m++) {
        var af = audioFormats[m];
        downloadAudio.push({
            id: String(af.format_id),
            label: (af.abr ? Math.round(af.abr) + "kbps" : "Audio") + " (" + (af.ext || "m4a") + ")",
            resolution: af.abr ? Math.round(af.abr) + "kbps" : "Audio",
            ext: af.ext || "m4a",
            downloadSelector: af.format_id
        });
    }

    return {
        playback: playback,
        downloadVideo: downloadVideo,
        downloadAudio: downloadAudio
    };
}
