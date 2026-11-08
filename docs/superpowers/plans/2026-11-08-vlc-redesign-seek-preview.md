# Seekbar Hover Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hovering the player's seekbar on a video shows the Figma `thumbnail` card (2151:9673): the frame at the hovered time and the time under it.

**Architecture:** A QML-registered `QQuickPaintedItem` (`SeekPreview`) owns a dedicated core preparser (thumbnail type, 1 thread, 2 s timeout), asks it for one frame at a time (latest position wins), converts the returned `picture_t` to RGBA on the core thread and paints it on the Qt thread. `SliderBar.qml` shows a card holding that item above the pointer and hides its old tooltip while the card shows. A new `qt-seek-thumbnail` option backs the Settings row.

**Tech Stack:** C++17, Qt 6 Quick, VLC core `vlc_preparser.h` thumbnailer, `vlc_image.h` converter, QtTest / QuickTest, meson (+ Makefile.am kept in step).

**Spec:** `docs/superpowers/specs/2026-11-08-vlc-redesign-seek-preview-design.md`

## Global Constraints
- Branch `redesign/seek-preview`; commits as the global git user (ming), no Claude trailers.
- No core changes: `vlc_preparser_req_NewThumbnail()` only.
- Card: 272×189, radius 14, fill token `bgA3` (95 % opacity), picture 252×142 at (10,10) radius 4, time Inter Regular 15 px, colour token `fgA2`, centred, top at y 162. No backdrop blur.
- Fresh `input_item_t` from the playing URI, no options copied.
- Seek speed: `input-fast-seek` true → `VLC_THUMBNAILER_SEEK_FAST`, else `VLC_THUMBNAILER_SEEK_PRECISE`; read on every request.
- No card for disc schemes `dvd`, `dvdsimple`, `bluray`, `vcd`, `cdda`; not seekable; no video track; setting off.
- Preparser `timeout = VLC_TICK_FROM_SEC(2)`; on failure/timeout the card keeps its last frame.
- Silent: thumbnailer opens no aout (core already guarantees it); harness runs keep `--aout=dummy`.
- Every harness run: `vlc-xvfb.sh start -vv`, then grep `build/redesign-profile/run/vlc.log` for `TypeError|ReferenceError|non-existent property|unavailable`; delete `RecoveryFilePath=` from `build/redesign-profile/config/vlc/vlc-qt-interface.conf` first.

## Review Focus
1. **Quit or media change while a request is in flight** → no crash, no stale frame from the old file. Task 2 generation counter (uri change drops old results) + Task 3 harness quit-during-hover and a file switch mid-hover.
2. **Sweeping fast across the bar** → at most one request in flight, the last hovered position is fetched after the sweep, card never blanks between frames. Task 1 `LatestOnly` tests; Task 3 shot sequence.
3. **Hover at the very ends (0 and length)** → card clamps inside the window; time 0:00 / length; no request past the end. Task 1 `clampPosition` test; Task 3 shots at both ends.
4. **Audio file / setting off** → old tooltip exactly as before, no empty card. Task 3 harness steps.
5. **Portrait or odd-aspect video** → picture letterboxed inside 252×142, not stretched. Task 1 `fitInto` test.

---

### Task 1: Pure helpers

**Files:**
- Create: `modules/gui/qt/player/seek_preview_util.hpp`, `modules/gui/qt/player/seek_preview_util.cpp`
- Test: `modules/gui/qt/tests/test_seek_preview_util.cpp`
- Modify: `modules/gui/qt/meson.build` (sources list near `waveform_util`, and a `vlc_tests += { 'name': 'test_qt_seek_preview_util', … }` block copied from `test_qt_waveform_util`), `modules/gui/qt/Makefile.am` (same, copied from `test_waveform_util`)

