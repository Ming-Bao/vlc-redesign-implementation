# Light theme (slice 10) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Light theme the Figma's light look on every redesign surface, by swapping each `Dark/*` token for its `Light/*` partner, and make System pick between the two Figma palettes.

**Architecture:**
- **One C++ token table** (`style/figmatokens.{hpp,cpp}`) holds both themes. It is the only place a token's hex is written.
- **`SystemPalette`** builds both palettes from the table and exposes the active theme's tokens to QML as a typed gadget: `theme.palette.tokens.<name>`.
- **Every QML `isDark ? "<hex>" : theme.<VLC 4 colour>` binding** becomes one token read.
- **The menu style and the menu icons** read the main palette's lightness through a static on `MenuStyle`.

**Tech Stack:** Qt 6 C++ (QObject, Q_GADGET, QProxyStyle, QIconEngine), QML, meson and Makefile.am, QtTest. Harness: `docs/superpowers/scripts/vlc-xvfb.sh`.

**Spec:** `docs/superpowers/specs/2026-11-06-vlc-redesign-light-theme-design.md`.
- Its token table (last column) holds the light values, and its player table holds the frame's values. Tasks don't repeat them.
- The reference shot is `docs/superpowers/figma/10/player-light-2425-13624.png`.

## Global Constraints

- **Figma is the source of truth** (`dSoAm0gN9ZterHSssJU9FN`, frame `2425:13624`, the `Light/*` paint styles). Where the spec overrides a Figma value, the spec wins; those overrides are marked *(my call)* there.
- **Token names in code** are the Figma names in lower camel case:
  - `fg1`, `fg2`, `fgA1`…`fgA4`, `fgB1`;
  - `bgA1`…`bgA5`, `bgB1`, `bgB2`, `bgA3Transparent`, `bgB1Transparent`, `bgB2Transparent`;
  - `dividerDim`, `dividerBright`;
  - `accent`, `accentBright`, `accentDim`, `logo`, `accentBgBright`, `accentBgDark`.
- **Dark must not change.** Every Dark screen matches its pre-slice shot pixel for pixel, apart from the spec's departures. Task 1 takes the baseline before any code changes.
- **No hex literal of a dark token stays in QML/JS** unless its line ends with `// fixed colour: <reason>`. Reasons are the spec's "colours with meaning" and the onboarding card (always dark: it reads `VLCStyle.darkPalette.tokens`, so it needs none). The check script in Task 1 enforces this.
- **Silent runs:** the harness passes `--aout=dummy`; any hand-rolled run adds it too. Clear `RecoveryFilePath=` from `build/redesign-profile/config/vlc/vlc-qt-interface.conf` before each run.
- **The theme for a harness run** is `MainWindow/color-scheme-index` in that conf: 0 System, 1 Light (Day), 2 Dark (Night). Write it after the harness's conf restore.
- **Git:** branch `redesign/light-theme` (it exists and holds the spec). Commits use the global git user, with no Co-Authored-By.
- **After each task:**
  - `ninja -C build` builds;
  - `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt` is all OK;
  - after any app run, `grep -E 'TypeError|ReferenceError|non-existent property|unavailable|Cannot assign|Unable to assign' build/redesign-profile/run/vlc.log` finds nothing new. Start with `vlc-xvfb.sh start -vv`, otherwise the log is near empty and the grep passes vacuously.
- **New files** go in `modules/gui/qt/meson.build`, `Makefile.am` and `po/POTFILES.in` (C++). Tests go in the meson test list, like `test_onboarding_folders`.

## Review Focus

1. **Switching Dark → Light → System while Settings, a menu and the mini player are open.** Every surface recolours at once, with no restart and no surface stuck in the old theme. Covered by Task 6, Step 3.
2. **A picked accent (green `#19A234`, grey `#AFAFAF`) in Light.** The seek elapsed fill, the dim accent and the play pill stay readable on light grey, and BG/Accent Bright comes from the light formula, not dark's ×0.26 (which would draw a near-black bar). Test in Task 1, Step 1; seen in Task 6, Step 2.
3. **The System scheme with no theme provider, or a provider that reports nothing.** System falls back to Light and still draws the Figma light palette, not VLC 4's. Test in Task 1, Step 1.
4. **A surface that forces `VLCStyle.darkPalette`** (`ArtistTopBanner`, the onboarding card) **while the app is Light.** It reads dark tokens, because tokens come from the palette it is given, not from a global. Checked in Task 5, Step 3 and Task 6, Step 2.
5. **Placeholder and disabled text in Light** (search box, empty text fields, the off knob, disabled rows at 0.4 opacity). It stays dimmer than real text but readable. FG/A4 is `#9B9B9B`, not the Figma's `#3B3B3B`. Seen in Task 6, Step 2 (Settings ▸ Network field, library search).

