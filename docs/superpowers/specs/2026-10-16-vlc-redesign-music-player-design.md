# VLC Redesign: Music Player (slice 3d) Design

**Source of truth:** Figma "VLC Redesign (Community)", file key `dSoAm0gN9ZterHSssJU9FN`.
- This account can read that key. Galen's duplicate, `d9xvroRclV6SaObbcqRmBr`, is not readable here. Node IDs are the same in both.
- Frames:
  - `Player - Music` `4767:23726`.
  - `Controls` variant `music` `4778:26181`.
  - Waveform geometry: variant `waveform` `2139:8124`.
- Memory `figma-is-the-spec` applies: VLC 4's own audio view is not a reference.

## Decisions taken with the user (2026-10-16)

| Question | Ruling |
|---|---|
| Where does the waveform seek bar appear? | **Music only.** The Audioplayer control bar uses it. Videos keep the plain seek bar, and the `waveform` variant `2139:8124` is used only for its geometry. |
| VLC 4 audio-view extras that Figma doesn't show | **Pure Figma.** Remove the album/artist labels, the lyrics line, the two-panel lyrics view and the inline ±10 / visualisation / lyrics row. Visualisations stay reachable only through VLC's existing menus. |
| Where the bar heights come from | **Background decode.** A hidden player decodes the audio faster than real time when a track starts. Nothing is cached to disk. |

## Figma values

**Frame layout:** `4767:23726`, 1920×1080.
- **Order:** title bar (40), then the content column, then the control bar (54).
- **Content column:** `justify-between`. Cover 738×737 at y 113, title at y 924 (29 tall). The three gaps (title bar to cover, cover to title, title to control bar) are each 73 px, about 7.4 % of the 986 px content height.
- **Cover:** radius 20, glow `0 0 90.5px 64px rgba(255,255,255,0.03)`.
- **Title:** "untangle - juxtopposed", i.e. title, " - ", artist. Inter Medium 24, `#969696`, centred.
- **Background:** the same artwork at 1952×1952, centred, blurred 10 px, on `#1B1B1B`.

**Music control bar:** `4778:26181`.
- **Bar:** 54 tall, `rgba(25,25,25,.95)`, 1 px `#222222` top border, padding 20/11, gap 20. Same as slice 2.
- **Left group:** prev, back 15, play pill, forward 15, next. 30×28 cells with an 8 px gap.
- **Centre:** current time (76×28, Inter 15 `#8F8F8F`), the waveform, then the duration (76×28).
- **Right:**
  - Volume: icon plus an 88 px meter.
  - Then audio tracks and settings: 30×32 each, 12 px gap.
  - Then the queue button.
  - No subtitle button.

**Waveform:** `4778:26191`.
- **Track:** `#090909`, radius 6, 28 tall, clips its children.
- **Bars:** 2 px wide, radius 4, pitch 5 px. Vertically centred. Heights only ever 2, 4, 6, 8, 10, 12 or 14 px.
- **Colours:** unplayed bars `#404040`, played bars `#AB6314`.
- **Playhead:** 4×24 `#D37918`, radius 4, at the progress x.

## Design

### 1. Music view (`player/qml/Player.qml`, audio branch)

**Layout:**
- A column under the title bar: cover, then title line, then the control bar.
- `gap = round(contentHeight × 0.074)`.
- `coverSide = min(contentHeight − titleHeight − 3·gap, contentWidth − 2·gap)`.

**Cover:**
- `Player.artwork` drawn square: the same `Image` with a rounded mask, radius 20 (scaled).
- The Figma glow is a `RoundedRectangleShadow`: white at 3 %, blur 90, spread 64.
- **No-art fallback:** a dark tile (`#191919` with a centred 96 px music glyph in `#404040`). It replaces the light `noArtAlbumCover`.

**Title line:**
- `Player.title + " - " + Player.artist`; if there's no artist, just `Player.title`.
- One line, elided in the middle, max width = the cover side.

**Background:**
- Keeps the existing `DualKawaseBlur` of the cover, with its black tint.
- Accepted deviation: Figma only blurs by 10 px, but its sample art is already dark. The tint keeps bright covers readable behind the `#969696` text.
- With no art, the background is plain `#1B1B1B`, not a blurred placeholder.

**Removed from the audio branch:**
- `albumLabel`, `artistLabel` and `lyricsLabel`.
- The `leftSideParent`/`rightSideParent` lyrics panels, the lyrics `Loader` and the "Sync to Playback" checkbox.
- The `audioControls` row.
- `LyricsFlickable.qml` and `MainCtx.lyricsMode` stay in the tree (other code may use them). They just aren't used by the player any more.

### 2. Music control bar

**Default `Audioplayer` layout** (`dialogs/toolbar/controlbar_profile_model.cpp`, `DEFAULT_STYLE`):
- Left: `PREVIOUS_BUTTON, SKIP_BACK_BUTTON, PLAY_BUTTON, SKIP_FW_BUTTON, NEXT_BUTTON`.
- Centre: empty, so the inline time + slider fill it, as in slice 2.
- Right: `VOLUME, LANG_BUTTON, EXTENDED_BUTTON, PLAYLIST_BUTTON`.
- Users with a saved custom profile keep theirs. Only the default changes.

