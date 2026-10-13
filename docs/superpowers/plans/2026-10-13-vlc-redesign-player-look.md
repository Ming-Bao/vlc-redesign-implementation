# VLC Redesign — Slice 2: Player + Global Look Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the playback screen and the interface's type and icons match the Figma "VLC Redesign (Community)" file, replacing VLC 4's overlay player.

**Architecture:** The player keeps the window title bar (the library's `LocalTopbar`, extended with a folder chip) and a solid compact control bar (slice 1's Inline `ControlBar`) with the video between them; fullscreen hides both and shows them as translucent overlays. The app font becomes Inter and the `VLCIcons` icon font is regenerated from SVGs exported from the Figma icon set, keeping every glyph key so no QML call site changes.

**Tech Stack:** Qt 6.11 / QML, C++17, Meson, FontForge Python (`makeIconFont.py`), Figma MCP (`use_figma` SVG export), Xvfb + Wayland screenshot harness.

**Spec:** `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md` (slice 2 row) and Figma nodes `247:445` (player), `3328:11554` (player, hidden UI), `491:1780` variant `Property 1=default` (control bar), `244:184` (volume), `42:356` (icon set). Slice 1 spec `docs/superpowers/specs/2026-10-13-vlc-redesign-shell-player-design.md` holds the colour tokens.

## Global Constraints

- The Figma file is the spec; VLC 4's existing player design is not a reference (memory `figma-is-the-spec`).
- Dark tokens from slice 1 (accent `#D37918`, `#0E0E0E`/`#191919`/`#1B1B1B`, FG `#C6C6C6`/`#8F8F8F`/`#6B6B6B`); hard-coded hex values are dark-theme only (gate on `palette.isDark`).
- Sizes via `VLCStyle.dp(n, VLCStyle.scale)`; strings via `qsTr()`/`qtr()`.
- Qt ≥ 6.2 APIs only; build with `ninja -C build`; run the dev build as `build/bin/vlc-static`.
- Icon font keeps its 96 existing keys in the same order (charcodes are assigned by index in `pixmaps/makeIconFont.py`); new keys are only appended.
- After every visual change grep `build/redesign-profile/run/vlc.log` (run with `-vv`) for `TypeError|ReferenceError|non-existent property|unavailable|Unable to assign` — must be empty.
- One commit per task on branch `redesign/player-look`; commit prefixes `qml:` / `qt:` / `doc:`.

## Review Focus

1. **Audio-only media** (no video output) — the player shows artwork, not a video; title bar and compact bar must still be solid and usable. (Check in Task 4, Step 6 with `build/redesign-music/untangle.mp3`.)
2. **Fullscreen + mouse idle** — both bars hide, video fills the screen, moving the mouse brings them back as translucent overlays. (Task 4, Step 5.)
3. **Media with no parent folder** (network URL) — the folder chip must hide, not show "" or "/". (Task 3, Step 5 with `http://127.0.0.1:9/none.mp4`.)
4. **Glyphs missing from the Figma set** (e.g. `tvtelx`, `dvd_menu`, `regex`) — keys without a Figma counterpart must keep their old glyph, not render blank. (Task 2, Step 4 check.)
5. **Saved pre-redesign profiles** for the video player — fall back like the mini bar did in slice 1 (seek row above buttons), never vanish. (Task 5, Step 6.)

---

### Task 0: Branch

- [ ] **Step 1:** `git switch -c redesign/player-look`

---

### Task 1: Inter as the interface font

**Files:**
- Modify: `modules/gui/qt/qt.cpp` (after `QApplication app( argc, argv );`, ~line 912)
- Create: `modules/gui/qt/util/ui_font.hpp`, `modules/gui/qt/util/ui_font.cpp`
- Create: `modules/gui/qt/tests/test_ui_font.cpp`; Modify `modules/gui/qt/meson.build` (sources + test), `modules/gui/qt/Makefile.am` (sources)

**Interfaces:** Produces `QString vlc::preferredUiFontFamily(const QStringList& installed)` → `"Inter"` (or `"Inter Variable"`) when present, else `QString()`.