---

### Task 1: Token table, palette, baseline

**Files:**
- Create: `modules/gui/qt/style/figmatokens.{hpp,cpp}`, `modules/gui/qt/tests/test_figma_tokens.cpp`, `docs/superpowers/scripts/theme-shots.sh`, `docs/superpowers/scripts/check-theme-literals.sh`
- Modify: `modules/gui/qt/style/systempalette.{hpp,cpp}` (`makeDarkPalette`, `makeLightPalette`, `makeSystemPalette`, `readAccent`), `modules/gui/qt/style/VLCStyle.qml`, build files

**Interfaces:**
- Produces: `struct FigmaTokens` (Q_GADGET, `QML_VALUE_TYPE(figmaTokens)` or registered as the codebase registers gadgets), one `Q_PROPERTY(QColor <name> MEMBER <name>)` per token name in Global Constraints.
- Produces: `FigmaTokens figmaTokens(bool dark, const QColor& accent, bool defaultAccent)`. It returns the table for that theme, with the accent tokens derived as the spec says. `defaultAccent` selects Figma's own accent, logo and accent-background values (dark `#D37918` / `#D37918` / `#371F06`; light `#E8851A` / `#C2711A` / `#D8BA9A`) over the derived ones.
- Produces: `SystemPalette` `Q_PROPERTY(FigmaTokens tokens READ tokens NOTIFY paletteChanged)`.
- Produces: `SystemPalette` `Q_PROPERTY(bool drivesWidgets MEMBER m_drivesWidgets)`. `VLCStyle.palette` sets it true. Task 2 uses it.
- Produces: `theme-shots.sh <outdir> <scheme-index>`: one PNG per screen in a fixed list (below).
- Produces: `check-theme-literals.sh`, which exits non-zero and lists offenders.

- [ ] **Step 1: Write the failing test** `tests/test_figma_tokens.cpp` (QtTest, like `test_onboarding_folders.cpp`)

```cpp
void darkDefault()  { auto t = figmaTokens(true, QColor("#D37918"), true);
    QCOMPARE(t.fgA2, QColor("#8F8F8F")); QCOMPARE(t.bgB1, QColor("#0E0E0E"));
    QCOMPARE(t.accentBgBright, QColor("#371F06")); QCOMPARE(t.bgA3Transparent, QColor(0x19,0x19,0x19,qRound(0.95*255))); }
void lightDefault() { auto t = figmaTokens(false, QColor("#E8851A"), true);
    QCOMPARE(t.fg1, QColor("#161616")); QCOMPARE(t.fg2, QColor("#2E2E2E")); QCOMPARE(t.fgA1, QColor("#3C3C3C"));
    QCOMPARE(t.fgA4, QColor("#9B9B9B")); QCOMPARE(t.bgA4, QColor("#D5D5D5")); QCOMPARE(t.bgA5, QColor("#DEDEDE"));
    QCOMPARE(t.bgB1Transparent, QColor(0xE7,0xE7,0xE7,qRound(0.8*255))); QCOMPARE(t.dividerDim, QColor("#ACACAC"));
    QCOMPARE(t.accent, QColor("#E8851A")); QCOMPARE(t.logo, QColor("#C2711A")); QCOMPARE(t.accentBgBright, QColor("#D8BA9A")); }
void lightDerived() { auto t = figmaTokens(false, QColor("#E8851A"), false);   // the formula, not the table
    QVERIFY(close(t.accentBgBright, QColor("#D8BA9A"), 3)); QVERIFY(close(t.accentDim, QColor("#965916"), 6)); }
void darkDerived()  { auto t = figmaTokens(true, QColor("#D37918"), false);
    QVERIFY(close(t.accentBgBright, QColor("#371F06"), 1)); QVERIFY(close(t.accentDim, QColor("#AB6314"), 3)); }
void lightGreen()   { auto t = figmaTokens(false, QColor("#19A234"), false);
    QVERIFY(t.accentBgBright.lightness() > 150); }               // Review Focus 2: no dark bar in light
void everyTokenSet(){ for (bool d : {true, false}) { auto t = figmaTokens(d, QColor("#D37918"), true);
    for (int i = 0; i < FigmaTokens::staticMetaObject.propertyCount(); ++i)
        QVERIFY(FigmaTokens::staticMetaObject.property(i).readOnGadget(&t).value<QColor>().isValid()); } }
```

