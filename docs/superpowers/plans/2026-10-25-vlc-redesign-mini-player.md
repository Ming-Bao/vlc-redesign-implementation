# Mini player card (slice 6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The library's bottom player bar and VLC 4's floating video become one Figma mini player card: a floating card in a bottom corner with the video or cover, a seek bar, a title, a folder/artist row and a queue it can open.

**Architecture:**
- **One file:** `player/qml/MiniPlayer.qml` is rewritten in place as the card. `PIPPlayer.qml` is deleted.
- **Wiring:** `MainDisplay.qml` drops every reference to the old bar (`miniPlayer.sliderY`, `_showMiniPlayer`, `pipPlayerComponent`…) and places the card above `loaderUpdatePane`.
- **Pure logic** goes in the `Helpers` singleton and is tested by `tst_LibraryHelpers.qml`: the folder name from a URL, the "ended" decision, the snap side.
- **The queue section** is slice 3b's `QueuePage` with a new `compact` mode.

**Tech Stack:** Qt 6 QML (QtQuick, Templates), meson, QtQuickTest. Figma MCP for the SVGs (load `figma:figma-design-to-code` before `get_design_context`).

**Spec:** `docs/superpowers/specs/2026-10-25-vlc-redesign-mini-player-design.md`

## Global Constraints

- **Figma is the source of truth** (`dSoAm0gN9ZterHSssJU9FN`).
  - Variants: `970:3090` Default, `975:4333` hover, `1919:9515` ended, `970:3092` queue, `975:4377` queue + hover.
  - Shots are in `docs/superpowers/figma/6/`.
- **Every Figma px value is written `VLCStyle.dp(n, VLCStyle.scale)`**, as in slices 2–5.
- **Colours** (dark):
  - card `#1B1B1B`, video border `#090909`, video background `#303030`, ended video `#202020`;
  - veil `rgba(0,0,0,0.6)`;
  - text `#969696`, icons `#8F8F8F`, count text `#6B6B6B`;
  - queue header `#151515`;
  - seek track `#090909`, elapsed `#371F06`, accent `#D37918`.
- **Card geometry:**
  - card 391 wide, radius 14, padding 8, 20 between blocks;
  - shadow 0 0 5.9 `rgba(0,0,0,0.38)`;
  - inset 6 from the corner;
  - video 375 × 211, border 2, radius 6;
  - seek bar 16 high;
  - info block padding 8/4, 14 between rows;
  - meta groups 20 apart, icon 24 + 8 gap.
- **Silent runs:** `--aout=dummy` (the harness passes it). Clear `RecoveryFilePath=` from `build/redesign-profile/config/vlc/vlc-qt-interface.conf` before each run (memory `redesign-harness`).
- **Git:**
  - branch `redesign/mini-player` (exists);
  - commits as the global git user, no Co-Authored-By;
  - the spec, this plan and `docs/superpowers/figma/6/` go in the first commit (done before Task 1).
- **After each task:**
  - `ninja -C build` builds;
  - `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt` is all OK;
  - after any app run, `grep -E 'TypeError|ReferenceError|non-existent property|unavailable' build/redesign-profile/run/vlc.log` finds nothing new. Start with `docs/superpowers/scripts/vlc-xvfb.sh start -vv …`, or the grep passes vacuously.
- **Harness media:** `build/redesign-media/Shows/The Clip/S01/` (video, folder "S01"), `build/redesign-media/sine.ogg` (audio). Start with a file to play: `vlc-xvfb.sh start -vv "$PWD/build/redesign-media/plain.mp4"`. Then `key Escape` or the title bar's library toggle returns to the library while it plays.
- **New or removed QML files** go in `modules/gui/qt/meson.build`, `Makefile.am` and `po/POTFILES.in`. New SVGs go in `assets.qrc`, `Makefile.am` and the meson resource list.

## Review Focus

