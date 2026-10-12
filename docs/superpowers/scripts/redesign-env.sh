#!/bin/sh
# Shared paths for the redesign verification scripts. Source, don't execute.
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
BUILD="$REPO/build"
PROFILE="$BUILD/redesign-profile"
export XDG_CONFIG_HOME="$PROFILE/config" XDG_DATA_HOME="$PROFILE/data" XDG_CACHE_HOME="$PROFILE/cache"
export VLC_LIB_PATH="$BUILD/modules" VLC_PLUGIN_PATH="$BUILD/modules"
export QT_QPA_PLATFORM=xcb DISPLAY=:77
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
printf 'XDG_VIDEOS_DIR="%s"\nXDG_MUSIC_DIR="%s"\n' "$BUILD/redesign-media" "$BUILD/redesign-music" \
    > "$XDG_CONFIG_HOME/user-dirs.dirs"
# Force the dark scheme (Xvfb has no desktop to report one): MainWindow/color-scheme-index 2 = Night
mkdir -p "$XDG_CONFIG_HOME/vlc"
[ -f "$XDG_CONFIG_HOME/vlc/vlc-qt-interface.conf" ] ||
    printf '[MainWindow]\ncolor-scheme-index=2\n' > "$XDG_CONFIG_HOME/vlc/vlc-qt-interface.conf"