`close(a, b, tol)` means every channel is within `tol`. Add a `SystemPalette` case too. It needs a `MainCtx`, so if the existing test stubs can't build one, test the System decision as a free function: `bool systemIsDark(ExternalPaletteImpl* providerOrNull)`, where null means false (Review Focus 3).

- [ ] **Step 2: Run it.** `meson test -C build test_figma_tokens`. Expected: build FAIL (no `figmatokens.hpp`).

- [ ] **Step 3: Take the Dark baseline before any product change.**
  - Write `theme-shots.sh`. It starts the harness with the given scheme index and walks a fixed list, one shot each:
    - Home, Videos grid, Videos list, Music, Network, Playlists, Recent;
    - the player with the side panel open; player Tracks, Playback, Queue and Settings tabs;
    - the mini player; Settings ▸ General and Settings ▸ Network; New Playlist; Open Network Stream; Keyboard Shortcuts; Customize Player; the "…" menu;
    - onboarding, theme page (start with `--qt-privacy-ask`).
  - Then run `theme-shots.sh build/redesign-shots/dark-before 2`.
  - Commit only the script; the shots stay in `build/`.

- [ ] **Step 4: Implement `figmatokens.{hpp,cpp}`.** Values come from the spec's token table, last column; the light formulas from the spec's "token swap".

- [ ] **Step 5: Rebuild `SystemPalette` on the table.**
  - **`makeDarkPalette()`** keeps every colour it sets today, but reads it from `figmaTokens(true, …)`: no hex in it.
  - **`makeLightPalette()`** sets the same sets and states as `makeDarkPalette()`, each with the light partner of the dark token it uses. VLC 4's `lightGrey*` values go.
  - **Default accent:** `readAccent()` makes Light use `#E8851A` and Dark `#D37918`.
  - **`makeSystemPalette()`:** builds `makeDarkPalette()` or `makeLightPalette()` by the provider's `isThemeDark()`. It no longer takes the provider's colours, but keeps `m_palettePriv` (change signal, CSD). With no provider it falls back to Light.
  - `tokens()` returns the active theme's table with the current accent.

- [ ] **Step 6: Run the test.** Expected: PASS; the whole qt suite is OK.

- [ ] **Step 7: Write `check-theme-literals.sh`.**
  - It greps `modules/gui/qt` `*.qml`/`*.js` for any of the 20 dark token hexes, plus `#1E1E1E #171717 #2A2A2A #3A3A3A #202020 #2D2D2D` and `Qt.rgba(0x`.
  - It skips lines carrying `// fixed colour:`.
  - Run it now. Expected: it fails and lists today's offenders, the input for Tasks 3–5.

- [ ] **Step 8: Verify Dark is unchanged.** Run `theme-shots.sh build/redesign-shots/dark-t1 2` and diff against `dark-before`: `compare -metric AE` for each pair. Expected: 0 differing pixels everywhere.

- [ ] **Step 9: Commit**

```bash
git add docs/superpowers/plans/2026-11-06-vlc-redesign-light-theme.md docs/superpowers/scripts modules/gui/qt
git commit -m "qt: Figma token table; both palettes and System built from it"
```

### Task 2: Menus

**Files:**
- Modify: `modules/gui/qt/style/menustyle.{hpp,cpp}`, `modules/gui/qt/menus/menus.cpp`, `modules/gui/qt/style/systempalette.cpp`, `modules/gui/qt/tests/test_menu_style.cpp`

**Interfaces:**
- Consumes: `figmaTokens()`, `SystemPalette::drivesWidgets` (Task 1).
- Produces: `static void MenuStyle::setDark(bool)` and `static bool MenuStyle::isDark()`. `SystemPalette::updatePalette()` calls `setDark(m_isDark)` when `drivesWidgets` is set.
- Produces: `QIcon menuIcon(const QString& name)` returns an icon whose engine renders `:/redesign/menu/<name>.svg` through `colorizeSvg()`. In light it swaps `#8F8F8F` → light FG/A2 and `#EAEAEA` → light FG/1, checking `MenuStyle::isDark()` at paint time, so it is never cached across a switch.

