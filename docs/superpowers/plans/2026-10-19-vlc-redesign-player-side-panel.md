# Player side panel (slice 4e) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A sidebar button in the player's title bar slides in the Figma's library panel (icon rail plus the 4b–4d pages, narrow) beside the video. Alongside it:
- the Figma's filled glyph for the active sidebar entry;
- a compact two-row page header with ↗ "open in library";
- the playing item marked in the library pages.

**Architecture:**
- **Shared history:** the player and `MainDisplay` are never alive together (`MainInterface`'s `viewLoader` swaps them). So the panel is a second `PageLoader` on the global `History`, with the same page list.
- **Shared loader:** the page list, the sort memory and the history wiring move out of `MainDisplay` into `LibraryPageLoader.qml`, used by both. The sidebar's Add item menu moves into `LibraryAddMenu.qml`, used by both.
- **The rail** is `SideNavigationPane` in its existing collapsed (icon-only) state.
- **The panel's place:** the video / music area's left edge follows the panel's right edge.

**Tech Stack:** Qt 6 / QML, meson. Icon font pipeline: `pixmaps/makeIconFont.py` with python3-fontforge, plus the Figma MCP. Tests: `qml_test` (`tests/tst_LibraryHelpers.qml`).

**Spec:** `docs/superpowers/specs/2026-10-19-vlc-redesign-player-side-panel-design.md`

## Global Constraints

- **Figma is the source of truth** (`dSoAm0gN9ZterHSssJU9FN`).
  - Panel `848:1995` (and the variants in `848:1996`); `Player - Music 4767:23726`.
  - Shots are in `docs/superpowers/figma/4e/`.
  - The video `redesign source.mp4` 11:36–11:56 covers behaviour only.
- **Sizes:** every Figma px goes through `VLCStyle.dp(<px>, VLCStyle.scale)`.
  - Panel 427 (rail 50 + page area 377).
  - Page area padding 20.
  - Header rows 24 high, 20 apart; divider 17 below.
  - Rows 32 high, 10 apart.
- **Colours:**
  - accent `#D37918`;
  - the others come from 848:1995's `get_design_context` (load the `figma:figma-design-to-code` skill first);
  - pattern `theme.palette?.isDark ? <figma> : <theme role>`.
- **The global `History` is shared, not duplicated.** No second `NavigationHistory`, and no edits to the 27 pages that call `History`.
- **Harness runs:**
  - `docs/superpowers/scripts/vlc-xvfb.sh` only (Xvfb :77, `--aout=dummy`). Never send xdotool to the user's display.
  - The harness resumes the saved queue: click the video and press `s` to stop.
- **Git:** commits as the global git user (ming), with no Co-Authored-By. Branch `redesign/player-side-panel` (it exists, and holds the spec).
- **After each task:**
  - `ninja -C build`;
  - `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt` all OK;
  - after any harness run, `grep -E 'TypeError|ReferenceError|non-existent property' build/redesign-profile/run/vlc.log` finds nothing new.
- **New QML files** go in `modules/gui/qt/meson.build`, `Makefile.am` and `po/POTFILES.in`.

## Review Focus

1. **VLC launched straight into a file** (empty `History`), then the panel opened: it shows Home, with no warning. Task 5, Step 5.
2. **A playing file whose name has spaces or non-ASCII characters:** it is still marked. The `mrl` role and `Player.url` encode differently. Task 6, Step 1.
3. **A narrow window (800 px) with the panel open:** the panel stays usable and the video keeps a positive width. The panel width is capped at half the window. Task 5, Step 5.
4. **The next item starts while the panel is open:** the mark moves to it, and the panel page doesn't reload or lose its scroll. Task 6, Step 5.
5. **↗ during a video when there's no picture-in-picture:** the video stops (today's leave-player rule) and the library opens on the panel's page. During music, playback continues under the mini bar. Task 4, Step 4.

---

### Task 1: Seven new glyphs

**Files:**
- Create: `modules/gui/qt/pixmaps/redesign/{home,videos,music,streaming,playlists,recent}-filled.svg`, `modules/gui/qt/pixmaps/redesign/open-in-library.svg`
- Modify: `modules/gui/qt/pixmaps/redesign/mapping.json`, `modules/gui/qt/pixmaps/VLCIcons.json`
- Regenerate: `modules/gui/qt/pixmaps/VLCIcons.ttf`, `modules/gui/qt/style/vlcicons.hpp`

**Interfaces:**
- Produces the `VLCIcons` keys `home_filled`, `videos_filled`, `music_filled`, `network_filled`, `playlists_filled`, `recent_filled` and `open_in_library`.

- [ ] **Step 1: Export from Figma.** Use the 4a recipe (`docs/superpowers/plans/2026-10-16-vlc-redesign-library-shell.md`, the icon task at lines 247–285):
  - `exportAsync({ format: 'SVG_STRING', svgOutlineText: true })`, then `flatten-figma-svg.py`.
  - **Filled glyphs:** the active rail icon of each variant: home 1106:5633, videos 848:1997, music 858:5001, network 858:5294, playlists 858:5374. Export the glyph only, not the wrapper.
  - **Recent** has no active variant. Look for a filled `recent` in the icon set 42:356. If there is none, map `recent_filled` to `recent.svg` and say so in the commit message.
  - **↗:** `1851:3230` (the second icon of 848:1995's header Frame 103).
- [ ] **Step 2: Add the keys.**
  - Append the seven keys to `VLCIcons.json`, after `genre`.
  - Add the matching `mapping.json` entries.
  - From `modules/gui/qt/pixmaps`, run `python3 makeIconFont.py VLCIcons.json`.
- [ ] **Step 3: Verify.**
  - `git diff modules/gui/qt/style/vlcicons.hpp` shows seven added keys and no renumbered key.
  - `python3 -I docs/superpowers/scripts/check-icon-font.py` passes.
  - Render the seven glyphs to PNG with the 4a fontforge one-liner and look at them: each is filled where the Figma is filled, and has no stroke artefacts.
- [ ] **Step 4: Commit** `qt: filled sidebar glyphs and the open-in-library glyph`.

### Task 2: Active sidebar entry is the Figma's filled glyph

**Files:**
- Modify: `modules/gui/qt/util/qml/Helpers.qml`, `modules/gui/qt/tests/tst_LibraryHelpers.qml`, `modules/gui/qt/maininterface/qml/SideNavigationDelegate.qml`, `modules/gui/qt/maininterface/qml/SideNavigationPane.qml` (the delegate's `checked` binding around line 210)

**Interfaces:**
- Consumes the Task 1 keys.
- Produces `Helpers.sidebarEntryState(viewPath : var, uri : var) : int`, which returns:
  - `0` for another section;
  - `1` deeper in the entry's section;
  - `2` at the section's root.

- [ ] **Step 1: Write the failing test** `test_sidebarEntryState_data` / `test_sidebarEntryState` in `tst_LibraryHelpers.qml`:

| tag | viewPath | uri | expected |
|---|---|---|---|
| home root | `["home"]` | `["home"]` | 2 |
| videos root | `["video"]` | `["video"]` | 2 |
| default subpage | `["video", "base"]` | `["video"]` | 2 |
| folder level | `["video", "folder"]` | `["video"]` | 1 |
| songs | `["music", "songs", "folder"]` | `["music"]` | 1 |
| other section | `["network"]` | `["video"]` | 0 |
| add item | `["home"]` | `["additem"]` | 0 |
| empty history | `[]` | `["home"]` | 0 |

- [ ] **Step 2: Run** `meson test -C build tst_LibraryHelpers`. Expected: FAIL (`sidebarEntryState` is not a function).
- [ ] **Step 3: Implement `sidebarEntryState`.**
  - It returns 2 when `viewPath` starts with `uri` and the rest is empty or exactly `["base"]`, the `PageLoader` default name.
  - It returns 1 for any other prefix match.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Delegate.** `SideNavigationDelegate` gets `property int entryState` (bound from the pane with `Helpers.sidebarEntryState(History.viewPath, uri)`). It replaces the `highlighted || checked` accent rule:
  - **Glyph:** state ≥ 1 → the filled key, picked by `uri[0]` from a QML map (`home`, `video`, `music`, `network`, `playlists`, `recent` → the Task 1 keys).
  - **Glyph colour:** accent at 2; at 1, the inactive glyph colour.
  - **Label:** primary colour at 2; as inactive otherwise.
  - **Unchanged:** keyboard focus and hover keep their current look. `checked` (used by navigation) stays true for states 1 and 2.
- [ ] **Step 6: Harness check.** Start, then capture:
  - Home → `after_sidebar_home.png`: filled orange house, white label.
  - Videos ▸ Shows → `after_sidebar_deeper.png`: filled grey Videos glyph.
  - Compare with `docs/superpowers/figma/4b/home.png` and `4a/grid.png`.
  - Check the Music glyph is the Figma's folder with a note; if not, fix the `mapping.json` entry for `topbar_music`.
- [ ] **Step 7: Commit** `qt: the active sidebar entry is the Figma's filled glyph`.

### Task 3: LibraryPageLoader and LibraryAddMenu out of MainDisplay

A pure refactor: the library must behave exactly as before.

**Files:**
- Create: `modules/gui/qt/maininterface/qml/LibraryPageLoader.qml`, `modules/gui/qt/maininterface/qml/LibraryAddMenu.qml`
- Modify: `modules/gui/qt/maininterface/qml/MainDisplay.qml`:
  - `pageModel` at 107–134;
  - `contextSaver` and its `Connections` at 185–208;
  - the onCompleted history fallback at 87–90;
  - `addItemMenu` and `onItemClicked` at about 596–660.
- Modify: `meson.build`, `Makefile.am`, `po/POTFILES.in`

**Interfaces:**
- **`LibraryPageLoader`** (root `Widgets.PageLoader`) produces:
  - `pageModel`: the list moved verbatim;
  - `function loadCurrentHistoryView(focusReason)`;
  - `function openSection(uri : var)`: scroll to the top when `isDefaulLoadedForPath(uri)` or `History.exactMatch(History.viewPath, uri)`, else `History.push(uri)`;
  - `signal viewLoaded()`, emitted when a load finds its page.
  - It owns the `ModelSortSettingHandler` and both `Connections` (`MainCtx.sort`, `History.onNavigate`).
  - On completion it applies the `History.update(["home"])` fallback, then loads.
- **`LibraryAddMenu`** (root `Widgets.FigmaMenu`): `property Item loader` (a `LibraryPageLoader`). It holds the three rows moved verbatim; New playlist uses `loader.isDefaulLoadedForPath(["playlists"])`.

- [ ] **Step 1: Create both files and switch `MainDisplay` to them.**
  - `stackView` becomes `LibraryPageLoader`.
  - `MainDisplay.loadView` stays as the outer `PageLoader` API, delegating to the loader. The mini-player rule moves to `onViewLoaded`.
  - The sidebar's `onItemClicked`: `additem` → `addMenu.popup(item, item.width, 0)`. The collapsed-expandable branch stays as it is. Otherwise `stackView.openSection(modelUri)`.
- [ ] **Step 2: Build and run the tests.** Expected: all OK.
- [ ] **Step 3: Harness regression pass.**
  - Every sidebar entry.
  - Clicking the current entry scrolls the page to the top.
  - Back / Forward.
  - Add item ▸ New playlist lands on Playlists.
  - Set the sort on Videos, go to Music and back: the sort is kept.
  - Restart: VLC opens on Home.
  - The log is clean.
- [ ] **Step 4: Commit** `qt: library page loader and add menu shared out of MainDisplay`.

### Task 4: Compact page header with ↗

**Files:**
- Modify: `modules/gui/qt/widgets/qml/PageExt.qml`; `modules/gui/qt/widgets/qml/GridSortFilterControls.qml` if the search field's collapse lives there

**Interfaces:**
- Consumes `VLCIcons.open_in_library`.
- Produces `PageExt.compact : bool` (readonly, `width < VLCStyle.dp(600, VLCStyle.scale)`), which Task 5 relies on and doesn't set.

- [ ] **Step 1: Compact layout.** When `compact`:
  - **Row 1:** back, forward, the crumbs (keeping the `_hiddenCrumbs` "…" collapsing), "…", and ↗ (36 apart).
  - **Row 2:** the count; then sort, view and a search icon (36 apart).
  - **Spacing:** 20 between rows; the divider 17 below row 2. Wide layout unchanged.
  - **Search:**
    - The icon swaps the count for the search field and focuses it.
    - Escape, or leaving the field while it's empty, swaps back and returns focus to the icon.
    - A non-empty search stays open.
- [ ] **Step 2: ↗ "Open in library".**
  - Visible only when `MainCtx.playerView` (both layouts; it's only ever true in the panel). Description `qsTr("Open in library")`.
  - Its action copies `Player.qml`'s `leavePlayer()` (3 lines), with a comment naming it as the twin: stop when `MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP`, then `MainCtx.playerView = false`.
- [ ] **Step 3: Harness check (library window).** Resize the window to 560 wide:
  - Every page gets the two-row header, with no ↗.
  - Search opens, filters and closes as Step 1 says.
  - Back at 1600 the header is unchanged from master: compare with `docs/superpowers/figma/4d/after_playlists_list.png`.
- [ ] **Step 4: ↗ is checked in Task 5's harness run** (Review Focus 5).
- [ ] **Step 5: Commit** `qt: compact two-row page header with open-in-library`.

### Task 5: The panel in the player

**Files:**
- Create: `modules/gui/qt/player/qml/LibraryPanel.qml`
- Modify: `modules/gui/qt/player/qml/Player.qml`:
  - the `LocalTopbar` at 648–720;
  - `playerSpecializationLoader` anchors at 185–190;
  - the auto-hide locks around 98–152.
- Modify: `meson.build`, `Makefile.am`, `po/POTFILES.in`

**Interfaces:**
- Consumes `LibraryPageLoader` (`openSection`, `loadCurrentHistoryView`) and `LibraryAddMenu` from Task 3.
- `LibraryPanel` (root `FocusScope`):
  - `property bool open`;
  - `readonly property Item content` (the loader, for navigation);
  - `signal closeRequested()`.

- [ ] **Step 1: `LibraryPanel.qml`.**
  - **Rail:** `SideNavigationPane` with `delegateShowText: false`, 50 wide. Glyph wrappers 30×32 at x 10, the first at y 8, 46 apart. Its `onItemClicked` is the Task 3 pattern (`additem` → `LibraryAddMenu`, else `openSection`).
  - **Page area:** a `LibraryPageLoader` with 20 padding left / right / top. Pages bring their own header (now compact by width).
  - **Background:** rail and page-area colours from 848:1995.
  - **Escape:** `History.previous(Qt.BacktabFocusReason)`, or `closeRequested()`'s focus hand-back when `History.previousEmpty`.
- [ ] **Step 2: Player wiring.**
  - **Toggle:** `rootPlayer.libraryPanelOpen` (false on each player start, not saved). `topBar.showNavigationToggle: true`, `navigationVisible: libraryPanelOpen`, and `onToggleNavigationVisibility` flips it.
  - **Geometry:** the panel's top is `topBar.bottom` and its bottom `controlBar.top`, in fullscreen too.
    - Width `Math.min(VLCStyle.dp(427, VLCStyle.scale), rootPlayer.width / 2)`.
    - `x` slides from `-width` to 0 with a `VLCStyle.duration_long` `OutCubic` behaviour.
    - It's not visible while fully closed.
  - **Video / music area:** `playerSpecializationLoader.anchors.left` becomes the panel's right edge. Check the video surface during the slide; if it stutters, drop the `Behavior` and note it in the ledger.
  - **Auto-hide:** `lockUnlockAutoHide(true)` while open. When it closes, restore the previous rule (`_controlsUnderVideo` / the queue card), as the queue card's `onVisibleChanged` does.
  - **Navigation:**
    - `topBar.Navigation.downItem` is the panel while it's open.
    - The panel's `Navigation.rightItem` is the video (or the control bar if there's no video).
    - `closeRequested` focuses `topBar.navigationButton`.
- [ ] **Step 3: Build and run the tests.** Expected: all OK.
- [ ] **Step 4: Harness: video.** Play S01E05 from Videos ▸ Shows ▸ The Clip ▸ S01 (the fixture's name for the Figma's The Wand) (stop the resumed queue first), then open the panel:
  - **Opens on S01**, list view: shoot `after_panel_video.png` and compare with `sb_default.png` (layout, sizes, colours).
  - **Rail:** every entry; Home's sections; Back / Forward; search; the view toggle (the grid works at panel width).
  - **↗ with video** (Review Focus 5): the library opens on the same page, as video-without-PIP does today.
  - **↗ with music** (Review Focus 5): playback keeps going under the mini bar.
  - **Escape at the root** focuses the toggle.
  - **Controls** don't auto-hide while the panel is open.
- [ ] **Step 5: Harness: edges.**
  - **Music:** play a song and shoot `after_panel_music.png`; compare with `player_music.png` (the cover is centred in the remaining area).
  - **Empty history** (Review Focus 1): start with `vlc-xvfb.sh start "$PWD/build/redesign-media/Shows/The Clip/S01/The_Clip_S01E01.mp4"`, open the panel: it shows Home, with no warning.
  - **Narrow window** (Review Focus 3): `xdotool windowsize` the main window to 800×600 on :77 and open the panel: it is 400 wide and the video is visible.
- [ ] **Step 6: Commit** `qt: player side panel`.

### Task 6: The playing item is marked

**Files:**
- Modify: `modules/gui/qt/util/qml/Helpers.qml`, `modules/gui/qt/tests/tst_LibraryHelpers.qml`
- Modify: `modules/gui/qt/medialibrary/qml/HomeVideoCard.qml`, `HomeSquareCard.qml`, `HomeListRow.qml`
- Modify: `LibraryFolderPage.qml` (media delegates only), `RecentDisplay.qml`, `HomePage.qml` (Continue Watching / Listen Again)

**Interfaces:**
- Produces:
  - `Helpers.sameMedia(mrl : string, url : string) : bool`;
  - `property bool playing` on the three delegates.
- Before writing Step 3, check the Figma `media` row component (instances 6784:16226…) for a playing variant. If there is one, its values replace the ones below.

- [ ] **Step 1: Write the failing test** `test_sameMedia_data` / `test_sameMedia`:

| tag | mrl | url | expected |
|---|---|---|---|
| same | `file:///m/a.mp4` | `file:///m/a.mp4` | true |
| space encoded | `file:///m/a%20b.mp4` | `file:///m/a b.mp4` | true |
| non-ASCII | `file:///m/%C3%A9t%C3%A9.mp4` | `file:///m/été.mp4` | true |
| different | `file:///m/a.mp4` | `file:///m/b.mp4` | false |
| empty mrl | `""` | `file:///m/a.mp4` | false |
| malformed % | `file:///m/a%E0%A4%A.mp4` | `file:///m/a%E0%A4%A.mp4` | true, with no throw |

- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement `sameMedia`.**
  - Compare `decodeURIComponent` of both. If decoding throws, fall back to the raw string.
  - An empty `mrl` or `url` is never a match.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Delegates and pages.**
  - **When `playing`:**
    - the title colour is accent `#D37918`;
    - the thumbnail gets a 40 % black overlay and the accent `VLCIcons.play` glyph centred: `icon_normal` on the rows, `icon_large` on the cards.
  - **Pages** bind `playing: Helpers.sameMedia(model.mrl, Player.url)` on media items only. Folders, playlists and artists don't.
  - **Harness, with the panel open on S01 during S01E05:**
    - E05 is marked;
    - press `n` (next): E06 is marked, E05 isn't, and the list didn't jump (Review Focus 4);
    - the same mark shows on Home's Continue Watching in the library;
    - the log is clean.
- [ ] **Step 6: Commit** `qt: mark the playing item in the library pages`.

### Task 7: Ledger, roadmap, merge

- [ ] **Step 1: Ledger.** Add a `## Ledger` here comparing each after-shot with its Figma frame: what matches, and each departure with its reason. Known in advance: the title bar toggle keeps the library's checked look; the video's half-filled toggle glyph isn't done.
- [ ] **Step 2: Roadmap.** Mark the 4e row done in `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md`, naming the plan and the departures (including the skipped grid-page extraction).
- [ ] **Step 3: Commit, then merge and push.** Commit `doc: record slice 4e`. After the whole-branch review, fast-forward `master` and push.
