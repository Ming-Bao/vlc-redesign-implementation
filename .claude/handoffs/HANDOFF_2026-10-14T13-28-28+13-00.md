# Session Handoff

- Generated: 2026-10-14T13:28:28+13:00
- Working directory: /home/ming/Documents/projects/vlc-redesign-implementation (on `master` at 99baec491b; local only, never pushed)

## Session goal
Finish the slice 3a leftovers from the previous handoff (the next-video crash fix, the commits, the merge). Then plan and carry out slice 3b of the Figma redesign: the player's queue card with Queue, Bookmarks and Chapters tabs, plus the deferred 3a panel polish. Slice 3b ran with subagent-driven development. Both slices are merged to master. Figma file `dSoAm0gN9ZterHSssJU9FN` is the spec.

## Decisions
- **The slice 3 roadmap is split into 3a, 3b, 3c and 3d** in `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md`.
  - 3c covers the gear panel's Video/Audio/Subtitles *settings* tabs and the 7 effect accordions.
  - 3d covers the music player's waveform seek bar.
  - Why: the Figma `Controls` variants (`498:2937`, `536:1059`, `763:1958`) show these tabs are settings, not track lists, so 3a's ruling that dropped them was a misreading.
- **The queue card is a non-modal `PlayerPanel` driven by `MainCtx.playqueuePanel.visible`** through the existing `PlayerPlaylistVisibilityFSM`.
  - It replaces the `PlaylistPane` Loader in Player.qml. `shown` is bound to `isPlaylistVisible`; `onClosed` toggles the FSM only while the queue is docked and visible.
  - Rejected: making it a modal, click-away panel, which would have broken the hotkey, the button and the detached window.
- **The card does not take focus when it opens** (`focus: false`; PlayerPanel `onOpened: if (focus) focusPage()`). Otherwise `InterfaceWindowHandler::applyKeyEvent`'s popup exception eats every player hotkey.
- **Keyboard navigation follows the current tab.**
  - `QueuePanel` owns `navigationParent/Up/Down`, `navigationCancel`, `currentList` and `currentTabButton`.
  - The pages' Up goes to the current tab, and Up from a tab goes to the top bar.
- **`MLBookmarkModel` is built with `Qt.createQmlObject`.** The type is only registered when a media library exists, so an inline Loader component fails to compile and takes the whole card with it.
  - It gained `canAdd` and Q_INVOKABLE `add`/`remove`.
- **Removing the playing item stops playback** (VLC core behaviour, the same as the library pane). Two QML workarounds failed.
- **`PanelRow` forwards keys to its ListView** (`Keys.forwardTo`), because GNOME turned Return on a focused row into a click.
- **The next-item crash fix applies only the vout states that were saved** (`7655da355f`). Fixing the remaining race on reused vouts properly was deferred, with the user's agreement.
- **Git identity is always the global user**, `ming <mingbao2891@gmail.com>`, with no Claude attribution. Saved as memory `git-identity`.

## Bugs / issues surfaced
- **Next-item heap corruption: fixed.** RestoreMlStates reset vout vars while the vout was being reused. A narrower race may remain for media that *do* have saved vout states. It is open and unreproduced, and needs ASan or valgrind (not installed).
- **The autoresize `dW>=0` assert is fixed** (`1c39fc7536`).
- **Hotkeys were dead while the queue card was open: fixed** (`f6ca7b74c8`).
- **Drag-reorder bugs are fixed** (`5c6dc3e0b5`, `a15e074f44`). A drop in the 12 px gap between rows sent the item to the end of the queue. After an async move the cursor sat one row off, so "–" removed the neighbouring row.
- **Undocking while the card was open hid the detached queue: fixed** (`ab30d764fc`).
- **Open: Ctrl+L toggling the card is untested.** Neither xdotool under Xvfb nor `wl-drive.py` (single keysyms only) can send key combinations.
- **Open minors, triaged as non-blocking:**
  - The headers read "1 items" and "1 Bookmarks" (no plurals).
  - The card's top uses `positionSliderY - 80` instead of `topBar`.
  - No auto-scroll while dragging.
  - A cancelled drag still moves the row.
  - The queue header buttons are reachable only with Tab.
  - `_otherPopupOpen` relies on overlay child order.
  - The queue-tab glyph is monochrome; Figma has an orange accent.
  - A second video window appeared once in the Xvfb harness, probably a harness artifact.
  - The first click after the pointer sits idle is sometimes dropped in the harness.
