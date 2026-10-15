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
# player samples: plain.mp4 (one video + audio track), tracks2.mkv (2 audio tracks + 2 subtitle tracks)
P="$BUILD/redesign-media"
ffmpeg -v error -y -f lavfi -i "testsrc2=size=1280x720:rate=25:duration=120" -f lavfi -i "sine=frequency=440:duration=120" \
       -c:v libx264 -preset ultrafast -c:a aac -shortest "$P/plain.mp4"
printf '1\n00:00:00,500 --> 00:01:00,000\nFirst subtitle line\n\n2\n00:01:00,500 --> 00:02:00,000\nSecond subtitle line\n' > "$P/sub-en.srt"
printf '1\n00:00:00,500 --> 00:02:00,000\nDeuxieme piste\n' > "$P/sub-fr.srt"
ffmpeg -v error -y -f lavfi -i "testsrc=size=1280x720:rate=25:duration=120" \
       -f lavfi -i "sine=frequency=330:duration=120" -f lavfi -i "sine=frequency=660:duration=120" \
       -i "$P/sub-en.srt" -i "$P/sub-fr.srt" \
       -map 0 -map 1 -map 2 -map 3 -map 4 -c:v libx264 -preset ultrafast -c:a aac -c:s srt \
       -metadata:s:a:0 language=eng -metadata:s:a:1 language=fra \
       -metadata:s:s:0 language=eng -metadata:s:s:1 language=fra -shortest "$P/tracks2.mkv"
# music player: a shaped envelope (silence, ramp, bursts) with an embedded cover, and a long file for cancel tests
ffmpeg -v error -y -f lavfi -i "testsrc2=size=600x600:duration=1" -frames:v 1 "$M/cover.png"
ffmpeg -v error -y \
       -f lavfi -i "aevalsrc='if(lt(t,3),0,if(lt(t,13),(t-3)/10*sin(2*PI*220*t),if(lt(mod(t-13,2),1),0.9*sin(2*PI*330*t),0.05*sin(2*PI*330*t))))':d=40:s=44100" \
       -i "$M/cover.png" -map 0:a -map 1:v -c:a libmp3lame -q:a 6 -c:v png -disposition:v attached_pic \
       -id3v2_version 3 -metadata title=waveform -metadata artist=Tester "$M/waveform.mp3"
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.5*sin(2*PI*220*t)*sin(2*PI*0.05*t)':d=1200:s=22050" \
       -c:a libmp3lame -q:a 9 -metadata title=long -metadata artist=Tester "$M/long.mp3"
rm -f "$M/cover.png"
echo samples ready