1. **The queue advancing to the next item** (two files queued, the first ends): the card never flashes the ended/replay state between them. Task 3, Step 5.
2. **Pressing Stop (`s`) in the library in the last second of a file** reads as "ended" and shows replay. This is accepted (the spec's `ponytail:` limit). But Stop at any earlier point must hide the card. Task 3, Step 5.
3. **Window resized narrower or shorter while the card sits on the left or right:** the card stays in its corner, inside the window. With the queue open in a 600-high window, the list shrinks and the card's top stays below the page header. Task 3, Step 5 and Task 4, Step 4.
4. **Audio-only media** (`sine.ogg`, no artwork): the plain `#303030` area, the folder group shows "redesign-media", and the artist group is hidden. No TypeError from a null `Player.artwork`. Task 2, Step 5.
5. **Going to the player and back** (pop-out, then Escape): one video shows, in the player, and after Escape it is back in the card. A black card or a frozen frame is a failure. Task 2, Step 5.

---

### Task 1: Helpers for the card

**Files:**
- Modify: `modules/gui/qt/util/qml/Helpers.qml` (after `sameMedia`), `modules/gui/qt/tests/tst_LibraryHelpers.qml`

**Interfaces:**
- Produces (on the `Helpers` singleton, `import VLC.Util`):
  - `function urlFolderName(url : string) : string`: the decoded name of the folder holding a `file://` URL. `""` for non-file URLs, files at the root, or an empty string. Takes either the encoded form or the decoded `Player.url` form. On a malformed escape it returns the raw segment, as `folderEntries` does.
  - `function playbackEnded(position : real, lengthMs : real) : bool`: `true` when `lengthMs > 0`, `position > 0` and `(1 - position) * lengthMs <= 1500`.
  - `function snapToLeft(x : real, width : real, areaWidth : real) : bool`: `x + width / 2 < areaWidth / 2`.

- [ ] **Step 1: Write the failing tests** in `tst_LibraryHelpers.qml`:

```qml
function test_urlFolderName_data() {
    return [
        { tag: "encoded", url: "file:///home/u/The%20Wand/S01/The_Wand_S01E11.mp4", name: "S01" },
        { tag: "decoded", url: "file:///home/u/My Show/a.mkv", name: "My Show" },
        { tag: "utf8", url: "file:///m/S%C3%A9rie/a.mkv", name: "Série" },
        { tag: "malformed", url: "file:///m/%E9t%E9/a.mp3", name: "%E9t%E9" },
        { tag: "root", url: "file:///a.mkv", name: "" },
        { tag: "http", url: "https://x/y/z.mp4", name: "" },
        { tag: "empty", url: "", name: "" },
    ]
}
function test_urlFolderName(data) { compare(Helpers.urlFolderName(data.url), data.name) }

function test_playbackEnded_data() {
    return [
        { tag: "last 0.6 s", position: 0.999, lengthMs: 600000, ended: true },
        { tag: "6 s left", position: 0.99, lengthMs: 600000, ended: false },
        { tag: "at the end", position: 1.0, lengthMs: 1000, ended: true },
        { tag: "no length (stream)", position: 0.9999, lengthMs: 0, ended: false },
        { tag: "never started", position: 0, lengthMs: 1000, ended: false },
    ]
}
function test_playbackEnded(data) { compare(Helpers.playbackEnded(data.position, data.lengthMs), data.ended) }

function test_snapToLeft() {
    verify(Helpers.snapToLeft(10, 391, 1600))
    verify(!Helpers.snapToLeft(1200, 391, 1600))
    verify(!Helpers.snapToLeft(604.5, 391, 1600)) // centred exactly: stays right
}
```

- [ ] **Step 2: Run the tests and check that they fail**

Run: `QT_QPA_PLATFORM=offscreen meson test -C build tst_LibraryHelpers`
Expected: FAIL (`Helpers.urlFolderName is not a function`)

- [ ] **Step 3: Implement the three functions in `Helpers.qml`.** `urlFolderName` reuses `folderEntries`'s slash rule (`slash <= "file://".length` means root) and the `try { decodeURIComponent } catch` fallback. Decoding an already-decoded name must not throw ("My Show" has no `%`).

- [ ] **Step 4: Run the tests and check that they pass**

Run: `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt`
Expected: all OK

- [ ] **Step 5: Commit**

```bash
git add modules/gui/qt/util/qml/Helpers.qml modules/gui/qt/tests/tst_LibraryHelpers.qml
git commit -m "qt: helpers for the mini player card (folder name, ended, snap side)"
```

---

### Task 2: The card replaces the bottom bar and the floating video

**Files:**
- Create: `modules/gui/qt/pixmaps/redesign/mini/{close,popout,previous,next,play,pause,replay,folder,artist,queue,queue_active}.svg`
- Modify:
  - `modules/gui/qt/player/qml/MiniPlayer.qml` (rewritten);
  - `modules/gui/qt/maininterface/qml/MainDisplay.qml`;
  - `modules/gui/qt/assets.qrc`, `Makefile.am`, `meson.build`, `po/POTFILES.in`.
- Delete: `modules/gui/qt/player/qml/PIPPlayer.qml`, plus its `meson.build`, `Makefile.am` and `POTFILES.in` lines.

**Interfaces:**
- Consumes: `Helpers.urlFolderName` (Task 1).
- Produces, on `MiniPlayer` (root `T.Control`, `id: root`), for Tasks 3 and 4:
  - `property bool queueOpen: false`, toggled by the queue button;
  - `property bool ended: false`, read by the video area and the controls; Task 3 drives it;
  - `readonly property bool shown`, which is `Player.isStarted || ended`; the card's `visible` binds to it;
  - `property Item mediaBlock`, the video plus seek bar, so Task 4 can stack the queue above it;
  - `property bool atLeft: false`, which the card's anchoring in `MainDisplay` reads (left corner when true).

- [ ] **Step 1: Fetch the icons.** Download them from the design context of `975:4333` (close `196ad`, pop-out `deb6a`, previous `d3bb6`, next `bfa2f`, play `50560`, folder `cf6e1`, artist `7bb62`, queue `0eda2`), `1919:9515` (replay `11a05`) and `970:3092` (queue_active `ff804`). Save them unchanged as the files above.
  - **Mirrored instances:** pop-out and folder have a `-scale-y-100 rotate-180` wrapper in Figma, which is a horizontal mirror. Wrap their paths in `<g transform="matrix(-1 0 0 1 24 0)">`, as slice 5 did (R3).
  - **`pause.svg`:** draw it in the play glyph's 42.857 box, with two rounded bars in the same `#EAEAEA` fill and stroke as `50560`.
  - **Check:** open each SVG in a browser or `rsvg-convert` it to a PNG and compare it with `docs/superpowers/figma/6/mini-variant3-975-4333.png`.

- [ ] **Step 2: Rewrite `MiniPlayer.qml` as the card.** Keep the GPL header. Root `T.Control`, with the Global Constraints geometry.
  - **Background:** a `Rectangle` (`#1B1B1B`, radius 14) with `Widgets.DefaultShadow` or a matching `MultiEffect` shadow.
  - **Content:** a `ColumnLayout` holding the media block and the info block, 20 apart.
  - **Video area:**
    - a `VideoSurface { videoSurfaceProvider: MainCtx.videoSurfaceProvider }`, shown when `MainCtx.canShowVideoPIP && MainCtx.hasEmbededVideo`;
    - otherwise an `Image { source: Player.artwork; fillMode: Image.PreserveAspectFit }` on `#303030`;
    - `#202020` and no picture when `root.ended`;
    - a `HoverHandler`, plus a tap on touch that toggles `hideControls` (as `PIPPlayer` did);
    - the veil and controls show on hover, or always when `ended`;
    - `TapHandler.onDoubleTapped` → `MainCtx.playerView = true`; a single tap does nothing.
  - **Controls:**
    - previous / next → `MainPlaylistController.prev()` / `next()`, `enabled` from `hasPrev` / `hasNext`;
    - centre: play / pause → `MainPlaylistController.togglePlayPause()`, swapped for replay when `ended` (Task 3 fills in its action);
    - × → `MainPlaylistController.stop()`;
    - pop-out → `MainCtx.playerView = true`;
    - each one a `Widgets.IconToolButton`-like `T.AbstractButton` showing its SVG, with `Accessible.name` and `focusPolicy: Qt.TabFocus`.
  - **Seek bar:** `SliderBar { blockStyle: true; barHeight: VLCStyle.dp(16, VLCStyle.scale) }`, with its handle shown only while the media block is hovered or `ended`.
  - **Info block:**
    - title `Player.title`, elided;
    - folder group `Helpers.urlFolderName(Player.url.toString())`, hidden when `""`;
    - artist group `Player.artist`, hidden when `""`;
    - queue button on the right, with `queue.svg` or `queue_active.svg` by `queueOpen`.
  - **Keyboard:** Navigation `Left`/`Right` across the buttons; `Navigation.upItem` / `cancelAction` go to the page (wired in Step 3).

- [ ] **Step 3: Wire it into `MainDisplay.qml`.**
  - **Remove:** `hasMiniPlayer`, `positionSliderY`, `_showMiniPlayer` (and its set in `onViewLoaded`), `pipPlayerComponent` and its `createObject`, and every `miniPlayer.*` use (lines ~39–57, 248–344, 407, 460, 709, 755, 823, 831, 978, 989, 996–1027).
  - **Keep:** the `!MainCtx.canShowVideoPIP → stop()` rule in `Component.onCompleted`.
  - **`displayMargin`:** only the update pane, so `stackView`'s bottom margin is the update pane alone.
  - **Pages' `displayMarginEnd`:** `displayMargin + (miniPlayer.visible ? miniPlayer.height + inset : 0)`.
  - **`enableEndFade`:** binds to `!miniPlayer.visible`.
  - **Card position:** `id: miniPlayer`, `z: 4`, anchored `bottom: loaderUpdatePane.top` with a 6 margin, `right: parent.right` or `left: parent.left` (6 margin) by `atLeft`.
  - **Dialogs and `FloatingNotification`:** anchor `bottom` to `parent.bottom` (the notification to `loaderUpdatePane.top`).
  - **Navigation:** `loaderUpdatePane`'s `Navigation.downItem` stays `miniPlayer`; the card's `Navigation.upItem` is `loaderUpdatePane`.

- [ ] **Step 4: Build and run the tests**

Run: `ninja -C build && QT_QPA_PLATFORM=offscreen meson test -C build --suite qt`
Expected: builds, all OK

- [ ] **Step 5: Check on Xvfb.** Start with `vlc-xvfb.sh start -vv "$PWD/build/redesign-media/Shows/The Clip/S01/<first file>"`, then return to the library. Take these shots, each with a reference:
  - `/tmp/…/rest.png` against `mini-default-970-3090.png` (pointer parked at 1599,899): the card bottom-right, live video, the "S01" folder group;
  - hover over the video (`xdotool mousemove` onto it), against `mini-variant3-975-4333.png`: veil, ×, pop-out, the three buttons, the seek handle;
  - Review Focus 5: click pop-out, then `key Escape`, then shot. The card shows video again;
  - Review Focus 4: restart with `sine.ogg`. The card shows the `#303030` area, the "redesign-media" group, and no artist group;
  - click × and shot: no card, playback stopped.
  - Then run the `-vv` log grep. It finds nothing new.

- [ ] **Step 6: Commit**

```bash
git add -A modules/gui/qt po/POTFILES.in
git commit -m "qt: the Figma mini player card replaces the bottom bar and the floating video"
```

---

### Task 3: Ended state, replay, drag to a corner

**Files:**
- Modify: `modules/gui/qt/player/qml/MiniPlayer.qml`

**Interfaces:**
- Consumes: `Helpers.playbackEnded`, `Helpers.snapToLeft` (Task 1); `ended`, `atLeft` (Task 2).

- [ ] **Step 1: Ended.**
  - **Track the end:** keep `_lastPosition` and `_lastLengthMs` up to date from `Player.position` and `Player.length.toMilliseconds()` while `Player.isStarted`. If `toMilliseconds` isn't invokable from QML, use `toSeconds() * 1000`.
  - **When `Player.isStarted` turns false:** start a 500 ms `Timer`. If, when it fires, the player is still stopped and `Helpers.playbackEnded(_lastPosition, _lastLengthMs)`, set `ended = true`. This stops the flash between queued items (Review Focus 1).
  - **Clear it:** `ended = false` when `Player.isStarted` turns true, and when × is clicked while ended.
  - **`ponytail:` comment** on the timer: a stop request in the last 1.5 s reads as ended; a core end-of-stream signal would remove the guess.

- [ ] **Step 2: Replay and the other ended actions.**
  - **Replay:** `MainPlaylistController.goTo(MainPlaylistController.currentIndex, true)`, or `MainPlaylistController.play()` when `currentIndex < 0`.
  - **Previous / next while ended:** `goTo(currentIndex ∓ 1, true)`, where those indexes exist.
  - **Check on the harness** that `currentIndex` still points at the last item after the queue ends. If it doesn't, note what it points at in the Ledger and use it.

- [ ] **Step 3: Drag to a corner.**
  - **Drag:** a `DragHandler` on the card's non-control area (`target: root`, `dragThreshold` as default). It clears the side anchors while active, as `PIPPlayer` did.
  - **Drag bounds:** the main display less the 6 inset and the top bar (`localTopbar.y + localTopbar.height`), passed in from `MainDisplay` as `dragXMax` / `dragYMin` / `dragYMax`.
  - **On release:** `atLeft = Helpers.snapToLeft(root.x, root.width, parent.width)`, then restore the anchors so the card animates to its corner (`Behavior` on the anchor margin or `x`, `VLCStyle.duration_long`).

- [ ] **Step 4: Build and run the tests**

Run: `ninja -C build && QT_QPA_PLATFORM=offscreen meson test -C build --suite qt`
Expected: builds, all OK

- [ ] **Step 5: Check on Xvfb**
  - **Ended:** play the shortest clip in `Shows/The Clip/S01/` alone and wait for it to end in the library. The shot matches `mini-variant5-1919-9515.png`. Click replay and it plays again.
  - **Review Focus 1:** queue two clips (`start -vv fileA fileB`) and take a shot every 100 ms around the switch (`for i in $(seq 10); do …shot…; sleep 0.1; done`). No shot shows replay.
  - **Review Focus 2:** during playback, `key s` at mid-file. The card is gone.
  - **Snap:** drag the card (`xdotool mousedown`, stepped `mousemove` to x=300, `mouseup`). It sits bottom-left, 6 in, over the sidebar, as in `library-3792-card-left.png`. Drag it back right.
  - **Review Focus 3:** with the card on the left, `xdotool windowsize` the window to 900×600. The card stays bottom-left, inside the window.
  - Then run the `-vv` log grep.

- [ ] **Step 6: Commit**

```bash
git commit -am "qt: mini player card ended state with replay, and drag to a bottom corner"
```

---

### Task 4: The queue section

**Files:**
- Modify: `modules/gui/qt/player/qml/QueuePage.qml`, `modules/gui/qt/player/qml/MiniPlayer.qml`

**Interfaces:**
- Consumes: `queueOpen`, `mediaBlock` (Task 2).
- Produces: `QueuePage.compact : bool` (default `false`). When true:
  - the count row is 64 high with 20 between its buttons;
  - `LoopButton`, `RandomButton` and the clear button are hidden, leaving sort, remove and add.

- [ ] **Step 1: Add `compact` to `QueuePage.qml`.** The player's `QueuePanel` doesn't set it, so it is unchanged.

- [ ] **Step 2: The queue section in the card.**
  - **Placement:** when `queueOpen`, a section shows above the media block, with 20 between them.
  - **Header strip:** 58 high, `#151515`, corners 14/14/2/2 (`topLeftRadius` etc. where Qt ≥ 6.7, as `MainDisplay`'s top-left corner does, or a clipped rounded rect). "Queue" is Inter 16 `#8F8F8F`, centred 16 from the top.
  - **Below the strip:** `QueuePage { compact: true }`, 375 wide, list 215 high.
  - **Card height:** 690 when open. The card's bottom stays anchored, so it grows up.
  - **Short windows:** when the space above the card's bottom, below the top bar, is less than that, the list's height shrinks, down to two rows (12 + 2 × row height). It doesn't clip.
  - **Navigation:** the queue's Navigation `downItem` is the card's buttons; its `upItem` is the page.

- [ ] **Step 3: Build and run the tests**

Run: `ninja -C build && QT_QPA_PLATFORM=offscreen meson test -C build --suite qt`
Expected: builds, all OK

- [ ] **Step 4: Check on Xvfb**
  - **Queue open:** start with four files from `Shows/The Clip/S01/`, go to the library and click the queue button. The shot matches `mini-variant2-970-3092.png` (header strip, "4 items - …", sort / − / +, four rows, accent queue icon).
  - **Queue and hover:** hover the video too; the shot matches `mini-variant4-975-4377.png`.
  - **Rows:** double-click row 3 and it plays.
  - **Player panel unchanged:** open the player's queue panel. It still shows loop, shuffle and clear.
  - **Review Focus 3:** resize the window to 900×600 with the queue open. The list shrinks and the card stays below the page header.
  - Then run the `-vv` log grep.

- [ ] **Step 5: Commit**

```bash
git commit -am "qt: mini player card opens the queue above the video"
```

---

### Task 5: Ledger, roadmap, merge

**Files:**
- Modify: this plan (`## Ledger`), `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md` (row 6 → done, with plan name and departures)

- [ ] **Step 1: Check the card's look on Wayland.** Run `dbus-run-session -- docs/superpowers/scripts/wl-drive.py OUT vlc:"$PWD/build/redesign-media/plain.mp4" sleep:3 key:Escape sleep:2 shot`, or use the driver's step names. The card's rounded corners and shadow draw.
- [ ] **Step 2: Bring the Ledger up to date** with what was built, and mark roadmap row 6 done in the style of rows 4a–5.
- [ ] **Step 3: Commit**, then merge per superpowers:finishing-a-development-branch.

---

## Ledger

Departures from the frames (the spec's *(my call)* items, plus any found while building):

- **Customize Player's "Mini player" tab** stays and now edits nothing visible. Slice 8 redoes that dialog.
- **Ended** is detected from the last position: within 1.5 s of the end, still stopped 500 ms later. A Stop in the last 1.5 s reads as ended.
- **Ended state** shows its controls without hover.
- **Snap:** the card snaps to the nearer bottom corner, left or right. The side is kept for the session only.
- **The card is a fixed size.** The queue list shrinks to two rows in short windows.
- **Pages get an end margin** of the card's height, so the last rows can scroll clear of it.
- **Audio:** the artwork is fitted on `#303030`; with no artwork, the plain `#303030`.
- **No PIP** (`qt-pip-mode` off or no depth buffer): VLC's existing stop of embedded video stays, so the card shows audio only.
- **Folder group:** the playing file's folder name, hidden for non-file media. **Artist group:** `Player.artist`, hidden when empty.
- **Single click on the video does nothing.** A double-click opens the player.
- **Pause glyph** is drawn to match the Figma play glyph (the Figma has none).
- **The queue's compact mode** shows sort, remove and add only, as the Figma does. The player's queue panel keeps loop, shuffle and clear.
