.pragma library

function formatDuration(seconds) {
    if (seconds === undefined || seconds === null || seconds < 0) return "LIVE";
    var s = Math.round(Number(seconds));
    if (s === 0) return "LIVE";
    var hrs = Math.floor(s / 3600);
    var mins = Math.floor((s % 3600) / 60);
    var secs = s % 60;
    var secText = secs < 10 ? "0" + secs : "" + secs;
    if (hrs > 0) return hrs + ":" + (mins < 10 ? "0" + mins : mins) + ":" + secText;
    return mins + ":" + secText;
}

function formatViews(views) {
    if (views === undefined || views === null || views === "" || views === 0) return "";
    var value = Number(views);
    if (isNaN(value)) return String(views);
    if (value >= 1000000000) return (value / 1000000000).toFixed(1) + "B views";
    if (value >= 1000000) return (value / 1000000).toFixed(1) + "M views";
    if (value >= 1000) return Math.round(value / 1000) + "K views";
    return value + " views";
}

function formatUploadDate(dateStr, timestamp, fallbackText) {
    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    
    // 1. Exact Unix timestamp
    if (timestamp && typeof timestamp === "number" && timestamp > 0) {
        var d = new Date(timestamp * 1000);
        if (!isNaN(d.getTime())) {
            return months[d.getUTCMonth()] + " " + d.getUTCDate() + ", " + d.getUTCFullYear();
        }
    }

    // 2. Exact YYYYMMDD date string
    if (dateStr && typeof dateStr === "string" && dateStr.length === 8 && /^\d{8}$/.test(dateStr)) {
        var year = dateStr.substring(0, 4);
        var month = parseInt(dateStr.substring(4, 6), 10) - 1;
        var day = parseInt(dateStr.substring(6, 8), 10);
        if (month >= 0 && month < 12) {
            return months[month] + " " + day + ", " + year;
        }
    }

    // 3. Fallback relative text (e.g. "3 days ago")
    if (fallbackText && typeof fallbackText === "string" && fallbackText.trim()) {
        return fallbackText.trim();
    }

    return "";
}

function parseSearchResults(data) {
    if (!Array.isArray(data)) return [];
    var results = [];
    for (var i = 0; i < data.length; i++) {
        var item = data[i];
        if (!item || !item.id || item._type === "playlist" || item._type === "channel") continue;

        var isLive = item.is_live === true || item.live_status === "is_live";
        var durationSecs = Number(item.duration) || 0;
        
        var rawUploadDate = (item.upload_date && typeof item.upload_date === "string" && /^\d{8}$/.test(item.upload_date)) ? item.upload_date : "";
        var exactTimestamp = (typeof item.timestamp === "number" && item.timestamp > 0)
            ? item.timestamp
            : ((typeof item.release_timestamp === "number" && item.release_timestamp > 0) ? item.release_timestamp : 0);

        var rawPublishedText = item.published_time_text || item.publishedTimeText || "";
        if (typeof rawPublishedText === "object" && rawPublishedText !== null) {
            rawPublishedText = rawPublishedText.simpleText || "";
        }

        var approxSeconds = Number(item.published_time_seconds) || 0;
        var precision = item.published_time_precision || (exactTimestamp > 0 ? "exact" : (rawPublishedText ? "relative" : "unknown"));

        var uploadTimeState = "unavailable";
        if (exactTimestamp > 0 || rawUploadDate) {
            uploadTimeState = "exact";
        } else if (rawPublishedText) {
            uploadTimeState = "relative";
        }

        var publishedText = formatUploadDate(rawUploadDate, exactTimestamp, rawPublishedText);

        var thumb = "";
        if (item.thumbnails && Array.isArray(item.thumbnails) && item.thumbnails.length > 0) {
            thumb = item.thumbnails[item.thumbnails.length - 1].url || "";
        }
        if (!thumb) {
            thumb = "https://i.ytimg.com/vi/" + item.id + "/mqdefault.jpg";
        }

        results.push({
            id: String(item.id),
            videoId: String(item.id),
            originalUrl: item.webpage_url || item.url || ("https://www.youtube.com/watch?v=" + item.id),
            sourceType: "youtube",
            mediaType: isLive ? "live" : "video",
            title: item.title || "Untitled Video",
            author: item.uploader || item.channel || "YouTube Channel",
            authorId: item.uploader_id || item.channel_id || "",
            durationSeconds: durationSecs,
            lengthSeconds: durationSecs,
            durationText: isLive ? "LIVE" : formatDuration(durationSecs),
            viewCount: item.view_count || 0,
            viewCountText: formatViews(item.view_count),
            uploadDate: rawUploadDate,
            uploadTimestamp: exactTimestamp,
            approxUploadTimestamp: approxSeconds,
            uploadTimeState: uploadTimeState,
            uploadTimePrecision: precision,
            publishedText: publishedText,
            publishedTextRaw: rawPublishedText,
            description: item.description || "No description available.",
            artworkUrl: thumb,
            thumbnailUrl: thumb,
            liveNow: isLive,
            availability: item.availability || "public",
            providerData: { provider: "youtube", videoId: String(item.id) }
        });
    }
    return results;
}

