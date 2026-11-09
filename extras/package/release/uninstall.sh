#!/bin/sh
# Completely uninstall VLC Redesign: the app, its settings, media library and caches.
# Linux:  sh uninstall.sh [path/to/vlc-redesign.AppImage] [-y]
# macOS:  double-click "Uninstall VLC Redesign.command" (this script)
set -u

YES=
APP=
for a in "$@"; do
    case $a in
        -y|--yes) YES=1 ;;
        *) APP=$a ;;
    esac
done

H=$HOME
if [ "$(uname)" = Darwin ]; then
    ID=io.github.ming-bao.vlc-redesign
    set -- "/Applications/VLC Redesign.app" "$H/Applications/VLC Redesign.app" \
        "$H/Library/Preferences/$ID" "$H/Library/Application Support/$ID" \
        "$H/Library/Caches/$ID" "$H/Library/Preferences/$ID.plist" \
        "$H/Library/Saved Application State/$ID.savedState" \
        "$H/Library/Preferences/com.vlc.vlc-qt-interface.plist"
else
    C=${XDG_CONFIG_HOME:-$H/.config}
    D=${XDG_DATA_HOME:-$H/.local/share}
    K=${XDG_CACHE_HOME:-$H/.cache}
    set -- "$C/vlc" "$D/vlc" "$K/vlc"
    # Desktop entries and icons left by AppImage integration tools.
    for f in "$D"/applications/*vlc-redesign*.desktop "$D"/icons/hicolor/*/apps/*vlc-redesign*; do
        [ -e "$f" ] && set -- "$@" "$f"
    done
    [ -n "$APP" ] && set -- "$APP" "$@"
fi

echo "This removes VLC Redesign and ALL its settings, media library and caches:"
found=
for p in "$@"; do
    [ -e "$p" ] && { echo "  $p"; found=1; }
done
if [ -z "$found" ]; then
    echo "  (nothing found, already uninstalled)"
    exit 0
fi
[ "$(uname)" = Darwin ] || echo "Note: regular VLC on this computer shares these settings folders."

if [ -z "$YES" ]; then
    printf 'Continue? [y/N] '
    read -r ans
    case $ans in y|Y|yes|YES) ;; *) echo "Cancelled."; exit 1 ;; esac
fi

for p in "$@"; do
    [ -e "$p" ] && rm -rf -- "$p"
done
echo "VLC Redesign is uninstalled."
