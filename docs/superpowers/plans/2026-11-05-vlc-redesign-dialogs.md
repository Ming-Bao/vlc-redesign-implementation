# Dialogs (slice 8) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace VLC's stock dialogs with the Figma's Open Network Stream, New Playlist, Keyboard Shortcuts and Add Subtitles windows, and replace the Toolbar Editor with Customize Player, which edits the player's bars in place by drag and drop.

**Architecture:**
- **One shared card** (`DialogCard.qml`, extracted from `SettingsWindow.qml`) frames the four form dialogs as modal top-level windows, loaded from `Dialogs.qml` on `DialogsProvider` signals.
- **Thin C++ models** carry what QML can't do (`SavedStreams`, `HotkeyModel`, `AddSubtitlesController`, the pure `matchSubtitles`).
- **Customize Player** extends the existing profile system with two identifiers (`Topbar`, `SeekRow`) and new control ids, makes the player's title bar model-driven, and swaps the bars for the existing `EditorDNDView` while editing.

**Tech Stack:** Qt 6 QML (QtQuick, Templates, Window), C++ (libvlccore config and media library APIs), meson and Makefile.am, QtTest. Figma MCP for icons and per-control values (load `figma:figma-design-to-code` before `get_design_context`). `Qt6Network` in Task 13 only.

**Spec:** `docs/superpowers/specs/2026-11-05-vlc-redesign-dialogs-design.md`. Its tables hold the Figma values and copy; tasks don't repeat them.

## Global Constraints

- **Figma is the source of truth** (`dSoAm0gN9ZterHSssJU9FN`). Frames are in the spec's first table, shots in `docs/superpowers/figma/8/`. VLC 4's look is not a reference.
- **Every Figma px value is written `VLCStyle.dp(n, VLCStyle.scale)`.**
- **The accent is read through `theme.accent`**, never `#D37918` literally.
- **All strings go through `qsTr`/`qtr`.** Copy is the spec's, verbatim.
- **Silent runs:** the harness passes `--aout=dummy`; any hand-rolled run adds it too. Clear `RecoveryFilePath=` from `build/redesign-profile/config/vlc/vlc-qt-interface.conf` before each run.
- **Git:** branch `redesign/dialogs` (exists, holds the tray fix). Commits use the global git user, no Co-Authored-By.
- **After each task:**
  - `ninja -C build` builds;
  - `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt` is all OK;
  - after any app run, `grep -E 'TypeError|ReferenceError|non-existent property|unavailable|Cannot assign' build/redesign-profile/run/vlc.log` finds nothing new. Start with `docs/superpowers/scripts/vlc-xvfb.sh start -vv`, otherwise the log is near empty and the grep passes vacuously.
- **New files:**
  - QML and C++ files go in `modules/gui/qt/meson.build`, `Makefile.am` and `po/POTFILES.in`; QML in the `VLC.Dialogs` list (controls in the `VLC.PlayerControls` list).
  - SVGs and fonts go in `assets.qrc`, `Makefile.am` and the meson resource list.
- **Legacy fallback:** each `DialogsProvider` entry that now emits a signal checks `isSignalConnected` and falls back to the legacy dialog when nothing listens, as `prefsDialog()` does since slice 7.
- **Merge points:** the branch is mergeable after Tasks 3, 5, 7 and 12. Task 13 shipped on the user's go-ahead of 2026-11-05.

## Review Focus

1. **A saved stream name with `/`, `..`, leading dots or only symbols:** the file stays inside `network-playlists/` and the title shows as typed. Test in Task 2.
2. **Binding Escape or Delete in Keyboard Shortcuts:** the key is captured, and the dialog neither closes nor clears. Test in Task 5, Step 5.
3. **Add Subtitles on a folder with no subtitles, a read-only folder, or 500 media:** rows show None, Save stays off, and the window doesn't freeze while scanning. Task 7, Step 6.
4. **Dragging "…" and every other control off the player:** Customize Player is still reachable from the right-click menu; Cancel restores the bars exactly. Task 11, Step 7.
5. **Customize Player in a 600 × 420 window or at `VLCStyle.scale` 2:** the card fits above the bars and the palette scrolls. Task 11, Step 7.

---

### Task 1: Shared DialogCard and a drag step for the harness

**Files:**
- Create: `modules/gui/qt/dialogs/dialogs/qml/DialogCard.qml`
- Modify: `modules/gui/qt/dialogs/settings/qml/SettingsWindow.qml`, `docs/superpowers/scripts/wl-drive.py`

**Interfaces:**
- Produces: `DialogCard` (a `Window`): `title: string`, `cardColor: color` (default `#191919` at 95 %), `figmaWidth`, `figmaHeight: real`, `showFooter: bool`, `saveEnabled: bool`, `saveText: string` (default `qsTr("Save")`), `footerNote: string`, `default property alias content`, `headerExtra: Component`; signals `saved()`, `cancelled()`; `function ask(text, yesCb)`. Modal when `modal: true`.
- Produces: `wl-drive.py` step `drag:X1,Y1,X2,Y2`.

- [ ] **Step 1: Commit the spec, the plan and the Figma shots**

```bash
git add docs/superpowers/specs/2026-11-05-vlc-redesign-dialogs-design.md docs/superpowers/plans/2026-11-05-vlc-redesign-dialogs.md docs/superpowers/figma/8
git commit -m "docs: dialogs spec, plan and Figma shots"
```

- [ ] **Step 2: Move the window code out of `SettingsWindow.qml` into `DialogCard.qml`**

Move the frameless flags, `transientParent`, shadow margin, `_place()`, the title-bar `startSystemMove` and `ask()`. Add the title bar and footer per the spec's Shared window values. Settings keeps its own top bar through `showFooter: false` and `headerExtra`, and its existing `onClosing` save. Escape and × emit `cancelled()`; Enter emits `saved()` when `saveEnabled` and the focus item isn't multi-line.

- [ ] **Step 3: Add the `drag` step to `wl-drive.py`**

Motion to X1,Y1, button down, 10 stepped motions to X2,Y2 with `pump(0.05)` between them, button up, `pump(0.3)`. Document it in the docstring.

- [ ] **Step 4: Verify Settings is unchanged and now drags**

