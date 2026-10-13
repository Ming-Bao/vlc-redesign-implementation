#!/bin/sh
# usage: count-px.sh IMG X Y W H HEX [FUZZ%] — print how many pixels in the box match HEX within FUZZ (default 12%)
img=$1 x=$2 y=$3 w=$4 h=$5 hex=$6 fuzz=${7:-12}
magick "$img" -crop "${w}x${h}+${x}+${y}" +repage -fuzz "${fuzz}%" -fill white -opaque "$hex" \
    -fuzz 0 -fill black +opaque white -format "%[fx:round(mean*w*h)]" info:
