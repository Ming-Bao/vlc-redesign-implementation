# VLC Redesign: Mini player card (slice 6) Design

**Source of truth:** Figma "VLC Redesign (Community)", file key `dSoAm0gN9ZterHSssJU9FN`.
- **Component set `Miniplayer 970:3091`**, 391 wide, five variants:
  - `Default 970:3090`: resting card (video, seek bar, title, folder/artist row, queue button).
  - `Variant3 975:4333`: the pointer is over the video. 60 % black veil, × top-left, pop-out top-right, previous / play / next in the middle, seek handle shown.
  - `Variant5 1919:9515`: playback has ended. Dark video area, × / pop-out, previous / **replay** / next.
  - `Variant2 970:3092` and `Variant4 975:4377`: Default and Variant3 with the **queue** open above the video (card 690 high).
- **Placed in** three library frames, 6 px from the window's bottom corner: `970:3308` and `970:2703` (bottom-right), `970:3792` (bottom-left, over the sidebar). The library has no bottom player bar in any of them.
- **Prototype links:** hovering the video goes to Variant3; the queue button toggles Variant2; × and pop-out both link to the player frame `247:445`.
- **Reference shots** in `docs/superpowers/figma/6/`: `mini-default-970-3090.png`, `mini-variant2-970-3092.png`, `mini-variant3-975-4333.png`, `mini-variant4-975-4377.png`, `mini-variant5-1919-9515.png`, and `library-3308-card-right.png`, `library-3792-card-left.png`, `library-2703-card-right.png`.
- **Memory `figma-is-the-spec`** applies. The user skipped the question round ("go next"); every choice no frame shows is marked *(my call)*.

## Scope

- One floating card in the library that replaces both of today's library-side players:
  - the compact bottom bar (`player/qml/MiniPlayer.qml`, slice 1);
  - VLC 4's floating video (`player/qml/PIPPlayer.qml`).
- The card's five states, its controls, and the queue it opens.

Out of scope:
- **The player view** (slices 2–4e): no card there, including in the 4e side panel.
- **Customize Player's "Mini player" toolbar tab:** it stays as is and now edits nothing visible. *(my call: slice 8 redoes that dialog.)*
- **The light theme** (slice 10): dark values only, but read through `ColorContext` where an existing component already does.

## Where it lives and when it shows

- **Where:** a QML item in `MainDisplay.qml`, above the library pages (where `PIPPlayer` sits today). It is not a separate window.
- **Shows when:** the main window shows the library (`!MainCtx.playerView`) and either:
  - something is playing or paused (`Player.isStarted`), or
  - playback has **ended** (below) and the card hasn't been dismissed.
- **Hides when:**
  - playback is stopped any other way (× on the card, the Stop hotkey or menu entry);
  - the player view opens;
  - new playback starts in the player view. The card comes back, in its playing state, when the user returns to the library.
- **Ended** means the player stopped on its own at the end of the queue, not because of a stop request.
  - *(my call)* Detect it as: the last position seen before `Player.playingState` went to stopped was within about a second of the end.
  - Mark this with a `ponytail:` comment naming its limit: a stop request in the last second reads as "ended". Upgrade path: a core end-of-stream signal.
- **Position:** the bottom-right corner of the main display, 6 px in (× scale). The card can be dragged by any part that isn't a control.
  - On release it snaps to the nearer bottom corner, left or right. This matches the two placements the Figma shows. *(my call)*
  - On the left it sits over the sidebar, as in `970:3792`.
  - The side is kept for the session only. *(my call)*
- **Size:** the card is fixed at 391 × 339, or 391 × 690 with the queue open (× `VLCStyle.scale`, via `VLCStyle.dp(n, VLCStyle.scale)` like the other slices).
  - When the window is too short for the queue, the queue list shrinks, down to about two rows. *(my call)*
  - When the window is shorter than the closed card, the card overflows upward. It is not clipped.
- **The library around it:**
  - Pages no longer reserve a bottom strip for a bar. `displayMargin` stops including a player bar.
  - When the card shows, pages get an end margin of the card's height plus its inset (the existing `displayMarginEnd` binding), so the last rows can scroll out from under it. *(my call)*
  - `Dialogs` and `FloatingNotification` anchor to the display's bottom instead of the bar's top.

## The card (all values in Figma px, × scale)

| Part | Figma |
|---|---|
| Card | `#1B1B1B` (Dark/BG/A3), radius 14, padding 8, shadow 0 0 5.9 `rgba(0,0,0,0.38)`; 20 between the media block and the info block (and between the queue and the media block) |
| Media block | 375 wide, 230 high; the video, 4 gap, the seek bar |
| Video area | 16:9 (375 × 211), 2 px `#090909` border, radius 6, background `#303030` |
| Seek bar | 16 high, track `#090909` radius 6, elapsed `#371F06` inset 2 (12 high, radius 4), handle 8 × 12 accent `#D37918` radius 4. The handle shows only on hover (Variant3/5) |
| Info block | padding 8 left/right, 4 top/bottom; 14 between title row and meta row |
| Title | Inter 16, `#969696` (Dark/FG/A1), one line, elided at the right |
| Meta row | two groups 20 apart, each = 24 px icon `#8F8F8F` + 8 gap + Inter 16 `#969696` |
| Queue button | 30 wide, padding 4, radius 4; list icon `#8F8F8F`; while the queue is open the icon is the accent version (2 px strokes, `#D37918`) |
| Hover veil | `rgba(0,0,0,0.6)` over the video |
| Hover controls | × (24) at 14,14; pop-out (24) at the top-right, 14 in; previous / play / next are 42.86 px glyphs `#EAEAEA` with shadow 0 4.76 4.76 `rgba(0,0,0,0.7)`, centred as a row (previous box at x 83, play at 165.6, next box at 233 in the 375 frame) |
| Ended | video area `#202020`, no veil; × / pop-out / previous / replay / next shown without hover *(my call: there is nothing else to see)* |

**Video area content:**
- **Video playing:** the live video. It uses `VideoSurface` with `MainCtx.videoSurfaceProvider`, as `PIPPlayer` does.
  - When `MainCtx.canShowVideoPIP` is false (`qt-pip-mode` off, or no depth buffer), the area shows what audio shows. VLC's existing rule stays: with no PIP, the library stops embedded video when it loads (`MainDisplay`'s `Component.onCompleted`). So in that setup the card only ever shows audio. *(my call: the video has nowhere else to draw.)*
- **Audio only:** `Player.artwork` fitted (aspect kept) and centred on `#303030`. With no artwork, the plain `#303030`. *(my call)*
- **Ended:** `#202020` and the controls.

**Title and meta row:**
- **Title:** `Player.title`.
- **Folder group:** the name of the folder holding the playing file, taken from `Player.url`. Hidden for non-`file://` media. *(my call: the Figma's "S01" is that file's folder.)*
- **Artist group:** `Player.artist`, hidden when empty. *(my call)*
- **Both hidden:** the row keeps only the queue button.

**Icons:**
- Each one is the Figma SVG, unchanged, downloaded from the variants' design context into `pixmaps/redesign/mini/`. They are listed in `assets.qrc`, `Makefile.am` and `meson.build`, as slice 5 did for `pixmaps/redesign/menu/`.
- **Mirrored instances** (pop-out, folder) carry the flip as a `<g transform>` in the SVG (slice 5's R3).
- **The set:** close, pop-out, previous, next, play, replay, folder, artist, queue, queue-active.
- **Pause:** the Figma has no pause glyph, so a pause SVG is drawn to match the play glyph's size, colour and stroke. It shows while playing. *(my call)*

## Controls

| Control | Action |
|---|---|
| Previous / Next | `MainPlaylistController.prev()` / `next()`; dimmed when `hasPrev` / `hasNext` is false |
| Play / Pause | `MainPlaylistController.togglePlayPause()`; the glyph follows `Player.playingState` |
| Replay (ended) | plays the item the card shows from the start |
| × | playing: `MainPlaylistController.stop()` (the card hides, as above); ended: hides the card |
| Pop-out | `MainCtx.playerView = true` |
| Double-click on the video | opens the player, as `PIPPlayer` does today |
| Single click on the video | nothing; the hover controls do the work *(my call: avoids a pause flicker before a double-click)* |
| Seek bar | click and drag seek (`SliderBar` with `blockStyle`, `barHeight` 16) |
| Queue button | toggles the queue section |

- **Touch:** a tap on the video toggles the hover controls, like `PIPPlayer`'s `hideControls`.
- **Keyboard:** the card is a Navigation item below the library page. It is reached the way the old bar was, through the page's `Navigation.downItem`.
  - Inside the card, Left/Right moves through its buttons.
  - Up from the card returns to the page; Escape returns too.
  - Each button has an accessible name.

## Queue section (Variant2/4)

- **Placement:** it opens above the media block. The card grows upward and its bottom edge stays put.
- **Header strip:** 58 high, `#151515` (Dark/BG/A5), top corners 14 and bottom corners 2. "Queue", Inter 16 `#8F8F8F`, is centred 16 from the top.
- **The rest is slice 3b's `QueuePage`,** reused with a new compact mode:
  - Count row: 64 high, padding 28 left / 20 right, "N items - length" in Inter 14 `#6B6B6B`.
  - Buttons on the right, 20 apart: **sort, remove, add**, as in the Figma. The compact mode hides loop, shuffle and clear.
  - The list: 215 high, padding 20 left/right, rows 12 apart. Each row is a drag handle, the title (14 `#969696`) and the duration (14 `#6B6B6B`).
- **Behaviour:** reorder by drag, double-click to play, Delete to remove. It is unchanged from 3b.

## Removed

- `MiniPlayer.qml` and `PIPPlayer.qml`, their uses in `MainDisplay.qml` (`miniPlayer`, `hasMiniPlayer`, `positionSliderY`, `_showMiniPlayer`, `pipPlayerComponent`), and their entries in the QML module lists.
- Any other user of these files moves to the card or drops the reference.

## Verification

- **Xvfb shots** (`vlc-xvfb.sh`), each next to its reference in `docs/superpowers/figma/6/`:
  - the card at rest, while video plays;
  - the card with the pointer over the video;
  - the queue open;
  - after the queue ends;
  - with audio-only media;
  - the card snapped to the left.
- **Wayland driver:** one check that the card's shadow and rounded corners draw.
- **The `-vv` log grep** for QML errors (TypeError / ReferenceError / non-existent property / unavailable), as in every slice.
- **One runnable check per non-trivial helper:** the folder name from a URL, the "ended" decision, the left/right snap side.
- **Manual checks:**
  - × stops playback;
  - pop-out and double-click open the player;
  - returning to the library brings the card back;
  - Stop from the hotkey hides the card rather than showing "ended".

## Ledger

The plan file keeps a `## Ledger` of every departure from the frames. It starts with each *(my call)* above.
