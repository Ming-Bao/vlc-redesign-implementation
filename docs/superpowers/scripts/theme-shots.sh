#!/bin/sh
# theme-shots.sh OUTDIR SCHEME-INDEX
# One PNG per screen in a fixed list, for theme regressions (slice 10).
# SCHEME-INDEX is MainWindow/color-scheme-index: 0 System, 1 Light (Day), 2 Dark (Night).
# Compare two runs with: for f in A/*.png; do compare -metric AE -fuzz 1% "$f" "B/${f##*/}" null:; echo; done
# (-fuzz 1%: two launches of the same build differ by 1-2 levels on 20-200 text pixels, run to run;
# without it every pair reports that noise.)
#
# Re-runnable unchanged, and two runs of the same build give the same pixels:
# - Every launch starts from one profile snapshot ($PROFILE/theme-shots-seed: the Qt conf, vlcrc
#   and the media library), taken the first time the script runs and restored before each launch
#   and at the end. Delete the seed to re-take it.
# - GTK (Qt's gtk3 platform theme) runs on :77, not the user's Wayland session, with the text
#   cursor's blink off, so a focused text field looks the same in every shot.
# - Each launch is a fresh harness start (silent: the harness passes --aout=dummy), with -vv;
#   its log is kept as OUTDIR/vlc-<launch>.log for the QML error grep.
# Coordinates are for the harness's 1600x900 window and the slice 9 UI. If a screen moves,
# fix its coordinates here, then re-take the Dark baseline with the old build.
set -u
[ $# -eq 2 ] || { echo "usage: $0 OUTDIR SCHEME-INDEX(0 System|1 Light|2 Dark)"; exit 2; }
OUT=$1; SCHEME=$2
. "$(dirname "$0")/redesign-env.sh"
DRV="$(dirname "$0")/vlc-xvfb.sh"
RUN="$PROFILE/run"; CONFDIR="$XDG_CONFIG_HOME/vlc"; CONF="$CONFDIR/vlc-qt-interface.conf"
ML="$XDG_DATA_HOME/vlc/ml"; SEED="$PROFILE/theme-shots-seed"
mkdir -p "$OUT" "$RUN" "$XDG_CONFIG_HOME/gtk-3.0"
printf '[Settings]\ngtk-cursor-blink=false\n' > "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"

if [ ! -d "$SEED" ]; then
    mkdir -p "$SEED" && cp "$CONF" "$CONFDIR/vlcrc" "$SEED/" && cp -a "$ML" "$SEED/ml" || exit 1
fi
restore() { cp "$SEED/vlc-qt-interface.conf" "$SEED/vlcrc" "$CONFDIR/" && rm -rf "$ML" && cp -a "$SEED/ml" "$ML"; }
setup() {
    restore
    sed -i '/^RecoveryFilePath=/d' "$CONF"   # else a modal "closed abruptly" dialog
    if grep -q '^color-scheme-index=' "$CONF"; then
        sed -i "s/^color-scheme-index=.*/color-scheme-index=$SCHEME/" "$CONF"
    else
        sed -i "/^\[MainWindow\]/a color-scheme-index=$SCHEME" "$CONF"
    fi
}
park() { xdotool mousemove 1599 899 || fail "xdotool cannot reach :77"; }   # off every control, so nothing is hovered
launch() {   # launch NAME [vlc args]
    NAME=$1; LAST=start; shift
    setup; RUNNING=1
    env -u WAYLAND_DISPLAY GDK_BACKEND=x11 "$DRV" start -vv "$@" > /dev/null || { echo "$NAME: VLC did not start"; exit 1; }
    park; sleep 2
}
finish() { "$DRV" stop > /dev/null; RUNNING=; sleep 1; cp "$RUN/vlc.log" "$OUT/vlc-$NAME.log"; }
LAST=start
fail() { echo "theme-shots: $NAME launch, after shot $LAST: $*"; exit 1; }
alive() { kill -0 "$(cat "$RUN/vlc.pid")" 2> /dev/null || fail "VLC is no longer running (see $RUN/vlc.log)"; }
c() {   # c X Y [wait]
    alive
    "$DRV" click "$1" "$2" > /dev/null || fail "click $1,$2 failed"
    park; sleep "${3:-2}"
}
shot() { sleep 1; alive; "$DRV" shot "$OUT/$1.png" || fail "shot $1 failed"; LAST=$1; }
RUNNING=
trap '[ -n "$RUNNING" ] && "$DRV" stop > /dev/null 2>&1 && sleep 1; restore' EXIT

# --- library and dialogs (nothing playing) ---
launch library
shot 01-home
c 66 129;   c 362 487 3;   shot 02-videos-grid      # sidebar Videos; the redesign-media folder card
c 1159 77;  c 987 169 3;   shot 03-videos-list      # view button; List View
c 1159 77;  c 990 121                                # view button; Grid View (it is a global setting)
c 64 175 3;                shot 04-music            # sidebar Music
c 72 221 5;                shot 05-network          # sidebar Network (LAN discovery settles)
c 70 267 3;                shot 06-playlists        # sidebar Playlists
c 304 236 3;               shot 07-new-playlist     # "Create playlist" card
c 514 708                                            # Cancel
c 67 313 3;                shot 08-recent           # sidebar Recent
c 54 20;    c 118 542 3;   shot 09-settings-general # "..." menu; Settings
c 362 717;                 shot 10-settings-network # Settings sidebar Network
c 1294 93                                            # Settings close
c 54 20;    c 165 157 3;   shot 11-open-network     # "..." menu; Open Network Stream
c 346 729                                            # Cancel
c 54 20;    c 156 446 4;   shot 12-shortcuts        # "..." menu; Keyboard Shortcuts (scroll bar fades)
c 346 794                                            # Cancel
c 54 20;    c 148 494 4;   shot 13-customize        # "..." menu; Customize Player
c 346 706                                            # Cancel
c 54 20;                   shot 14-menu             # "..." menu, left open
finish

# --- player: plain.mp4 paused on its first frame ---
launch player --start-paused "$BUILD/redesign-media/plain.mp4"
c 90 20 3;                 shot 15-player-panel     # title bar panel button: the library side panel
c 1504 873;                shot 16-player-tracks    # control bar Tracks
c 1504 873                                           # Tracks again: closes it
c 1536 873;                shot 17-player-playback  # control bar Playback (gear), Playback tab
c 1340 84;                 shot 18-player-settings  # its Video tab (the settings pages)
c 1536 873                                           # gear again: closes it
c 1568 873;                shot 19-player-queue     # control bar Queue
c 1568 873                                           # Queue again: closes it
c 382 71 3;                shot 20-miniplayer       # side panel's open-in-library button: library + mini player
finish

# --- onboarding (the card is always dark; slice 10 makes its preview follow the tile) ---
launch onboarding --qt-privacy-ask
c 1233 757 3;              shot 21-onboarding-theme # Welcome: Next
finish
