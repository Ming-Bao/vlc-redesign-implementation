# Settings window (slice 7) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** "Settings" (Ctrl+P, the "…" menu, the player panels' links) opens a new Figma Settings window: a frameless card with a search box, a 13-page sidebar and rows that write VLC config options directly. The legacy Preferences dialog stays reachable for hotkeys and "All settings".

**Architecture:**
- **One C++ bridge** (`SettingsBridge`, a QML singleton in `VLC.Dialogs`) reads and writes config options and lists their choices and help.
- **One JS data file** describes every page → section → row. One row delegate draws a row by its `kind`, and a few small custom components cover the special rows.
- **The window** is a top-level QML `Window` loaded from `Dialogs.qml`, like `ToolbarEditorDialog`.
- **Row controls** are slice 3c's `player/qml/settings/` components, reused.

**Tech Stack:** Qt 6 QML (QtQuick, Templates, Window), C++ (libvlccore config API), meson, QtTest. Figma MCP for icons and per-control values (load `figma:figma-design-to-code` before `get_design_context`).

**Spec:** `docs/superpowers/specs/2026-10-25-vlc-redesign-settings-design.md`. It is the row-by-row source: every page table there (row, control, option, notes) is the data to enter.

## Global Constraints

- **Figma is the source of truth** (`dSoAm0gN9ZterHSssJU9FN`).
  - The 19 frames are listed in the spec. Shots are in `docs/superpowers/figma/7/<page>-<node>.png`.
  - Rows come from the spec's tables, not from the shots: the frames clip at 865 px.
- **Every Figma px value is written `VLCStyle.dp(n, VLCStyle.scale)`.**
- **Colours** (dark):
  - window `#0E0E0E` at 95 %, top bar `#090909`, search box `#151515`, sidebar card `rgba(25,25,25,0.95)`, selected category `#222222`;
  - text: title `#969696`, section `#C6C6C6` (Medium 16), label `#8F8F8F` (14), group header `#6B6B6B`, selected label `#EAEAEA`, placeholder `#404040`;
  - controls: field `#090909`, face `#191919`, accent `#D37918`, accent background `#371F06`, knob on `#AB6314`, knob off `#404040`.
- **Geometry:**
  - window 1048 × 865, radius 14, shadow 0 8 15 `#00000075`;
  - top bar 50; sidebar column 216 (card 200, padding 6, gap 8, item 188 × 40);
  - content padding 20/24/100, sections 20 apart, rows 46 (padding 5), control column 320;
  - Advanced bar 38.
- **Copy:**
  - page titles are the spec's "Title-bar text" column, verbatim;
  - row labels are verbatim, except the three typo fixes listed in the spec;
  - new strings: "No results", "All settings", "Password".
  - All strings go through `qsTr`/`qtr`.
- **No row is built for "—" entries** in the spec's tables.
- **Silent runs:** the harness passes `--aout=dummy`. Clear `RecoveryFilePath=` from `build/redesign-profile/config/vlc/vlc-qt-interface.conf` before each run (memory `redesign-harness`).
- **Settings persistence check:** the harness's `start` restores `vlc-qt-interface.conf` from `/tmp/conf.bak`. VLC options live in `build/redesign-profile/config/vlc/vlcrc`, which it does not restore.
- **Git:**
  - branch `redesign/settings` (exists; the spec and the Figma shots are committed in `5c274e677e`);
  - commits as the global git user, no Co-Authored-By.
- **After each task:**
  - `ninja -C build` builds;
  - `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt` is all OK;
  - after any app run, `grep -E 'TypeError|ReferenceError|non-existent property|unavailable|Cannot assign' build/redesign-profile/run/vlc.log` finds nothing new. Start with `docs/superpowers/scripts/vlc-xvfb.sh start -vv`, or the grep passes vacuously.
- **New files:**
  - QML and C++ files go in `modules/gui/qt/meson.build`, `Makefile.am` and `po/POTFILES.in`. QML goes in the `VLC.Dialogs` file list, like `ToolbarEditorDialog.qml`.
  - SVGs go in `assets.qrc`, `Makefile.am` and the meson resource list.

## Review Focus

