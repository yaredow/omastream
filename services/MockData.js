.pragma library

// Mock data module providing sample video search results for UI development and layout testing.

var defaultInstances = [
    "https://inv.tux.pizza",
    "https://invidious.nerdvpn.de",
    "https://invidious.privacydev.net"
];

var mockSearchResults = [
    {
        videoId: "dQw4w9WgXcQ",
        title: "Building a Custom Linux Shell in QML & C++",
        author: "Omarchy Dev",
        lengthSeconds: 845,
        durationText: "14:05",
        viewCountText: "128K views",
        publishedText: "3 days ago",
        thumbnailUrl: "https://picsum.photos/seed/linuxshell/320/180"
    },
    {
        videoId: "3tmd-ClpJxA",
        title: "Neovim vs Emacs 2026: Ultimate Comparison and Workflow Guide for Linux Power Users",
        author: "TechTavern",
        lengthSeconds: 1520,
        durationText: "25:20",
        viewCountText: "45K views",
        publishedText: "1 week ago",
        thumbnailUrl: "https://picsum.photos/seed/neovim/320/180"
    },
    {
        videoId: "L_LUpnjgPso",
        title: "Hyprland Smooth Animations & Dynamic Tiling Configuration Masterclass",
        author: "Dotfiles Club",
        lengthSeconds: 412,
        durationText: "06:52",
        viewCountText: "98K views",
        publishedText: "2 weeks ago",
        thumbnailUrl: "https://picsum.photos/seed/hyprland/320/180"
    },
    {
        videoId: "jNQXAC9IVRw",
        title: "Understanding Wayland Compositors: Hyprland, Sway, and Quickshell Deep Dive",
        author: "ArchAcademy",
        lengthSeconds: 1105,
        durationText: "18:25",
        viewCountText: "31K views",
        publishedText: "1 month ago",
        thumbnailUrl: "https://picsum.photos/seed/wayland/320/180"
    },
    {
        videoId: "9bZkp7q19f0",
        title: "Distraction-Free Productivity Tools for Modern Linux Workstations",
        author: "Minimalist Code",
        lengthSeconds: 630,
        durationText: "10:30",
        viewCountText: "210K views",
        publishedText: "2 months ago",
        thumbnailUrl: "https://picsum.photos/seed/zen/320/180"
    }
];

function getSampleResults(query) {
    if (!query || query.trim() === "") {
        return mockSearchResults;
    }
    var q = query.toLowerCase();
    var filtered = mockSearchResults.filter(function(item) {
        return item.title.toLowerCase().indexOf(q) !== -1 || item.author.toLowerCase().indexOf(q) !== -1;
    });
    return filtered.length > 0 ? filtered : mockSearchResults;
}