**Interfaces:**
- Produces (namespace `seekpreview`):
  - `bool previewableScheme(const QString& scheme)` — false for the five disc schemes (case-insensitive), true otherwise.
  - `double clampPosition(double p)` — clamps to `[0, 0.999]` (NaN → 0).
  - `QSize fitInto(QSize src, QSize box)` — aspect-preserving fit, never zero in either axis when `src` is valid; returns `box` for an invalid `src`.
  - `class LatestOnly { public: bool request(double p); std::optional<double> finished(); void reset(); }` — `request` returns true when nothing is in flight (caller starts `p` now) and false otherwise (stores `p` as pending, replacing any older pending); `finished` marks the in-flight one done and returns the pending value (now in flight) or `nullopt` (nothing in flight); `reset` drops both.

- [ ] **Step 1: Write the failing tests** in `tests/test_seek_preview_util.cpp` (`class TestSeekPreviewUtil`, `QTEST_GUILESS_MAIN`, `#include "test_seek_preview_util.moc"`):
  - `discSchemesRejected`: `previewableScheme` false for `dvd`, `DVD`, `dvdsimple`, `bluray`, `vcd`, `cdda`; true for `file`, `smb`, `nfs`, `sftp`, `ftp`, `http`, `https`.
  - `clampPosition`: `clampPosition(-0.5) == 0.0`, `clampPosition(0.5) == 0.5`, `clampPosition(1.0) == 0.999`, `clampPosition(qQNaN()) == 0.0`.
  - `fitInto`: `fitInto({1920,1080},{252,142}) == QSize(252,142)`; `fitInto({1080,1920},{252,142}) == QSize(80,142)`; `fitInto({640,480},{252,142}) == QSize(189,142)`; `fitInto({},{252,142}) == QSize(252,142)`.
  - `latestOnlyCoalesces`: `request(0.1)` true; `request(0.2)` false; `request(0.3)` false; `finished() == 0.3`; `finished() == nullopt`; `request(0.4)` true.
  - `latestOnlyReset`: `request(0.1)`; `request(0.2)`; `reset()`; `request(0.5)` true; `finished() == nullopt`.
- [ ] **Step 2: Run, expect a build failure** — `cd build && ninja test_qt_seek_preview_util` → error: `seek_preview_util.hpp` not found.
- [ ] **Step 3: Implement** the header/cpp (`fitInto` rounds with `qRound`, minimum 1 px per axis).
- [ ] **Step 4: Run** — `cd build && meson test --suite qt test_qt_seek_preview_util` → `OK`.
- [ ] **Step 5: Commit** — `git add` the 3 new files + meson.build + Makefile.am; `git commit -m "qt: seek preview helpers"`.

### Task 2: `SeekPreview` item and the `qt-seek-thumbnail` option

**Files:**
- Create: `modules/gui/qt/player/seek_preview.hpp`, `modules/gui/qt/player/seek_preview.cpp`
- Modify: `modules/gui/qt/qt.cpp` (option, next to `qt-video-autoresize`), `modules/gui/qt/maininterface/mainui.cpp:339` (register beside `Waveform`), `modules/gui/qt/meson.build` + `Makefile.am` (sources, moc header)
- Test: `modules/gui/qt/tests/test_seek_preview_util.cpp` is unchanged; the item's behaviour is checked in Task 3 on the harness (it needs a libvlc instance).

**Interfaces:**
- Consumes: Task 1's `seekpreview::*`.
- Produces: QML type `SeekPreview` in the same module as `Waveform` (`qmlRegisterType<SeekPreview>(uri, versionMajor, versionMinor, "SeekPreview")`), `class SeekPreview : public QQuickPaintedItem` with
  - `Q_PROPERTY(MainCtx* ctx …)` (same pattern as `PlayerWaveform::ctx`)
  - `Q_PROPERTY(QUrl uri …)` — setting a new uri cancels the in-flight request, `LatestOnly::reset()`, clears the frame (`hasFrame` false), `update()`.
  - `Q_PROPERTY(double position …)` 0–1 — setting it calls `LatestOnly::request(clampPosition(p))` and submits when it returns true.
  - `Q_PROPERTY(bool hasFrame READ hasFrame NOTIFY hasFrameChanged)`.
  - `Q_INVOKABLE bool allowed() const` — `var_InheritBool(intf, "qt-seek-thumbnail") && previewableScheme(uri.scheme())`.
