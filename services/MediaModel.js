.pragma library

function formatDuration(seconds) {
    if (!seconds || seconds <= 0) return "LIVE";
    var s = Math.round(Number(seconds));
    var hrs = Math.floor(s / 3600);
    var mins = Math.floor((s % 3600) / 60);
    var secs = s % 60;
    var secText = secs < 10 ? "0" + secs : "" + secs;
    if (hrs > 0) return hrs + ":" + (mins < 10 ? "0" + mins : mins) + ":" + secText;
    return mins + ":" + secText;
}

function formatViews(views) {
    if (views === undefined || views === null || views === 0) return "";
    var value = Number(views);
    if (isNaN(value)) return String(views);
    if (value >= 1000000) return (value / 1000000).toFixed(1) + "M views";
    if (value >= 1000) return Math.round(value / 1000) + "K views";
    return value + " views";
}

function parseSearchResults(data) {
    if (!Array.isArray(data)) return [];
    var results = [];
    for (var i = 0; i < data.length; i++) {
        var item = data[i];
        if (!item || !item.id || item._type === "playlist" || item._type === "channel") continue;
        results.push({
            id: String(item.id),
            videoId: String(item.id),
            sourceType: "youtube",
            mediaType: "video",
            title: item.title || "Untitled Video",
            author: item.uploader || item.channel || "YouTube Channel",
            authorId: item.channel_id || "",
            lengthSeconds: item.duration || 0,
            durationText: formatDuration(item.duration),
            viewCount: item.view_count || 0,
            viewCountText: formatViews(item.view_count),
            publishedText: "",
            artworkUrl: "https://i.ytimg.com/vi/" + item.id + "/mqdefault.jpg",
            thumbnailUrl: "https://i.ytimg.com/vi/" + item.id + "/mqdefault.jpg",
            liveNow: item.is_live === true,
            providerData: { provider: "youtube", videoId: String(item.id) }
        });
    }
    return results;
}
