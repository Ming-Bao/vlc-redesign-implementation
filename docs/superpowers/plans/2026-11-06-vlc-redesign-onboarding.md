# Onboarding (slice 9) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace VLC's Qt-widgets first-run wizard with the Figma's three-page onboarding card (Welcome + media folder, Theme + accent, Keyboard shortcuts), and make the accent colour apply live.

**Architecture:**
- **`OnboardingWindow.qml`** is a `DialogCard` (slice 8) with no title bar. It holds the three pages in one file and is loaded from `MainInterface.qml`'s `dialogWindows` on a new `DialogsProvider::showOnboarding()` signal.
- **`OnboardingController`** (C++ singleton `Onboarding` in `VLC.Dialogs`) does the parts QML can't: the folder field rules, the folder picker, and Finish/skip writes. Its path rules are free functions with their own unit test.
- **The live accent:** `SystemPalette` re-reads `qt-accent-color` on every `updatePalette()`, and reruns that when `MainCtx::accentColorChanged()` fires.

**Tech Stack:** Qt 6 QML (QtQuick, Templates, Window), C++ (libvlccore config, media library), meson and Makefile.am, QtTest and QtQuickTest. Figma MCP for the cone and the preview icons (load `figma:figma-design-to-code` before `get_design_context`).

**Spec:** `docs/superpowers/specs/2026-11-06-vlc-redesign-onboarding-design.md`. Its tables hold the Figma values and copy; tasks don't repeat them.

## Global Constraints

- **Figma is the source of truth** (`dSoAm0gN9ZterHSssJU9FN`). Frames are in the spec's first table, shots in `docs/superpowers/figma/9/`. VLC 4's look is not a reference.
- **Every Figma px value is written `VLCStyle.dp(n, VLCStyle.scale)`.**
- **Inside the card, accent-coloured parts use the card's own `accent` property** (the chosen swatch), not `theme.accent`. This is because the card previews the choice before it is saved. Everything else keeps `theme.accent`.
- **The nine accent colours live in one place.** `AccentRow.qml`'s list moves to a shared `AccentSwatches.js` in `VLC.Dialogs`, and both users import it.
- **All strings go through `qsTr`/`qtr`.** Copy is the spec's, verbatim.
- **Silent runs:** the harness passes `--aout=dummy`; any hand-rolled run adds it too. Clear `RecoveryFilePath=` from `build/redesign-profile/config/vlc/vlc-qt-interface.conf` before each run.
- **Git:** branch `redesign/onboarding` (exists, holds the spec). Commits use the global git user, no Co-Authored-By.
- **After each task:**
  - `ninja -C build` builds;
  - `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt` is all OK;
  - after any app run, `grep -E 'TypeError|ReferenceError|non-existent property|unavailable|Cannot assign' build/redesign-profile/run/vlc.log` finds nothing new. Start with `docs/superpowers/scripts/vlc-xvfb.sh start -vv`, otherwise the log is near empty and the grep passes vacuously.
- **New files:** QML, JS and C++ files go in `modules/gui/qt/meson.build`, `Makefile.am`, `po/POTFILES.in` (C++ and QML) and `qt6.pro`. QML and JS go in the `VLC.Dialogs` list. Assets go in `assets.qrc`, `Makefile.am` and the meson resource list.

## Review Focus

1. **The folder field holding `~`, `~/`, a trailing slash, a file instead of a folder, or a folder with spaces.** Next is on only for a real folder (or an empty field), and Finish adds exactly that folder. Tests in Task 2, Step 1.
2. **Escape on page 2 or 3 after choices were made, and closing the window from the WM.** Nothing is written but `qt-privacy-ask=0`, and onboarding does not come back on the next launch. Task 4, Step 7.
3. **A key option whose value is empty, has two tab-separated bindings, or uses a modifier VLC spells differently (`Ctrl+Alt+…`, `Command+…` on macOS).** Each shows sensible caps, never a blank cap. Test in Task 3, Step 1.
4. **Picking an accent, then Back to page 1 and Next again.** The choice and the field text survive, because pages are not recreated. Task 4, Step 7.
5. **A 1366 × 768 screen, or `VLCStyle.scale` 1.5.** The card is capped at 90 % of the screen and nothing is cut off; the preview scales with the card. Task 4, Step 7.

---

### Task 1: Live accent

**Files:**
- Modify: `modules/gui/qt/style/systempalette.{hpp,cpp}` (`componentComplete`, `updatePalette`, `setCtx`), `maininterface/mainctx.hpp` (signal + invokable), `dialogs/settings/qml/rows/AccentRow.qml`
- Create: `modules/gui/qt/dialogs/dialogs/qml/AccentSwatches.js`