Run: `dbus-run-session -- docs/superpowers/scripts/wl-drive.py build/redesign-shots/d1 vlc: click:<"…"> click:<Settings> sleep:2 shot:before drag:800,70,600,170 sleep:1 shot:after exit:1`, with the coordinates read from a first shot (`key:` doesn't deliver Ctrl to VLC; memory `redesign-harness`).
Expected: `before` matches `docs/superpowers/figma/7/general-999-5047.png`; in `after` the window moved by 200,100.

- [ ] **Step 5: Commit**

```bash
git add modules/gui/qt docs/superpowers/scripts/wl-drive.py
git commit -m "qt: shared DialogCard, wl-drive drag step"
```

### Task 2: Open Network Stream

**Files:**
- Create: `modules/gui/qt/dialogs/network/saved_streams.{hpp,cpp}`, `modules/gui/qt/dialogs/network/qml/NetworkStreamDialog.qml`, `modules/gui/qt/tests/test_saved_streams.cpp`
- Modify: `dialogs/dialogs_provider.{hpp,cpp}` (`openNetDialog`), `dialogs/dialogs/qml/Dialogs.qml`, `maininterface/mainui.cpp`, `network/qml/NetworkHomeDisplay.qml`

**Interfaces:**
- Consumes: `DialogCard` from Task 1.
- Produces: signal `DialogsProvider::showNetworkStreamDialog()`.
- Produces: `SavedStreams` (QML singleton in `VLC.Dialogs`):
  - `explicit SavedStreams(const QString& dir, QObject* parent = nullptr)`; the app passes `<userdata>/network-playlists`;
  - `Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)`, each `{ name, mrl, path }`, where `mrl` is the single URL or else the file;
  - `Q_INVOKABLE static QStringList parseLinks(const QString& text)`;
  - `Q_INVOKABLE static QString safeFileName(const QString& name)`;
  - `Q_INVOKABLE bool exists(const QString& name) const`;
  - `Q_INVOKABLE QVariantMap save(const QString& name, const QStringList& links)`, an empty map on failure;
  - `Q_INVOKABLE bool remove(const QString& path)`.

- [ ] **Step 1: Write the failing test `tests/test_saved_streams.cpp`**

```cpp
void parseLinks_cases() {
    QCOMPARE(SavedStreams::parseLinks("\n a.com/x \n\nhttps://b/y\n"),
             (QStringList{"http://a.com/x", "https://b/y"}));
    QCOMPARE(SavedStreams::parseLinks("  \n"), QStringList{});
}
void safeFileName_staysInside() {
    QCOMPARE(SavedStreams::safeFileName("Fav/TV"), QString("Fav_TV"));
    QVERIFY(!SavedStreams::safeFileName("../../x").contains('/'));
    QVERIFY(!SavedStreams::safeFileName("..").startsWith('.'));
    QVERIFY(!SavedStreams::safeFileName("///").isEmpty());
}
void save_roundTrip() {
    QTemporaryDir dir; SavedStreams s(dir.path());
    auto one = s.save("Fav/TV", {"http://a/x"});
    QCOMPARE(one["name"].toString(), QString("Fav/TV"));          // title as typed
    QCOMPARE(one["mrl"].toString(), QString("http://a/x"));       // single URL browses the URL
    auto two = s.save("Two", {"http://a/x", "http://b/y"});
    QVERIFY(two["mrl"].toString().endsWith("Two.m3u8"));
    QCOMPARE(s.entries().size(), 2);
    QVERIFY(s.exists("Two"));
    SavedStreams again(dir.path());                                // read back from disk
    QCOMPARE(again.entries().size(), 2);
    QVERIFY(again.remove(two["path"].toString()));
    QCOMPARE(again.entries().size(), 1);
}
```

Register `test_qt_saved_streams` beside `test_settings_bridge` in `meson.build`.

- [ ] **Step 2: Run it to verify it fails**

Run: `meson test -C build test_qt_saved_streams`
Expected: FAIL, `saved_streams.hpp` not found.

- [ ] **Step 3: Implement `SavedStreams`**

Write with `QSaveFile`: `#EXTM3U`, `#PLAYLIST:<name>`, one URL per line. Read back by parsing those lines. `safeFileName` replaces anything outside letters, digits, space, `-`, `_` with `_`, and falls back to `stream` when empty. `exists` compares safe file names, so `Fav/TV` and `Fav_TV` count as the same.

- [ ] **Step 4: Run the test to verify it passes**

Run: `meson test -C build test_qt_saved_streams`
Expected: OK.

- [ ] **Step 5: Build `NetworkStreamDialog.qml` and route `openNetDialog()`**

Layout and copy from the spec's table. Button text: `saveText: nameField.text.trim() ? qsTr("Save") : qsTr("Open")`. Save enabled when `parseLinks` isn't empty.
- With a name: confirm through `ask` if `exists(name)`, `save()`, then `History.push(["network","browse"], { tree: MainCtx.folderTree(entry.mrl) })`.
- Without a name: `MediaLib.addAndPlay` the first and `addToPlaylist` the rest, or the playlist controller when the library is absent.

- [ ] **Step 6: Add the tiles to `NetworkHomeDisplay`**

Concatenate `SavedStreams.entries` into `tiles` after Radio with `{ glyph: VLCIcons.topbar_network, text: name, stream: entry }`. Activating opens the `folderTree`. The tile's context menu has Delete, calling `remove`.

- [ ] **Step 7: Verify end to end**

Serve a sample: `python3 -m http.server 8765 --directory build/redesign-media` with an `index.m3u` of three samples. In the app: paste `http://127.0.0.1:8765/index.m3u`, name "Index", Save.
Expected: the page reads Network ▸ Index with 3 rows, as the video shows at 13:18. Network's root has an Index tile. Empty name plays the first link. Shot matches `open-network-6216-13614.png`.

- [ ] **Step 8: Commit**

```bash
git add modules/gui/qt
git commit -m "qt: Open Network Stream dialog with saved streams on the Network page"
```

### Task 3: New Playlist

**Files:**
- Create: `modules/gui/qt/dialogs/playlists/playlist_cover.{hpp,cpp}`, `modules/gui/qt/dialogs/playlists/qml/NewPlaylistDialog.qml`, `modules/gui/qt/tests/test_playlist_cover.cpp`
- Modify: `dialogs/dialogs_provider.{hpp,cpp}` (`newPlaylist`, new `pickImage`), `dialogs/dialogs/qml/Dialogs.qml`, `medialibrary/mlplaylistlistmodel.{hpp,cpp}`, `maininterface/qml/LibraryAddMenu.qml`

**Interfaces:**
- Consumes: `DialogCard`.
- Produces: `DialogsProvider::newPlaylist()` returns `void` and emits `showNewPlaylistDialog()`; signal `DialogsProvider::playlistCreated()`; `Q_INVOKABLE QUrl DialogsProvider::pickImage(const QString& title)`.
- Produces, in `playlist_cover.hpp`:
  - `QString coverDir()` returns `<userdata>/playlist-covers`;
  - `QString customCoverPath(const QString& dir, int64_t playlistId)`, empty when there is none;
  - `bool storeCustomCover(const QString& dir, int64_t playlistId, const QUrl& image)`, which replaces any earlier cover of that id;
  - `void removeCustomCover(const QString& dir, int64_t playlistId)`.
- Produces: `Q_INVOKABLE void MLPlaylistListModel::createFromFiles(const QString& name, const QList<QUrl>& files, const QUrl& cover)`.

- [ ] **Step 1: Write the failing test `tests/test_playlist_cover.cpp`**

```cpp
void cover_lifecycle() {
    QTemporaryDir dir, src;
    const QString png = src.filePath("c.png");
    QImage(4, 4, QImage::Format_RGB32).save(png);
    QCOMPARE(customCoverPath(dir.path(), 7), QString{});
    QVERIFY(storeCustomCover(dir.path(), 7, QUrl::fromLocalFile(png)));
    QVERIFY(customCoverPath(dir.path(), 7).endsWith("/7.png"));
    QVERIFY(QFile::exists(png));                                   // the source is copied, not moved
    const QString jpg = src.filePath("c.jpg");
    QImage(4, 4, QImage::Format_RGB32).save(jpg);
    QVERIFY(storeCustomCover(dir.path(), 7, QUrl::fromLocalFile(jpg)));
    QVERIFY(customCoverPath(dir.path(), 7).endsWith("/7.jpg"));    // no stale png wins
    QCOMPARE(customCoverPath(dir.path(), 70), QString{});          // 70 isn't 7
    removeCustomCover(dir.path(), 7);
    QCOMPARE(customCoverPath(dir.path(), 7), QString{});
    QVERIFY(!storeCustomCover(dir.path(), 8, QUrl::fromLocalFile(src.filePath("missing.png"))));
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `meson test -C build test_qt_playlist_cover`
Expected: FAIL, `playlist_cover.hpp` not found.

- [ ] **Step 3: Implement the cover functions and use them in the model**

Copy through a temp file and rename. `MLPlaylistListModel::getCover` returns the file URL when `customCoverPath` isn't empty. `deletePlaylists` removes covers. `createFromFiles` runs on the ML thread: `vlc_ml_get_media_by_mrl`, else `vlc_ml_new_external_media`, then the same path as `create()`, then stores the cover under the new id and emits `DialogsProvider::playlistCreated` on the UI thread.

- [ ] **Step 4: Run the test to verify it passes**

Run: `meson test -C build test_qt_playlist_cover`
Expected: OK.

- [ ] **Step 5: Build `NewPlaylistDialog.qml` and route `newPlaylist()`**

Layout and copy from the spec's table. Cover well: `DialogsProvider.pickImage`. Drop box: `DropArea` for files, and a click or the + button calls `DialogsProvider.pickMedia`. Dropped folders are read one level deep with VLC's media extensions. Once filled, rows with a × replace the hint. Switch `LibraryAddMenu` from the `bool` return to `playlistCreated()`. Remove the `QInputDialog` code.

- [ ] **Step 6: Verify end to end**

Run the app and create "Fav Episodes" with a cover and two files from `build/redesign-media`.
Expected: it appears on Playlists with that cover and a count of 2. Delete it and `playlist-covers/` has no file left. Empty-state shot matches `new-playlist-6259-14954.png`.

- [ ] **Step 7: Commit**

```bash
git add modules/gui/qt
git commit -m "qt: New Playlist dialog with files and a custom cover"
```

### Task 4: Hotkey model and data

**Files:**
- Create: `modules/gui/qt/dialogs/hotkeys/hotkey_model.{hpp,cpp}`, `modules/gui/qt/dialogs/hotkeys/qml/HotkeysData.js`, `modules/gui/qt/tests/test_hotkey_model.cpp`, `modules/gui/qt/tests/tst_HotkeysData.qml`
- Modify: `docs/superpowers/scripts/check-settings-options.py`

**Interfaces:**
- Produces: `struct HotkeyRow { QString option, globalOption, label, longText, keys, globalKeys; }`.
- Produces: `HotkeyModel : QAbstractListModel`, roles `option`, `label`, `longText`, `keys`, `globalKeys`:
  - `explicit HotkeyModel(QObject* parent = nullptr)` loads from `module_get_main()`; `HotkeyModel(QVector<HotkeyRow>, QObject*)` for tests;
  - `Q_PROPERTY(bool dirty READ dirty NOTIFY dirtyChanged)`;
  - `Q_INVOKABLE int rowOf(const QString& option) const`;
  - `Q_INVOKABLE QString conflict(const QString& key, int row, bool global) const`, the other row's label or empty;
  - `Q_INVOKABLE void assign(int row, bool global, const QString& key)`, which replaces the cell and removes `key` from every other row in that column;
  - `Q_INVOKABLE void clear(int row, bool global)`;
  - `Q_INVOKABLE QString keyFromEvent(int qtKey, int modifiers, const QString& text) const`, through `qtEventToVLCKey`;
  - `Q_INVOKABLE static QString displayKeys(const QString& keys)`;
  - `Q_INVOKABLE void save()`, which writes changed cells with `config_PutPsz` and then `config_SaveConfigFile`.
- Produces: `HotkeysData.js`: `sections` (`[{ title, rows: [{ option, label? }] }]`), `filter(sections, labelOf, keysOf, text, field)` with `field` one of `"all"`, `"action"`, `"hotkey"`, `"global"`.

- [ ] **Step 1: Write the failing tests**

```cpp
void assign_movesAKey() {
    HotkeyModel m({{"key-a","global-key-a","A","","x",""},{"key-b","global-key-b","B","","y\tz",""}});
    QCOMPARE(m.conflict("y", 0, false), QString("B"));
    QCOMPARE(m.conflict("y", 1, false), QString{});
    QCOMPARE(m.conflict("q", 0, false), QString{});
    m.assign(0, false, "y");
    QCOMPARE(m.data(m.index(0), HotkeyModel::KeysRole).toString(), QString("y"));
    QCOMPARE(m.data(m.index(1), HotkeyModel::KeysRole).toString(), QString("z"));   // the other key stays
    QVERIFY(m.dirty());
}
void columnsAreIndependent() {
    HotkeyModel m({{"key-a","global-key-a","A","","x",""},{"key-b","global-key-b","B","","",""}});
    QCOMPARE(m.conflict("x", 1, true), QString{});
    m.assign(1, true, "x");
    QCOMPARE(m.data(m.index(0), HotkeyModel::KeysRole).toString(), QString("x"));
}
void clear_and_display() {
    HotkeyModel m({{"key-a","global-key-a","A","","x",""}});
    m.clear(0, false);
    QCOMPARE(m.data(m.index(0), HotkeyModel::KeysRole).toString(), QString{});
    QCOMPARE(HotkeyModel::displayKeys("Esc\tq"), QString("esc, q"));
}
```

`tst_HotkeysData.qml`, registered in `qml_tests` in `meson.build`: the first section title is `Basic`, the second `Playback`; `sections[0].rows[0].label === "Toggle fullscreen"`; `filter` with `"esc"` and `"hotkey"` keeps only rows whose keys match; with `"action"` it doesn't match keys; regex characters (`"("`) don't throw.

- [ ] **Step 2: Run them to verify they fail**

Run: `meson test -C build test_qt_hotkey_model`
Expected: FAIL, `hotkey_model.hpp` not found.

- [ ] **Step 3: Implement `HotkeyModel` and `HotkeysData.js`**

Load exactly as `KeySelectorControl::finish` (`preferences_widgets.cpp:1353`): `CONFIG_ITEM_KEY` items, pairing `global-` ones by name. Fill `sections` from the spec's table with its nine labels. Options the build lacks are skipped when drawing, through `rowOf === -1`.

- [ ] **Step 4: Extend `check-settings-options.py`**

Read the `key-*` names from `add_key(` in `src/libvlc-module.c` and every `option:` in `HotkeysData.js`. Fail unless each appears exactly once.

- [ ] **Step 5: Run the checks to verify they pass**

Run: `meson test -C build --suite qt && python3 docs/superpowers/scripts/check-settings-options.py`
Expected: all OK, and the script reports no missing or duplicate keys.

- [ ] **Step 6: Commit**

```bash
git add modules/gui/qt docs/superpowers/scripts/check-settings-options.py
git commit -m "qt: hotkey model and shortcut sections"
```

### Task 5: Keyboard Shortcuts dialog

**Files:**
- Create: `modules/gui/qt/dialogs/hotkeys/qml/HotkeysDialog.qml`, `modules/gui/qt/pixmaps/redesign/dialogs/pencil.svg`, `modules/gui/qt/fonts/DMMono-Regular.ttf` plus its OFL text
- Modify: `dialogs/dialogs_provider.hpp`, `dialogs/dialogs/qml/Dialogs.qml`, `menus/menus.cpp:305`, `dialogs/settings/qml/SettingsRowDelegate.qml:168`, `maininterface/mainui.cpp`

**Interfaces:**
- Consumes: `HotkeyModel`, `HotkeysData` from Task 4; `DialogCard`.
- Produces: signal `DialogsProvider::showHotkeysDialog()`.

- [ ] **Step 1: Bundle DM Mono**

Download Regular from the Google Fonts repository (`ofl/dmmono`) with its `OFL.txt`, and register it the way the UI font is (`test_ui_font`). Offline, fall back to `font.styleHint: Font.Monospace` and record it in the Ledger.

- [ ] **Step 2: Build `HotkeysDialog.qml`**

Values from the spec's table. A `ListView` of section heads and rows with a section filter from `HotkeysData.filter`. The field dropdown uses `SettingCombo`. The pencil comes from Figma `2437:14832`. `footerNote: qsTr("Changes apply the next time VLC starts.")`.

- [ ] **Step 3: Implement capture in the key cell**

The focused cell has a `capturing` state. `Keys.onPressed` calls `model.keyFromEvent(event.key, event.modifiers, event.text)` and accepts the event. It ignores bare modifier presses. On a non-empty `conflict`, `ask(qsTr("%1 is already used by %2. Reassign it?"))`, then `assign`. Not capturing, Delete on a focused cell calls `clear`. Losing focus leaves capture without a change.

- [ ] **Step 4: Route the entry points**

`menus.cpp:305` emits `showHotkeysDialog`. `SettingsRowDelegate`'s `editHotkeys` does too. Save calls `model.save()` and closes; Cancel closes without saving.

- [ ] **Step 5: Verify, including Escape**

Run on Xvfb with `vlc-xvfb.sh start -vv`:
- bind Toggle fullscreen to `g`, Save, and check `key-toggle-fullscreen=g` in `build/redesign-profile/config/vlc/vlcrc`;
- capture on Exit fullscreen, press Escape: the cell shows `esc` and the dialog stays open;
- bind Stop to `g`: the reassign question appears, and Yes clears Toggle fullscreen;
- Cancel leaves `vlcrc` unchanged.

Expected: all four, and the shot matches `shortcuts-2437-14832.png`.

- [ ] **Step 6: Commit**

```bash
git add modules/gui/qt
git commit -m "qt: Keyboard Shortcuts dialog replaces the hotkeys panel paths"
```

### Task 6: Subtitle matching and the Add Subtitles controller

**Files:**
- Create: `modules/gui/qt/dialogs/subtitles/subtitle_matching.{hpp,cpp}`, `modules/gui/qt/dialogs/subtitles/add_subtitles_controller.{hpp,cpp}`, `modules/gui/qt/tests/test_subtitle_matching.cpp`
- Modify: `maininterface/mainui.cpp`

**Interfaces:**
- Produces: `QVector<int> matchSubtitles(const QStringList& mediaNames, const QStringList& subtitleNames)`.
- Produces: `AddSubtitlesController : QObject`, a QML type in `VLC.Dialogs`:
  - `enum Target { File, Folder, Playlist }`, `enum Origin { Computer, OpenSubtitles, Link }`;
  - properties `target`, `origin`, `QString location`, `QString link`, `QVariantList mediaItems` (`{ name, mrl, id }`), `QStringList candidates`, `QVector<int> pairs`, `QVector<int> ticked`, `bool canSave`, `bool busy`;
  - `Q_INVOKABLE void setContext(const QVariantMap& context)`, with keys `target` (`"file"|"folder"|"playlist"`), `mlId`, `mrl`, `folder`, `playlistId`;
  - `Q_INVOKABLE void setFolder(const QUrl& folder)`;
  - `Q_INVOKABLE void setPair(int mediaRow, int candidate)` (`-1` = None); `Q_INVOKABLE void toggle(int candidate)`;
  - `Q_INVOKABLE void save()`; signal `finished(int attached, int failed)`.

- [ ] **Step 1: Write the failing test**

```cpp
void matchSubtitles_cases() {
    const QStringList media{"The_Wand_S01E01.mp4", "The_Wand_S01E02.mp4", "Other.mkv"};
    // normalised stems, as in the video
    QCOMPARE(matchSubtitles(media, {"thewand_s01e02.srt", "thewand_s01e01.srt"}), (QVector<int>{1, 0, -1}));
    // subtitle stem extends the media stem
    QCOMPARE(matchSubtitles({"The_Wand_S01E01.mp4"}, {"The_Wand_S01E01_English.srt"}), QVector<int>{0});
    // SxxEyy token, any padding
    QCOMPARE(matchSubtitles({"Show.S01E02.1080p.mkv"}, {"s1e2.ass"}), QVector<int>{0});
    // each subtitle is used once; an exact match beats an earlier prefix match
    QCOMPARE(matchSubtitles({"a.mp4", "a2.mp4"}, {"a2.srt"}), (QVector<int>{-1, 0}));
    // no candidates
    QCOMPARE(matchSubtitles({"a.mp4"}, {}), QVector<int>{-1});
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `meson test -C build test_qt_subtitle_matching`
Expected: FAIL, `subtitle_matching.hpp` not found.

- [ ] **Step 3: Implement `matchSubtitles`**

Three passes in the spec's order, marking used subtitles, so an exact match anywhere wins before prefix or token matches.

- [ ] **Step 4: Run it to verify it passes**

Run: `meson test -C build test_qt_subtitle_matching`
Expected: OK.

- [ ] **Step 5: Implement `AddSubtitlesController`**

Media lists (`vlc_ml_list_folder_media`, `vlc_ml_list_playlist_media`) and the directory scan run on the ML thread (`runOnMLThread<Ctx>`), with `busy` true meanwhile. `save()` uses `MediaLib::addExternalTrack` for items with an id. Items without one, and the playing media, also go through `PlayerController::AddAssociatedMedia(SPU_ES, uri, true, true, false)`. Subtitle extensions come from `EXTENSIONS_SUBTITLE`. `canSave` is true when a pair, tick or valid link exists.

- [ ] **Step 6: Commit**

```bash
git add modules/gui/qt
git commit -m "qt: subtitle matching and Add Subtitles controller"
```

### Task 7: Add Subtitles dialog

**Files:**
- Create: `modules/gui/qt/dialogs/subtitles/qml/AddSubtitlesDialog.qml`, `modules/gui/qt/pixmaps/redesign/dialogs/{swap,subtitle-file,media-file}.svg`
- Modify: `dialogs/dialogs_provider.{hpp,cpp}`, `dialogs/dialogs/qml/Dialogs.qml`, `medialibrary/qml/MLContextMenu.qml:252`, `medialibrary/qml/FolderContextMenu.qml` (Figma `2139:8935`), the playlist menu from slice 5 (Figma `2459:9389`), `player/qml/TracksListPage.qml:264`, `player/qml/TracksPanel.qml:71`, `menus/menus.cpp:522`

**Interfaces:**
- Consumes: `AddSubtitlesController` from Task 6; `DialogCard`.
- Produces: signal `DialogsProvider::showAddSubtitles(const QVariantMap& context)`.

- [ ] **Step 1: Build the top row and rows in `AddSubtitlesDialog.qml`**

`cardColor: "#0E0E0E"` at 95 %. Values and copy from the spec. Dropdowns use the `FigmaMenu` look with the spec's three targets and two of its origins: From OpenSubtitles joins the list in Task 13.

- [ ] **Step 2: Build the three row kinds**

File rows toggle with `controller.toggle`. Pair rows draw the dashed line (Figma dash values), hover shows the swap glyph, and a click opens a `FigmaMenu` of `candidates` plus None, calling `setPair`.

- [ ] **Step 3: Route the entry points**

Per the spec's table. `addExternalTrack(media, true)` opens the dialog; the audio path keeps `pickFile`. Add "Edit Subtitle Tracks" to the folder menu and "Add Subtitle Tracks" to the playlist menu, and update the slice 5 spec's departure lines.

- [ ] **Step 4: Handle From Link**

The field replaces the location. Choosing Folder or Playlist while on Link switches the origin to Computer.

- [ ] **Step 5: Verify the main flows**

In `build/redesign-media/Shows/The Clip/S01/`, add `The_Clip_S01E01.srt` and `the_clip_s01e02.srt`, then open a file, the folder and the Tracks panel Add. Remove them afterwards.
Expected:
- the folder pairs both;
- swap to None and back works;
- Save, then playing E01 lists the track at once in the Tracks panel;
- shots match `add-subtitles-1919-8707.png` and `add-subtitles-3336-11929.png`.

- [ ] **Step 6: Verify the edge folders**

Open To This Folder on a folder with no subtitles, on a read-only folder, and on a folder of 500 generated empty `.mp4` names (`make-samples.sh` or `touch`).
Expected: rows show None, Save stays off, and the window stays responsive during the scan. Log the time for the 500 case.

- [ ] **Step 7: Commit**

```bash
git add modules/gui/qt docs/superpowers/specs/2026-10-25-vlc-redesign-menus-design.md
git commit -m "qt: Add Subtitles dialog"
```

### Task 8: Control ids, identifiers and defaults

**Files:**
- Modify: `player/control_list_model.hpp`, `player/player_controlbar_model.{hpp,cpp}`, `dialogs/toolbar/controlbar_profile.{hpp,cpp}`, `dialogs/toolbar/controlbar_profile_model.cpp`
- Test: `modules/gui/qt/tests/test_control_ids.cpp`

**Interfaces:**
- Produces, in `ControlListModel::ControlType` with exact values:

| Value | Name | Value | Name | Value | Name |
|---|---|---|---|---|---|
| 0x2B | `DIVIDER` | 0x33 | `FILE_NAME_WIDGET` | 0x3B | `PLAYLISTS_BUTTON` |
| 0x2C | `JUMP_FW_10_BUTTON` | 0x34 | `ARTIST_NAME_WIDGET` | 0x3C | `MORE_MENU` |
| 0x2D | `JUMP_BACK_10_BUTTON` | 0x35 | `FOLDER_NAME_WIDGET` | 0x3D | `LIBRARY_PANEL` |
| 0x2E | `ZOOM_BUTTON` | 0x36 | `PLAYLIST_NAME_WIDGET` | 0x3E | `FOLDER_CHIP` |
| 0x2F | `SIDE_PANEL_BUTTON` | 0x37 | `REPLAY_BUTTON` | 0x3F | `MEDIA_TITLE` |
| 0x30 | `SETTINGS_BUTTON` | 0x38 | `CHAPTERS_BUTTON` | 0x42 | `WINDOW_MINIMIZE` |
| 0x31 | `HOME_BUTTON` | 0x39 | `FAVORITE_BUTTON` | 0x43 | `WINDOW_MAXIMIZE` |
| 0x32 | `THUMBNAIL_WIDGET` | 0x3A | `BOOKMARKS_BUTTON` | 0x44 | `WINDOW_CLOSE` |
|  |  |  |  | 0x45 | `SEEKBAR` |

`WIDGET_MAX` follows at 0x46.
- Produces: `PlayerControlbarModel::Topbar` and `::SeekRow`, appended after `Miniplayer`.
- Produces: `void ControlbarProfile::ensureModel(int identifier, const std::array<QVector<int>, 3>& defaults)`; loading a saved profile calls it for both identifiers.

- [ ] **Step 1: Write the failing test `tests/test_control_ids.cpp`**

```cpp
void existingIdsAreStable() {
    QCOMPARE(int(ControlListModel::SPLITTER), 0x20);
    QCOMPARE(int(ControlListModel::VOLUME), 0x21);
    QCOMPARE(int(ControlListModel::NAVIGATION_BOX), 0x2A);
    QCOMPARE(int(ControlListModel::WIDGET_SPACER), 0x40);
    QCOMPARE(int(ControlListModel::WIDGET_SPACER_EXTEND), 0x41);
    QCOMPARE(int(ControlListModel::SEEKBAR), 0x45);
}
void oldProfileGainsDefaults() {
    ControlbarProfile p;
    p.setModelData(PlayerControlbarModel::Videoplayer, {QVector<int>{ControlListModel::PLAY_BUTTON}, {}, {}});
    p.ensureModel(PlayerControlbarModel::SeekRow, {QVector<int>{}, {}, {}});
    p.ensureModel(PlayerControlbarModel::Topbar, {QVector<int>{ControlListModel::MORE_MENU}, {}, {}});
    QVERIFY(p.getModel(PlayerControlbarModel::SeekRow)->empty());
    QCOMPARE(p.getModelData(PlayerControlbarModel::Topbar)[0], QVector<int>{ControlListModel::MORE_MENU});
    // a model already present is left alone
    p.ensureModel(PlayerControlbarModel::Videoplayer, {QVector<int>{}, {}, {}});
    QCOMPARE(p.getModelData(PlayerControlbarModel::Videoplayer)[0], QVector<int>{ControlListModel::PLAY_BUTTON});
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `meson test -C build test_qt_control_ids`
Expected: FAIL, `SEEKBAR` isn't a member.

- [ ] **Step 3: Implement the enums, `ensureModel` and the defaults**

Default `Topbar`: left `MORE_MENU, LIBRARY_PANEL, FOLDER_CHIP`; center `MEDIA_TITLE`; right `WINDOW_MINIMIZE, WINDOW_MAXIMIZE, FULLSCREEN_BUTTON, WINDOW_CLOSE`. Default `SeekRow` is empty. Add both to each built-in profile in `controlbar_profile_model.cpp`. Keep `getPlaylistIdentifierListModel` limited to the three player identifiers until Task 11 removes it. The `dirty` flag covers the new models through `newModel`.

- [ ] **Step 4: Run it to verify it passes**

Run: `meson test -C build test_qt_control_ids`
Expected: OK.

- [ ] **Step 5: Commit**

```bash
git add modules/gui/qt
git commit -m "qt: control ids and Topbar/SeekRow profile models"
```

### Task 9: The new controls

**Files:**
- Create in `player/qml/controlbarcontrols/`: `DividerWidget.qml`, `JumpButton.qml` (`seconds` property), `ZoomButton.qml`, `SidePanelButton.qml`, `SettingsButton.qml`, `HomeButton.qml`, `ThumbnailWidget.qml`, `MediaTextWidget.qml` (`field` property), `ReplayButton.qml`, `ChaptersButton.qml`, `FavoriteButton.qml`, `BookmarksButton.qml`, `PlaylistsButton.qml`, `MoreMenuButton.qml`, `LibraryPanelButton.qml`, `FolderChipWidget.qml`, `MediaTitleWidget.qml`, `WindowButton.qml` (`action` property)
- Create: icons in `pixmaps/redesign/customize/` from `2107:5604`'s palette
- Modify: `player/qml/PlayerControlbarControls.qml`, `player/player_controller.hpp` if a getter is missing

**Interfaces:**
- Consumes: ids from Task 8.
- Produces: `controlList` entries `{ id, file, label, text }` for every new id; the `text` is the palette label.
- Produces: all new controls follow `SnapshotButton.qml`'s shape: `paintOnly` honoured, `requestLockUnlockAutoHide` where they open menus.

- [ ] **Step 1: Export the palette glyphs**

`get_design_context` on each palette cell of `2107:5604` (skill `figma-design-to-code`), saved as SVGs. Prefer existing glyphs for items slice 3 already has (repeat, shuffle, record).

- [ ] **Step 2: Implement the controls**

Behaviour per the spec's palette table. `MoreMenuButton`, `LibraryPanelButton`, `FolderChipWidget` and `MediaTitleWidget` move their code out of `LocalTopbar` (lines 131, 164, 198, 277), which keeps using them for the library. `WindowButton` wraps `CSDWindowButton` and hides when `!MainCtx.clientSideDecoration`. `FavoriteButton` is disabled for media not in the library. `Player` panel pages are opened through the existing `PlayerPanel.currentTab`. A `SEEKBAR` entry is not listed: `ControlBar` owns it.

- [ ] **Step 3: Verify each control runs**

Temporarily add all of them to a test profile through `vlcrc`/`vlc-qt-interface.conf`, start with `-vv`, click each.
Expected: each does what the table says, with no new log errors. Put the profile back.

- [ ] **Step 4: Commit**

```bash
git add modules/gui/qt
git commit -m "qt: controls for Customize Player's palette and the title bar"
```

### Task 10: Model-driven title bar and seek row

**Files:**
- Modify: `maininterface/qml/LocalTopbar.qml`, `player/qml/Player.qml:658`, `player/qml/ControlBar.qml`

**Interfaces:**
- Consumes: `Topbar`, `SeekRow`; controls from Task 9.
- Produces: `LocalTopbar.controlModel: PlayerControlbarModel` (null for the library, which keeps its fixed layout). `ControlBar.seekRowModel: PlayerControlbarModel`.

- [ ] **Step 1: Take before-shots**

Run: `dbus-run-session -- docs/superpowers/scripts/wl-drive.py build/redesign-shots/d10 vlc:build/redesign-media/plain.mp4 sleep:2 shot:before exit:1`
Expected: `build/redesign-shots/d10/before.png` exists; keep it.

- [ ] **Step 2: Drive the player's title bar from the model**

When `controlModel` is set, `LocalTopbar` shows three `ControlRepeater` rows (left beside the fixed cone, centre on the window's centre as `windowTitle` is, right at the edge) instead of its fixed groups. Tap-and-drag stays beneath them. Player passes `MainCtx.controlbarProfileModel.currentModel.getModel(PlayerControlbarModel.Topbar)`.

- [ ] **Step 3: Drive the seek position from `SeekRow`**

`ControlBar._textPosition`: non-empty `seekRowModel` means `AboveSlider`-with-side-times (frame `2160:6137`), else `Inline`. Inline needs an empty `center` to have a filler: when `center` holds items and the seekbar is inline, show the row above (a profile from before this slice can't hit this; Task 11's drop rule prevents it after).

- [ ] **Step 4: Verify nothing moved**

Run the same command with `shot:after`, and compare `before.png` and `after.png`.
Expected: identical chrome (the only change a pixel diff may show is the video frame).

- [ ] **Step 5: Commit**

```bash
git add modules/gui/qt
git commit -m "qt: the player's title bar and seek row follow the profile"
```

### Task 11: Customize Player

**Files:**
- Create: `dialogs/toolbar/qml/CustomizePlayerOverlay.qml`, `dialogs/toolbar/qml/CustomizePalette.js`, `modules/gui/qt/tests/tst_CustomizePalette.qml`
- Modify: `dialogs/toolbar/qml/EditorDNDView.qml`, `EditorDNDDelegate.qml`, `maininterface/mainctx.{hpp,cpp}`, `maininterface/qml/MainInterface.qml`, `player/qml/ControlBar.qml`, `maininterface/qml/LocalTopbar.qml`, `dialogs/dialogs/qml/Dialogs.qml`
- Delete: `dialogs/toolbar/qml/{ToolbarEditorDialog,ToolbarEditor,ToolbarEditorButtonList,EditorTabButton,EditorDummyButton}.qml`, `PlayerControlbarModel::getPlaylistIdentifierListModel`, the `positionSliderY` fallbacks in `ExtendedSettingsButton.qml:62-64` and `LangButton.qml:76-78`

**Interfaces:**
- Consumes: Tasks 8–10.
- Produces: `Q_PROPERTY(bool customizingPlayer READ … WRITE … NOTIFY … )` on `MainCtx`.
- Produces: `CustomizePalette.js`: `items` (`[{ id, label, repeats? }]` in Figma order, HDR absent, then the seven title-bar controls); `available(items, placedIds)` returns those not placed plus every `repeats` item.

- [ ] **Step 1: Write the failing `tst_CustomizePalette.qml`, registered in `qml_tests`**

```qml
function test_order_and_filter() {
    compare(Palette.items[0].label, "Spacer")
    compare(Palette.items[1].label, "Divider")
    verify(!Palette.items.some(i => i.label === "HDR"))
    verify(!Palette.items.some(i => i.id === ControlListModel.SEEKBAR))
    const placed = [ControlListModel.FAVORITE_BUTTON, ControlListModel.WIDGET_SPACER]
    const left = Palette.available(Palette.items, placed)
    verify(!left.some(i => i.id === ControlListModel.FAVORITE_BUTTON))   // frame 6587:19923
    verify(left.some(i => i.id === ControlListModel.WIDGET_SPACER))      // repeats stay
    // the order holds after a removal
    const stop = left.findIndex(i => i.label === "Stop")
    compare(left[stop + 1].label, "Repeat")
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt`
Expected: FAIL, `CustomizePalette.js` can't be loaded.

- [ ] **Step 3: Implement `CustomizePalette.js`**

Use the spec's table for the order. `Forward 15s` and `Backward 15s` are `SKIP_FW_BUTTON` and `SKIP_BACK_BUTTON`.

- [ ] **Step 4: Run it to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt`
Expected: OK.

- [ ] **Step 5: Add edit mode to the bars**

When `MainCtx.customizingPlayer`, `ControlBar` and the player's `LocalTopbar` draw `EditorDNDView` rows for each zone in place of their `ControlRepeater`s, with dashes per the spec on every item and zone, including empty ones. The auto-hide FSMs stay locked. Remove `EditorDNDView`'s tab and footer assumptions. Drop rules:
- `SEEKBAR` only moves between `SeekRow` and bottom centre, and bounces back from anywhere else;
- dropping it into bottom centre appends that zone's items to bottom left.

- [ ] **Step 6: Build `CustomizePlayerOverlay.qml` and open it**

An item parented over the main window. Card values, hint and grid per the spec, with a `Flickable` palette. The palette is a `DropArea`: dropping a bar item removes it. `showToolbarEditorDialog` sets `customizingPlayer`; if the player isn't the current page, `History.push(["player"])`, and restore with `History.previous()` on close. Placeholder text with no media. Save → `controlbarProfileModel.save()`; Cancel, ×, Escape → `reload()`. Save enabled follows `currentModel.dirty`. Delete the listed files.

- [ ] **Step 7: Verify against the storyboard**

Using `wl-drive.py`'s `drag:` step, replay the eight steps in the spec's storyboard.
Expected:
- each shot matches its frame in `docs/superpowers/figma/8/customize-player-*.png`;
- Save survives a restart;
- after dragging every control off, the right-click menu still offers Customize Player;
- Cancel restores the original bars exactly;
- at a 600 × 420 window and with `--qt-interface-scale=2` the card fits above the bars and the palette scrolls.

- [ ] **Step 8: Commit**

```bash
git add -A modules/gui/qt
git commit -m "qt: Customize Player edits the player's bars in place"
```

### Task 12: Profile ▸ New, docs, branch check

**Files:**
- Modify: `menus/menus.cpp:300`, `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md:27`, this plan (`## Ledger`)

**Interfaces:**
- Consumes: `ControlbarProfileModel::cloneSelectedProfile(name)`, `DialogsProvider::getTextDialog`, `showToolbarEditorDialog`.

- [ ] **Step 1: Make Profile ▸ New ask, clone and open**

Prompt "Profile %1" by default, as `ToolbarEditorDialog.newProfile` did. Cancel does nothing. Select the clone, then emit `showToolbarEditorDialog`.

- [ ] **Step 2: Verify**

Run the app: "…" ▸ Profile ▸ New, enter "Work".
Expected: the menu reads Profile (Work), the editor is open, and edits don't change the first profile after switching back.

- [ ] **Step 3: Write the Ledger and mark the roadmap**

`## Ledger` lists every *(my call)* from the spec that shipped, plus anything changed during the build. Fill roadmap row 8's Scope and mark it done.

- [ ] **Step 4: Run the whole branch check**

Run: `ninja -C build && QT_QPA_PLATFORM=offscreen meson test -C build --suite qt && python3 docs/superpowers/scripts/check-settings-options.py && coredumpctl list --since -2h | grep vlc`
Expected: builds, all OK, the script is clean, and no new coredumps.

- [ ] **Step 5: Commit**

```bash
git add modules/gui/qt docs/superpowers
git commit -m "qt: new profiles from the menu; dialogs ledger and roadmap"
```

### Task 13: From OpenSubtitles (needs the user's go-ahead)

**Do not start until the user answers Open Decision 1 in the spec.** If they choose to hide it, delete this task.

**Files:**
- Create: `modules/gui/qt/dialogs/subtitles/opensubtitles_client.{hpp,cpp}`, `modules/gui/qt/tests/test_opensubtitles_client.cpp`
- Modify: `modules/gui/qt/meson.build`, `Makefile.am`, `qt6.pro` (Network), `modules/gui/qt/qt.cpp` (option), `dialogs/settings/qml/SettingsData.js` (Network row), `add_subtitles_controller.{hpp,cpp}`, `qml/AddSubtitlesDialog.qml`

**Interfaces:**
- Consumes: `AddSubtitlesController`, `matchSubtitles`.
- Produces: `OpenSubtitlesClient : QObject`: `void search(const QString& query, const QString& language)`; signals `results(QVector<SubtitleHit>)`, `failed(QString)`; `void download(int fileId, const QString& destPath)`; signals `downloaded(QString path)`, `downloadFailed(QString)`; `static QVector<SubtitleHit> parseResults(const QByteArray& json)`.
- Produces: `struct SubtitleHit { int fileId; QString fileName; QString language; }`.

- [ ] **Step 1: Check the official API docs**

Read `https://opensubtitles.stoplight.io/` for the exact search and download requests, the `Api-Key` and `User-Agent` rules, and the anonymous download limit. Record a captured response as `tests/data/opensubtitles_search.json`. If the docs differ from the spec, update the spec first.

- [ ] **Step 2: Write the failing test**

```cpp
void parseResults_fromCapturedResponse() {
    QFile f(QFINDTESTDATA("data/opensubtitles_search.json")); QVERIFY(f.open(QIODevice::ReadOnly));
    const auto hits = OpenSubtitlesClient::parseResults(f.readAll());
    QVERIFY(!hits.isEmpty());
    QVERIFY(hits[0].fileId > 0);
    QVERIFY(!hits[0].fileName.isEmpty());
}
void parseResults_badInput() {
    QVERIFY(OpenSubtitlesClient::parseResults("not json").isEmpty());
    QVERIFY(OpenSubtitlesClient::parseResults("{\"data\":[{}]}").isEmpty());
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `meson test -C build test_qt_opensubtitles_client`
Expected: FAIL, the header isn't found.

- [ ] **Step 4: Implement the client and the option**

`QNetworkAccessManager`. The option is `qt-opensubtitles-key` (string, empty default), with a Network row labelled "OpenSubtitles API key". The key is sent only to `api.opensubtitles.com`, over HTTPS, and is never logged.

- [ ] **Step 5: Run it to verify it passes**

Run: `meson test -C build test_qt_opensubtitles_client`
Expected: OK.

- [ ] **Step 6: Wire it into the dialog**

Add the entry to the origin dropdown, the search field and language dropdown. An empty key shows the spec's message and a button opening Settings. To This Folder pairs results with `matchSubtitles`. Save downloads and then attaches per the spec. A failed download skips that file and reports it through `finished(attached, failed)`.

- [ ] **Step 7: Verify with a real key**

With the user's key: search "The Wand S01E01", tick one, Save.
Expected: the file lands beside the media and lists in the Tracks panel. With no key or no network, the message shows and nothing crashes. The shot matches `add-subtitles-1919-9278.png`.

- [ ] **Step 8: Commit**

```bash
git add modules/gui/qt
git commit -m "qt: Add Subtitles from OpenSubtitles"
```

## Ledger

What the spec left to the implementer (*my call*) and what the build changed. Section names follow the spec.

### Spec calls that shipped

**Shared window**
- The four form dialogs are separate modal windows (`Qt.ApplicationModal`), like Settings, not overlays.
- Their Loaders and Settings' live in `MainInterface.qml`, not the per-view `Dialogs`, so a view change doesn't destroy them with their edits. The per-view `Dialogs` keeps the popups that need `bgContent`. This also gives minimal view the new dialogs instead of the legacy fallback (read from the code, not run).

**Open Network Stream**
- One URL per line, blank lines ignored, a line without `://` gets `http://`.
- Without a name the button reads **Open** and plays without saving. The user confirmed this on 2026-11-05 ("go with your plan").
- Saved streams are `<userdata>/network-playlists/<name>.m3u8` (`#EXTM3U`, `#PLAYLIST:<name>`, one line per URL), so they need no media library and VLC's browse tree can open them.
- `NetworkHomeDisplay` shows one tile per saved file after Radio. Activating it opens `folderTree` on the single URL when that URL's path ends in `.m3u`, `.pls` or `.xspf`, otherwise on the saved file, whose rows play. The tile menu has Delete, with no confirmation.

**New Playlist**
- Save is on when the name is non-blank. Files are optional.
- Once the drop box holds files it lists them in rows with a remove x and keeps the + button.
- Dropped folders add their media files, not recursively.
- A custom cover is copied to `<userdata>/playlist-covers/<id>.<ext>`. `MLPlaylistListModel::getCover` prefers it, and deleting the playlist deletes it.

**Keyboard Shortcuts**
- Every `key-*` option the Figma doesn't show goes into a section from `HotkeysData.js` and uses VLC's own text.
- Clicking a cell or its pencil captures ("Press a key..."), clicking elsewhere cancels. Delete clears a focused cell that isn't capturing.
- Capture replaces the option's whole value, so a row with two default keys ends up with one. Existing multi-key values display joined by `, `.
- Changes apply on the next launch, and a note by Save says so. `Esc` displays as `esc`.

**Add Subtitles**
- From Computer is a full-width folder row that opens a folder picker. From Link takes a URL, To This File only.
- To This File: multi-select, and a file matching the media starts ticked.
- To This Folder / Playlist: clicking the paired subtitle opens a menu of the candidates plus **None**. A media with no match shows **None** in `#404040`.
- Folder media are the library's media directly in that folder. Candidate subtitle files come from one directory scan with VLC's subtitle extensions.
- From OpenSubtitles (Task 13): `qt-opensubtitles-key` is a password row in Settings ▸ Network. An empty key shows "Add an OpenSubtitles API key in Settings ▸ Network" with an Open Settings button that opens Settings on that page.
  - The search box searches after a 0.7 s pause in typing or on Enter, and the language is a dropdown of 16 codes. Choosing From OpenSubtitles or coming back from Settings sends nothing: the prefilled file name stays on this machine until the user asks, and the page says "Press Enter to search OpenSubtitles". Changing the language with a query in the box does search. Hits are the candidates, so To This File ticks them and To This Folder / Playlist pair them with `matchSubtitles` through the same menu. The search text starts as the media's name (File) or the folder's name.
  - Save downloads one file at a time to `<media stem>.<lang>.srt` beside the media, or to `<userdata>/subtitles/` when that folder isn't writable, then attaches it. The name is built from the local stem and a language code kept to `[a-z0-9-]`, never from the server's `file_name`; a taken name gets `.2`, `.3` and so on. A failed download is counted in `finished(attached, failed)`, and nothing partial is written (`QSaveFile`).
  - The key goes only to `https://api.opensubtitles.com/api/v1`; the client's base URL is a constructor argument used by the tests, and no option sets it. The file link a download returns is fetched without the key. Errors never carry the key or the response body.
  - Open Settings opens Settings modal to the dialog for that trip; on return the dialog reads the key again and takes the focus back. Closing the dialog however it closes stops a search or download in flight.
  - Unverified: any search or download with a real key, so real results, the real response shape, `POST /download` auth and the User-Agent rules are all open (the official docs could not be read; see the Task 13 report). What the real service has shown: a multi-word search with a dummy key, sent by the app, passes its redirect and reaches the key check, and the dialog says "OpenSubtitles refused the API key". That is the only path a dummy key can reach. Saving and cancelling were run against a local mock only.

**Customize Player**
- With no media the editor shows placeholder text, "Title" and `00:00`.
- The seekbar is one mandatory item that bounces back if dropped on the palette or anywhere but the Seek row or the inline centre.
- Only the player's title bar is model-driven. The library's `LocalTopbar` stays fixed.
- Picture in Picture leaves the player for the mini card.
- Title-bar-only widgets (`MORE_MENU`, `LIBRARY_PANEL`, `FOLDER_CHIP`, `MEDIA_TITLE`, `WINDOW_*`) can go in any zone and reappear in the palette after the Figma's items.
- Profile > New asks for a name ("Profile %1" by default, as the removed editor did), clones the selected profile, selects the clone and opens Customize Player. Cancel in the prompt changes nothing. Cancel in the editor keeps the clone, because the overlay saves on open and `reload()` restores that.

### Changed during the build

- Ruling: the default Topbar's right group is minimize, maximize, fullscreen, close, with the queue toggle only in the bottom bar. The spec's zone table and frame 2107:5604 set this, and Figma outranks the plan's "identical" line.
- Ruling: Customize Player's seek row uses `ControlBar.TimeTextPosition.LeftRightSlider`, which draws frame 2160:6137 (times beside the slider in their own row).
- Ruling: empty title-bar zones and the empty seek row are dashed only during a drag. Frames 2107:5604 and 2160:7437 show them undashed.
- Ruling: Customize Player opens the player through `MainCtx.playerView`, not `History.push(["player"])`, because the player isn't a History page here.
- Ruling: the palette also lists prev, play, next, volume, tracks, extended settings, queue and fullscreen after the Figma's items when unplaced, so dragging them off doesn't lose them.
- Ruling: the legacy preferences dialog's Toolbar Editor button is hidden. The card opened behind that modal dialog with the bars unresponsive, and closing the dialog first would lose unsaved preferences. Legacy-prefs users reach Customize Player through the "..." menu.
- Ruling: a media with no library id that isn't playing counts as failed when attaching subtitles, because the player can only attach to its current input.
- Ruling: To This Playlist stays disabled when the opener has no playlist.
- Ruling: Task 7's playlist menu path was found by searching the Figma labels.
- Ruling: work stayed on branch `redesign/dialogs` in the main checkout, no worktree.
- Ruling: Task 13's gate is cleared by the user's "go with your plan". A local mock server replaces a real API key unless one is supplied, so the live service stays unverified.
- Profile > New is only offered when the interface isn't a dialog provider, since the overlay lives in the main window.
- Removed: `ToolbarEditorDialog.qml`, `ToolbarEditor.qml`, `ToolbarEditorButtonList.qml`. `EditorTabButton.qml` and `EditorDummyButton.qml` became `SettingsButton.qml` and `DividerWidget.qml` in `player/qml/controlbarcontrols/`.
- Known gaps, reviewed and left: The default bottom bar has no "visualizer" control although the spec's zone table lists one (pre-existing). The main `make` of the plugin has never been run; automake and configure have, in a temporary copy, and `test_control_ids` and `test_opensubtitles_client` built and passed there with `make`.
- Ruling (final review I3): contrib Qt builds set `FEATURE_network=OFF` (`contrib/src/qt/rules.mak`), so From OpenSubtitles' `Qt6Network` requirement would break them. This fork builds on system Qt, so the build stays as it is. A contrib build needs the module enabled, or Network made optional, first.
- Ruling (final review I8): a visible modal `DialogCard` turns `MainCtx.useGlobalShortcuts` off, through a count (`MainCtx.holdGlobalShortcuts`) so nested cards restore in any order and a search field losing focus can't turn it back on. The property was seen going off and back on across Cancel, x, Escape, Save, Alt+F4 (Wayland) and the Add Subtitles to Settings trip. Whether a shortcut is really held off over a card stays a hand check: Qt Shortcuts never fire on Xvfb and `wl-drive` can't send Ctrl chords. On a real session: Ctrl+N from the library, then Ctrl+P and Ctrl+N with Keyboard Shortcuts open and its search field focused.
- Final review I6: Customize Player hides the queue card and leaves the saved state alone, so `MainWindow/playqueue-panel-visible` is unchanged after Cancel and an open queue is open again after.
- Final review Minor 5: Add Subtitles to a playing file looks up its library id from the mrl, so the Tracks panel's Add persists for a library file as the file menu's does.
