# Settings Apply-on-Change Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every Settings row either applies to the running app the moment it changes or carries a "Next video" / "After restart" tag. The 4 dead rows are wired up or removed.

**Architecture:** Every Settings write already goes through `SettingsBridge::setValue` (custom rows and `setListHas` included), and that emits `changed(name)`. A new `SettingsApplier` listens to that signal and, by a fixed option → kind table, pushes the new value live. It uses three paths:
1. **Output vars:** the playing audio/video outputs, through `PlayerEffects`.
2. **Player:** the player and play-queue APIs.
3. **Interface:** `MainCtx`, which reloads its prefs and tells the window handlers.

The "when does it apply" tag is a new `applies` field per row in `SettingsData.js`, drawn as a chip by `SettingsRowDelegate`.

**Tech Stack:** C++17 / Qt 6 (Quick, QML), libvlc core APIs (`vlc_player_*`, `vlc_playlist_*`, `var_*`), Qt Test, QML TestCase, meson (autotools `Makefile.am` kept in step).

**Spec:** `docs/superpowers/specs/2026-11-08-vlc-redesign-settings-apply-design.md`. Read it, including the Appendix table of all 182 rows.

## Global Constraints

- Tag text exactly `Next video` and `After restart` (qsTr). About 11 px, a quiet grey chip after the row name and its ⓘ, radius 4, padding 2×7, colours from `theme.palette.tokens` (Light and Dark). Row height unchanged.
- Rows that apply on change get **no** chip.
- No reopening the current media and no restarting VLC to apply anything.
- **One way:** Settings → player. Never write Settings defaults from the player's own controls. The exception is repeat/shuffle, which already share config.
- Keep save-on-close (`SettingsBridge::save` from `SettingsWindow.qml`) as is.
- Dark theme visuals unchanged apart from the chip. `docs/superpowers/scripts/check-theme-literals.sh` stays clean (no new hex literals).
- Qt suite stays green (currently 29/29) plus the new tests. Every source/test added to `modules/gui/qt/meson.build` is also added to `modules/gui/qt/Makefile.am`.
- Harness runs are silent: `--aout=dummy` (the harness passes it). Never change GNOME settings. Never click "Open configurations folder" on the harness (it opens a file manager on the user's real desktop).
- Harness: `docs/superpowers/scripts/vlc-xvfb.sh start -vv --loop build/redesign-media/longsub.mkv`. Open Settings via "…" (54,20) ▸ Settings (118,543). After each run, grep `build/redesign-profile/run/vlc.log` for `TypeError|ReferenceError|non-existent|unavailable`. Back up `build/redesign-profile/config/vlc/vlcrc` before a run and restore it after.

## Review Focus

1. **Changing a live setting with nothing playing** (library open, no aout/vout/input). It must not crash or warn-spam. The value saves and is used when playback starts. → Task 2 Step 1 (`applyWithNoPlayback`) and Task 3 harness step.
2. **Changing one row must not re-push other defaults** onto the media. For example, after the player's speed button sets 1.5×, changing the equalizer must leave the rate at 1.5×. The applier acts only on the option named in `changed(name)`. → Task 2 test `onlyNamedOptionApplied`, Task 3 harness step.
3. **Reset all settings / Reset all shortcuts / per-row reset** emit `changed("")` or many names. An empty name must be ignored, with no live push of every option. → Task 2 test `emptyNameIgnored`.
4. **Slider drags** (speed, sub delay, picture) write on every move. Each write pushes live without piling up or stalling, and the last value wins. → Task 3 harness step (drag Default playback speed).
5. **A changed interface setting must not apply unrelated start-up options.** Today `MainCtx::loadPrefs` calls `setMinimalView` from `qt-minimal-view`, so a reload would switch to compact mode. → Task 4 Step 1 test `reloadKeepsMinimalView`.

---

### Task 1: The "applies" tag, and the two removed rows

**Files:**
- Modify: `modules/gui/qt/dialogs/settings/qml/SettingsData.js` (header comment + rows)
- Modify: `modules/gui/qt/dialogs/settings/qml/SettingsRowDelegate.qml` (chip after the label)
- Modify: `modules/gui/qt/dialogs/settings/qml/rows/BufferingRows.qml` (fullRow: draws its own label; add the chip there)
- Test: `modules/gui/qt/tests/tst_SettingsData.qml`
- Modify: `.gitignore` (add `.superpowers/`)

**Interfaces:**
- Produces: row field `applies: "next" | "restart"` (absent = applies on change). Exported `function appliesText(row)` in SettingsData.js returns `qsTr("Next video")`, `qsTr("After restart")` or `""`. Delegates and custom rows use it.

- [ ] **Step 1: Write the failing tests** in `tst_SettingsData.qml`

```qml
function rowsByOption() {               // first option of each row → row
    const m = {}
    for (const p of Data.pages) for (const s of p.sections) for (const r of s.rows)
        m[r.option ?? r.list ?? r.component ?? r.action] = m[r.option ?? r.list ?? r.component ?? r.action] ?? r
    return m
}
function test_appliesValues() {
    for (const p of Data.pages) for (const s of p.sections) for (const r of s.rows)
        verify(r.applies === undefined || r.applies === "next" || r.applies === "restart", r.label)
}
function test_appliesSpot() {
    const m = rowsByOption()
    compare(m["dec-dev"].applies, "next")
    compare(m["sub-autodetect-file"].applies, "next")
    compare(m["aout"].applies, "next")             // see Task 3 ruling
    compare(m["media-library"].applies, "restart")
    compare(m["file-logging"].applies, "restart")
    compare(m["qt-icon-change"].applies, "restart")
    compare(m["BufferingRows.qml"].applies, "next")
    compare(m["volume-save"].applies, "restart")      // Startup volume (custom row)
    compare(m["rate"].applies, undefined)
    compare(m["qt-max-volume"].applies, undefined)
    compare(m["freetype-color"].applies, undefined)
    compare(Data.appliesText(m["dec-dev"]), "Next video")
    compare(Data.appliesText(m["media-library"]), "After restart")
    compare(Data.appliesText(m["rate"]), "")
}
function test_deadRowsRemoved() {
    const m = rowsByOption()
    compare(m["qt-fs-sensitivity"], undefined)
    compare(m["playlist-tree"], undefined)
    verify(m["qt-fs-controller"] !== undefined)
    verify(m["qt-error-dialogs"] !== undefined)
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `meson test -C build qml_test_tst_SettingsData --print-errorlogs` (or the name `meson test -C build --list | grep SettingsData` shows)
Expected: FAIL on `appliesText` not a function / `applies` undefined.

- [ ] **Step 3: Implement**
  - Add `applies` to the header's field list: `applies  "next" (read when a video, decoder or output starts) | "restart" (read when VLC starts); absent = applies on change`.
  - Set `applies: "next"` on every row in the spec Appendix with class NEXT, **except** Default audio track and Default subtitle track (PLAYER per the spec ruling). Also set it on Output device (`aout`).
  - Set `applies: "restart"` on every LAUNCH row, plus Allow the app icon to change (`qt-icon-change`: the icon is set once at start, so it moves from UI to restart).
  - Set it on the custom rows Buffering (`"next"`) and Startup volume (`"restart"`).
  - Remove the rows for `qt-fs-sensitivity` and `playlist-tree`.
  - Add `appliesText(row)`. Chip: a small `Rectangle` + `Text` after the ⓘ in the delegate's label line. Text colour token FG/A3-ish, fill BG/A2-ish (pick the nearest tokens in `theme.palette.tokens`), font ~11 px via `VLCStyle.dp(11, VLCStyle.scale)`, radius 4, padding 2×7.
  - BufferingRows draws its own label: put the same chip there. Factor the chip as a small inline `component AppliesChip` in the delegate, or a file in `rows/`. Either is fine; one definition only.
  - Search results use the same delegate, so they get the chip for free. Check it.

- [ ] **Step 4: Run, expect PASS**; also run the whole Qt suite: `meson test -C build --suite qt` (or all `test_qt_*` + `qml_test_*`). Expected: all pass.

- [ ] **Step 5: Harness look.** Open Settings ▸ Performance and Settings ▸ Audio (Startup volume), Dark then Light (General ▸ Theme). Shoot both. The chip sits right after the ⓘ, rows keep their height, and it's readable but quiet in both themes. Search "decod" and see the chip in results. Run `check-theme-literals.sh`.

- [ ] **Step 6: Commit**

```bash
git add .gitignore modules/gui/qt/dialogs/settings/qml modules/gui/qt/tests/tst_SettingsData.qml
git commit -m "qt: settings rows say when they apply (Next video / After restart); drop two dead rows"
```

---

### Task 2: SettingsApplier and the output-var path

**Files:**
- Create: `modules/gui/qt/dialogs/settings/settings_apply_kind.hpp` (header-only, pure: no VLC player deps)
- Create: `modules/gui/qt/dialogs/settings/settings_apply.hpp`, `settings_apply.cpp`
- Modify: `modules/gui/qt/player/player_effects.hpp/.cpp` (split the live push out of `setValue`)
- Modify: `modules/gui/qt/maininterface/mainui.cpp:~292,~334` (create bridge, effects, applier together)
- Modify: `modules/gui/qt/meson.build`, `modules/gui/qt/Makefile.am`
- Test: `modules/gui/qt/tests/test_settings_apply_kind.cpp` (new meson test `test_qt_settings_apply_kind`)

**Interfaces:**
- Produces (`settings_apply_kind.hpp`, namespace `settingsapply`):
  - `enum class Kind { None, OutputVar, Player, Interface };`
  - `Kind kindOf(const QString& option);`. Fixed tables:
    - **OutputVar:** `aspect-ratio crop zoom autoscale deinterlace deinterlace-mode video-wallpaper sub-margin stereo-mode audio-filter video-filter equalizer-bands equalizer-preamp equalizer-2pass pitch-shift audio-visual audio-replay-gain-mode hue brightness contrast saturation gamma`
    - **Player:** `rate audio-desync sub-delay sub-text-scale video audio spu audio-track sub-track repeat loop random play-and-stop play-and-exit`
    - **Interface:** `qt-video-autoresize video-on-top qt-name-in-title mouse-hide-timeout qt-system-tray qt-notification qt-opacity qt-pause-minimized qt-bgcone qt-fs-opacity qt-max-volume qt-error-dialogs qt-fs-controller`
    - anything else, and `""` → `None`.
- Produces: `void PlayerEffects::pushToOutputs(const QString& name, const QVariant& v);`. Sets the var on the aout and every vout that has it (today's body of `setValue` minus the config write). `setValue` becomes `pushToOutputs` + `setConfigValue`.
- Produces: `class SettingsApplier : public QObject` with `SettingsApplier(qt_intf_t* intf, SettingsBridge* bridge, PlayerEffects* effects, QObject* parent);`. It connects `bridge->changed` to `void apply(const QString& option);`. `apply` reads the value with `bridge->value(option)`, then switches on `kindOf(option)`: OutputVar → `effects->pushToOutputs`; Player → `applyPlayer(option, value)` (Task 3, a no-op here); Interface → `applyInterface(option)` (Task 4, a no-op here); None → nothing.

- [ ] **Step 1: Write the failing test** `test_settings_apply_kind.cpp`

```cpp
void kinds() {
    using namespace settingsapply;
    QCOMPARE(kindOf("aspect-ratio"), Kind::OutputVar);
    QCOMPARE(kindOf("audio-filter"), Kind::OutputVar);
    QCOMPARE(kindOf("hue"), Kind::OutputVar);
    QCOMPARE(kindOf("rate"), Kind::Player);
    QCOMPARE(kindOf("loop"), Kind::Player);
    QCOMPARE(kindOf("qt-max-volume"), Kind::Interface);
    QCOMPARE(kindOf("qt-fs-controller"), Kind::Interface);
}
void emptyNameIgnored()       { QCOMPARE(settingsapply::kindOf(""), settingsapply::Kind::None); }
void tagsAreNeverLive() {     // rows tagged in Task 1 must not also be pushed live
    for (const char* o : {"fullscreen", "dec-dev", "aout", "video-title-show", "qt-minimal-view",
                          "volume-save", "qt-icon-change", "custom-aspect-ratios", "align"})
        QCOMPARE(settingsapply::kindOf(o), settingsapply::Kind::None);
}
```

The applier's behaviour with nothing playing (Review Focus 1), and with only the named option (Review Focus 2), is checked on the harness in Task 3. Its body is plain dispatch, and the live objects can't be faked in this test env.

- [ ] **Step 2: Run, expect FAIL** (does not compile: header missing).
Run: `meson test -C build test_qt_settings_apply_kind --print-errorlogs`

- [ ] **Step 3: Implement** `kindOf` (static `QSet<QString>` tables), `pushToOutputs`, and `SettingsApplier`. In `MainUI` keep the `SettingsBridge*` and `PlayerEffects*` you register as singletons, and construct `new SettingsApplier(m_intf, bridge, effects, this)` once both exist. Register test + sources in meson.build and Makefile.am.

- [ ] **Step 4: Run, expect PASS**; whole Qt suite green.

- [ ] **Step 5: Harness check (OutputVar).** While `longsub.mkv` plays, change each of these in Settings and confirm the video/audio changes **without** reopening:
  - Video ▸ Hue (move the window aside with `xdotool windowmove` to see the video): colours shift. The Picture rows enable the `adjust` filter through `video-filter`.
  - Aspect ratio 16:9 → 4:3, Crop, Zoom, Scale video to the window, Deinterlacing.
  - Subtitles ▸ Vertical position: the subtitle moves.
  - Audio ▸ Equalizer preset, Speaker setup, a spatial/effect toggle, Visualizer: check via `vlc.log` (`-vv` shows filter loads) since audio is dummy.

  Any row that does **not** apply: drop its option from the OutputVar table, give the row `applies: "next"`, and add a Ledger line. Restore vlcrc.

- [ ] **Step 6: Commit**

```bash
git add modules/gui/qt/dialogs/settings modules/gui/qt/player/player_effects.* modules/gui/qt/maininterface/mainui.cpp modules/gui/qt/meson.build modules/gui/qt/Makefile.am modules/gui/qt/tests/test_settings_apply_kind.cpp
git commit -m "qt: settings push video/audio output options to the playing media"
```

---

### Task 3: Player and play-queue path

**Files:**
- Modify: `modules/gui/qt/dialogs/settings/settings_apply.cpp` (`applyPlayer`)
- Modify: `modules/gui/qt/dialogs/settings/qml/rows/RepeatRow.qml` and the Shuffle row's re-read (see Step 3)

**Interfaces:**
- Consumes: `SettingsApplier::apply` dispatch (Task 2), `kindOf` Player table.
- Produces: `void SettingsApplier::applyPlayer(const QString& option, const QVariant& value);`

- [ ] **Step 1: Implement `applyPlayer`** (no unit test: it drives the live player; verified on the harness). The value → call mapping is fixed:

| option | call |
|---|---|
| `rate` | `THEMIM->setRate(value.toFloat())` |
| `audio-desync` (ms) | `THEMIM->setAudioDelayMS(value.toInt())` |
| `sub-delay` (1/10 s) | `THEMIM->setSubtitleDelayMS(value.toInt() * 100)` |
| `sub-text-scale` (%) | `effects->setSubtitleTextScale(value.toInt())` |
| `video` / `audio` / `spu` | `vlc_player_SetTrackCategoryEnabled(player, VIDEO_ES / AUDIO_ES / SPU_ES, value.toBool())` (player locked) |
| `audio-track` / `sub-track` | if value ≥ 0 and < track count: select `vlc_player_GetTrackAt(player, AUDIO_ES / SPU_ES, value)`; else nothing |
| `repeat` / `loop` | `THEMPL->setRepeatMode(config repeat ? REPEAT_CURRENT : config loop ? REPEAT_ALL : REPEAT_NONE)`. Read **both** options from config (RepeatRow writes them one after the other) |
| `random` | `THEMPL->setRandom(value.toBool())` |
| `play-and-stop` / `play-and-exit` | `THEMPL->setMediaStopAction(config play-and-exit ? EXIT : config play-and-stop ? STOP : CONTINUE)`. Read both |

Do nothing when there is no current input (where a call needs one). Add a `PlayerController` accessor for the raw `vlc_player_t*` only if none exists.

**Output device ruling:** `aout` stays tagged "Next video" (Task 1). VLC 4 has no public run-time output-module switch. Add a Ledger line.

- [ ] **Step 2: Keep the Settings rows in step with the queue.** RepeatRow and the Shuffle toggle re-read when `PlaylistController::repeatModeChanged` / `randomChanged` fire. Bump the delegate's `reloadTick`, or have `SettingsBridge` emit `changed("repeat")` on those signals. Pick one and use it for both. The player's buttons already write the same config (`playlist_controller.cpp`).

- [ ] **Step 3: Harness check.** While `longsub.mkv` plays:
  - Default playback speed 2×: the clock runs 2× (two shots 4 s apart differ by ~8 s). **Drag** the slider across its range and release on 1.25×: it settles at 1.25× (Review Focus 4).
  - Then use the player's own speed button for 1.5×, change Settings ▸ Audio ▸ Equalizer: the rate stays 1.5× (Review Focus 2).
  - Subtitle delay +2 s, Audio delay: visible as the subtitle shift / log.
  - Enable subtitles off/on: the subtitle disappears/returns. Enable video off/on.
  - Repeat "Current": the queue card's repeat button shows the mode. Then click the player's repeat button and see Settings ▸ Playback ▸ Repeat follow (Settings open).
  - With **nothing playing** (press `s` in the player first), change speed, aspect ratio, equalizer, subtitle delay. No crash, no new warnings in `vlc.log` beyond one per change at most, and the values saved (Review Focus 1). Then play: the new defaults are used.
  - Restore vlcrc.

- [ ] **Step 4: Commit**

```bash
git commit -am "qt: settings push speed, delays, tracks and queue order to the player"
```

---

### Task 4: Interface path (reload, window handlers, tray)

**Files:**
- Modify: `modules/gui/qt/maininterface/mainctx.hpp/.cpp` (`loadPrefs`, new signal + slot, two new properties)
- Modify: `modules/gui/qt/maininterface/interface_window_handler.cpp:~67-90` (pause-on-minimize, opacity, name in title)
- Modify: `modules/gui/qt/maininterface/video_window_handler.cpp` (`qt-video-autoresize`)
- Modify: `modules/gui/qt/dialogs/systray/systray.cpp` and MainCtx's tray set-up (`qt-system-tray`, `qt-notification`)
- Modify: `modules/gui/qt/dialogs/settings/settings_apply.cpp` (`applyInterface`)
- Test: `modules/gui/qt/tests/test_mainctx_prefs.cpp` **only if** MainCtx can be constructed in the test env; otherwise this check is a harness step, recorded in the Ledger.

**Interfaces:**
- Produces: `void MainCtx::onSettingChanged(const QString& name);` (public slot). It calls `reloadPrefs()`, then `emit settingChanged(name)`.
- Produces: `signal void MainCtx::settingChanged(const QString& name);`. The window handlers and tray connect to it and re-read their own option when `name` matches.
- Produces: `Q_PROPERTY(bool errorDialogs READ errorDialogs NOTIFY errorDialogsChanged FINAL)` (`qt-error-dialogs`) and `Q_PROPERTY(bool fsController READ fsController NOTIFY fsControllerChanged FINAL)` (`qt-fs-controller`), both loaded in `loadPrefs`. They're used by Task 5.
- `applyInterface(option)` = `p_intf->p_mi->onSettingChanged(option)`.

- [ ] **Step 1: Stop `loadPrefs(true)` from applying `qt-minimal-view`.** Call `setMinimalView` from it only on the first load (`callSignals == false`), so the legacy dialog and the applier never flip compact mode at run time (Review Focus 5). Test `reloadKeepsMinimalView`: set `qt-minimal-view` true in config, call `reloadPrefs()`, and `minimalView` stays false. Write it in the test file above if MainCtx is constructible; otherwise check on the harness (toggle Start in compact mode, then change Maximum volume: the view must not go compact).

- [ ] **Step 2: Implement** the slot/signal/properties and the per-owner re-reads:
  - **opacity:** `m_window->setOpacity`
  - **pause-on-minimize:** the member
  - **name in title:** connect/disconnect `nameChanged`, and set the title to the current name or `""` now
  - **autoresize:** the member
  - **tray:** create/destroy the tray icon; update the notification setting

- [ ] **Step 3: Build, run the Qt suite (green).**

- [ ] **Step 4: Harness check.** Change each and see it without restarting:
  - Maximum volume 300% (the bar's volume slider rescales)
  - Show the file name in the title bar (title text)
  - Hide after (cursor hide delay over the video)
  - Show cover art (play an audio file from `build/redesign-media`)
  - Fullscreen controls opacity (fullscreen with `f`)
  - Keep window above other windows (flag only; log it)
  - Window opacity (Xvfb has no compositor: check `xprop _NET_WM_WINDOW_OPACITY` on the main window)
  - System tray: the icon appears/disappears (`xdotool search --class` / log)

  Rows that can't be verified on Xvfb go in the Ledger as "code only". Restore vlcrc.

- [ ] **Step 5: Commit**

```bash
git commit -am "qt: interface settings apply on change; reload no longer flips compact mode"
```

---

### Task 5: The two rewired dead rows

**Files:**
- Modify: `modules/gui/qt/dialogs/dialogs/qml/Dialogs.qml:~145` (error pop-up)
- Modify: `modules/gui/qt/player/qml/Player.qml` (fullscreen control bar) and, if the bar's show/hide lives there, `PlayerToolbarVisibilityFSM.qml`

**Interfaces:**
- Consumes: `MainCtx.errorDialogs`, `MainCtx.fsController` (Task 4).

- [ ] **Step 1: Implement.**
  - **Error pop-up:** `onCountChanged` shows the pop-up only when `MainCtx.errorDialogs`. The model still collects the error, so the messages log keeps it. Confirmations that guard Reset/delete are unaffected; they don't go through this model.
  - **Fullscreen bars:** with `MainCtx.fsController` false, the bars never show in fullscreen. The top and bottom bars stay hidden on mouse move, the cursor still shows, and keyboard shortcuts still work. Windowed mode is unchanged. Applies live.

- [ ] **Step 2: Harness check.**
  - **Error pop-up:** trigger an error, e.g. open a missing file with `vlc-static … /nonexistent.mkv` via the "…" ▸ Open Network Stream with `file:///nonexistent.mkv`. On: the pop-up shows. Off: none, and the error is in `vlc.log`.
  - **Fullscreen bars:** press `f`, move the mouse. Bars show with the row on and stay hidden with it off. Toggle the row while fullscreen.

- [ ] **Step 3: Commit**

```bash
git commit -am "qt: wire 'Show confirmation and error dialogs' and 'Show controls in fullscreen'"
```

---

### Task 6: Buttons, whole sweep, docs

**Files:**
- Modify: this plan's `## Ledger`
- Modify: `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md` (new row "11 Settings apply (done)" after 10)

- [ ] **Step 1: Buttons.** Check on the harness and record the result:
  - Reset all settings: confirm dialog, then the restart prompt. Run it on a **backed-up** profile and restore afterwards.
  - Reset all shortcuts: confirm. The keys revert after restart, per slice 8.
  - Privacy ▸ Clear history now: the Home "Continue Watching" row empties.
  - Open configurations folder: **code-read only** (`SettingsBridge::openConfigFolder` → `QDesktopServices::openUrl`). Don't click it on the harness.

- [ ] **Step 2: Sweep.** For every row in the spec Appendix with class PLAYER or UI, confirm it was checked in Tasks 2–5 or moved to a tag (Ledger line). For 5 LIVE rows not yet checked (Font, Show feedback for shortcuts, Format/snapshot, When opening a folder, OpenSubtitles API key), check them once.

- [ ] **Step 3: Whole suite + theme lint + log grep clean.** Roadmap row 11: scope "Settings rows apply on change or say when (Next video / After restart)", plan link, departures = the Ledger summary.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers
git commit -m "docs: settings apply ledger and roadmap row 11"
```

## Ledger

(Departures, rows moved between classes, and "code only" checks go here as tasks find them.)

- Output device (`aout`) is tagged "Next video": VLC 4 has no public run-time output-module switch. (Plan ruling)
- Allow the app icon to change (`qt-icon-change`) moved from UI to "After restart": the icon is set once at start. (Plan ruling)