**Interfaces:**
- Produces: signal `MainCtx::accentColorChanged()`; `Q_INVOKABLE void MainCtx::reloadAccentColor()`, which only emits it.
- Produces: `AccentSwatches.js` (`.pragma library`): `const colors = ["#D37918", "#E15032", "#C49E23", "#19A234", "#18AAD3", "#185DD3", "#8E42FF", "#F052B3", "#AFAFAF"]`; `function optionValue(hex)` returns `"default"` for `colors[0]`, else `hex`; `function fromOption(v)` returns `colors[0]` for `"default"`/empty, else `v.toUpperCase()`.

- [x] **Step 1: Commit the plan**

```bash
git add docs/superpowers/plans/2026-11-06-vlc-redesign-onboarding.md docs/superpowers/specs/2026-11-06-vlc-redesign-onboarding-design.md
git commit -m "docs: onboarding plan"
```

- [ ] **Step 2: Move the accent read into `updatePalette()`**

Make it a private `void SystemPalette::readAccent()`, called first thing in `updatePalette()`. `componentComplete` then only calls `updatePalette()`. `"default"` must reset `orange500`/`orange800` to their `COLOR_DEFINITION` values; today it relies on never having changed them. In `setCtx`, connect `ctx` `accentColorChanged` to `updatePalette` (disconnect the old ctx first).

- [ ] **Step 3: Shared swatches; AccentRow applies live**

`AccentRow.qml` imports `AccentSwatches.js`, drops its own list, writes `optionValue(...)` and then calls `MainCtx.reloadAccentColor()`. Update the file's header comment: the accent now applies at once.

- [ ] **Step 4: Verify**

Run: `docs/superpowers/scripts/vlc-xvfb.sh start -vv`, open Settings (Ctrl+P) ▸ General, click the green swatch, close Settings, take a shot.
Expected: the play button, the seek fill and the sidebar's active item are `#19A234`, with no restart. Click orange: back to `#D37918`. The log grep is clean.

- [ ] **Step 5: Commit**

```bash
git add modules/gui/qt
git commit -m "qt: the accent colour applies without a restart"
```

### Task 2: Folder rules and the onboarding controller

**Files:**
- Create: `modules/gui/qt/dialogs/onboarding/onboarding_folders.{hpp,cpp}`, `dialogs/onboarding/onboarding_controller.{hpp,cpp}`, `modules/gui/qt/tests/test_onboarding_folders.cpp`
- Modify: `maininterface/mainui.cpp` (register the singleton), `meson.build` (test `test_qt_onboarding_folders` beside `test_qt_saved_streams`)

**Interfaces:**
- Consumes: `MainCtx::reloadAccentColor()` (Task 1).
- Produces, in `namespace onboarding` (`onboarding_folders.hpp`, no VLC deps):
  - `QString expandHome(const QString& text, const QString& home)`. `~` → home and `~/x` → home/x; anything else is unchanged; the result is trimmed and `QDir::cleanPath`ed.
  - `QString displayPath(const QString& path, const QString& home)`. home or under home → `~` / `~/…`.
  - `bool fieldValid(const QString& text, const QString& home)`. Blank → true; else `QFileInfo(expandHome(...)).isDir()`.
  - `QStringList foldersToAdd(const QString& chosen, const QString& music)`. Both arguments are already expanded and may be empty. It returns `chosen` if non-empty, then `music` if non-empty and neither equal to `chosen` nor inside it.
- Produces `OnboardingController`, the QML singleton `Onboarding` in `VLC.Dialogs`, built with the `qt_intf_t*`:
  - `Q_PROPERTY(bool hasMediaLibrary READ … CONSTANT)`;
  - `Q_PROPERTY(QString defaultFolder READ … CONSTANT)`: `displayPath` of `config_GetUserDir(VLC_VIDEOS_DIR)`, or `""` when that folder doesn't exist;
  - `Q_INVOKABLE bool folderValid(const QString& text) const`;
  - `Q_INVOKABLE QString pickFolder(const QString& text)`: `QFileDialog::getExistingDirectory` starting at the expanded text (or home), returning the `displayPath` or `""` on cancel;
  - `Q_INVOKABLE void finish(int scheme, const QString& accent, const QString& folderText)`;
  - `Q_INVOKABLE void skip()`.

- [ ] **Step 1: Write the failing test `tests/test_onboarding_folders.cpp`**