- **Pre-existing, not ours:**
  - `test_modules_misc_medialibrary` segfaults in libmedialibrary's `~shared_ptr<ILogger>` at exit.
  - In the tracks panel, Up and Escape do nothing once focus is on "+".

## Next steps
1. Ask the user to check Ctrl+L by hand on their desktop: it should toggle the queue card.
2. Plan slice 3c with `superpowers:writing-plans` and save it as `docs/superpowers/plans/2026-10-14-vlc-redesign-player-settings.md`.
   - Spec nodes: `Controls` video settings `498:2937`, audio settings `536:1059`, subtitle settings `763:1958`.
   - Effect accordions: Video Essential `536:1855`, Crop `543:990`, Colors `614:1430`; Audio Equalizer `6114:13610`, Compressor `536:1513`, Spatializer `536:1703`, Stereo Widener `612:1223`.
   - Shots already downloaded: `scratchpad/figma/fx_*.png` and `c_vset/c_aset/c_sset.png` in session scratchpad `/tmp/claude-1000/-home-ming-Documents-projects-vlc-redesign-implementation/23f2c0ce-3503-4596-a827-a6a36e63ef9b/`; they may be gone.
   - The gear panel is `modules/gui/qt/player/qml/PlaybackPanel.qml`; add tabs after Playback.
   - Map each control to existing VLC vars and models: `Player.*`, audio/video filter vars, the equalizer (look at `dialogs/extended`).
   - Omit anything with no VLC feature behind it, as 3a did.
3. Optionally fix the cheap minors before 3c: the plurals (`qsTr("%n item(s)", "", n)`), and anchoring the card top to `topBar`.

## Files touched
- `src/player/medialib.c`: apply only the saved vout states (the crash fix).
- `modules/gui/qt/maininterface/video_window_handler.cpp`/`.hpp`: measure the scene and keep the last valid autoresize compensation.
- `docs/superpowers/scripts/vlc-xvfb.sh`, `wl-drive.py`: `--aout=dummy`.
- `docs/superpowers/scripts/count-px.sh`: new helper that counts matching pixels in a box.
- `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md`: slice 3 split.
- `docs/superpowers/plans/2026-10-14-vlc-redesign-player-queue.md`: the slice 3b plan.
- `modules/gui/qt/pixmaps/redesign/{queue-tab,chapters,drag-handle}.svg`, `mapping.json`, `VLCIcons.json`/`.ttf`, `style/vlcicons.hpp`: glyphs `playqueue`, `chapters` and `drag_handle` appended (U+E061–E063).
- `modules/gui/qt/player/qml/PlayerPanel.qml`:
  - `fillHeight`; the tab bar shows for a single tab.
  - The outside-click close applies only to modal cards; `_otherPopupOpen` counts only popups above the card.
  - `focusPage()`; the current tab is the only one focusable; `currentTabButton`/`tabsNavigationUp`.
- `player/qml/PanelRow.qml`, `QueuePage.qml`, `BookmarksPage.qml`, `ChaptersPage.qml`, `QueuePanel.qml`: new files for the card and its tabs.
- `player/qml/Player.qml`: the PlaylistPane loader is replaced by `QueuePanel`, and Navigation now goes through `currentList`.
- `player/qml/controlbarcontrols/PlaylistButton.qml`: guard against the undefined `playlistWidget`.
- `player/qml/TrackSection.qml`, `TracksPanel.qml`, `PlaybackPanel.qml`:
  - `#222222` dividers and 18 dp padding below each section.
  - A focus ring on rows.
  - Speed snaps to steps and rounds to 0.01.
  - The Reverse switch has `checkable: false` and uses `onClicked`.
- `medialibrary/mlbookmarkmodel.hpp`/`.cpp`: `canAdd` plus `canAddChanged`, and Q_INVOKABLE `add`/`remove`.
- `meson.build`, `Makefile.am`: register the new QML files.

## Open questions
- Should the remaining vout-state race (saved states applied to a reused vout) be investigated with ASan before more features land?
- The user's old report that changing tracks didn't change the sound or subtitles is still unreproduced. Their `/tmp/vlc-tracks.log` was never received.
