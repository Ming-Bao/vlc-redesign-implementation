# Menus (slice 5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every menu VLC pops up takes the Figma look. The "…" menu, the player right-click menu and the library's file, folder and playlist menus get the Figma entries and the actions behind the new ones.

**Architecture:**
- **One style:** a `QProxyStyle` (`MenuStyle`) installed on the `QApplication` draws every native `QMenu`: card, 48 px rows, two-tone SVG icons, shortcut column, chevrons, checks, dividers. It wraps whatever base style is active.
- **Content:** each menu's entries change in its existing builder (`menus/menus.cpp`, `menus/qml_menu_wrapper.cpp`, `medialibrary/qml/MLContextMenu.qml`).
- **`NativeMenu`/`StringListMenu`** learn icons and dividers through map rows.
- **New backends:**
  - the media library module turns a media's attached subtitle/audio files into input slaves;
  - `MediaLib` gains folder reload, external-track attach and playlist favourite;
  - an M3U8 writer for Export Playlist.

**Tech Stack:** Qt 6.11 widgets (`QProxyStyle`, `QMenu`) and QML, meson, QtTest. VLC core test `test/modules/misc/medialibrary.c`. Figma MCP for the icon SVGs (load `figma:figma-design-to-code` before `get_design_context`).

**Spec:** `docs/superpowers/specs/2026-10-25-vlc-redesign-menus-design.md`

## Global Constraints

- **Figma is the source of truth** (`dSoAm0gN9ZterHSssJU9FN`).
  - Frames: `6062:13354` (…), `6648:20666` (Profiles), `6065:13616` (right-click), `2404:13340` (file), `2139:8935` (folder), `2459:9389` (playlist).
  - Shots are in `docs/superpowers/figma/5/`.
- **Measures** (logical px × `MainCtx::getIntfScaleFactor()`):
  - card `rgba(25,25,25,0.95)`, radius 10, padding 4;
  - shadow 0 8 15 `rgba(0,0,0,0.46)`;
  - row 48 high, padding 14/14/2/2, spacing 10, radius 6, highlight `#1F1F1F`;
  - label Inter 14 `#8F8F8F`; shortcut Inter 14 `#6B6B6B`, right-aligned;
  - divider 1 px `#222222`;
  - icon 24; check `#D37918`; minimum width 265.
- **Shortcut text** is written with spaces around `+`: "Ctrl + O".
- **Mnemonics** are never underlined.
- **Labels follow the frames exactly** (no "…" endings), e.g. "Open File(s)", "Quit VLC", "Properties & Metadata".
- **The shortcut column shows the key VLC actually binds** (`src/libvlc-module.c`, non-Apple block): Space, S, P, N, Shift + R, Ctrl + Q. Never a key VLC doesn't bind.
- **Visual checks run on Wayland** (`dbus-run-session -- docs/superpowers/scripts/wl-drive.py`). Xvfb has no compositor: translucent menus show black corners there. Xvfb (`vlc-xvfb.sh`) is still fine for "does the entry do the thing".
- **Silent runs:** `--aout=dummy` (both drivers already pass it). Clear `RecoveryFilePath=` from `build/redesign-profile/config/vlc/vlc-qt-interface.conf` before each run (memory `redesign-harness`).
- **Git:**
  - branch `redesign/menus` from `master`;
  - commits as the global git user (ming), no Co-Authored-By;
  - the spec and this plan go in the first commit.
- **After each task:**
  - `ninja -C build`;
  - `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt` all OK;
  - after any app run, `grep -E 'TypeError|ReferenceError|non-existent property' <run dir>/vlc.log` finds nothing new (start with `-vv`, or the grep is vacuous).
- **New files:**
  - C++ sources go in `modules/gui/qt/meson.build` and `Makefile.am`;
  - SVGs go in `assets.qrc`, `Makefile.am` and the meson resource list;
  - QML files also go in `po/POTFILES.in`.

## Review Focus

1. **A menu opened at the screen's bottom-right corner** (right-click at 1590,890 in a 1600×900 window). The card is fully visible and the shadow margin doesn't push it off-screen; Qt flips it above or left of the cursor. Task 1, Step 6.
2. **Interface scale 1.5** (Settings ▸ Interface ▸ scale): rows are 72 high, icons 36, and text stays vertically centred. Task 1, Step 1 (`rowHeightScales`).
3. **Labels with a literal ampersand** (a recent media "Tom & Jerry" in Open Recent, a playlist "Rock & Roll"): the `&` shows and no letter is underlined. Task 1, Step 1 (`labelText`).
4. **Two library items selected (Ctrl+click), then right-click.**
   - Play, Add to Queue and Add to Playlist act on both.
   - Mark as Watched, Favorite, Stream, Convert, Show in File Explorer, Go to Source, Add Subtitle/Audio Tracks and Properties are hidden.
   - Task 5, Step 6.
5. **A subtitle attached with Add Subtitle Tracks, then the media played from a Home card, from Recent, and from a Videos folder page:** the subtitle is in the Subtitle track list each time. All three go through `MediaToInputItem`. Task 6, Step 6.

---

### Task 1: MenuStyle draws every QMenu the Figma way

**Files:**
- Create: `modules/gui/qt/style/menustyle.hpp`, `modules/gui/qt/style/menustyle.cpp`, `modules/gui/qt/tests/test_menu_style.cpp`
- Modify:
  - `modules/gui/qt/qt.cpp` (install after the saved `MainWindow/QtStyle` is applied, ~line 1472);
  - `modules/gui/qt/dialogs/preferences/simple_preferences.cpp:1356` (re-wrap after a style change);
  - `modules/gui/qt/maininterface/mainctx.cpp` (feed the scale factor);
  - `meson.build` (sources and a `test_qt_menu_style` entry, modelled on `test_qt_waveform_util`), `Makefile.am`;
  - `docs/superpowers/scripts/wl-drive.py` (`rclick:X,Y`).

**Interfaces:**
- Produces:
  - `class MenuStyle : public QProxyStyle` with `explicit MenuStyle(QStyle* base = nullptr)` and `static void setScale(qreal)` (default 1.0);
  - `static void MenuStyle::install()`: wraps `QApplication::style()` unless it is already a `MenuStyle`;
  - free functions `QString menuShortcutText(const QKeySequence&)` and `QString menuLabelText(const QString&)`;
  - the action property `"vlc-chevron"` (bool): draw a chevron on a non-submenu action.
- Later tasks set icons with `QIcon(":/redesign/menu/<name>.svg")` (Task 2) and rely on `install()` having run.

- [ ] **Step 1: Write the failing tests** in `tests/test_menu_style.cpp` (`QTEST_MAIN`, widgets).
  - `shortcutText`:
    - `menuShortcutText(QKeySequence("Ctrl+O")) == "Ctrl + O"`;
    - `"Ctrl+Shift+O"` → `"Ctrl + Shift + O"`;
    - `"Shift+F1"` → `"Shift + F1"`;
    - `QKeySequence(Qt::CTRL | Qt::Key_Plus)` → `"Ctrl + +"`;
    - `"Space"` → `"Space"`.
  - `labelText`:
    - `menuLabelText("Open &File(s)") == "Open File(s)"`;
    - `"Tom && Jerry"` → `"Tom & Jerry"`;
    - `"Rock && &Roll"` → `"Rock & Roll"`.
  - `rowHeight`:
    - a `QMenu` with `setStyle(new MenuStyle)`, an action "A" and a separator, after `adjustSize()`;
    - `actionGeometry(a).height() == 48`;
    - separator geometry height `== 1`;
    - `menu.width() >= 265 + 2 * shadowMargin`, where the shadow margin is a public `MenuStyle::shadowMargin()` returning the scaled margin.
  - `rowHeightScales`: after `MenuStyle::setScale(1.5)`, the action height is `72`; reset to 1.0 at the end.
- [ ] **Step 2: Run** `meson test -C build test_qt_menu_style`. Expected: FAIL (no `menustyle.hpp`).
- [ ] **Step 3: Implement `MenuStyle`.**
  - Override `polish(QWidget*)` / `unpolish(QWidget*)` (for a `QMenu`: `WA_TranslucentBackground`, `FramelessWindowHint | NoDropShadowWindowHint`, and contents margins = shadow margin).
  - Override `drawPrimitive(PE_PanelMenu / PE_FrameMenu)` (card and shadow) and `drawControl(CE_MenuItem)` (row, icon, label via `menuLabelText`, shortcut via `menuShortcutText`, chevron, check, divider).
  - Override `sizeFromContents(CT_MenuItem)`, `pixelMetric(PM_MenuPanelWidth, PM_MenuHMargin, PM_MenuVMargin, PM_SmallIconSize for menus)` and `styleHint(SH_UnderlineShortcut → 0, SH_Menu_* as needed)`.
  - **Popup position:** keep the card at the requested point. In an event filter on the menu's `QEvent::Show`, move by `-shadowMargin` horizontally and `-(shadowMargin - yOffset)` vertically. Don't move it if that would put the card off the screen's available geometry.
  - **Checks:** checked checkable/radio items draw `checkmark.svg` (Task 2), or until then the `VLCIcons` checkmark glyph, in `#D37918` in the icon slot.
  - **Chevron:** a 24 px chevron-right (`VLCIcons.chevron_right` glyph, or Task 2's `chevron-right.svg`) in `#8F8F8F`, at the row's right.
  - **Colours:** dark only, with `// ponytail: dark values only; read the palette's lightness in slice 10 (light theme)`.
  - `MenuStyle::install()` is called in `qt.cpp` after the saved style block and in `simple_preferences.cpp` after `QApplication::setStyle(style)`.
  - `MainCtx` calls `MenuStyle::setScale(m_intfScaleFactor)` wherever it updates the factor.
- [ ] **Step 4: Run the test.** Expected: PASS. Then `ninja -C build` and the qt suite.
- [ ] **Step 5: Add `rclick:X,Y` to `wl-drive.py`.** Same as `click` with `BTN_RIGHT = 0x111`; add it to the docstring.
- [ ] **Step 6: Look at it.**
  - Run `wl-drive.py $OUT vlc: sleep:2 click:54,20 sleep:1 shot:main key:Escape rclick:1590,890 sleep:1 shot:corner` (the "…" button at 54,20 as in the Xvfb shots; adjust if the Wayland title bar differs).
  - `main.png`: the "…" menu (old entries, new look) has rounded corners, no black corners and 48 px rows.
  - `corner.png`: the menu is fully on-screen (Review Focus 1). If nothing opens at that point, right-click the video area of a playing file instead.
- [ ] **Step 7: Commit** `qt: draw native menus the redesign way` (with the spec and this plan on the branch's first commit, if not already there).

### Task 2: The two-tone menu icons

**Files:**
- Create: `modules/gui/qt/pixmaps/redesign/menu/*.svg`
- Modify: `modules/gui/qt/assets.qrc` (prefix so paths read `:/redesign/menu/<name>.svg`), `Makefile.am`, meson's resource list

**Interfaces:**
- Produces these files. Tasks 3–7 use exactly these names:
  - **"…" menu:** `open-file`, `open-folder`, `open-network`, `open-disc`, `open-capture`, `convert`, `open-recent`, `profile`, `keyboard`, `customize`, `settings`, `about`;
  - **right-click:** `play`, `pause`, `stop`, `previous`, `next`, `record`, `hide-ui`, `playback`, `video`, `audio`, `subtitles`, `more-settings`, `playlist`, `open-media`, `quit`;
  - **library:** `mark-watched`, `favorite`, `stream`, `add-to-queue`, `add-to-playlist`, `show-in-explorer`, `go-to-source`, `info`, `add`, `add-folder`, `resync`, `shuffle`, `export`;
  - **shared:** `checkmark`, `chevron-right`.

- [ ] **Step 1: Download.** `get_design_context` on each of the six frames (session: `create_session` on the file first). Each `Icon` instance's asset URL is in the returned constants; match each to its row by the row's text node.
  - Save each SVG **unchanged** under its name above. `play` is the right-click "Play" row (playback default variant). `playback` is the "Playback" row (selected variant).
  - `convert` and `add-to-queue` etc. come from whichever frame shows them; one file each.
- [ ] **Step 2: Pause.** No frame shows Pause. Look in the Figma icon set (page with component set `42:356`) for a two-tone `pause` in the same style.
  - If there is none, copy `play`'s colours onto two 1.5 px vertical strokes in `#AB6314` (x 9 and 15, y 7–17).
  - Note in the commit message which one it is.
- [ ] **Step 3: Check colours.** `grep -L 'AB6314\|D37918\|8F8F8F' modules/gui/qt/pixmaps/redesign/menu/*.svg` lists nothing (every icon uses the Figma colours), except `chevron-right` if its frame colour is the label grey.
- [ ] **Step 4: Register them** in `assets.qrc`, `Makefile.am` and meson. Rebuild. `strings build/modules/libqt_plugin.so | grep -c 'redesign/menu'` (or a QTest one-liner `QVERIFY(!QIcon(":/redesign/menu/play.svg").isNull())` added to `test_menu_style.cpp`) shows they are bundled.
- [ ] **Step 5: Use them in `MenuStyle`.** Switch the check and chevron to `checkmark.svg` / `chevron-right.svg`, tinted to `#D37918` / `#8F8F8F` only if the SVG isn't already that colour.
- [ ] **Step 6: Commit** `qt: two-tone menu icons from the redesign`.

### Task 3: The "…" menu and its Profile submenu

**Files:**
- Modify: `modules/gui/qt/menus/menus.cpp` (`VLCMenuBar::MainMenu`, ~line 241), `modules/gui/qt/dialogs/dialogs_provider.{hpp,cpp}`, `modules/gui/qt/dialogs/preferences/preferences.{hpp,cpp}`

**Interfaces:**
- Consumes Task 2's icons.
- Produces:
  - `void PrefsDialog::showSimplePanel(int sprefsIndex)`;
  - `void DialogsProvider::prefsDialog(int simplePanel)`: a slot overload that opens on that panel; `SPrefsHotkeys` for Keyboard Shortcuts.

- [ ] **Step 1: Rewrite `MainMenu`'s entries.** Use the spec's order, labels, icons and shortcuts (spec § The "…" menu): Open File(s) … About VLC, with one divider after Open Recent.
  - Keyboard Shortcuts and Customize Player get `setProperty("vlc-chevron", true)`.
  - Remove the top-level Quit.
  - Keep More ▸ (its content unchanged) last, below a divider.
- [ ] **Step 2: Profile submenu.** Read `ControlbarProfileModel` from `p_intf->p_mi->controlbarProfileModel()` (check the getter's name in `mainctx.hpp`).
  - The parent row's label is `qtr("Profile (%1)").arg(<selected profile's name>)`, with the `profile` icon.
  - The submenu has one checkable action per row, in an exclusive `QActionGroup`, checked on `selectedProfile()`; triggering sets `setSelectedProfile(row)`.
  - Then a divider, and "New" with the `add` icon → `DialogsProvider::showToolbarEditorDialog`.
- [ ] **Step 3: Keyboard Shortcuts → `prefsDialog(SPrefsHotkeys)`.** Implement `showSimplePanel` by selecting the row in `simple_tree` (the same path a click takes) after making sure the simple view is shown.
- [ ] **Step 4: Check on Wayland.**
  - Run `wl-drive.py $OUT vlc: sleep:2 click:54,20 sleep:1 shot:main move:<Profile row> sleep:1 shot:profiles`.
  - Compare with `docs/superpowers/figma/5/main_menu.png` / `profiles.png`: the same entries, order, icons and shortcuts. Profile reads e.g. "Profile (Default Style)".
  - On Xvfb, pick another profile: the control bar changes. Keyboard Shortcuts opens Preferences on Hotkeys.
- [ ] **Step 5: Commit** `qt: the redesign's "…" menu with control-bar profiles`.

### Task 4: The player right-click menu

**Files:**
- Modify: `modules/gui/qt/menus/menus.cpp` (`PopupMenu` ~line 807, `PopupMenuPlaylistEntries` ~638, `PopupMenuControlEntries` ~687, `PopupMenuStaticEntries` ~746)

**Interfaces:**
- Consumes Task 2's icons.
- Changes no signatures: `PopupMenu(qt_intf_t*, bool)` keeps serving `DialogsProvider::popupMenu` and `QmlAudioContextMenu`.

- [ ] **Step 1: Top block** (`PopupMenuPlaylistEntries`).
  - Entries: Play/Pause `Space`, Stop `S`, Previous Item `P`, Next Item `N`, Record `Shift + R`, with the `play`/`pause`, `stop`, `previous`, `next`, `record` icons.
  - Shortcuts are display-only (`QAction::setShortcut` with `Qt::WidgetShortcut` context or `setShortcutVisibleInContextMenu`, so the menu doesn't grab the keys).
  - Enabled rules stay as today. Then a divider.
- [ ] **Step 2: Hide UI.** One checkable "Hide UI" `Ctrl + H` with the `hide-ui` icon, bound like `ViewMenu`'s Minimal View (`MainCtx::setMinimalView`, checked from `isMinimalView()`). Then a divider.
- [ ] **Step 3: Track submenus.**
  - Playback ▸ (`playback`): `NavigMenu`, then a divider, then the speed submenu and the Jump/Go to time entries from `PopupMenuControlEntries`.
  - Video ▸ (`video`): the Fullscreen toggle first, then `VideoMenu`.
  - Audio ▸ (`audio`) and Subtitle ▸ (`subtitles`).
  - Keep today's "disable when empty" rules. With no input, the four still show, disabled (*my call*; today they're absent, the Figma shows them).
  - Then a divider.
- [ ] **Step 4: Bottom block.**
  - More Settings ▸ (`more-settings`): `ToolsMenu`, then a divider, then `ViewMenu`.
  - Playlist ▸ (`playlist`): Show/hide the play queue (`MainCtx` playlist visibility toggle), Shuffle, Repeat (checkable, from `PlaylistController`), Save play queue to file (`savePlayingToPlaylist`, `Ctrl + Y`), Clear (`PlaylistController::clear`). Use whichever of these exist; list the rest as not available in the Ledger.
  - Open Media ▸ (`open-media`): today's open list.
  - Quit VLC `Ctrl + Q` (`quit`).
  - The `b_isDialogProvider` branch keeps its Interface/Help extras.
- [ ] **Step 5: Check.**
  - On Wayland: play `build/redesign-media/chapters.mkv`, `rclick:800,400`, shot. Compare with `right_click.png`.
  - On Xvfb: each submenu opens; Hide UI toggles the minimal view; Quit VLC exits with status 0.
- [ ] **Step 6: Commit** `qt: the redesign's player right-click menu`.

### Task 5: Library file menu, with icons and dividers in native menus

**Files:**
- Modify:
  - `modules/gui/qt/menus/qml_menu_wrapper.{hpp,cpp}` (`StringListMenu::popup` ~line 73);
  - `modules/gui/qt/util/qml/NativeMenu.qml`, `modules/gui/qt/medialibrary/qml/MLContextMenu.qml`;
  - `modules/gui/qt/dialogs/dialogs_provider.{hpp,cpp}`;
  - `modules/gui/qt/medialibrary/qml/LibraryFolderPage.qml` and the other `MLContextMenu` hosts only if Go to Source needs a navigation hook;
  - `tests/test_menu_style.cpp` (or a new `tests/test_menu_rows.cpp`).

**Interfaces:**
- Produces:
  - `void addMenuRows(QMenu* menu, const QVariantList& rows, std::function<void(int)> onSelected)` (free function, `qml_menu_wrapper.hpp`). A row is a string, or a map `{ text, icon, separator, checked, enabled, shortcut, chevron }`. `icon` is a name from Task 2. `onSelected(i)` gets the row's index in `rows`, separators included (they never fire). `StringListMenu::popup` calls it.
  - `NativeMenu` `actions` entries take optional `icon` (string), `separator` (true → a divider row, no `action`), `checked`, `enabled`. `visible` works as today, including on separators.
  - `Q_INVOKABLE void DialogsProvider::streamMedia(const QUrl& url, bool stream)` → `streamingDialog({url}, stream)`.
  - `MLContextMenu` signal `goToSource(var mrl)`, handled by the host page, or a direct `History.push` if the browse path for a folder MRL already exists (*builder's choice, say which in the commit*).

- [ ] **Step 1: Write the failing test** `menuRows`. Pass `["A", {separator: true}, {text: "B", icon: "play", enabled: false}, {text: "Tom && Jerry"}]` to `addMenuRows` on a plain `QMenu` and assert:
  - 4 actions, `actions()[1]->isSeparator()`;
  - `actions()[2]` is disabled with a non-null icon;
  - triggering `actions()[3]` calls `onSelected(3)`;
  - triggering `actions()[0]` calls `onSelected(0)`.
- [ ] **Step 2: Run.** Expected: FAIL (no `addMenuRows`).
- [ ] **Step 3: Implement `addMenuRows`.** Route `StringListMenu::popup` through it. `NativeMenu.setData` builds the row list: strings stay strings; entries with `icon`/`separator`/`checked`/`enabled` become maps. `_effectiveActions` keeps the same indices as the rows.
- [ ] **Step 4: Run the test.** Expected: PASS.
- [ ] **Step 5: `MLContextMenu` entries** in the spec's order (§ File menu), each with its Task 2 icon:
  - Play; Mark as Watched / Mark as Unwatched (by `isNew`); Favorite / Remove from Favorites (by `isFavorite`);
  - Stream / Convert (`DialogsProvider.streamMedia(dataList[0].mrl, true|false)`);
  - Add to Queue; Add to Playlist;
  - Show in File Explorer (today's `openContainingFolder`); Go to Source;
  - Add Subtitle Tracks and Add Audio Tracks: **added in Task 6**, so leave a `// Task 6` placeholder comment only;
  - Properties & Metadata (today's Media Information).
  - Then a divider and the kept VLC entries: Play as audio, Play as album, Enqueue as album, the audio-/video-only playlist entry, Information, Delete, Delete File From System.
  - Single-item entries' `visible` require `dataList.length === 1`; the divider shows only if a kept entry below it does.
  - The `mrl` role: check that the models have it (4e's `sameMedia` used `mrl`); add it to the `getData` result if missing.
- [ ] **Step 6: Check on Xvfb** (the Videos folder page and a Home card).
  - Each entry does its thing: Stream/Convert open the streaming wizard with the file filled in; Go to Source lands on the folder page holding the file.
  - With two items selected (Ctrl+click), check Review Focus 4.
  - Then a Wayland shot next to `file_ctx.png`.
- [ ] **Step 7: Commit** `qt: the redesign's file context menu`.

### Task 6: Add Subtitle Tracks / Add Audio Tracks, and attached tracks play

**Files:**
- Modify: `modules/misc/medialibrary/entities.cpp` (`MediaToInputItem`, ~line 545), `test/modules/misc/medialibrary.c`, `modules/gui/qt/medialibrary/medialib.{hpp,cpp}`, `modules/gui/qt/medialibrary/qml/MLContextMenu.qml`

**Interfaces:**
- Produces `Q_INVOKABLE void MediaLib::addExternalTrack(const MLItemId& media, const QUrl& file, bool subtitle)` → `vlc_ml_media_add_external_mrl(ml, media.id, url, subtitle ? VLC_ML_FILE_TYPE_SUBTITLE : VLC_ML_FILE_TYPE_SOUNDTRACK)` on the ML thread (`runOnMLThread`, as the other `MediaLib` writers do).

- [ ] **Step 1: Write the failing test** in `test/modules/misc/medialibrary.c`, after the thumbnail test:
  - `vlc_ml_new_external_media(ml, MOCK_URL)`;
  - `vlc_ml_media_add_external_mrl(ml, media->i_id, "file:///tmp/vlc-test.srt", VLC_ML_FILE_TYPE_SUBTITLE) == VLC_SUCCESS`;
  - `input_item_t *item = vlc_ml_get_input_item(ml, media->i_id)`;
  - `assert(item->i_slaves == 1)`, `assert(item->pp_slaves[0]->i_type == SLAVE_TYPE_SPU)`, `assert(strcmp(item->pp_slaves[0]->psz_uri, "file:///tmp/vlc-test.srt") == 0)`.
  - Add a second case with `VLC_ML_FILE_TYPE_SOUNDTRACK` → `SLAVE_TYPE_GENERIC`.
- [ ] **Step 2: Run** `meson test -C build test_modules_misc_medialibrary`. Expected: FAIL on `i_slaves`.
- [ ] **Step 3: In `MediaToInputItem`,** for each of `media->files()` with type `Subtitles` → `SLAVE_TYPE_SPU`, or `Soundtrack` → `SLAVE_TYPE_GENERIC`:
  - `input_item_AddSlave(item, input_item_slave_New(mrl, type, SLAVE_PRIORITY_USER, false))`;
  - skip a file whose `mrl()` throws `DeviceRemoved`.
- [ ] **Step 4: Run the test.** Expected: PASS (and the earlier thumbnail case still passes).
- [ ] **Step 5: Menu entries.**
  - Add `MediaLib::addExternalTrack`.
  - In `MLContextMenu`, Add Subtitle Tracks (`subtitles` icon) and Add Audio Tracks (`audio` icon) go where Task 5 left the placeholder. Single item, local media only (`isLocal`).
  - The file picker is the Qt one through a new `DialogsProvider` invokable `QUrl pickFile(const QString& title, const QString& filter)`:
    - subtitle filter `EXTENSIONS_SUBTITLE`;
    - audio filter `EXTENSIONS_AUDIO` (from `vlc_interface.h` / `qt.hpp`, as the open dialog uses);
    - it starts in the media's folder.
- [ ] **Step 6: Check on Xvfb.**
  - Attach `build/redesign-media/*.srt` (or make one with `make-samples.sh`) to `chapters.mkv`.
  - Play it from a Home card, from Recent and from the Videos folder page. Each time the Subtitle track list has the attached track (Review Focus 5).
  - Then a Wayland shot of the whole file menu next to `file_ctx.png`.
- [ ] **Step 7: Commit** `medialibrary: play a media's attached subtitle and audio files` (the module and the test), then `qt: add subtitle and audio tracks from the library menu`.

### Task 7: Folder and playlist menus

**Files:**
- Create: `modules/gui/qt/medialibrary/m3u8.hpp` (header-only), `modules/gui/qt/tests/test_m3u8.cpp`
- Modify:
  - `modules/gui/qt/medialibrary/medialib.{hpp,cpp}`;
  - `modules/gui/qt/medialibrary/mlplaylistlistmodel.{hpp,cpp}` (favourite role and setter, if absent);
  - `modules/gui/qt/menus/qml_menu_wrapper.{hpp,cpp}` (`PlaylistListContextMenu::popup`, ~line 762);
  - `modules/gui/qt/medialibrary/qml/HomePage.qml` (folder `FigmaMenu`, ~line 409), `LibraryFolderPage.qml` (folder tiles/rows);
  - meson / `Makefile.am`.

**Interfaces:**
- Produces:
  - `QByteArray toM3u8(const QStringList& mrls)` returns `"#EXTM3U\n"` followed by each MRL plus `"\n"`, UTF-8.
  - `Q_INVOKABLE void MediaLib::reloadFolder(const QString& mrl)` → `vlc_ml_reload_folder`.
  - `Q_INVOKABLE void MLPlaylistListModel::setFavorite(const QModelIndex&, bool)` and role `PLAYLIST_IS_FAVORITE` (only if the model lacks them) → `VLC_ML_PLAYLIST_SET_FAVORITE`.
  - A folder menu: a `NativeMenu` named `FolderContextMenu.qml` in `medialibrary/qml/`, with `popup(folderMrl, globalPos, videoIds)`. Both hosts use it.

- [ ] **Step 1: Write the failing test** `test_qt_m3u8`:
  - `toM3u8({"file:///a/One.mkv", "file:///b/D%C3%A9j%C3%A0.mkv"}) == "#EXTM3U\nfile:///a/One.mkv\nfile:///b/D%C3%A9j%C3%A0.mkv\n"`;
  - `toM3u8({}) == "#EXTM3U\n"`.
- [ ] **Step 2: Run.** Expected: FAIL (no `m3u8.hpp`).
- [ ] **Step 3: Implement `toM3u8`** and register the test. Run it. Expected: PASS.
- [ ] **Step 4: Playlist menu.** Entries:
  - Play (`play`);
  - Favorite / Remove from Favorites (`favorite`);
  - Shuffle (`shuffle`: `addAndPlay`, then `THEMPL->shuffle()` once the queue holds the items, i.e. after the add returns on the ML thread);
  - Export Playlist (`export`: a `QFileDialog::getSaveFileName` with an `.m3u8` filter, the playlist's media MRLs fetched on the ML thread, `toM3u8`, write the file);
  - Add to Queue (`add-to-queue`);
  - a divider, then Rename and Delete (kept).
  - Single-item rules: Favorite, Export and Rename need exactly one playlist.
- [ ] **Step 5: Folder menu (`FolderContextMenu.qml`).** Entries:
  - Play all videos and Add all videos to the queue (4d, unchanged rules);
  - Add File (`add`) and Add Folder (`add-folder`): a file/folder picker opened in the folder; the results join the queue through `MediaLib.addToPlaylist(url)`;
  - Resync (`resync`) → `MediaLib.reloadFolder(mrl)`.
  - Home's folder `FigmaMenu` is replaced by it. `LibraryFolderPage` opens it for folder tiles/rows (`model.isFolder`) and keeps `MLContextMenu` for files.
- [ ] **Step 5b: A playlist's own tracks** (`PlaylistMediaContextMenu::popup`, `qml_menu_wrapper.cpp` ~line 813). Use the file menu's labels and icons for the entries it already has: Play, Add to Queue, Add to Playlist, Properties & Metadata (its media information entry). Keep its playlist-only entries (remove from the playlist, and so on) below a divider. Add no new actions here.
- [ ] **Step 6: Check on Xvfb.**
  - Export a two-item playlist and `cat` the file: `#EXTM3U` plus two lines.
  - Favorite toggles: the label flips on the next open.
  - Shuffle plays the playlist and the queue is shuffled.
  - Resync logs the ML discovery start for that folder.
  - Then Wayland shots next to `folder_ctx.png` / `playlist_ctx.png`.
- [ ] **Step 7: Commit** `qt: the redesign's folder and playlist context menus`.

### Task 8: Ledger, roadmap, merge

- [ ] **Step 1: After-shots.**
  - Wayland, 1600×900: `after_main.png`, `after_profiles.png`, `after_right_click.png`, `after_file_ctx.png`, `after_folder_ctx.png`, `after_playlist_ctx.png`.
  - Plus one QML `FigmaMenu` (the sort menu) next to a native one, to confirm the two renderers match: `after_sort_vs_native.png`.
  - All go in `docs/superpowers/figma/5/`.
- [ ] **Step 2: Ledger.** Fill `## Ledger` below: each shot against its frame, what matches, and each departure with its reason.
- [ ] **Step 3: Roadmap.** Mark row 5 done in `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md`, naming this plan and the main departures.
- [ ] **Step 4: Commit** `doc: record slice 5`. After the whole-branch review, fast-forward `master` and push.

## Ledger

Known before the build (spec *(my call)*s):
- The native menu style is dark only; light comes with slice 10.
- The "…" menu keeps More ▸ (Discover and the full VLC menus) and drops Quit.
- Keyboard Shortcuts opens Preferences ▸ Hotkeys; Customize Player opens today's editor. Both keep the Figma's chevron.
- Profile = VLC's control-bar profiles; Movies/Shows/Music/Work are read as placeholders. "New" opens Customize Player.
- Shortcut labels show VLC's real bindings: Record `Shift + R` (Figma R), Hide UI `Ctrl + H` (Figma Ctrl + \).
- Right-click Playback/Video/Audio/Subtitle show disabled with no input.
- File menu: Mark as Watched/Favorite flip their labels; VLC's extra entries stay below a divider; Go to Source = the item's library folder page.
- Folder menu: Edit Subtitle Tracks, Edit Audio Tracks and Info are not shown (no backend); Add File / Add Folder enqueue (VLC 3's playlist meaning); Resync = rescan; 4d's Play all / Add all stay on top; Home's folder menu becomes native.
- Playlist menu: Add Subtitle/Audio Tracks and Properties & Metadata are not shown; Export writes M3U8 only; Rename/Delete stay below a divider.