```cpp
void expandHome_cases() {
    QCOMPARE(onboarding::expandHome("~", "/h"), QString("/h"));
    QCOMPARE(onboarding::expandHome("~/", "/h"), QString("/h"));
    QCOMPARE(onboarding::expandHome(" ~/My Videos/ ", "/h"), QString("/h/My Videos"));
    QCOMPARE(onboarding::expandHome("/abs/x/", "/h"), QString("/abs/x"));
    QCOMPARE(onboarding::expandHome("~other", "/h"), QString("~other"));
}
void displayPath_cases() {
    QCOMPARE(onboarding::displayPath("/h/Videos", "/h"), QString("~/Videos"));
    QCOMPARE(onboarding::displayPath("/h", "/h"), QString("~"));
    QCOMPARE(onboarding::displayPath("/hx/Videos", "/h"), QString("/hx/Videos"));
}
void fieldValid_cases() {
    QTemporaryDir d; QDir(d.path()).mkdir("My Videos");
    QFile f(d.path() + "/file"); QVERIFY(f.open(QIODevice::WriteOnly));
    QVERIFY(onboarding::fieldValid("  ", d.path()));
    QVERIFY(onboarding::fieldValid("~/My Videos", d.path()));
    QVERIFY(!onboarding::fieldValid("~/file", d.path()));
    QVERIFY(!onboarding::fieldValid("~/missing", d.path()));
}
void foldersToAdd_cases() {
    QCOMPARE(onboarding::foldersToAdd("/h/V", "/h/M"), (QStringList{"/h/V", "/h/M"}));
    QCOMPARE(onboarding::foldersToAdd("", "/h/M"), QStringList{"/h/M"});
    QCOMPARE(onboarding::foldersToAdd("/h", "/h/M"), QStringList{"/h"});        // music inside chosen
    QCOMPARE(onboarding::foldersToAdd("/h/M", "/h/M"), QStringList{"/h/M"});    // same
    QCOMPARE(onboarding::foldersToAdd("/h/Mu", "/h/M"), (QStringList{"/h/Mu", "/h/M"})); // prefix, not inside
    QCOMPARE(onboarding::foldersToAdd("/h/V", ""), QStringList{"/h/V"});
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `meson test -C build test_qt_onboarding_folders`
Expected: FAIL, `onboarding_folders.hpp` not found.

- [ ] **Step 3: Implement the four functions**

The inside test compares `cleanPath` results with a trailing `/` appended, so `/h/Mu` is not inside `/h/M`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `meson test -C build test_qt_onboarding_folders`
Expected: OK.

- [ ] **Step 5: Implement `OnboardingController` and register it**

`finish(scheme, accent, folderText)` does, in order:
1. `p_mi->getColorScheme()->setScheme(static_cast<ColorSchemeModel::ColorScheme>(scheme))`.
2. `config_PutPsz("qt-accent-color", …)` with the value QML passes, already `"default"` or a hex.
3. For each of `foldersToAdd(expandHome(folderText), <XDG Music if it exists>)`: the same `runOnMLThread` / `vlc_ml_add_folder` call as `DialogsProvider::addFolderToLibrary()`, with `QUrl::fromLocalFile`. Skip this step without a media library.
4. `config_PutInt("qt-privacy-ask", 0)`, `getMediaLibrary()->reload()` if there is one, `config_SaveConfigFile`, then `p_mi->reloadAccentColor()`.

`skip()` does only `config_PutInt("qt-privacy-ask", 0)`, the media library reload and the save. It is idempotent.

Register the singleton in `mainui.cpp` next to `SettingsBridge`.

- [ ] **Step 6: Commit**

```bash
git add modules/gui/qt
git commit -m "qt: onboarding folder rules and controller"
```

### Task 3: Key caps and the file browser shortcut

**Files:**
- Create: `modules/gui/qt/dialogs/onboarding/qml/OnboardingKeys.js`, `modules/gui/qt/tests/tst_OnboardingKeys.qml`
- Modify: `menus/qml/GlobalShortcuts.qml`, `meson.build` (register `tst_OnboardingKeys` beside `tst_HotkeysData`)

**Interfaces:**
- Produces: `OnboardingKeys.js` (`.pragma library`):
  - `function caps(value)` returns an array of cap strings for one binding;
  - `const rows`: the spec's 12 rows as `{ label, keys: [optionOrLiteral, …] }`, left column first. A literal is written `"=Ctrl+L"`, so the queue row is `["=Ctrl+L"]` and the file browser row is `["=Ctrl+Shift+L"]`.

- [ ] **Step 1: Write the failing test `tests/tst_OnboardingKeys.qml`**

```qml
function test_caps() {
    compare(Keys.caps("Space"), ["Space"])
    compare(Keys.caps("Shift+s"), ["SHIFT", "S"])
    compare(Keys.caps("Ctrl+Alt+Left"), ["CTRL", "ALT", "←"])
    compare(Keys.caps("Up"), ["↑"])
    compare(Keys.caps("n\tMedia Next Track"), ["N"])      // first binding only
    compare(Keys.caps("Esc"), ["esc"])                     // as HotkeyModel::displayKeys
    compare(Keys.caps(""), ["—"])
    compare(Keys.caps(undefined), ["—"])
}
function test_rows() {
    compare(Keys.rows.length, 12)
    compare(Keys.rows[1].keys, ["key-jump-extrashort", "key-jump+extrashort"])
    compare(Keys.rows[8].keys, ["=Ctrl+L"])
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `QT_QPA_PLATFORM=offscreen meson test -C build tst_OnboardingKeys`
Expected: FAIL, `OnboardingKeys.js` not found.

- [ ] **Step 3: Implement `caps`**

Take the part before the first `\t`, split on `+`, upper-case the modifiers (`Shift`, `Ctrl`, `Alt`, `Meta`, `Command`) and single letters, and map `Left`/`Right`/`Up`/`Down` to the arrows and `Esc` to `esc`. Keep other names as written (`Space`, `F11`). Blank input gives `["—"]`.

- [ ] **Step 4: Run it to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen meson test -C build tst_OnboardingKeys`
Expected: OK.

- [ ] **Step 5: Add the shortcut**

In `GlobalShortcuts.qml`, add `ShortcutExt { sequence: "Ctrl+Shift+L"; enabled: MainCtx.playerView; onActivated: PlayerControlbarControls.libraryPanelOpen = !PlayerControlbarControls.libraryPanelOpen }`, importing what `PlayerControlbarControls` needs. First grep `modules/gui/qt` and `src/libvlc-module.c` for `Ctrl+Shift+L` / `Ctrl+Shift+l`; if it is taken, stop and report.

- [ ] **Step 6: Verify the shortcut**

Run the app, play a sample, press Ctrl+Shift+L twice.
Expected: the side panel opens, then closes. In the library view nothing happens.

- [ ] **Step 7: Commit**

```bash
git add modules/gui/qt
git commit -m "qt: onboarding key caps; Ctrl+Shift+L toggles the player's file browser"
```

### Task 4: The onboarding window

**Files:**
- Create: `modules/gui/qt/dialogs/onboarding/qml/OnboardingWindow.qml`, and the cone asset if no existing one matches (`pixmaps/redesign/onboarding/cone.svg`)
- Modify: `dialogs/dialogs/qml/DialogCard.qml` (`showHeader`), `dialogs/dialogs_provider.{hpp,cpp}` (`firstRunDialog`), `maininterface/qml/MainInterface.qml` (`dialogWindows`), `docs/superpowers/scripts/vlc-xvfb.sh` (`seed`)
- Delete: `modules/gui/qt/dialogs/firstrun/` and its entries in `meson.build`, `Makefile.am` (sources, moc, ui header, `.ui`, `-I`), `qt6.pro` and `po/POTFILES.in`

**Interfaces:**
- Consumes: `Onboarding` (Task 2), `OnboardingKeys.js` (Task 3), `AccentSwatches.js` (Task 1), `SettingsBridge.value(option)`, `ColorSchemeModel.Night/Day/System`.
- Produces: `DialogCard.showHeader: bool` (default `true`). When false there is no title bar and the background drags the window. Signal `DialogsProvider::showOnboarding()`.

- [ ] **Step 1: `showHeader` on DialogCard**

When false, hide the title bar and give its height back to the body. A `DragHandler` (or the existing `startSystemMove` call) on the card background moves the window. Settings and the slice 8 dialogs must look unchanged. Shoot Settings before and after and compare.

- [ ] **Step 2: Route `firstRunDialog()`**

It emits `showOnboarding()` when the signal is connected. Otherwise (skins2 or no QML) it calls `config_PutInt("qt-privacy-ask", 0)` and saves; there is no legacy wizard to fall back to. Add a `Loader` + `Connections` in `dialogWindows`, following `networkStreamDialogLoader`.

- [ ] **Step 3: Build `OnboardingWindow.qml`**

- A `DialogCard`: `showHeader: false`, `showFooter: false`, `modal: true`, `figmaWidth: 1090`, `figmaHeight: 759`, `cardColor: "#0E0E0E"`, radius 14.
- State: `property color accent` (initialised from `AccentSwatches.fromOption(SettingsBridge.value("qt-accent-color"))`), `property int scheme: ColorSchemeModel.Night`, `property int page: 0`.
- The three pages sit in one `StackLayout` (not a Loader), so Back keeps what was typed. Layout, copy and values come from the spec's tables.
- Page 1: the field starts at `Onboarding.defaultFolder`. Browse calls `Onboarding.pickFolder(field.text)` and fills the field when the result isn't empty. Next is enabled when `Onboarding.folderValid(field.text)`. The folder block is visible when `Onboarding.hasMediaLibrary`.
- Page 2: tiles set `scheme`, swatches set `accent`. The preview is plain QML at the spec's sizes. Its icons are existing `VLCIcons` glyphs at the frame's sizes (prev, play, next, volume, the bar's right group, and the title bar's min/max/fullscreen/close). Get the values with `get_design_context` on `1902:3671`.
- Page 3: a `Repeater` over `OnboardingKeys.rows`. Each `"key-…"` entry is read with `SettingsBridge.value`, a `"=…"` entry is taken as written, and both go through `caps`. Pairs are joined by `/`, chords drawn with gap 4.
- Enter triggers Next/Finish. Finish calls `Onboarding.finish(scheme, AccentSwatches.optionValue(accent), field.text)` and closes. Escape and the window's `onClosing` call `Onboarding.skip()` once (guard with a flag), unless Finish already ran.

- [ ] **Step 4: The cone**

Check `pixmaps/` for the redesign's cone (`grep -ril cone modules/gui/qt/pixmaps/redesign`). If one is a fillable single-colour shape, reuse it and colour it with `accent`. Otherwise export `I1899:3056;51:798` as SVG through Figma, clean it with `docs/superpowers/scripts/clean-figma-svg.py`, and colour it with a `ColorOverlay`-free approach already used in the codebase (search for how `VLCIcons` or `Widgets.ScaledImage` tints).

- [ ] **Step 5: Delete the old wizard**

Remove the directory and every build and POTFILES entry. Check: `grep -rn firstrun modules/gui/qt po` shows only `firstRunDialog`.

- [ ] **Step 6: Rewrite `seed`**

Replace the old clicks with `xdotool key Return` three times, 2 s apart (Next, Next, Finish), then the existing `sleep 15` and stop.

- [ ] **Step 7: Verify against the frames**

Run: `docs/superpowers/scripts/vlc-xvfb.sh seed`, then a fresh profile started with `-vv` and without `--no-qt-privacy-ask`.

Shoot and compare with the frames:
- page 1 (`onboarding-01`);
- page 2 with orange (`onboarding-02`);
- page 2 with green (`onboarding-05`);
- page 3 (`onboarding-11`).

Then check each of these:
- Finish with green: the main window is green with no restart. `vlc-qt-interface.conf`/`vlcrc` have `qt-accent-color=#19A234` and `qt-privacy-ask=0`. The library lists `build/redesign-media` and `build/redesign-music`.
- Fresh profile, Escape on page 2 after picking red: `qt-privacy-ask=0`, the accent is still orange, no folder was added. A restart shows no onboarding.
- Type `~/nope`: Next is dimmed and does nothing. Clear the field: Next is on.
- Pick red, Back, Next: red is still picked, and the field text is unchanged.
- Run with `--qt-interface-scale=1.5` on the 1600 × 900 Xvfb screen: the card fits, nothing is clipped.
- The log grep is clean, and `coredumpctl list --since -10min | grep vlc` is empty.

- [ ] **Step 8: Commit**

```bash
git add -A modules/gui/qt po docs/superpowers/scripts
git commit -m "qt: Figma onboarding replaces the first-run wizard"
```

### Task 5: Ledger, roadmap, branch check

**Files:**
- Modify: this plan (`## Ledger`), `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md` (rows 7 and 9)

- [ ] **Step 1: Write the Ledger and mark the roadmap**

`## Ledger` lists every *(my call)* from the spec that shipped, plus anything changed during the build. Row 9: scope and departures, marked done. Row 7: drop "accent applies on the next launch".

- [ ] **Step 2: Run the whole branch check**

Run: `ninja -C build && QT_QPA_PLATFORM=offscreen meson test -C build --suite qt && python3 docs/superpowers/scripts/check-settings-options.py && coredumpctl list --since -2h | grep vlc`
Expected: builds, all OK, the script is clean, no new coredumps.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers
git commit -m "docs: onboarding ledger and roadmap"
```

## Ledger

*(filled in Task 5)*
