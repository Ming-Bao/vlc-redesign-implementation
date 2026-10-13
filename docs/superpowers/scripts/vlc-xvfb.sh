#!/bin/sh
# Drive the dev build of VLC on a private Xvfb display (:77) for screenshots.
. "$(dirname "$0")/redesign-env.sh"
RUN="$PROFILE/run"; mkdir -p "$RUN"
case "$1" in
start)
    shift
    Xvfb :77 -screen 0 1600x900x24 -nolisten tcp > "$RUN/xvfb.log" 2>&1 & echo $! > "$RUN/xvfb.pid"
    sleep 1
    # park the pointer off the (initially small, centred) window so nothing starts hovered
    xdotool mousemove 1599 899
    "$BUILD/bin/vlc-static" -I qt --no-qt-privacy-ask --restore-playback-pos=0 "$@" > "$RUN/vlc.log" 2>&1 & echo $! > "$RUN/vlc.pid"
    for i in $(seq 60); do
        if xdotool search --name "VLC media player" >/dev/null 2>&1; then
            sleep 3
            # no window manager: resize the top-level main window(s); popups/tooltips (< 400px) keep their size
            for w in $(xdotool search --maxdepth 1 --class vlc); do
                eval "$(xdotool getwindowgeometry --shell "$w")"
                [ "$WIDTH" -ge 400 ] && xdotool windowmove "$w" 0 0 windowsize "$w" 1600 900
            done
            sleep 4; echo ready; exit 0
        fi
        sleep 0.5
    done
    echo "VLC window never appeared; see $RUN/vlc.log"; exit 1 ;;
seed)
    # One-time: run the first-run wizard so the media library indexes build/redesign-{media,music}
    rm -rf "$PROFILE"; . "$(dirname "$0")/redesign-env.sh"; mkdir -p "$RUN"
    Xvfb :77 -screen 0 1600x900x24 -nolisten tcp > "$RUN/xvfb.log" 2>&1 & echo $! > "$RUN/xvfb.pid"
    sleep 1
    "$BUILD/bin/vlc-static" -I qt > "$RUN/vlc.log" 2>&1 & echo $! > "$RUN/vlc.pid"
    sleep 8
    xdotool key Return; sleep 2                      # privacy page -> folders page
    xdotool mousemove 1136 636 click 1; sleep 2      # Next -> colour scheme
    xdotool mousemove 1050 400 click 1; sleep 1      # Night
    xdotool mousemove 1136 636 click 1; sleep 2      # Next -> layout
    xdotool mousemove 1136 636 click 1; sleep 15     # Finish, let the library index
    "$0" stop; echo seeded ;;
shot)  import -window root "$2" && echo "saved $2" ;;
click) xdotool mousemove "$2" "$3" sleep 0.2 click 1 ;;
key)   shift; xdotool key "$@" ;;
stop)
    kill "$(cat "$RUN/vlc.pid")" 2>/dev/null; sleep 1; kill -9 "$(cat "$RUN/vlc.pid")" 2>/dev/null
    kill "$(cat "$RUN/xvfb.pid")" 2>/dev/null; true ;;
*) echo "usage: $0 seed|start [args]|shot OUT|click X Y|key KEYS|stop"; exit 2 ;;
esac
