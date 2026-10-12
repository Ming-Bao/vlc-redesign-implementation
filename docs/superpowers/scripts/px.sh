#!/bin/sh
# usage: px.sh IMG X Y HEX [TOL] — assert the pixel colour at (X,Y) is HEX (#RRGGBB) within TOL per channel.
img=$1 x=$2 y=$3 want=$(echo "$4" | tr -d '#' | tr a-f A-F) tol=${5:-6}
got=$(magick "$img" -format "%[hex:p{$x,$y}]" info: | cut -c1-6)
d() { a=$(printf %d 0x$(echo "$1" | cut -c$3-$(($3+1)))); b=$(printf %d 0x$(echo "$2" | cut -c$3-$(($3+1)))); echo $(( a>b ? a-b : b-a )); }
for c in 1 3 5; do [ "$(d "$got" "$want" $c)" -le "$tol" ] || { echo "FAIL ($x,$y): got #$got want #$want"; exit 1; }; done
echo "ok ($x,$y) #$got"
