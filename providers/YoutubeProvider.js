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
            isDirectStreamable: true
        }
    ];

    var downloadResolutions = {};
    var adaptivePlayback = {};
    var audioMap = {};

    for (var i = 0; i < rawFormats.length; i++) {
        var f = rawFormats[i];
        if (!f || !f.format_id) continue;

        var vcodec = f.vcodec || "none";
        var acodec = f.acodec || "none";
        var hasVideo = vcodec !== "none";
        var hasAudio = acodec !== "none";
        var height = Number(f.height) || 0;
        var width = Number(f.width) || 0;
        var ext = f.ext || "mp4";
        var proto = f.protocol || "";
        var fps = f.fps || 30;
        var filesize = f.filesize || f.filesize_approx || 0;

        // Progressive playback (both video and audio natively interleaved)
        // This is safe for simple Qt MediaPlayer without a local relay.
        if (hasVideo && hasAudio && height > 0 && proto !== "m3u8_native" && proto.indexOf("m3u8") === -1) {
            var resLabel = (f.format_note && f.format_note.indexOf("p") !== -1) ? f.format_note : height + "p";
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
                filesize: filesize
            });
        } else if (hasVideo && height > 0) {
            // HLS or DASH Video streams requiring proxy multiplexing for stability
            // MUST be H.264 (avc) because ffmpeg -c copy -f mpegts does not support VP9/AV1
            if (vcodec.indexOf("avc") !== -1 || vcodec.indexOf("h264") !== -1) {
                var resLabel = (f.format_note && f.format_note.indexOf("p") !== -1) ? f.format_note : height + "p";
                // Only overwrite if we don't have one, or if this one has higher framerate
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
