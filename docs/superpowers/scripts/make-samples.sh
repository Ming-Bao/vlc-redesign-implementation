#!/bin/sh
# Generate small sample media for the media library and the player.
. "$(dirname "$0")/redesign-env.sh"
V="$BUILD/redesign-media/Shows/The Clip/S01"; M="$BUILD/redesign-music"; mkdir -p "$V" "$M"
for i in 1 2 3 4 5 6; do
  ffmpeg -v error -y -f lavfi -i "testsrc=size=640x360:rate=25:duration=20" \
         -f lavfi -i "sine=frequency=$((300+i*50)):duration=20" -vf "hue=h=${i}0" \
         -c:v libx264 -preset ultrafast -c:a aac -shortest "$V/The_Clip_S01E0$i.mp4"
done
for n in untangle moonlight "black bird"; do
  ffmpeg -v error -y -f lavfi -i "sine=frequency=330:duration=15" -metadata artist=Tester \
         -metadata title="$n" "$M/$n.mp3"
done
printf ';FFMETADATA1\n[CHAPTER]\nTIMEBASE=1/1\nSTART=0\nEND=30\ntitle=One\n[CHAPTER]\nTIMEBASE=1/1\nSTART=30\nEND=60\ntitle=Two\n' > "$BUILD/redesign-media/ch.txt"
ffmpeg -v error -y -f lavfi -i "testsrc2=size=640x360:rate=25:duration=60" -i "$BUILD/redesign-media/ch.txt" \
       -map_metadata 1 -c:v libx264 -preset ultrafast "$BUILD/redesign-media/chapters.mkv"
echo samples ready
