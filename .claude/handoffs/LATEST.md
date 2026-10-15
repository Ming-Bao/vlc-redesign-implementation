# Session Handoff

- Generated: 2026-10-16T11:50:00+13:00 (updated after the 3d merge and the 4a spec)
- Working directory: /home/ming/Documents/projects/vlc-redesign-implementation (branch `redesign/library-shell`, holds the 4a spec only)
- State: slice 3d merged to local `master` (99fe07516b, fast-forward), `master` 12 commits ahead of `origin/master`, **not pushed**.

## Session goal
Pick up after the previous dev, who left no handoff. Slice 3c (the settings tabs) was already merged to `master` via PR #1. This session did slice 3d, the Figma music player: brainstorm, spec, plan, then subagent-driven development with a review per task and a final whole-branch review. It is merge-ready on `redesign/music-player`.

## Decisions
- **The Figma key that works is `dSoAm0gN9ZterHSssJU9FN`.** Galen's duplicate `d9xvroRclV6SaObbcqRmBr` returns "no edit access" for this account. The node IDs are the same in both.
- **User rulings:**
  - **Waveform for music only.** Videos keep the plain seek bar, so the Figma "waveform" variant `2139:8124` is used only for its geometry.
  - **Pure Figma.** The VLC 4 album/artist/lyrics labels, the two-panel lyrics view and the ±10/visualisation/lyrics row are removed from the audio view.
  - **Peaks from a background decode,** with no disk cache. Rejected: a disk cache, fill-in-as-it-plays, and decorative bars.
- **How the decode works.** A hidden `vlc_player` uses the fingerprinter pattern, a child `vlc_object` with `aout`/`vout` set to `dummy`, and the sout chain `#transcode{acodec=f32l,channels=1,samplerate=8000}:smem{…,no-time-sync}`.
  - A chain bool is switched off by its `no-` prefix; `time-sync=0` is ignored.
  - Measured: 94 ms for a 40 s file, 485 ms for 20 min.
  - It also pins `no-start-paused`, `start-time=0`, `stop-time=0`, `run-time=0` and `no-sout-video`/`no-sout-spu`.
- **Only `file://` URIs are decoded.** The Loader in `ControlBar.qml` is active only when `musicMode && audioTracks.count > 0 && videoTracks.count === 0`.
- **Cancelling joins on the GUI thread.** `vlc_player_Delete` runs synchronously on a uri change or destruction (a `ponytail:` comment). That takes milliseconds for local files; move it to a worker if it ever stalls.
- **±15 s skips use a new `PlayerController::jumpBySeconds(int)`,** because QML can't build a `VLCTime`. The hotkeys keep `short-jump-size`.
- **Icons:** the existing `skip_back`/`skip_for` keys now point at Figma's 15 s SVGs (`45:36`/`45:33`). `audio_tracks` was appended (U+E065).
- **Background tint.** The background keeps VLC's blur plus a 50 % black tint, not Figma's 10 px blur, so bright covers stay readable. The ledger notes the result is much brighter than Figma on bright art.
- **The ledger's scale note.** The Figma references are the 1920-wide frame rendered at 1600 (×0.833), so fixed-size elements look about 1.2× larger in our 1600 px shots. The values themselves match: the title is node `4778:24351`, Inter Medium 24, `#969696`.
- **SDD ran in the main checkout, not a worktree.** The build tree, profile, sample media and harness live only here.

## Bugs / issues surfaced
- **Fixed in the final review:**
  - User input options leaked into the hidden decode; `--start-paused` hung it.
  - A transient decode started for a video that followed a song.
  - The music audio-tracks button opened the tracks panel on Subtitles. It now opens on Audio (`currentTab = 1`).