**Skip buttons:**
- `SkipBackButton`/`SkipForwardButton` jump exactly ±15 s: a new `PlayerController::jumpBySeconds(int)` slot (`vlc_player_JumpTime`), since QML cannot build a `VLCTime`.
- They use two new glyphs exported from Figma, "skip back 15" and "skip forward 15", appended to the icon font (append-only, as in slice 3b).
- VLC's jump hotkeys keep the configurable `short-jump-size`.

**Audio tracks button:** `LangButton` shows the waveform/audio glyph from the Figma icon set when the control bar's `identifier` is `Audioplayer`. It still opens the slice-3a tracks panel.

### 3. Peak data: `PlayerWaveform` (C++, QML type `Waveform` in `VLC.Player`)

**Interface:**
- `Q_PROPERTY(QUrl uri)` (input).
- `Q_PROPERTY(QList<float> peaks NOTIFY peaksChanged)`: 1024 values from 0 to 1, empty until the first data arrives.
- `Q_PROPERTY(bool ready NOTIFY readyChanged)`: the decode has finished.

**Decode:** the in-repo pattern from `modules/misc/fingerprinter.c`.
- A hidden `vlc_player_t` is created as a child of the interface object.
- It plays an `input_item` for `uri` with trusted options:
  - `sout=#transcode{acodec=fl32,channels=1,samplerate=8000}:smem{audio-prerender-callback=…,audio-postrender-callback=…,audio-data=…,no-time-sync}`. A chain bool is switched off by its `no-` prefix; a value like `time-sync=0` is ignored.
  - `no-sout-video` and `no-sout-spu`.
- `no-time-sync` makes smem report itself as not synchronous, so the input runs faster than real time. A sout chain has no audio output, so nothing reaches the speakers.
- **Callbacks:**
  - The prerender callback hands out a reusable buffer.
  - The postrender callback folds each sample into `bucket = (pts − VLC_TICK_0) / length × 1024`, keeping `max |x|`.
  - `length` comes from the hidden player's length event.

**Threading:**
- The callbacks run on the sout thread and write under a mutex.
- A Qt timer on the GUI thread copies the buckets into `peaks` at most every 100 ms, so the bars fill in progressively.
- When the hidden player stops, a last copy is made, normalised to the loudest bucket, and `ready` is set.

**Scope guards:**
- Only `file://` URIs with a known length are decoded. Network streams are never downloaded twice.
- With no decode, or a failed one, `peaks` stays empty, and the bar draws flat 2 px bars.

**Lifetime:**
- A new `uri`, or destroying the object, stops and frees the hidden player (`vlc_player_Stop`, then `vlc_player_Delete`, under its lock).
- No callback runs after that returns.

**Pure helpers** (`player/waveform_util.{hpp,cpp}`, unit-tested):
- `foldSamples(buckets, samples, n, ptsStart, rate, length)`.
- `resample(peaks, barCount)`, using the max over each span.
- `barHeight(peak, minH = 2, maxH = 14, step = 2)`.

### 4. Waveform seek bar (`player/qml/SliderBar.qml`)

**Mode:**
- New `property bool waveform` and `property var peaks`.
- In waveform mode only the visuals change. Pointer and touch seek, drag, keyboard steps, the hover time tooltip, chapter names in the tooltip and chapter snapping all work as before. Chapter segments are not drawn over the waveform.

**Visuals:**
- A `#090909` radius-6 track, 28 tall.
- `barCount = floor((width − 4) / 5)` bars, heights from `barHeight(resample(peaks, barCount))`.
- Two layers, so playback never redraws bars:
  - the grey (`#404040`) bars over the full width;
  - the orange (`#AB6314`) bars, clipped to `x ≤ progress·width`.
- The 4×24 `#D37918` playhead sits on top.
- The bars use one `Canvas` per layer, redrawn only when `peaks` or the width changes.

**Wiring in `ControlBar.qml`:**
- `ControlBar` gains `musicMode`; `Player.qml` sets it to `!Player.hasVideoOutput`, the same condition that picks the Audioplayer layout. The slider's `waveform` is `musicMode && _compact`.
- A `Waveform { uri: Player.url }` lives in the control bar, in a Loader that is active only in that mode and only while `Player.videoTracks.count === 0`. No decode runs for videos.

### 5. Testing

**QTest** (`modules/gui/qt/tests/test_waveform_util.cpp`, registered in `meson.build` like `test_qt_effects_util`):
- `foldSamples` buckets by pts and keeps max |x|, and ignores samples past `length`.
- `resample` keeps the peak inside each span.
- `barHeight` snaps to 2…14 in steps of 2.

**Sample media:** `make-samples.sh` gains `build/redesign-music/waveform.mp3`.
- 40 s: 3 s of silence, a 10 s ramp, then 1 s bursts every 2 s.
- Tagged title "waveform", artist "Tester", with an embedded cover image.
- It has a visibly shaped waveform and a cover, unlike the flat sine samples.

**Harness:** Xvfb and Wayland.
- Shots of the music player compared with the Figma frame.
- Clicking the waveform seeks.
- The log grep is clean (TypeError, ReferenceError, etc.).
- After stop, `pgrep -x vlc-static` is empty.
- Silence: the harness always passes `--aout=dummy`. The hidden decode player creates no aout at all.

## Out of scope

- Disk cache of peaks.
- Waveform for videos or streams.
- The mini player (slice 6).
- The Music library pages (slice 4).
- The light theme (slice 10).
