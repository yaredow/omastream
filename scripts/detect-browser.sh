#!/usr/bin/env bash
# Helper to detect default browser on Linux for yt-dlp cookie extraction
BROWSER=""

if command -v xdg-settings >/dev/null 2>&1; then
    DESKTOP_FILE=$(xdg-settings get default-web-browser 2>/dev/null || true)
    case "$DESKTOP_FILE" in
        *chromium*) BROWSER="chromium" ;;
        *chrome*) BROWSER="chrome" ;;
        *brave*) BROWSER="brave" ;;
        *firefox*|*zen*) BROWSER="firefox" ;;
        *vivaldi*) BROWSER="vivaldi" ;;
        *opera*) BROWSER="opera" ;;
        *edge*) BROWSER="edge" ;;
    esac
fi

if [ -z "$BROWSER" ] && command -v xdg-mime >/dev/null 2>&1; then
    DESKTOP_FILE=$(xdg-mime query default x-scheme-handler/http 2>/dev/null || true)
    case "$DESKTOP_FILE" in
        *chromium*) BROWSER="chromium" ;;
        *chrome*) BROWSER="chrome" ;;
        *brave*) BROWSER="brave" ;;
        *firefox*|*zen*) BROWSER="firefox" ;;
        *vivaldi*) BROWSER="vivaldi" ;;
        *opera*) BROWSER="opera" ;;
        *edge*) BROWSER="edge" ;;
    esac
fi

if [ -z "$BROWSER" ]; then
    if [ -d "$HOME/.mozilla/firefox" ]; then
        BROWSER="firefox"
    elif [ -d "$HOME/.config/google-chrome" ]; then
        BROWSER="chrome"
    elif [ -d "$HOME/.config/chromium" ]; then
        BROWSER="chromium"
    elif [ -d "$HOME/.config/BraveSoftware" ]; then
        BROWSER="brave"
    fi
fi

if [ -n "$BROWSER" ]; then
    printf "%s\n" "$BROWSER"
    exit 0
else
    exit 1
fi