- [ ] **Step 1: Failing test** `tests/test_ui_font.cpp`:
```cpp
#include <QTest>
#include "../util/ui_font.hpp"
class TestUiFont : public QObject {
    Q_OBJECT
private slots:
    void prefersInter() { QCOMPARE(vlc::preferredUiFontFamily({"DejaVu Sans", "Inter", "Noto Sans"}), QString("Inter")); }
    void acceptsVariableInter() { QCOMPARE(vlc::preferredUiFontFamily({"Inter Variable"}), QString("Inter Variable")); }
    void emptyWhenMissing() { QVERIFY(vlc::preferredUiFontFamily({"DejaVu Sans"}).isEmpty()); }
};
QTEST_GUILESS_MAIN(TestUiFont)
#include "test_ui_font.moc"
```
Register as `test_qt_ui_font` (sources `tests/test_ui_font.cpp`, `util/ui_font.cpp`; moc_sources the test; deps `qt6_dep, qtest_qt6_dep`), modelled on `test_qt_navigation_history`.
- [ ] **Step 2:** `meson test -C build test_qt_ui_font` → compile FAIL (`ui_font.hpp` missing).
- [ ] **Step 3: Implement** `util/ui_font.hpp`:
```cpp
#ifndef VLC_QT_UI_FONT_HPP
#define VLC_QT_UI_FONT_HPP
#include <QStringList>
namespace vlc {
/// family the redesign uses for the interface, or empty when not installed
QString preferredUiFontFamily(const QStringList& installed);
}
#endif
```
`util/ui_font.cpp`:
```cpp
#include "ui_font.hpp"
QString vlc::preferredUiFontFamily(const QStringList& installed)
{
    for (const char* f : { "Inter", "Inter Variable" })
        if (installed.contains(QLatin1String(f)))
            return QLatin1String(f);
    return {};
}
```
In `qt.cpp` after the translator block:
```cpp
    {
        // Figma redesign: the interface uses Inter when it is installed
        const QString family = vlc::preferredUiFontFamily(QFontDatabase::families());
        if (!family.isEmpty())
        {
            QFont font = app.font();
            font.setFamily(family);
            app.setFont(font);
        }
    }
```
(include `<QFontDatabase>` and `"util/ui_font.hpp"`; add `util/ui_font.cpp/.hpp` to the plugin sources in meson.build and Makefile.am).
- [ ] **Step 4:** `ninja -C build && meson test -C build --suite qt` → all OK (9 tests).
- [ ] **Step 5: Visual check** — harness home shot; `fc-match Inter` must be installed (`rsms-inter-fonts`). Compare the "Home" header text against `/tmp/t5top.png` from slice 1: letterforms change (Inter's double-storey `a`, flat-topped `t`). Record both crops.
- [ ] **Step 6: Commit** `qt: use Inter for the interface when installed`

---

### Task 2: Regenerate the icon font from the Figma icon set

**Files:**
- Create: `modules/gui/qt/pixmaps/redesign/*.svg` (exported from Figma)
- Create: `modules/gui/qt/pixmaps/redesign/mapping.json` (Figma variant → VLCIcons key)
- Modify: `modules/gui/qt/pixmaps/VLCIcons.json` (paths of mapped keys), regenerate `pixmaps/VLCIcons.ttf`, `style/vlcicons.hpp/.cpp` (generator output; key order unchanged so charcodes stay)
- Create: `docs/superpowers/scripts/check-icon-font.py`

**Interfaces:** none new — QML keeps using `VLCIcons.<key>`.

Mapping (Figma `name[, direction]` → keys), all `state=default, value=default, two-tone=no`:
`home`→home · `videos`→topbar_video · `music`→topbar_music · `streaming`→topbar_network · `more`→more, ellipsis · `sidebar`→panel_left · `play`→play, play_filled · `pause`→pause_filled · `next`→next · `previous`→previous · `backward-10-sec`→skip_back · `forward-10-sec`→skip_for · `fullscreen`→fullscreen · `minimize`→window_minimize · `maximize`→window_maximize, window_restore · `close`→window_close, close · `search`→search · `sort`→topbar_sort · `grid`→grid · `list`→list · `settings`→settings · `lists`→playlist · `subtitles`→audiosub · `playback settings`→effect_filter · `bookmark`→bookmark · `shuffle`→shuffle · `repeat`→repeat_all · `record`→record · `snapshot`→snapshot · `stop`→stop · `add`→add · `check`→check · `arrow, direction=left`→back · `chevron, direction=up/down/left/right`→chevron_up, chevron_down, ic_fluent_chevron_left_24, ic_fluent_chevron_right_24 · `info`→info · `recent`→history · `disc`→eject · `tv`→tv · `profile`→profile_new · `remove`→remove · `volume` (value high/medium/low/mute/0 variants)→volume_high/medium/low/muted/zero · `queue`→enqueue · `speed`→faster · `refresh`→ic_fluent_arrow_sync_24_regular · `upload`→stream · `folder`→**folder** (new key, appended at the end of `VLCIcons.json` so existing charcodes do not move). Keys not listed keep their current SVG (Review Focus 4).

- [ ] **Step 1: Failing check** `docs/superpowers/scripts/check-icon-font.py`:
```python
#!/usr/bin/python3 -I
"""Assert every key in pixmaps/redesign/mapping.json uses pixmaps/redesign/<file>.svg in VLCIcons.json
and that the glyph in VLCIcons.ttf has the same contour count as importing that SVG."""
import json, sys, fontforge
base = sys.argv[1]  # modules/gui/qt/pixmaps
mapping = json.load(open(f"{base}/redesign/mapping.json"))
model = json.load(open(f"{base}/VLCIcons.json"))
font = fontforge.open(f"{base}/VLCIcons.ttf")
order = [g["key"] for g in model["glyphs"]]
bad = []
for svg, keys in mapping.items():
    ref = fontforge.font(); c = ref.createChar(0xE000); c.importOutlines(f"{base}/redesign/{svg}")
    for key in keys:
        g = model["glyphs"][order.index(key)]
        if g["path"] != f"./redesign/{svg}":
            bad.append(f"{key}: path {g['path']}")
            continue
        if len(font[0xE000 + order.index(key)].foreground) != len(c.foreground):
            bad.append(f"{key}: contour mismatch")
print("\n".join(bad) or "icon font OK"); sys.exit(1 if bad else 0)
```
- [ ] **Step 2:** Export the SVGs. Run this `use_figma` read-only script (file `dSoAm0gN9ZterHSssJU9FN`, skill `figma-use`) once per batch of ~15 names, writing each returned string to `pixmaps/redesign/<file>.svg` (file = name with spaces→`-` plus `-<direction>` when given):
```js
const set = await figma.getNodeByIdAsync('42:356');
const want = [/* e.g. ['home'], ['arrow','left'], ['volume', null, 'high'] */];
const out = {};
for (const [name, dir, value] of want) {
  const c = set.children.find(n => n.name.startsWith(`name=${name},`) && n.name.includes('two-tone=no')
     && n.name.includes(`direction=${dir ?? 'default'}`) && n.name.includes(`value=${value ?? 'default'}`)
     && n.name.includes('state=default'));
  out[[name, dir, value].filter(Boolean).join('-').replace(/ /g, '-')] = c ? await c.exportAsync({ format: 'SVG_STRING' }) : null;
}
return out;
```
Write `mapping.json` as `{ "<file>.svg": ["key", ...], ... }` from the table above. Then:
`python3 -I docs/superpowers/scripts/check-icon-font.py modules/gui/qt/pixmaps` → FAIL (`home: path ./icons/...`).
- [ ] **Step 3:** Point the mapped keys' `path` in `VLCIcons.json` to `./redesign/<file>.svg` (script: for each mapping entry set `glyph["path"]`), then from `modules/gui/qt/pixmaps`: `python3 makeIconFont.py VLCIcons.json` (regenerates `VLCIcons.ttf`, `../style/vlcicons.hpp/.cpp`). `git diff --stat ../style` must show no key/charcode reorder (only the generated header comment may change).
- [ ] **Step 4:** Check passes: `check-icon-font.py` → `icon font OK`. Review Focus 4: confirm an unmapped key (`tvtelx`) still has contours: `python3 -I -c "import fontforge,json;f=fontforge.open('modules/gui/qt/pixmaps/VLCIcons.ttf');k=[g['key'] for g in json.load(open('modules/gui/qt/pixmaps/VLCIcons.json'))['glyphs']];print(len(f[0xE000+k.index('tvtelx')].foreground)>0)"` → `True`.
- [ ] **Step 5:** `ninja -C build`; harness home + player screenshots; icons now Figma line icons (house with door, 4-line list, etc.). No QML log errors.
- [ ] **Step 6: Commit** `qt: regenerate the icon font from the redesign icon set` (include the SVGs, mapping, json, ttf, generated sources, check script).

---

### Task 3: Player title bar = window title bar with folder chip

**Files:**
- Modify: `modules/gui/qt/maininterface/qml/LocalTopbar.qml` (folder chip, `inPlayer` mode)
- Modify: `modules/gui/qt/player/qml/Player.qml` (replace `TopBar {…}` with `LocalTopbar {…}`; move resume to Task 4)

**Interfaces:**
- Produces on `LocalTopbar`: `property string folderName: ""`, `property bool showNavigationToggle: true`, `signal folderClicked()`.
- Consumes: `Player.url` (QUrl), `Player.title`, `MainCtx.playerView`.

- [ ] **Step 1: Failing visual check** — play `The_Clip_S01E01.mp4`, paused; the Figma title bar shows the folder chip "S01" at x≈150–230, y≈20 and the centred title `#8F8F8F`:
```bash
S=docs/superpowers/scripts; $S/vlc-xvfb.sh start -vv --start-paused "build/redesign-media/Shows/The Clip/S01/The_Clip_S01E01.mp4"
sleep 2; $S/vlc-xvfb.sh shot /tmp/s2t3.png; $S/vlc-xvfb.sh stop
magick /tmp/s2t3.png -crop 1600x40+0+0 /tmp/s2t3top.png   # expect: no folder chip, VLC 4 top bar (back arrow, ⋮)
```
- [ ] **Step 2: LocalTopbar additions** — after `navigationVisibilty` in `navigationButtonsRow` add:
```qml
                Rectangle {   // divider (Figma Frame 6)
                    visible: folderChip.visible
                    width: VLCStyle.dp(1, VLCStyle.scale); height: VLCStyle.dp(20, VLCStyle.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    color: theme.separator
                }

                Widgets.ButtonExt {   // folder chip (Figma Frame 12)
                    id: folderChip
                    visible: root.folderName.length > 0
                    iconTxt: VLCIcons.folder
                    text: root.folderName
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    onClicked: root.folderClicked()
                }
```
(`VLCIcons.folder` is the key Task 2 appends). Properties at the top:
```qml
    property string folderName: ""
    property bool showNavigationToggle: true
    signal folderClicked()
```
and `visible: root.showNavigationToggle` on `navigationVisibilty`.
- [ ] **Step 3: Player uses it** — in `Player.qml` replace the `TopBar { id: topBar … }` block with:
```qml
    LocalTopbar {
        id: topBar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        z: 1
        // Figma 247:445: the window title bar stays, with the media folder as a chip
        showNavigationToggle: false   // library side panel arrives in slice 4
        folderName: {
            const path = Player.url.toString().replace(/\/+$/, "")
            const parts = decodeURIComponent(path).split("/")
            return (Player.url.toString().startsWith("file:") && parts.length > 1) ? parts[parts.length - 2] : ""
        }
        onFolderClicked: MainCtx.playerView = false
        playqueueVisible: playlistVisibility.isPlaylistVisible
        onTogglePlayqueueVisibility: playlistVisibility.togglePlaylistVisibility()
        plListView: playlistpopup.active ? playlistpopup.item : null
        useAcrylic: false
        Binding on state { when: playerToolbarVisibilityFSM.started
            value: (playerToolbarVisibilityFSM.isVisible || rootPlayer._controlsUnderVideo) ? "visible" : "hidden" }
        FadeControllerStateGroup { target: topBar }
        Navigation.parentItem: rootPlayer
        Navigation.downItem: controlBar
    }
```
Remove every remaining reference to TopBar-only members (`resumeVisible`, `textWidth`, `pinControls`, `onBackRequested`, `topBarAcrylicBg`) — `grep -n "topBar\." player/qml/Player.qml` and fix each (resume moves in Task 4). `LocalTopbar` background colour in the player: `#1B1B1B` (dark) via a `tintColor` override or a `background` property.
- [ ] **Step 4:** Rebuild, re-run Step 1 → chip "S01" visible left, title "The_Clip_S01E01.mp4" centred, window buttons + fullscreen right; clicking the chip returns to the library (`click 190 20`, shot shows Home). Log clean.
- [ ] **Step 5: Review Focus 3** — start with a non-file input `vlc-xvfb.sh start -vv "http://127.0.0.1:9/none.mp4"`: chip hidden (no "" chip, no "/").
- [ ] **Step 6: Commit** `qml: use the window title bar in the player`

---

### Task 4: Player layout — video between bars, fullscreen overlays, resume toast

**Files:** Modify `modules/gui/qt/player/qml/Player.qml`, `modules/gui/qt/player/qml/ResumeDialog.qml`

- [ ] **Step 1: Failing visual check** — paused windowed player: pixel above the bar at (800,840) must be video, and the bar background `#1B1B1B` at (1000,880); VLC 4 shows the fade gradient over the video instead.
- [ ] **Step 2:** `_controlsUnderVideo: MainCtx.intfMainWindow.visibility !== Window.FullScreen || MainCtx.pinVideoControls` (windowed: always under video, per Figma; fullscreen: overlay unless the user pins).
- [ ] **Step 3:** Remove both `FadeRectangle` instances and the large left title; control-bar and title-bar backgrounds: windowed `#1B1B1B`, fullscreen `Qt.rgba(0x19/255, 0x19/255, 0x19/255, 0.95)` (dark; light keeps `windowTheme.bg.primary`).
- [ ] **Step 4:** Resume: move the `ResumeDialog` out of the top bar into a bottom-centred toast (Figma "continue": 552×52, `#191919`@0.95, radius `VLCStyle.dp(8)`, 10/10/10/20 padding, 60 gap) anchored `bottom: controlBar.top`, `bottomMargin: VLCStyle.dp(24)`.
- [ ] **Step 5: Review Focus 2** — fullscreen (`key f`), wait 5 s idle: shot shows only video; `mousemove 800 450`: both bars visible over the video with 95 % `#191919`.
- [ ] **Step 6: Review Focus 1** — audio file `build/redesign-music/untangle.mp3`: artwork view, both bars solid, no log errors.
- [ ] **Step 7:** Commit `qml: lay out the player after the redesign`

---

### Task 5: Player control bar = Figma Controls (default)

**Files:** Modify `modules/gui/qt/player/qml/Player.qml` (ControlBar), `modules/gui/qt/dialogs/toolbar/controlbar_profile_model.cpp` (Default style Videoplayer + Audioplayer)

- [ ] **Step 1: Failing visual check** — paused player: play pill accent at (62, 873) (bar y≈846–900) → FAIL today (round button centred).
- [ ] **Step 2:** Default style Videoplayer and Audioplayer: left `{PREVIOUS_BUTTON, PLAY_BUTTON, NEXT_BUTTON}`, centre `{}`, right `{VOLUME, LANG_BUTTON, EXTENDED_BUTTON, PLAYLIST_BUTTON}` (Figma: volume, audio, subtitles, playback settings, lists).
- [ ] **Step 3:** Player `ControlBar`: `compactStyle: true`, `textPosition: ControlBar.TimeTextPosition.Inline`, `inlineFallback: ControlBar.TimeTextPosition.LeftRightSlider`, `sliderHeight: _compact ? VLCStyle.dp(28, VLCStyle.scale) : VLCStyle.heightBar_xxsmall`, `topPadding/bottomPadding: _compact ? VLCStyle.dp(11, VLCStyle.scale) : …`, drop the `applicationVerticalMargin` bottom padding in compact.
- [ ] **Step 4:** Rebuild with a fresh profile config; Step 1 check passes; track `#090909` at (800, 873).
- [ ] **Step 5:** Chapters file: segments + handle visible (slice 1 behaviour).
- [ ] **Step 6: Review Focus 5** — old saved Videoplayer profile (`$0|61,80,8,83|14,3,0,4,15|33,81,7`) → seek row above the buttons, not vanished.
- [ ] **Step 7:** `meson test -C build --suite qt`; commit `qml: use the redesign control bar in the player`

---

### Task 6: Volume meter (Figma `volume`)

**Files:** Modify `modules/gui/qt/player/qml/controlbarcontrols/VolumeWidget.qml`

**Interfaces:** consumes `compactStyle` forwarded by `ControlRepeater` (slice 1).

- [ ] **Step 1: Failing check** — mini/player bar volume at 50 %: pixel at the meter's left quarter is green `#95D318`±25 → FAIL (thin grey slider).
- [ ] **Step 2:** `property bool compactStyle: false`; when compact (dark): `volControl.implicitWidth: dp(88)`, `background: Rectangle { radius dp(2); color "#090909"; height dp(28)-dp(6) }` with a child `Rectangle` of width `position*width`, `gradient: Gradient { orientation: Gradient.Horizontal; GradientStop{position:0; color:"#95D318"} GradientStop{position:0.58; color:"#B2A918"} GradientStop{position:0.79; color:"#D37918"} GradientStop{position:1; color:"#FF3737"} }`; handle hidden (`visible: false`); non-compact keeps today's look.
- [ ] **Step 3:** Check passes in the mini bar and the player bar; mute button still toggles; wheel still changes volume.
- [ ] **Step 4:** Commit `qml: redesign volume meter in compact bars`

---

### Task 7: Wayland pass

- [ ] Run `dbus-run-session -- docs/superpowers/scripts/wl-drive.py OUT vlc:<clip> sleep:2 key:Escape sleep:2 max shot:player key:F11 sleep:6 shot:fs-idle click:800,450 sleep:1 shot:fs-shown key:F11 sleep:2 shot:back` and confirm: title bar + bar solid windowed; fullscreen idle = video only; shown = translucent bars; log clean. Commit nothing unless a fix is needed (TDD it).
