# Session Handoff

- Generated: 2026-11-08T23:35:58+13:00
- Working directory: /home/ming/Documents/projects/vlc-redesign-implementation (master = origin/master = 6e82ef3591, clean tree)

## Session goal
Continue the previous handoff: fix Customize Player's title-bar drops, audit the 105 Figma frames, then build the one real gap found (slice 12, seekbar hover preview) via spec → plan → subagent-driven execution. Then fix two user reports: invisible chapter marks and an empty volume bar at startup. All pushed.

## Decisions
- **Customize Player title bar:** the edit zones now fill the bar (left zone to the centre zone, right zone from the centre zone to the edge), like the bottom row, instead of hugging their items. The centre zone is sized from `editRight.implicitWidth` to avoid a sizing loop.
- **Seek preview engine:** VLC's core thumbnailer (`vlc_preparser_req_NewThumbnail`) on a dedicated 1-thread preparser with a 2 s timeout, one request in flight, latest position wins. The alternative was a persistent hidden player, rejected after measuring: ~25 ms on the 640×360 test files, ~70 ms fast / ~96 ms precise on 1080p, ~0.5 s on 4K HEVC.
- **Seek preview behaviour:**
  - Seeks by position (0–1), not time: QML can't read µs from VLCTick.
  - Seek speed follows "Seek precisely" (`input-fast-seek`), so the preview shows the frame a click would land on.
  - Each request uses a fresh `input_item_t` from the URI, with no options copied.
  - Disc schemes (dvd, dvdsimple, bluray, vcd, cdda) are refused inside the C++ item, not only by the QML.
  - Frames are requested only while the card is visible; hiding the card cancels the request; the last frame is kept so the card never blanks.
  - The card replaces the old time tooltip only while it can show; otherwise the tooltip is unchanged.
  - The chapter name follows the time on the card.
  - New option `qt-seek-thumbnail` (default on, as Figma draws it) backs Settings ▸ Playback "Show thumbnail while scrubbing" and applies live.
- **Rotation:** taken from the player's current video track, because the core resets thumbnail pictures to ORIENT_NORMAL (`picture_Setup` → `video_format_Setup`). It's correct only for the playing file, the only case the QML binds.
- **Card fill:** `Qt.alpha(bgA3, 0.95)`, not `bgA3Transparent` (that one is 75 % in light). Dark comes out `#1B1B1B`, Figma has `#191919`.
- **Chapter marks:** no Figma design. The 2 px gaps between chapter segments are now filled with `Qt.alpha(tokens.fgA1, 0.5)` (my call).
- **Volume bar:** fixed in the core, not the widget (see Bugs).
- **Handoff files:** kept the committed LATEST.md instead of the stub `/clear` writes; the stub equals `HANDOFF_2026-11-08T05-25-52-427Z.md` (committed).

## Bugs / issues surfaced
- **Customize Player title bar took no drops in its free space.** Cause: zones were sized to their content. **Fixed** (007604e108).
- **Chapter breaks invisible on the dark compact seekbar.** Cause: the 2 px gap showed a near-black bar behind a near-black track. **Fixed** (dde3f266d5).
- **Volume bar empty at startup.** Cause: upstream commit 6958b29519 gated `on_volume_changed` on `oldval >= 0`, so the first report (unknown -1 → real) never reached interfaces. **Fixed** in `src/player/aout.c` (cccc8dc5ae): the event is always sent, only the OSD stays gated. Before any playback it's still empty: PipeWire reports volume only once a stream exists.
- **Title bar empty (no "…", folder or title) when started with `--no-qt-video-autoresize`.** Seen in a Task 3 harness run. **Open**, not investigated. Possibly the same bug as the empty title bar with a file argument from the earlier handoff.
- **Visualizer = "Visualizer filter" aborts VLC on the next video** (core, filters.c:418). **Open**, pre-existing.
- **4K HEVC preview** takes ~0.5 s per frame, so a sweep lags by one frame. Accepted; a possible follow-up is fast seek above some resolution.

## Next steps
1. **Empty title bar repro:** `vlc-xvfb.sh start -vv --no-qt-video-autoresize build/redesign-media/plain.mp4`, shoot the top 40 px, compare with a run without the flag; then try a file argument with autoresize on. Start from `maininterface/qml/LocalTopbar.qml` (`_modelDriven`, the BarRow visibility) and `player/qml/Player.qml:704` (topBar).
2. Ask the user whether "second top row" meant the bottom bar's upper (seek) row while customizing. It accepts only the seekbar, by design (`ControlBar.qml` `seekRowZone`).
3. Optionally investigate the Visualizer filter abort.
4. Docs: `docs/superpowers/specs/2026-11-08-vlc-redesign-settings-apply-design.md` appendix still marks 9 freetype rows LIVE (6 are; the rest are "Next video").

## Files touched
- `modules/gui/qt/maininterface/qml/LocalTopbar.qml`: Customize Player edit zones fill the title bar.
- `modules/gui/qt/player/seek_preview_util.{hpp,cpp}` + `tests/test_seek_preview_util.cpp`: helpers (`previewableScheme`, `clampPosition`, `fitInto`, `LatestOnly`, `oriented`) and their QtTest.
- `modules/gui/qt/player/seek_preview.{hpp,cpp}`: `SeekPreview` QQuickPaintedItem (preparser, RGBA convert, cancel on hide or uri change, rotation from the player).
- `modules/gui/qt/player/qml/SeekPreviewCard.qml`: the Figma card (own ColorContext; outside the player's context tree it would draw black).
- `modules/gui/qt/player/qml/SliderBar.qml`: `previewEnabled`, `_previewing`, shared `_hoverText`, the card Loader, `_recheckPreview` on hover, uri change and load; chapter gap marks.
- `modules/gui/qt/player/qml/ControlBar.qml`: `previewEnabled: !root.musicMode && !root.editing`.
- `modules/gui/qt/qt.cpp`: `qt-seek-thumbnail` option.
- `modules/gui/qt/maininterface/mainui.cpp`: registers `SeekPreview`.
- `modules/gui/qt/meson.build`, `Makefile.am`: sources, test, QML.
- `modules/gui/qt/dialogs/settings/qml/SettingsData.js`, `tests/tst_SettingsData.qml`: the new row and its test.
- `src/player/aout.c`: first volume report reaches interfaces, without an OSD.
- `docs/superpowers/specs/2026-11-08-vlc-redesign-seek-preview-design.md`, `plans/2026-11-08-vlc-redesign-seek-preview.md`, roadmap (row 12; Later bullets done), settings design row for the scrubbing setting.

## Open questions
- Does "second top row" in the original Customize Player report mean the seek row (bottom bar, upper row)? It's unanswered and decides whether that row should accept normal items.