1. **An option missing from this build** (skins2, the updater, gnutls or x264 not built): its row hides, a section left with no rows hides with its header, and no QML warning is logged. Task 3, Step 6.
2. **Typing in a field, then closing the window or switching page without pressing Enter**: the value is written (commit on `editingFinished`, which focus loss and window close both trigger). Task 3, Step 6.
3. **A value changed elsewhere while the window is open** (shuffle from the player's queue, the legacy dialog): the page shows the new value when it is shown again (a re-read on page show), with no stale binding. Task 4, Step 5.
4. **A 1280 × 720 screen, or `VLCStyle.scale` 2**: the window opens capped to 90 % of the screen and fully on it, and the content scrolls. Task 2, Step 5.
5. **Search text with regex characters** (`(`, `*`, `.`) or matching nothing: plain substring match, "No results", no exception. Task 7, Step 1.

---

### Task 1: SettingsBridge

**Files:**
- Create: `modules/gui/qt/util/vlc_config.hpp`, `util/vlc_config.cpp` (free functions moved out of `player/player_effects.cpp`)
- Create: `modules/gui/qt/dialogs/settings/settings_bridge.hpp`, `settings_bridge.cpp`
- Modify: `player/player_effects.cpp` (call the moved functions), `maininterface/mainui.cpp` (register the singleton in the `VLC.Dialogs` block)
- Test: `modules/gui/qt/tests/test_settings_bridge.cpp` (+ a `test_qt_settings_bridge` entry in `meson.build`, modelled on `test_qt_renderer_manager`: `vlc_stub_modules.cpp`, linked with `libvlccore` and `libvlc`)

**Interfaces:**
- Produces, in `util/vlc_config.hpp`:
  - `QVariant vlcConfigValue(const QString& name)`
  - `bool vlcSetConfigValue(const QString& name, const QVariant& v)`
  - These carry today's `PlayerEffects::configValue`/`setConfigValue` bodies, including the `"#RRGGBB"` → int rule. The setter returns false for an unknown option.
- Produces `class SettingsBridge : public QObject`, registered as `SettingsBridge` (`import VLC.Dialogs`):
  - `Q_PROPERTY(int revision READ revision NOTIFY changed)`, bumped by every write;
  - `signal changed(const QString& name)`;
  - `Q_INVOKABLE bool exists(const QString& name) const`: `config_GetType != 0`, and the item isn't obsolete (`module_config_t::b_removed`);
  - `Q_INVOKABLE QVariant value(const QString& name) const`, `Q_INVOKABLE void setValue(const QString& name, const QVariant& v)`;
  - `Q_INVOKABLE QVariant defaultValue(const QString& name) const`, `Q_INVOKABLE void reset(const QString& name)`;
  - `Q_INVOKABLE QVariantList choices(const QString& name) const`: `[{value, label}]` from `config_GetIntChoices` / `config_GetPszChoices`, labels translated (`qfut`); `[]` when there is no list;
  - `Q_INVOKABLE QString help(const QString& name) const`: the long text, else the text, else `""`;
  - `Q_INVOKABLE bool listHas(const QString& name, const QString& module) const`, `Q_INVOKABLE void setListHas(const QString& name, const QString& module, bool on)`, using `effects::toggleModule`;
  - `Q_INVOKABLE void resetPrefixes(const QStringList& prefixes)`: resets every core option whose name starts with one of them (walk `module_config_get(module_get_main())`);
  - `Q_INVOKABLE QVariantList languages() const`: `[{value:"", label:qtr("System language")}]`, then `vlc_iso_lang.h`'s table as `{value: psz_iso639_2T, label: psz_eng_name}`, sorted by label;
  - `Q_INVOKABLE QStringList fontFamilies() const` (`QFontDatabase::families()`);
  - `Q_INVOKABLE QStringList opticalDrives() const`: existing `/dev/sr*` and `/dev/cdrom` on Linux, optical drive roots on Windows;
  - `Q_INVOKABLE void resetAll()`: `config_ResetAll` + save; `Q_INVOKABLE void save()`: `config_SaveConfigFile`;
  - `Q_INVOKABLE void openConfigFolder()`: `QDesktopServices::openUrl` on `config_GetUserDir(VLC_CONFIG_DIR)`.

- [ ] **Step 1: Write the failing tests** (`initTestCase` creates `VLCTestingEnv`). Use core options only; the stub env loads no plugins.

```cpp
void roundTripBool()   { b.setValue("random", true); QCOMPARE(b.value("random"), QVariant(true)); }
void roundTripInt()    { b.setValue("long-jump-size", 120); QCOMPARE(b.value("long-jump-size").toLongLong(), 120); }
void roundTripFloat()  { b.setValue("rate", 1.5); QCOMPARE(b.value("rate").toFloat(), 1.5f); }
void roundTripString() { b.setValue("sub-language", "fre"); QCOMPARE(b.value("sub-language").toString(), QString("fre")); }
void unknownOption()   { QVERIFY(!b.exists("no-such-option")); QVERIFY(!b.value("no-such-option").isValid()); }
void intChoices()      { const auto c = b.choices("restore-playback-pos"); QCOMPARE(c.size(), 3);
                         QCOMPARE(c[0].toMap()["value"].toInt(), 0); }
void listToggle()      { b.setValue("audio-filter", "");
                         b.setListHas("audio-filter", "karaoke", true); b.setListHas("audio-filter", "normvol", true);
                         QCOMPARE(b.value("audio-filter").toString(), QString("karaoke:normvol"));
                         b.setListHas("audio-filter", "karaoke", false);
                         QVERIFY(!b.listHas("audio-filter", "karaoke")); QVERIFY(b.listHas("audio-filter", "normvol")); }
void resetOne()        { b.setValue("long-jump-size", 5); b.reset("long-jump-size");
                         QCOMPARE(b.value("long-jump-size"), b.defaultValue("long-jump-size")); }
void resetPrefix()     { const auto d = b.defaultValue("key-play-pause"); b.setValue("key-play-pause", "x");
                         b.resetPrefixes({"key-"}); QCOMPARE(b.value("key-play-pause"), d); }
void revisionBumps()   { const int r = b.revision(); b.setValue("random", false); QVERIFY(b.revision() > r); }
void languages()       { const auto l = b.languages(); QVERIFY(l.size() > 100); QCOMPARE(l[0].toMap()["value"].toString(), QString()); }
void helpText()        { QVERIFY(!b.help("rate").isEmpty()); }
```

- [ ] **Step 2: Run it and check that it fails**

Run: `ninja -C build && meson test -C build test_qt_settings_bridge`
Expected: build FAIL (`settings_bridge.hpp` not found)

- [ ] **Step 3: Move the config helpers into `util/vlc_config.cpp`.** `PlayerEffects::configValue`/`setConfigValue` become one-line calls to them, and `test_qt_effects_util` still passes. Then implement `SettingsBridge` and register it in `mainui.cpp`'s `VLC.Dialogs` block with `qmlRegisterSingletonInstance` (parent `this`).

- [ ] **Step 4: Run the tests and check that they pass**

Run: `ninja -C build && QT_QPA_PLATFORM=offscreen meson test -C build --suite qt`
Expected: all OK

- [ ] **Step 5: Commit**

```bash
git add modules/gui/qt/util/vlc_config.* modules/gui/qt/dialogs/settings/settings_bridge.* modules/gui/qt/player/player_effects.cpp modules/gui/qt/maininterface/mainui.cpp modules/gui/qt/tests/test_settings_bridge.cpp modules/gui/qt/meson.build modules/gui/qt/Makefile.am po/POTFILES.in
git commit -m "qt: SettingsBridge reads and writes VLC config for the settings window"
```

---

### Task 2: The window shell

**Files:**
- Create: `modules/gui/qt/dialogs/settings/qml/SettingsWindow.qml`, `dialogs/settings/qml/SettingsSidebar.qml`
- Create: `modules/gui/qt/pixmaps/redesign/settings/*.svg` (13 categories × default/active, plus `info.svg`, `search.svg`, `close.svg`, `chevron-right.svg`, `chevron-down.svg`)
- Modify: `dialogs/dialogs_provider.hpp/.cpp`, `dialogs/dialogs/qml/Dialogs.qml`, `assets.qrc`, `meson.build`, `Makefile.am`, `po/POTFILES.in`

**Interfaces:**
- Produces on `DialogsProvider`:
  - `signal showSettingsWindow()`. `prefsDialog()` (no argument) emits it instead of opening `PrefsDialog`. `prefsDialog(int)` is unchanged.
  - `Q_INVOKABLE void legacyPrefsDialog()`: opens `PrefsDialog` and switches it to its All view (make `setAdvanced()` callable).
- Produces in `SettingsWindow.qml` (root `Window`):
  - `property int currentPage` (index into the pages; 0 = General), kept across opens for the session (the `Loader` stays active once loaded);
  - `property string searchText`;
  - `function open()`: `show()`, `raise()`, `requestActivate()`.
  - It contains a `Loader`/`StackLayout` content area that Task 3 fills, and a `property Component pageComponent` hook. Task 3 decides the content, so Task 2 shows only the page title.
- Produces `SettingsSidebar.qml`: `required property var pages` (`[{title, name, icon, group}]`), `property int currentIndex`, `signal picked(int index)`. Groups "App" (General, Interface, Privacy, Controls), "Media" (Playback, Video, Audio, Subtitles, Library), "System" (Network, Performance, Recording, Extensions).

- [ ] **Step 1: Export the icons** with `get_design_context`/`use_figma` `exportAsync({format:'SVG_STRING'})` on the node ids in the spec's "sidebar icons" list.
  - Each has a grey default. The active variant is the same glyph in `#D37918`, filled where the active instance (`1088:4045` pattern) is filled.
  - Flipped instances carry their transform in the SVG, as in slice 5.

- [ ] **Step 2: Build the shell.**
  - A frameless `Window` (`flags: Qt.Window | Qt.FramelessWindowHint`, `color: "transparent"`), `transientParent: MainCtx.intfMainWindow`.
  - It holds the rounded card with the shadow, the top bar (search box, page title, ×), the sidebar and the content area.
  - The top bar's empty area calls `startSystemMove()`. 6 px edge `MouseArea`s call `startSystemResize(edges)`.
  - Size: the Figma size × scale, capped to 90 % of `screen.desktopAvailableWidth/Height`, centred on the main window, with a minimum of 760 × 480 × scale.
  - Escape and × call `close()`. `onClosing` calls `SettingsBridge.save()`.
  - Keyboard: Tab moves through the sidebar, the search box and the content. Up and Down move the sidebar selection.
  - `Dialogs.qml` gets a `Loader` like `toolbarEditorDialogLoader`, driven by `onShowSettingsWindow`.

- [ ] **Step 3: Run it.** `vlc-xvfb.sh start -vv`, `key ctrl+p`, then `shot`.
  - The card, the top bar and the sidebar match `general-999-5047.png` (content empty but the title).
  - Clicking each category changes the title to the spec's text and the selected look.
  - A second `ctrl+p` raises the same window and doesn't open a second one.

- [ ] **Step 4: Check the entry points.**
  - The "…" menu → Settings opens the new window.
  - "…" → Keyboard Shortcuts still opens the legacy dialog on Hotkeys.
  - The Tracks panel's "Show Preferences" opens the new window.

- [ ] **Step 5: Review Focus 4.** Run once with `QT_SCALE_FACTOR=2` in the harness environment (the 1600×900 Xvfb screen then acts as 800×450 logical). The window is fully on screen, at most 90 % of it, and the content scrolls. Then grep the log.

- [ ] **Step 6: Commit**

```bash
git add modules/gui/qt/dialogs/settings modules/gui/qt/pixmaps/redesign/settings modules/gui/qt/dialogs/dialogs_provider.* modules/gui/qt/dialogs/dialogs/qml/Dialogs.qml modules/gui/qt/assets.qrc modules/gui/qt/meson.build modules/gui/qt/Makefile.am po/POTFILES.in
git commit -m "qt: Figma settings window shell replaces Preferences as Settings"
```

---

### Task 3: Rows, Advanced Options, and the App pages

**Files:**
- Create: `dialogs/settings/qml/SettingsData.js` (`.pragma library`), `dialogs/settings/qml/SettingsWindowPage.qml` (not `SettingsPage`: `VLC.Player` has one and `PlaybackPanel` imports both modules), `dialogs/settings/qml/SettingsRowDelegate.qml`, `dialogs/settings/qml/AdvancedBar.qml`
- Create: `docs/superpowers/scripts/check-settings-options.py`
- Modify: `SettingsWindow.qml` (content), `player/qml/settings/*.qml` (only added properties, such as a label colour), build lists

**Interfaces:**
- Produces in `SettingsData.js`:
  - `var pages = [ {name, title, icon, group, sections: [ {title, adv, rows: [row…]} ]} ]`, in sidebar order.
  - A row is an object with these fields:
    - `label` (string), `kind` (below), and optional `option` (VLC name);
    - `adv` (bool): the row sits under the Advanced bar;
    - `choices` (`[{value,label}]`, an own list overriding VLC's), `choicesFrom` (`"languages"|"fonts"|"opticalDrives"|"screens"`);
    - `min`, `max`, `step`, `ticks` (label strings under the slider), `scale` (config = UI × scale, e.g. 1000 for s→ms), `suffix`;
    - `invert` (bool toggle written inverted), `on`/`off` (values a toggle writes, default true/false);
    - `list` + `module` (a toggle that adds/removes `module` in list option `list`);
    - `action` (button id: `"openConfig"|"resetAll"|"legacyPrefs"|"editHotkeys"|"resetHotkeys"|"clearHistory"`), `buttonText`;
    - `component` (file name of a custom row under `dialogs/settings/qml/rows/`), `keywords` (extra search text for custom rows).
  - `kind` ∈ `toggle`, `dropdown`, `field`, `password`, `number`, `browseFile`, `browseFolder`, `button`, `wideButton`, `slider`, `segments`, `color`, `custom`.
  - A section with `adv: true` and a title is a titled block under the Advanced bar (General's "Developer Options").
- Produces `SettingsRowDelegate.qml`:
  - `required property var row`;
  - `readonly property bool shown`: false when `row.option && !SettingsBridge.exists(row.option)`, or for a `list` row when `!SettingsBridge.exists(row.list)`;
  - it re-reads its value when `SettingsBridge.revision` changes.
- Produces `SettingsWindowPage.qml`: `required property var page`, `property bool advancedOpen`. A `Flickable` of sections, then the Advanced bar (only if the page has adv rows that are shown), then the adv rows. It hides a section whose rows are all hidden. `function reload()` re-reads every row; it is called when the page is shown.
- Produces `check-settings-options.py SettingsData.js`: extracts every `option:`/`list:` value and checks each against the `add_*("name"` set from `src/` and `modules/` (prefix macros: `SOUT_CFG_PREFIX "sout-chromecast-"`, `"sout-x264-"`). It exits 1 and lists unknown names. The allow-list for platform-only options lives in the script.

- [ ] **Step 1: Write the option check script first** and run it on a `SettingsData.js` holding only General's rows, with one deliberate typo (`"file-loging"`).
  - Run: `python3 docs/superpowers/scripts/check-settings-options.py modules/gui/qt/dialogs/settings/qml/SettingsData.js`
  - Expected: exit 1 listing `file-loging`. Fix the typo; then expected exit 0.

- [ ] **Step 2: Implement the delegate's kinds** by reusing `SettingToggle`, `SettingCombo`, `SettingField`, `SettingSlider`, `SettingSegments` and `ColorField`.
  - The label column holds the label, the info glyph and its tooltip. The tooltip is `SettingsBridge.help(option)`, on hover and focus, and only when non-empty.
  - The control column is 320 wide, right-aligned.
  - Fields commit on `editingFinished`.
  - A dropdown uses `row.choices`, else the `choicesFrom` source, else `SettingsBridge.choices(option)`. When the current value isn't in the list, it shows the raw value as an extra item.
  - Buttons route `action` ids to `SettingsBridge`/`DialogsProvider` calls. `clearHistory` uses an `MLRecentMediaModel { ml: MediaLib }` and is disabled without a media library. `editHotkeys` calls `DialogsProvider.prefsDialog(5)` (`SPrefsHotkeys`). `resetAll` and `resetHotkeys` ask first, with the existing `Dialogs` question dialog.

- [ ] **Step 3: Enter the data for General, Interface, Privacy, Controls and Library** from the spec's tables, in Figma order, with the spec's own lists and values (e.g. `qt-fs-sensitivity` stops 30/90/300, the `qt-fullscreen-screennumber` "Current screen" -1 plus screens). Theme and Accent are `custom` placeholders until Task 6. The other pages appear with no rows until Tasks 4–6.

- [ ] **Step 4: Run the check script.** Expected exit 0.

- [ ] **Step 5: Visual check.** Open each of the five pages at 1600×900.
  - Each matches its shot: `general-999-5047`, `general-3046-9282` (Advanced open), `interface-3062-11379`, `privacy-3062-11911`, `controls-6536-14482`, `library-6542-15251`.
  - Rows the spec marks "—" are absent. A missing-option row is absent: skins2 is likely not built, so "Use a custom skin" and "Skin file" hide.
  - Save the shots to `docs/superpowers/figma/7/after-<page>.png`.

- [ ] **Step 6: Behaviour check (Review Focus 1, 2).**
  - Toggle Interface ▸ "Keep window above other windows", type a new Last.fm username on Privacy without pressing Enter, then close with ×. (`qt-recentplay-filter` is obsolete in VLC 4, so its row is not built.)
  - `grep -E '^(video-on-top|lastfm-username)=' build/redesign-profile/config/vlc/vlcrc` shows both new values.
  - The log grep is clean, including no warning from a hidden row.

- [ ] **Step 7: Commit**

```bash
git add modules/gui/qt/dialogs/settings docs/superpowers/scripts/check-settings-options.py modules/gui/qt/player/qml/settings modules/gui/qt/meson.build modules/gui/qt/Makefile.am po/POTFILES.in docs/superpowers/figma/7
git commit -m "qt: settings rows, Advanced Options, General/Interface/Privacy/Controls/Library pages"
```

---

### Task 4: Playback, Video, Network, Performance and Recording pages

**Files:**
- Create: `dialogs/settings/qml/rows/RepeatRow.qml`, `rows/PictureRows.qml`, `rows/BufferingRows.qml`
- Modify: `SettingsData.js`, build lists

**Interfaces:**
- Consumes: Task 3's row schema and `SettingsRowDelegate`.
- Produces three custom rows:
  - `RepeatRow`: one dropdown Off/One/All writing `repeat` and `loop` (One = repeat, All = loop, Off = neither).
  - `PictureRows`: the five picture sliders plus Reset picture.
    - Moving any slider away from its default adds `adjust` to `video-filter`.
    - Reset sets all five to their defaults and removes `adjust`.
    - The sliders use the options' own ranges from `SettingsBridge` (add `Q_INVOKABLE QVariantMap range(name)` → `{min, max}` from `module_config_t::min/max` if not already there).
  - `BufferingRows`: the Low/Normal/High/Custom dropdown plus four ms fields.
    - Presets are relative to each option's default: ½, ×1, ×2.
    - The shown preset is the one all four values match, else Custom.
    - The fields are disabled (at `SettingsStyle.disabledOpacity`) unless Custom.

- [ ] **Step 1: Write the failing test** for the buffering preset rule, a pure JS function in `SettingsData.js`: `presetFor(values, defaults)` → `"low"|"normal"|"high"|"custom"`. It goes in a new `tests/tst_SettingsData.qml`, registered in `meson.build` like `tst_LibraryHelpers`, which imports the JS file by its qrc path `as Data`:

```qml
function test_presetFor() {
    const d = [1000, 300, 1000, 300]
    compare(Data.presetFor([1000, 300, 1000, 300], d), "normal")
    compare(Data.presetFor([500, 150, 500, 150], d), "low")
    compare(Data.presetFor([2000, 600, 2000, 600], d), "high")
    compare(Data.presetFor([2000, 300, 1000, 300], d), "custom")
}
```

- [ ] **Step 2: Run it.** `QT_QPA_PLATFORM=offscreen meson test -C build tst_SettingsData`. Expected: FAIL (`presetFor` is not a function).
- [ ] **Step 3: Implement `presetFor`, the three custom rows, and the five pages' data** from the spec's tables:
  - Default playback speed ticks `0.25 … 2`;
  - Time-shift sizes 10/50/200 MB (`input-timeshift-granularity` in bytes);
  - Zoom list Fit/¼/½/1:1/2:1;
  - Snapshot sizes;
  - `input-fast-seek` inverted;
  - the optical drive list from `choicesFrom: "opticalDrives"`, editable.
- [ ] **Step 4: Run the tests and the check script.** Expected: all OK, exit 0.
- [ ] **Step 5: Visual check** against `playback-3072-13408`, `video-3073-15375`, `network-6543-15649`, `performance-6571-15958` and `recording-6571-16429`. Save the after-shots.
  - On Network, pick Custom and check the four fields enable.
  - Move Hue and check `vlcrc` gains `video-filter=adjust`. Reset picture removes it.
  - **Review Focus 3:** with the window open on Playback, turn shuffle on from the player's queue (the playlist writes `random` to config), switch to Video and back to Playback. The Shuffle toggle shows on.
- [ ] **Step 6: Commit** (`qt: settings Playback, Video, Network, Performance and Recording pages`).

---

### Task 5: Audio and Subtitles pages

**Files:**
- Create: `rows/StartupVolumeRow.qml`, `rows/EqualizerRows.qml`, `rows/SpatialRows.qml`, `rows/FontSizeRows.qml`
- Modify: `SettingsData.js`, `player/qml/settings/EffectAccordion.qml` (or the EQ block inside it) only as needed to embed it outside the player panel; build lists

**Interfaces:**
- Consumes: Task 3's schema, `SettingsBridge.setListHas`.
- Produces four custom rows:
  - `StartupVolumeRow`: segments "Remember last volume" / "Always starts at:" with a read-only "100%" field (`volume-save` true/false). Figma `3073:15879`.
  - `EqualizerRows`: the Equalizer toggle (`equalizer` in `audio-filter`), the preset dropdown (`equalizer-preset`), and the band block with its "Close Equalizer" bar.
    - The band block writes `equalizer-preamp`/`equalizer-bands` to config (not to the live aout), reusing `effects::formatBands`/`parseBands`.
    - It shows while the toggle is on; the bar folds it.
    - Figma `3180:17398`.
  - `SpatialRows`: the Spatial audio toggle plus the mode dropdown Headphone virtualization/Room. Toggling adds the mode's module (`headphone`/`spatializer`) to `audio-filter`. Changing the mode while on swaps the module.
  - `FontSizeRows`: Size values (Relative/Pixels) plus Font size (a `freetype-rel-fontsize` dropdown, or a `freetype-fontsize` field). Relative writes `freetype-fontsize` = 0.

- [ ] **Step 1: Enter both pages' data** from the spec's tables:
  - filter toggles via `list: "audio-filter"`;
  - the opacity sliders 0–100 % with `scale: 2.55`;
  - Shadow (`on: 128, off: 0`), Background (None 0 / Box 128);
  - Shadow distance 0.03/0.06/0.1, Vertical position 0/50/150;
  - Subtitle delay in seconds with `scale: 10` (`sub-delay` is in tenths of a second); Audio delay in seconds with `scale: 1000` (`audio-desync` is in ms);
  - fonts from `choicesFrom: "fonts"`, languages from `"languages"`.
- [ ] **Step 2: Build the four custom rows.**
- [ ] **Step 3: Run the check script and the tests.** Expected: exit 0, all OK.
- [ ] **Step 4: Visual check** against `audio-3073-15879`, `audio-3180-17398` (Effects with the EQ open), `subtitles-3180-17989` and `subtitles-6536-13908`. Save the after-shots.
- [ ] **Step 5: Filter check.**
  - Toggle Karaoke and Spatial audio, then check `vlcrc`'s `audio-filter` holds `karaoke:headphone` (order free). Turn both off and check it's empty.
- [ ] **Step 6: Commit** (`qt: settings Audio and Subtitles pages`).

---

### Task 6: Extensions page, theme and accent colour

**Files:**
- Create: `rows/ExtensionsRows.qml`. Fill in: `rows/ThemeRow.qml`, `rows/AccentRow.qml` (Task 3 placeholders, label only, `fullRow: true`)
- Modify: `settings_bridge.hpp/.cpp` (extensions), `style/systempalettethemeprovider.cpp` (dark default accent), the eight accent-hardcoding files listed in the spec, `SettingsData.js`

**Interfaces:**
- Produces on `SettingsBridge`:
  - `Q_PROPERTY(QAbstractItemModel* extensions READ extensions CONSTANT)`: `ExtensionListModel` over `ExtensionsManager::getInstance(intf)`, loading extensions if not yet loaded;
  - `Q_INVOKABLE bool addExtension(const QUrl& luaFile)`: copies it into `<userdata>/lua/extensions/` and reloads;
  - `Q_INVOKABLE bool canRemoveExtension(int row) const`: the file is under that user folder;
  - `Q_INVOKABLE bool removeExtension(int row)`: deletes it and reloads.
- `ExtensionsRows`: the list box, the search field (filters with `QSortFilterProxyModel` or a QML filter on name), "Find more extensions" (`DialogsProvider.pluginDialog()`), Add (`FileDialog` for `*.lua`), Remove (enabled per `canRemoveExtension`; asks first), and the "Load add-ons on startup" toggle (`qt-autoload-extensions`, an ordinary data row after the custom one).
- `ThemeRow`: segments Dark/Light/System on `MainCtx.colorScheme`. Map to its Night/Day/System entries by scheme, not by index.
- `AccentRow`: nine swatches with the spec's hex values.
  - The first writes `default`; the others write their hex to `qt-accent-color`.
  - Selected = `#371F06` cell at full opacity. Unselected swatches are at 70 %.
- The accent routing:
  - `SystemPaletteThemeProvider`'s dark `default` becomes `#D37918`, pressed `#AB6314`.
  - `SettingsStyle.accent`, `accentDim` and `accentBg`, and the hardcoded `#D37918`/`#AB6314`/`#371F06` in the listed QML files and `menustyle.cpp`, read the theme accent. Dim = `Qt.darker(accent, 1.24)`; background = the accent at 26 % over `#090909` (gives `#371F06` for `#D37918`). Check both against the Figma values.

- [ ] **Step 1: Write the failing test** in `test_settings_bridge.cpp`: `canRemoveExtension(-1)` is false and `addExtension` of a missing file returns false. (The stub env has no Lua, so the list itself is checked in Step 4.)
- [ ] **Step 2: Run it.** Expected: build FAIL (no `addExtension`).
- [ ] **Step 3: Implement** the bridge extension calls, the three rows, the provider default and the accent routing.
- [ ] **Step 4: Visual and behaviour check.**
  - The Extensions page matches `extensions-6575-17137`, and the list shows the bundled extensions if the build installs any.
  - Pick the blue swatch, restart the harness, and check the library's accent spots (active sidebar text, the seek bar) are blue.
  - Pick the first swatch again and check they are `#D37918`.
  - Theme Light switches to VLC's light palette (expected to look unfinished; slice 10).
- [ ] **Step 5: Run the tests.** Expected: all OK.
- [ ] **Step 6: Commit** (`qt: settings Extensions page, theme and accent colour`).

---

### Task 7: Search

**Files:**
- Modify: `SettingsData.js` (`search(pages, text)`), `SettingsWindow.qml`, `SettingsWindowPage.qml` (a results mode), `tests/tst_SettingsData.qml`

**Interfaces:**
- Produces `function search(pages, text) → [{page: index, title: pageTitle, rows: [row…]}]`.
  - Case-insensitive plain substring match on the row `label`, its `keywords`, and its section title. Advanced rows are included.
  - Pages without matches are left out. `text` trimmed empty → `[]`.
- While `searchText` is non-empty:
  - the content shows the results, grouped under each page's title, using the same delegate (`shown` still hides missing options);
  - the sidebar has no selection;
  - "No results" shows when the list is empty.
  - Picking a category clears the search. Clearing the box returns to the last page.

- [ ] **Step 1: Write the failing tests** in `tst_SettingsData.qml`:

```qml
function test_search() {
    compare(Data.search(Data.pages, "").length, 0)
    compare(Data.search(Data.pages, "   ").length, 0)
    const r = Data.search(Data.pages, "DEVELOPER OPTIONS") // case, and an Advanced section title
    compare(r.length, 1); compare(r[0].title, "Global Settings")
    verify(Data.search(Data.pages, "(").length >= 0)      // no throw on regex characters
    compare(Data.search(Data.pages, "zzqq").length, 0)
    const p = Data.search(Data.pages, "proxy")
    compare(p[0].title, "Network Connections & Security")
}
```

- [ ] **Step 2: Run them.** Expected: FAIL (`search` is not a function).
- [ ] **Step 3: Implement `search` and the results mode.**
- [ ] **Step 4: Run the tests.** Expected: all OK. Then in the app, type "log" (results from General) and "zzqq" ("No results"). Then click Audio: the search clears and Audio shows. Save `after-search.png`.
- [ ] **Step 5: Commit** (`qt: settings search across pages`).

---

### Task 8: Ledger, roadmap, merge

**Files:**
- Modify: this plan (`## Ledger`), `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md` (row 7 → done, with the plan name and departures, in the style of rows 4a–6)

- [ ] **Step 1: Check the window on Wayland.** Run `dbus-run-session -- docs/superpowers/scripts/wl-drive.py OUT vlc: sleep:3 key:ctrl+p sleep:2 shot`, or use the driver's own step names. The rounded corners and shadow draw, the top bar drags and an edge resizes.
- [ ] **Step 2: Bring the Ledger up to date**, and mark roadmap row 7 done.
- [ ] **Step 3: Commit**, then merge per superpowers:finishing-a-development-branch.

---

## Ledger

Departures from the frames (the spec's *(my call)* items, plus any found while building), and known limits:

- **Rows not built** (no VLC equivalent, or Figma copy-paste): see the "—" rows in the spec's tables.
- **Rows hidden at run time** when the build lacks their option or plugin (the check script's allow-list names the platform-only ones).
- **Added rows:** General ▸ All settings, Controls ▸ Password.
- **Dropdown wording** is VLC's own choice labels where VLC has a list.
- **Startup volume's "Always starts at" field** is read-only at 100 %.
- **Keyboard shortcuts** open the legacy dialog's Hotkeys panel until slice 8.
- **Accent:** the SVG icons with orange baked in stay orange. The accent may apply only after a restart.
- **Theme Light** is VLC 4's light palette until slice 10.