- [ ] **Step 1: Failing test** in `test_menu_style.cpp`:
  - `MenuStyle::setDark(false)`, render a one-action menu to a QImage, and sample the card pixel: it is `#D5D5D5` at 75 % over the backdrop (light BG/A3 Transparent), and the label pixel is darker than 0x60.
  - `setDark(true)` gives back today's `#191919` card.
  - `menuIcon("open-file")` rendered at 24 px in light has no pixel within 8 of `#8F8F8F`.

- [ ] **Step 2: Run it.** Expected: FAIL (`setDark` undefined).

- [ ] **Step 3: Implement.**
  - The style's five colour constants become reads of `figmaTokens(isDark(), …)`: card = `bgA3Transparent`, highlight = `bgA2`, label = `fgA2`, shortcut = `fgA3`, divider = `dividerDim`.
  - Delete the slice 5 `ponytail:` line.
  - Every `QIcon(":/redesign/menu/…svg")` in `menus.cpp` (37 of them) becomes `menuIcon("…")`.

- [ ] **Step 4: Run tests.** Expected: PASS. Also run `theme-shots.sh build/redesign-shots/dark-t2 2`; the "…" menu shot matches `dark-before`.

- [ ] **Step 5: Commit** `qt: menus draw in the light theme`

### Task 3: Shell, library and Settings surfaces

**Files (every listed literal or `isDark` colour branch in):**
- `maininterface/qml/*`
- `medialibrary/qml/*`: HomeListRow, HomeVideoCard, HomeSquareCard, HomeSection, HomePage, HomeDisplay, LibraryFolderPage, LibraryRootPage, PlaylistsPage, RecentDisplay
- `widgets/qml/*`: PageExt, GridSortFilterControls, FigmaMenu
- `network/qml/*`
- `player/qml/settings/SettingsStyle.qml` and the Settings window under `dialogs/settings/qml/`

**Interfaces:**
- Consumes: `theme.palette.tokens.<name>` (Task 1).

- [ ] **Step 1: Convert.**
  - Each `isDark ? "<hex>" : <fallback>` becomes `theme.palette.tokens.<token of that hex>`.
  - An off-token hex takes the nearest dark token by lightness. Add a Ledger line: file, old hex, token.
  - `SettingsStyle.qml` keeps its property names. Each reads a token; its `dark` property goes if nothing else needs it.
  - An `isDark` branch that changes more than a colour (a size, a visibility) stays, and gets a Ledger line.

- [ ] **Step 2: Check.** `check-theme-literals.sh` lists none of this task's files.

- [ ] **Step 3: Verify.**
  - Dark: `theme-shots.sh build/redesign-shots/dark-t3 2`. The library and Settings shots match `dark-before` (0 px).
  - Light: `theme-shots.sh build/redesign-shots/light-t3 1`. Look at each library and Settings shot. Expected: no dark surface is left, all text is readable, and selected rows are visible.

- [ ] **Step 4: Commit** `qt: library and settings read the Figma tokens`

### Task 4: Player, mini player, dialogs, Customize Player

