# VLC Redesign — Slice 12: Seekbar hover preview

Figma = spec (file `dSoAm0gN9ZterHSssJU9FN`). The only real gap left by the 2026-11-08 frame audit.

## Intent
While a video plays, the user rests the pointer on the player's seekbar to **find a spot before clicking**. A card above
the pointer shows the video frame at that point and its time, so they can see where a click would land.
(User, 2026-11-08: the moment is hovering, not dragging the handle.)

## Figma
- Card `thumbnail` 2151:9673: 272×189 frame, radius 14, fill `#191919` at 95 % with a 50 px background blur;
  inner frame 252×142 at (10,10), radius 4 (the picture); text "00:02:10" Inter Regular 15, `#8F8F8F`, centred
  horizontally, top at y 162.
- Settings ▸ Playback row "Show thumbnail while scrubbing" (Figma 3072:13278), drawn with its toggle **on**.
  Slice 7 skipped it ("No VLC option"); this slice backs it.
- No frame shows the card placed over a seekbar; placement below is *my call*.

## Behaviour
- **Shows** while the pointer is over the player's seekbar (the `SliderBar` in `player/qml/ControlBar.qml`, every
  layout: inline, own row, fullscreen) and the playing media has video and is seekable, and the setting is on.
- **Replaces** the existing hover tooltip (`PointingToolTipAttached` time / chapter text) while it shows. When the
  card can't show (audio only, not seekable, setting off), the old tooltip stays as it is today.
- **Placement** *(my call)*: the card's bottom edge sits a small gap above the bar's top, centred on the pointer's x,
  clamped inside the window. It follows the pointer.
- **Time text**: the hovered time, formatted as the tooltip formats it today (`formatHMS`). With chapters, the
  chapter name follows the time as in today's tooltip (" - name"), elided to the card width *(my call; the Figma
  card has no chapter case)*.
- **The frame**: grabbed from a separate, hidden decode of the same media at the hovered time. Playback is not
  touched. Seek speed follows Settings ▸ "Seek precisely" (`input-fast-seek`): the card shows the frame a click there
  would land on *(my call)*. Measured 2026-11-08 with `build/bin/vlc-preparser-static` (one new input per request,
  start-up included): 640×360 test files ~25 ms; 1080p H.264 `redesign source.mp4` ~70 ms fast, ~96 ms precise.
  So the core thumbnailer, one request in flight, is fast enough; no persistent hidden player.
- **Which item**: a fresh `input_item_t` from the playing item's URI, no options copied (the playing item's
  `:start-time`, slaves, demux overrides would only get in the way) *(my call)*.
- **While a frame is being fetched**: the card keeps showing the last frame it got (or the empty `#191919`-ish
  placeholder fill before the first); the time text updates at once. Never more than one request in flight: when it
  ends, if the pointer has moved, request the newest position only (drop the in-between ones).
- **Picture fit**: the video frame is fitted into 252×142 (preserve aspect, centred, letterboxed on the card's fill).
- **Hides** when the pointer leaves the bar, when a drag on the handle starts (the drag keeps today's behaviour), and
  when the media changes. Pending requests are cancelled on hide/media change.
- **Not shown**: audio files and the music player's waveform bar; the mini player's bar; Customize Player editing
  mode (the seekbar is a drag item there); keyboard focus on the bar (the tooltip keeps working for that).

## Setting
- New Qt module option `qt-seek-thumbnail` (bool, default **true**, matching Figma's drawn "on") in `qt.cpp`.
- Settings ▸ Playback row "Show thumbnail while scrubbing", toggle, after "Seek precisely". Applies live (the
  bar reads it on each hover), so no "Next video"/"After restart" chip.

## Constraints
- Use the core's thumbnailer: `vlc_preparser_req_NewThumbnail()` with `VLC_THUMBNAILER_SEEK_TIME` (or POS) and fast
  seek, on a preparser created with `VLC_PREPARSER_TYPE_THUMBNAIL`. No core changes.
- The thumbnail callback runs on a core thread: hand the picture to the Qt thread, convert to a `QImage`
  (scaled to ≤ 2× 252×142 for HiDPI), expose to QML through an image provider or a painted item.
- Follow the theme tokens (slice 10): card fill/text from the token table, so Light gets the token swap.
- Must stay silent (the hidden decode opens no audio output; the preparser's thumbnailer already doesn't).
- Which media get a card *(my call)*: the player reports it seekable and it has video, and the URI scheme is not a
  disc (`dvd`, `dvdsimple`, `bluray`, `vcd`, `cdda`; reopening the drive per hover is slow and loses title state).
  Network files (smb, nfs, sftp, ftp, http with a length) are allowed; a request that takes longer than ~2 s times
  out and the card keeps its last frame. Live streams aren't seekable → no card.

## Goals / non-goals
- Goal: the Figma card on hover, responsive enough that sweeping across the bar feels live on a local file.
- Non-goals: pre-generated thumbnail strips/sprites, disk cache, previews in the mini player or library cards,
  preview while dragging the handle, keyboard-driven preview.
- Anti-goals: anything that stalls or stutters playback, audible output from the preview decode, a card that flickers
  to empty between frames.

## Left to the builder
- Where the C++ lives (a small `SeekPreview` object owned by the player controller or MainCtx, or a QML-registered type).
- Image hand-off mechanism (QQuickImageProvider vs. QQuickPaintedItem vs. texture).
- Exact gap above the bar and the pointer-follow smoothing (none needed).
- Whether to reuse an existing preparser instance or make a dedicated one (a dedicated one keeps library preparsing
  from queueing behind previews).

## Verify
- Xvfb harness: hover across the bar on `build/redesign-media/plain.mp4`, shots at several x positions; Light and
  Dark. The burnt-in timecode in the frame must be within 0.5 s of the card's time with "Seek precisely" on (the
  default); with it off, within the file's keyframe interval.
- Card fill and text map to existing tokens (BG/A3, FG/A2); the 50 px backdrop blur is not drawn (slice 10 precedent).
- Audio file: old tooltip only. Setting off: old tooltip only, live.
- `-vv` log clean of QML errors; no crash on quitting while a request is in flight.