function mergeHydrationUpdate(item, update) {
    if (!item || !update || item.id !== update.id) return item;
    if (update.state === "exact") {
        var exactDate = update.upload_date || item.uploadDate || "";
        var exactTs = update.timestamp || update.release_timestamp || item.uploadTimestamp || 0;
        item.uploadDate = exactDate;
        item.uploadTimestamp = exactTs;
        item.uploadTimeState = "exact";
        item.uploadTimePrecision = "exact";
        item.publishedText = formatUploadDate(exactDate, exactTs, item.publishedTextRaw);
    }
    return item;
}

function filterResults(items, filterType) {
    if (!items || !Array.isArray(items)) return [];
    if (!filterType || filterType === "all") return items;

    return items.filter(function(item) {
        if (filterType === "live") {
            return item.liveNow === true;
        } else if (filterType === "videos") {
            return !item.liveNow;
        } else if (filterType === "short") {
            return !item.liveNow && item.durationSeconds > 0 && item.durationSeconds <= 240;
        } else if (filterType === "medium") {
            return !item.liveNow && item.durationSeconds > 240 && item.durationSeconds <= 1200;
        } else if (filterType === "long") {
            return !item.liveNow && item.durationSeconds > 1200;
        }
        return true;
    });
}

function getBestTimestamp(item) {
    if (!item) return 0;
    if (item.uploadTimestamp && item.uploadTimestamp > 0) return item.uploadTimestamp;
    if (item.approxUploadTimestamp && item.approxUploadTimestamp > 0) return item.approxUploadTimestamp;
    if (item.uploadDate && item.uploadDate.length === 8) {
        var y = parseInt(item.uploadDate.substring(0, 4), 10);
        var m = parseInt(item.uploadDate.substring(4, 6), 10) - 1;
        var d = parseInt(item.uploadDate.substring(6, 8), 10);
        var dt = new Date(Date.UTC(y, m, d));
        return Math.floor(dt.getTime() / 1000);
    }
    return 0;
}

function sortResults(items, sortKey) {
    if (!items || !Array.isArray(items)) return [];
    var sorted = items.slice(0);

    if (sortKey === "newest") {
        sorted.sort(function(a, b) {
            var tsA = getBestTimestamp(a);
            var tsB = getBestTimestamp(b);
            if (tsA === 0 && tsB === 0) return 0;
            if (tsA === 0) return 1;
            if (tsB === 0) return -1;
            return tsB - tsA;
        });
    } else if (sortKey === "oldest") {
        sorted.sort(function(a, b) {
            var tsA = getBestTimestamp(a);
            var tsB = getBestTimestamp(b);
            if (tsA === 0 && tsB === 0) return 0;
            if (tsA === 0) return 1;
            if (tsB === 0) return -1;
            return tsA - tsB;
        });
    } else if (sortKey === "views") {
        sorted.sort(function(a, b) {
            return (b.viewCount || 0) - (a.viewCount || 0);
        });
    } else if (sortKey === "shortest") {
        sorted.sort(function(a, b) {
            return (a.durationSeconds || 0) - (b.durationSeconds || 0);
        });
    } else if (sortKey === "longest") {
        sorted.sort(function(a, b) {
            return (b.durationSeconds || 0) - (a.durationSeconds || 0);
        });
    }
    return sorted;
}