**Files:**
- `player/qml/*`: Player, MinimalView, ControlBar, PlayerPanel, PlaybackPanel, PanelRow, TrackSection, QueuePage, BookmarksPage, ChaptersPage, LibraryPanel, SliderBar, MiniPlayer, `controlbarcontrols/*` (PlayButton, VolumeWidget, AtoBButton, DividerWidget, ThumbnailWidget; RecordButton's reds are `// fixed colour: record`)
- `dialogs/*/qml/*` (NewPlaylistDialog, AddSubtitlesDialog, HotkeysDialog, the network dialog, DialogCard, `toolbar/qml/*`)

**Interfaces:**
- Consumes: `theme.palette.tokens` (Task 1).

- [ ] **Step 1: Convert,** the same way as Task 3. Then:
  - **Stop forcing dark on video:** `Player.qml`'s `windowTheme` and `MinimalView.qml`'s `theme` use `VLCStyle.palette` always.
  - **The player's bar colours** per the spec's player table:
    - `_barColor` and the title bar:
      - in a window, dark keeps BG/A3 (today's `#1B1B1B`) and light uses BG/A3 Transparent, as the frame has it. This is a kept `isDark` branch; give it a Ledger line.
      - in fullscreen, both use BG/A3 Transparent at 95 % alpha.
    - The control bar's top border: `dividerDim`.
  - **The volume meter in both themes:** `_meter` loses its `isDark` condition. Its track in light is the Figma's `#888888` (`// fixed colour: Figma volume track (light)`, used only when `!isDark`, dark keeps `bgB2`). Add the white 20 % wash over the gradient in light.
  - **The play pill** uses `tokens.accent`.
  - **The side panel rows:** unwatched `fgA1`, watched `fgA3`.
  - **Baked SVGs in QML** (`MiniPlayer.qml`'s `redesign/mini/*`, `AddSubtitlesDialog`/`HotkeysDialog`'s `redesign/dialogs/*`): load them through `SVGColorImage.colorize(path)` with `#8F8F8F` → `tokens.fgA2` and `#EAEAEA` → `tokens.fg1`. A dark run substitutes each colour with itself.

- [ ] **Step 2: Check.** `check-theme-literals.sh` lists no file in `player/` or `dialogs/` except `dialogs/onboarding` (Task 5).

- [ ] **Step 3: Verify.**
  - Dark: `theme-shots.sh …/dark-t4 2`. Everything matches `dark-before`, except the player shots taken with a video playing and unpinned controls (the dropped force). Those must also match: in Dark, dark is the theme anyway. If any differ, the force removal changed something else; investigate.
  - Light: `theme-shots.sh …/light-t4 1`. Put the player-with-panel shot beside `docs/superpowers/figma/10/player-light-2425-13624.png` and go down the spec's player table row by row. Then look at every other player, mini player and dialog shot for readability and dark leftovers.

- [ ] **Step 4: Commit** `qt: player, mini player and dialogs read the Figma tokens`

### Task 5: Onboarding preview follows the theme tile

**Files:**
- Modify: `modules/gui/qt/dialogs/onboarding/qml/OnboardingWindow.qml`

**Interfaces:**
- Consumes: `SystemPalette.tokens` (Task 1).

- [ ] **Step 1: Two palettes, no literals.**
  - Add `SystemPalette { id: previewPalette; source: root.scheme; ctx: MainCtx }`.
  - The preview's colours read `previewPalette.tokens`. The preview's accent stays the card's `accent` (the chosen swatch), as in slice 9.
  - The card's own colours read `VLCStyle.darkPalette.tokens`. The card is always dark.
  - The theme tile swatches (`#AFAFAF`, `#222222`) and the preview's dim volume gradient (`#77A913`, `#8E8713`) get `// fixed colour: Figma onboarding`.

- [ ] **Step 2: Check.** `check-theme-literals.sh` passes for the whole tree (exit 0).

- [ ] **Step 3: Verify.**
  - Start with `--qt-privacy-ask` in Light (index 1). Shot the theme page with the Light tile, then the Dark tile. Expected: the preview is light, then dark. The card is dark both times (Review Focus 4).
  - System tile: the preview matches the System palette's lightness.
  - Finish with Light: the main window is light, with no restart.

- [ ] **Step 4: Commit** `qt: onboarding preview shows the picked theme`

### Task 6: Whole-app check, Ledger, roadmap

**Files:**
- Modify: this plan's `## Ledger`, `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md` (row 10, and the "dark only" notes in rows 5, 6 and 9)

- [ ] **Step 1: Dark regression.** `theme-shots.sh build/redesign-shots/dark-after 2` against `dark-before`. Expected: 0 px on every shot. List any non-zero diff here with its cause, or fix it.

- [ ] **Step 2: Light pass.** `theme-shots.sh build/redesign-shots/light-after 1`. Then:
  - Look at all shots, plus:
    - green and grey accents (Settings ▸ General) on the player, Home and the Settings window (Review Focus 2);
    - an artist page (`ArtistTopBanner` stays dark, Review Focus 4);
    - placeholder text in the library search and in Settings ▸ Network (Review Focus 5).
  - Record each finding in the Ledger, fixed or parked.

- [ ] **Step 3: Live switch and System.**
  - Open Settings, the mini player (library view, media playing) and a menu, then switch Theme Dark → Light → System. Shots after each switch. Expected: every surface is in the new theme at once; a menu opened after the switch draws in it.
  - On the Wayland driver: run `gsettings set org.gnome.desktop.interface color-scheme prefer-dark`, then `default`, with System. Expected: the app follows. If the headless session can't change it, note that in the Ledger as unverified.

- [ ] **Step 4: Docs.**
  - Roadmap row 10: done, with "Plan 2026-11-06-vlc-redesign-light-theme" and the spec's Departures summary.
  - Rows 5 and 6: drop "dark only (light with slice 10)".
  - Row 9: drop "the preview stays dark for Light and System until slice 10".
  - The Ledger lists every off-token mapping and every kept `isDark` branch.

- [ ] **Step 5: Commit** `docs: light theme ledger and roadmap`

## Ledger

(departures and findings, filled in during execution)

Task 3 (dark keeps the exact literal; light reads the nearest token):
- SettingsStyle.qml: `#2A2A2A` (tick) -> bgA1; `#1E1E1E` (sidebarHover) -> bgA2.
- HomeSquareCard.qml, HomeVideoCard.qml, HomeListRow.qml: `#171717` -> bgA4 (tie with bgA5; first in list).
- HomeDisplay.qml, HomePage.qml, LibraryRootPage.qml, PlaylistsPage.qml, LibraryFolderPage.qml (x2): `#1E1E1E` backing -> bgA2.
- HomeListRow.qml: compact thumbnail backing `#303030` (placeholder with meaning) kept in dark; light reads bgA4 (was bg.secondary).
- AccentRow.qml: selected swatch background now `style.accentBg` (token) instead of swatch x0.26.
- AccentSwatches.js: swatch list marked `// fixed colour: accent swatch`.

Task 4 (player, mini player, dialogs):
- Player.qml `_barColor`: in a window dark keeps solid BG/A3 (`#1B1B1B`), light reads BG/A3 Transparent (the frame); fullscreen both read BG/A3 Transparent at 95 %. Kept `isDark` branch.
- Player.qml control bar: a 1 px Divider/Dim top border in light only (the frame has it, the dark frame doesn't). Kept `isDark` branch that adds an item.
- Player.qml, MinimalView.qml: the forced `VLCStyle.darkPalette` while a video plays is gone (spec); Dark shots unchanged.
- Player.qml resume dialog: `Qt.rgba(#191919, 0.95)` -> BG/A3 Transparent (light #D5D5D5 75 % over the video).
- LibraryPanel.qml rail: dark keeps BG/A4 (`#191919`), light reads BG/A3 Transparent (spec's player table). Kept `isDark` branch.
- ControlBar.qml compact seek elapsed: dark keeps `Qt.tint(track, accent 26 %)` (not a token: #3D2509-ish, not #371F06), light reads BG/Accent Bright. Kept `isDark` branch.
- VolumeWidget.qml: the meter shows in both themes; light track `#888888` (fixed colour: Figma volume track (light)), dark BG/B2; a white 20 % wash over the level in light only. Kept `isDark` branches.
- PlayButton.qml: playing pill light `#9E9E9E` -> FG/A3 (`#6B6B6B`, the dark value's token, same in both).
- PlaybackPanel.qml: speed ticks `#3A3A3A` -> dividerBright.
- MiniPlayer.qml: video area backing `#202020` (ended) -> bgA2, `#303030` (placeholder) -> bgA4, as Task 3's HomeListRow.
- ThumbnailWidget.qml: `#303030` placeholder -> bgA4 (it now has a ColorContext).
- Baked SVG greys (cross-task, includes Task 3's Settings): one helper, `Helpers.themedSvg(palette, path)` (util/qml/Helpers.qml, VLC.Util), swaps `#8F8F8F` -> fgA2 and `#EAEAEA` -> fg1. It loads every `redesign/mini/*`, `redesign/dialogs/*` and `redesign/settings/*` SVG drawn from QML: MiniPlayer, DialogCard, NewPlaylistDialog, CustomizePlayerOverlay, HotkeysDialog, AddSubtitlesDialog, SettingsWindow, SettingsSidebar, AdvancedBar, SettingsRowDelegate. Onboarding's cone is Task 5's.
- NewPlaylistDialog.qml: "+" tile `#161616` (FG/B1 used as a surface; FG/B1 is same-in-both, so it would stay black in light) -> bgA5, like lightPartner() would; dashed box stroke `#2D2D2D` -> dividerBright.
- SliderBar.qml waveform: played bars light `theme.accent` -> accentDim (dark already drew Qt.darker(accent, 1.24) = accentDim); unplayed fgA4. Both now repaint on a theme switch.