- **Pre-existing, not ours:** every vlc-static exit segfaults in medialibrary `~shared_ptr<ILogger>` at `exit()`. The coredump check is therefore masked.
- **Open minors, deferred by the final review as can-wait:**
  - The first waveform bar is a dot on a track that is loud from the start. This is probably MP3 priming silence; log the first pts and buckets 0–6 before changing anything.
  - `poll()` emits every 100 ms even when nothing changed. A failed decode logs `waveform: N ms` and sets `ready`. `ready` has no consumer.
  - On VBR without a Xing header, the length is re-read per block, which smears the buckets.
  - Progressive normalisation rescales the bars during long decodes.
  - The canvases don't repaint on a live theme switch (slice 10).
  - The queue card needs two Escapes after a mouse open (probably slice 3b; seen on Xvfb only).
  - The window title reads "Tester - waveform" while the view line reads "waveform - Tester" (slice 2's title rule).
  - Untested: an ASan stress of a uri change during a decode (ASan isn't installed); corrupt files end playback before any bars show.
- **Plan defect.** `firstrunwizard.cpp:178/337` saves all control-bar profiles. So everyone who ran the first-run wizard keeps the old Audioplayer layout (no ±15 s buttons). They still get the waveform.

## Next steps
1. **Slice 4a (Library shell): the spec is written and committed; get the user's review, then plan.**
   - Spec: `docs/superpowers/specs/2026-10-16-vlc-redesign-library-shell-design.md` (`25d6a557cd` on `redesign/library-shell`). Reference shots: `docs/superpowers/figma/4a/`.
   - If the user approves it, run `superpowers:writing-plans` to `docs/superpowers/plans/2026-10-16-vlc-redesign-library-shell.md`, then execute with `superpowers:subagent-driven-development`, as 3d did. The user chose subagents for 3b and 3d.
   - Code entry points:
     - Sidebar: `modules/gui/qt/maininterface/qml/SideNavigationPane.qml`, and the `pageModel` in `MainDisplay.qml` (pages home/video/music/network/discover/mlsettings).
     - Header: `widgets/qml/PageExt.qml` `DefaultPageHeader` (back/forward, title label, "N items") and `widgets/qml/GridSortFilterControls.qml` (grid toggle, `SortControl`, `SearchBox`).
     - The "…" main menu: `menus/menus.cpp` `VLCMenuBar::MainMenu`, which has a "More" submenu.
     - Models: `MLPlaylistListModel` (`playlistType: PLAYLIST_TYPE_ALL`, `create(name, [])`), `MLRecentMediaModel`, `MLFolderModel.add(url)`, `MediaLib.reload()`.
     - Dialogs: `DialogsProvider.openNetDialog()`, `openFileDialog()`, `getTextDialog`. The static `getDirectoryDialog` still needs a `Q_INVOKABLE` wrapper.
     - QML tests: `meson.build` `qml_tests` (`tst_FSM`).
2. **Then 4b → 4c → 4d → 4e,** each with its own spec → plan → build. The roadmap `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md` has one row per part, with its Figma nodes and decisions.
3. **Ask the user** whether to push `master` to `origin` (`Ming-Bao/vlc-redesign-implementation`), using the global git identity.
4. **Ask** whether the new Audioplayer default should reach users whose control-bar profiles the first-run wizard saved (`firstrunwizard.cpp:178/337`). If yes, it needs a profile migration in `controlbar_profile_model.cpp`.
5. **Ask the user to hand-check** the music player (waveform click, ±15 s, the audio-tracks button) and Ctrl+L (from 3b).

## Files touched
- `modules/gui/qt/player/waveform_util.{hpp,cpp}` and `tests/test_waveform_util.cpp`: tested peak fold, resample, normalise and bar-height helpers.
- `modules/gui/qt/player/player_waveform.{hpp,cpp}`: the `Waveform` QML type, the hidden-player decode into 1024 peaks, polled every 100 ms.
- `modules/gui/qt/maininterface/mainui.cpp`: registers `Waveform` in `VLC.Player`.
- `modules/gui/qt/meson.build`, `Makefile.am`: new sources, moc, and `test_qt_waveform_util`. The qt suite now has 11 tests.
- `modules/gui/qt/player/player_controller.{hpp,cpp}`: the `jumpBySeconds(int)` slot.
- `modules/gui/qt/dialogs/toolbar/controlbar_profile_model.cpp`: new `DEFAULT_STYLE` Audioplayer layout.
- `player/qml/controlbarcontrols/{SkipBackButton,SkipForwardButton,LangButton}.qml` and `PlayerControlbarControls.qml`: ±15 s, the audio glyph, Audio-tab opening, labels.
- `player/qml/SliderBar.qml`: waveform mode (two Canvas layers, 4×24 playhead).
- `player/qml/ControlBar.qml`: `musicMode` and the gated `Waveform` Loader.
- `player/qml/Player.qml`: music view (ImageExt cover with radius 20 and glow, title line, no-art tile, `#1B1B1B` background); lyrics and the button row removed; `coverSource` removed; the control bar's Up goes to `topBar`.
- `pixmaps/redesign/{backward-15-sec,forward-15-sec,audio-tracks}.svg`, `mapping.json`, `VLCIcons.json`/`.ttf`, `style/vlcicons.hpp`: icons.
- `docs/superpowers/scripts/make-samples.sh`: adds `waveform.mp3` (shaped envelope plus cover) and `long.mp3`. The cancel tests used an uncommitted 10 h `huge.mp3` in the session scratchpad.
- `docs/superpowers/specs/2026-10-16-vlc-redesign-music-player-design.md`, `plans/2026-10-16-vlc-redesign-music-player.md` (with `## Ledger`), `figma/3d/*.png`, and the roadmap row 3d marked done.

## Open questions
- Push `master` to origin now?
- 4a spec: approved as written?
- Migrate the control-bar profiles saved by the first-run wizard to the new music layout?