- Option: `add_bool("qt-seek-thumbnail", true, SEEK_THUMBNAIL_TEXT, SEEK_THUMBNAIL_LONGTEXT)` with `N_("Show thumbnail while scrubbing")` / `N_("Show the video frame under the pointer when hovering the seek bar.")`.

- [ ] **Step 1: Implement `SeekPreview`.** Decisions the implementer can't infer:
  - Preparser created lazily on the first request: `cfg.types = VLC_PREPARSER_TYPE_THUMBNAIL; cfg.max_thumbnailer_threads = 1; cfg.timeout = VLC_TICK_FROM_SEC(2); cfg.external_process = false;`, on `VLC_OBJECT(ctx->getIntf())` (as `mainctx.cpp:283`). Destructor: `vlc_preparser_Delete` (cancels and joins; queued Qt calls to a dead `this` are dropped because they go through `QMetaObject::invokeMethod(this, …)`).
  - Each request: `input_item_New(uri.toString(QUrl::FullyEncoded).toUtf8(), nullptr)`; arg `seek.type = VLC_THUMBNAILER_SEEK_POS`, `seek.pos = p`, speed from `input-fast-seek`, `hw_dec = false`; submit; release the item after `NewThumbnail` (the request holds it). Tag each request with a generation counter bumped on uri change; a result whose generation differs is dropped.
  - `on_ended` (core thread): if `thumbnail`, convert with an `image_handler_t` (created once, on the core thread side guarded by the 1-thread executor) to `VLC_CODEC_RGBA` at `fitInto(visible size × SAR, 504×284)`, copy into a `QImage::Format_RGBA8888` (`.copy()` so it owns its pixels), then `QMetaObject::invokeMethod(self, [=]{ … }, Qt::QueuedConnection)`; on the Qt thread: release the req, store the image if the generation matches, `update()`, then `if (auto next = m_latest.finished()) submit(*next)`.
  - `paint()`: fill nothing (the card behind draws the fill); draw the image centred and fitted (`fitInto(image.size(), size().toSize())`) with `QPainter::SmoothPixmapTransform`; clip to a 4 px (`VLCStyle.dp(4)` passed from QML as the item's `radius` property, `Q_PROPERTY(qreal radius …)`) rounded rect.
- [ ] **Step 2: Build** — `cd build && ninja` → no warnings in `seek_preview.cpp`.
- [ ] **Step 3: Run the existing Qt suites** — `cd build && meson test --suite qt` → all pass (count = previous 30 + 1 from Task 1).
- [ ] **Step 4: Commit** — `git commit -m "qt: SeekPreview item renders a frame of the playing file at a time"`.

### Task 3: The card on the seekbar, the Settings row, harness check

**Files:**
- Create: `modules/gui/qt/player/qml/SeekPreviewCard.qml` (add to the player QML list in `meson.build` / `Makefile.am` and the qrc where `SliderBar.qml` is listed)
- Modify: `modules/gui/qt/player/qml/SliderBar.qml:117-140` (tooltip gating), `modules/gui/qt/player/qml/ControlBar.qml:273` (enable the card on the main player's bar only: `previewEnabled: !root.musicMode && !root.editing`), `modules/gui/qt/dialogs/settings/qml/SettingsData.js:183` (row after "Seek precisely"), `modules/gui/qt/tests/tst_SettingsData.qml` (`test_appliesSpot`), `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md` (slice 12 row; the Later Figma-audit bullet becomes done), `docs/superpowers/specs/2026-10-25-vlc-redesign-settings-design.md:205` (row now built)

**Interfaces:**
- Consumes: `SeekPreview` (Task 2): `ctx`, `uri`, `position`, `hasFrame`, `radius`, `allowed()`.
- Produces: `SliderBar.previewEnabled: bool` (default false; MiniPlayer's bar keeps false).

- [ ] **Step 1: Settings test first** — in `test_appliesSpot` add `compare(m["qt-seek-thumbnail"].applies, undefined)` and `verify(m["qt-seek-thumbnail"] !== undefined)`; run `cd build && meson test --suite qt tst_SettingsData` → FAIL (row missing).
- [ ] **Step 2: Add the row** `{ label: qsTr("Show thumbnail while scrubbing"), kind: "toggle", option: "qt-seek-thumbnail" }` right after "Seek precisely"; rerun → PASS.
- [ ] **Step 3: `SeekPreviewCard.qml`** — an `Item` with `property alias uri/position` onto an inner `SeekPreview`, `property string text`, a `Rectangle` card per Global Constraints (sizes via `VLCStyle.dp(n, VLCStyle.scale)`), `SeekPreview` at 10,10 sized 252×142 with `radius: dp(4)`, a `Widgets.LabelExt` for `text` (time + optional " - chapter", `elide: Text.ElideRight`, width card − 20). Before the first frame the picture area shows the card fill only.
- [ ] **Step 4: SliderBar wiring.**
  - `readonly property bool _previewing: previewEnabled && hoverHandler.hovered && !dragHandler.active && Player.seekable && Player.videoTracks.count > 0 && _previewAllowed`, where `_previewAllowed` is re-read from `card.allowed()` whenever `hoverHandler.hovered` turns true (so the setting applies live).
  - Existing tooltip: `visible: (… existing …) && !control._previewing`.
  - Card: a `Loader` (active while `previewEnabled`), parented to `control.Window.contentItem`, `visible: _previewing`; `position` = `Helpers.clamp(pointer x, 0, width) / width`, `uri: Player.url`; position: x = pointer's window x − width/2 clamped to `[margin, window width − width − margin]` with margin `VLCStyle.margin_xsmall`; y = slider's window top − height − `VLCStyle.margin_xsmall`. Text reuses the tooltip's formatting (`formatHMS`, chapter suffix) — move that expression into a function `_hoverText(x)` used by both.
- [ ] **Step 5: Build and run the QML tests** — `cd build && ninja && meson test --suite qt` → all pass.
- [ ] **Step 6: Harness check** (`docs/superpowers/scripts/vlc-xvfb.sh start -vv build/redesign-media/plain.mp4`, `key space` to pause, `xdotool mousemove` onto the bar):
  - Shots at bar x ≈ 5 %, 50 %, 95 %, and at both ends: card above the pointer, inside the window; burnt-in timecode within 0.5 s of the card's time.
  - Sweep: 20 `mousemove` steps across the bar at 30 ms, shot right after and 500 ms later: the later shot's frame matches the final position; no blank card in either.
  - Settings ▸ Playback: toggle off, hover again → old tooltip only, no restart. Toggle back on.
  - Theme Light (Settings or `theme-shots.sh` index 1): card is the light token swap.
  - Audio: restart with a file from `build/redesign-music` (or `build/redesign-media/*.mkv` audio-only if present) → music player bar, old tooltip only.
  - Next file (`key n` with two files queued) while hovering → the card shows nothing from the old file.
  - Quit (`key ctrl+q`) while hovering mid-sweep → exits; `coredumpctl list --since -5min | grep vlc` empty.
  - Log grep clean (Global Constraints).
- [ ] **Step 7: Docs** — roadmap: add row `| 12 Seek preview (done) | thumbnail 2151:9673; Settings ▸ Playback "Show thumbnail while scrubbing" | Plan 2026-11-08-vlc-redesign-seek-preview. Departures: … |` listing anything the harness forced; settings design line 205 → `toggle | qt-seek-thumbnail | Slice 12`.
- [ ] **Step 8: Commit** — `git commit -m "qt: seekbar hover preview card and its Settings row"`.

## Ledger
(Rulings made during execution go here.)
