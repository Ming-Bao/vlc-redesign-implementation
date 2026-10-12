# VLC Redesign — Shell + Player (slice 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring VLC 4's Qt/QML window shell (title bar, sidebar, page header, `…` menu) and compact mini-player bar in line with the Figma "VLC Redesign (Community)" file.

**Architecture:** Mostly QML restyling of existing components (`LocalTopbar`, `SideNavigationPane/Delegate`, `PageExt`, `ControlBar`/`MiniPlayer`, `SliderBar`, `PlayButton`), driven by Figma colour tokens placed in the C++ dark palette (`SystemPalette`). Two small C++ behaviour additions carry unit tests: forward navigation in `NavigationHistory`, and new sidebar labels in `NavigationModel`. QML visuals are verified with a scripted Xvfb screenshot harness plus pixel assertions.

**Tech Stack:** C++17 / Qt 6.11 (Quick, QuickControls2 templates, QtTest), QML, Meson + Ninja, ImageMagick + xdotool + Xvfb for visual checks.

**Spec:** `docs/superpowers/specs/2026-10-13-vlc-redesign-shell-player-design.md`

## Global Constraints

- Build: `meson setup build -Dqt=enabled -Dmedialibrary=enabled` (already configured in `build/`); rebuild with `ninja -C build`.
- Qt minimum stays 6.2 — no Qt ≥ 6.3-only QML APIs.
- Accent `#D37918`; BG `#0E0E0E` / `#191919` / `#151515`; FG `#C6C6C6` / `#8F8F8F` / `#6B6B6B`; divider `#222222` (dark theme only; light theme unchanged).
- Sizes go through `VLCStyle.dp(n, VLCStyle.scale)` or existing `VLCStyle.*` metrics — never raw pixels in QML.
- All user-visible strings via `qsTr()` (QML) / `qtr()` (C++).
- Do not delete features the Figma omits (Discover, Preferences, Tools/View/Help menus) — keep them reachable.
- Existing saved control-bar profiles must keep working; only defaults change.
- Commit style: `qml: <summary>` / `qt: <summary>` (matches repo history); one commit per task, on branch `redesign/shell-player`.

## Review Focus

1. **Mini player with a custom profile whose centre section is non-empty** — the inline seek bar has no filler slot; expected: falls back to the time/slider row above the buttons instead of vanishing. (Test in Task 7, Step 7.)
2. **Forward after a new push** — Back, then navigate somewhere new: Forward must become disabled (no stale forward stack). (Test in Task 2, Step 1 `testPushClearsForward`.)
3. **Forward with nothing to go to** — `next()` on an empty forward stack (fresh start, or after reaching the newest page) must be a no-op, not a crash or an empty view. (Test in Task 2, Step 1 `testInitiallyNoForward`.)
4. **Media with chapters in the mini player** — the block seek bar hides its track when chapters exist; expected: chapter segments still readable and handle still visible. (Check in Task 7, Step 9 with the chaptered sample.)
5. **Collapsed sidebar (icon rail)** — the inner rounded card must not render when labels are hidden. (Check in Task 3, Step 8.)

---

### Task 0: Branch and visual-verification harness

**Files:**
- Create: `docs/superpowers/scripts/redesign-env.sh`
- Create: `docs/superpowers/scripts/vlc-xvfb.sh`
- Create: `docs/superpowers/scripts/px.sh`
- Create: `docs/superpowers/scripts/make-samples.sh`

**Interfaces:**
- Produces (used by every later task):
  - `vlc-xvfb.sh start [vlc args…]` → starts Xvfb `:77` (1600×900) + dev VLC, prints `ready`.
  - `vlc-xvfb.sh shot OUT.png` → full-screen capture of `:77`.
  - `vlc-xvfb.sh click X Y` / `vlc-xvfb.sh key KEYS` → input on `:77`.
  - `vlc-xvfb.sh stop`.
  - `px.sh IMG X Y HEX [TOL]` → exit 0 if pixel within TOL (default 6) per channel, else prints actual and exits 1.
  - `make-samples.sh` → `build/redesign-media/{Shows/The Clip/S01/*.mp4, chapters.mkv}` and `build/redesign-music/*.mp3`.

- [ ] **Step 1: Create the branch**

```bash
git switch -c redesign/shell-player
```

- [ ] **Step 2: Write `redesign-env.sh`**

```sh
#!/bin/sh
# Shared paths for the redesign verification scripts. Source, don't execute.
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
BUILD="$REPO/build"
PROFILE="$BUILD/redesign-profile"
export XDG_CONFIG_HOME="$PROFILE/config" XDG_DATA_HOME="$PROFILE/data" XDG_CACHE_HOME="$PROFILE/cache"
export VLC_LIB_PATH="$BUILD/modules" VLC_PLUGIN_PATH="$BUILD/modules"
export QT_QPA_PLATFORM=xcb DISPLAY=:77
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
printf 'XDG_VIDEOS_DIR="%s"\nXDG_MUSIC_DIR="%s"\n' "$BUILD/redesign-media" "$BUILD/redesign-music" \
    > "$XDG_CONFIG_HOME/user-dirs.dirs"
```

- [ ] **Step 3: Write `vlc-xvfb.sh`**

```sh
#!/bin/sh
# Drive the dev build of VLC on a private Xvfb display (:77) for screenshots.
. "$(dirname "$0")/redesign-env.sh"
RUN="$PROFILE/run"; mkdir -p "$RUN"
case "$1" in
start)
    shift
    Xvfb :77 -screen 0 1600x900x24 -nolisten tcp > "$RUN/xvfb.log" 2>&1 & echo $! > "$RUN/xvfb.pid"
    sleep 1
    "$BUILD/bin/vlc-static" -I qt "$@" > "$RUN/vlc.log" 2>&1 & echo $! > "$RUN/vlc.pid"
    for i in $(seq 60); do
        w=$(xdotool search --name "VLC media player" 2>/dev/null | tail -1)
        [ -n "$w" ] && { xdotool windowmove "$w" 0 0 windowsize "$w" 1600 900; sleep 4; echo ready; exit 0; }
        sleep 0.5
    done
    echo "VLC window never appeared; see $RUN/vlc.log"; exit 1 ;;
shot)  import -window root "$2" && echo "saved $2" ;;
click) xdotool mousemove "$2" "$3" sleep 0.2 click 1 ;;
key)   shift; xdotool key "$@" ;;
stop)
    kill "$(cat "$RUN/vlc.pid")" 2>/dev/null; sleep 1; kill -9 "$(cat "$RUN/vlc.pid")" 2>/dev/null
    kill "$(cat "$RUN/xvfb.pid")" 2>/dev/null; true ;;
*) echo "usage: $0 start [args]|shot OUT|click X Y|key KEYS|stop"; exit 2 ;;
esac
```

`vlc-static` (not `vlc`) is required from the build tree: it finds `vlc-preparser-static` via `VLC_LIB_PATH`;
plain `bin/vlc` fails with "Fail to create Process in process_pool".

- [ ] **Step 4: Write `px.sh`**

```sh
#!/bin/sh
# usage: px.sh IMG X Y HEX [TOL] — assert the pixel colour at (X,Y) is HEX (#RRGGBB) within TOL per channel.
img=$1 x=$2 y=$3 want=$(echo "$4" | tr -d '#' | tr a-f A-F) tol=${5:-6}
got=$(magick "$img" -format "%[hex:p{$x,$y}]" info: | cut -c1-6)
d() { a=$(printf %d 0x$(echo "$1" | cut -c$3-$(($3+1)))); b=$(printf %d 0x$(echo "$2" | cut -c$3-$(($3+1)))); echo $(( a>b ? a-b : b-a )); }
for c in 1 3 5; do [ "$(d "$got" "$want" $c)" -le "$tol" ] || { echo "FAIL ($x,$y): got #$got want #$want"; exit 1; }; done
echo "ok ($x,$y) #$got"
```

- [ ] **Step 5: Write `make-samples.sh`**

```sh
#!/bin/sh
# Generate small sample media for the media library and the player.
. "$(dirname "$0")/redesign-env.sh"
V="$BUILD/redesign-media/Shows/The Clip/S01"; M="$BUILD/redesign-music"; mkdir -p "$V" "$M"
for i in 1 2 3 4 5 6; do
  ffmpeg -v error -y -f lavfi -i "testsrc=size=640x360:rate=25:duration=20" \
         -f lavfi -i "sine=frequency=$((300+i*50)):duration=20" -vf "hue=h=${i}0" \
         -c:v libx264 -preset ultrafast -c:a aac -shortest "$V/The_Clip_S01E0$i.mp4"
done
for n in untangle moonlight "black bird"; do
  ffmpeg -v error -y -f lavfi -i "sine=frequency=330:duration=15" -metadata artist=Tester \
         -metadata title="$n" "$M/$n.mp3"
done
printf ';FFMETADATA1\n[CHAPTER]\nTIMEBASE=1/1\nSTART=0\nEND=30\ntitle=One\n[CHAPTER]\nTIMEBASE=1/1\nSTART=30\nEND=60\ntitle=Two\n' > "$BUILD/redesign-media/ch.txt"
ffmpeg -v error -y -f lavfi -i "testsrc2=size=640x360:rate=25:duration=60" -i "$BUILD/redesign-media/ch.txt" \
       -map_metadata 1 -c:v libx264 -preset ultrafast "$BUILD/redesign-media/chapters.mkv"
echo samples ready
```

- [ ] **Step 6: Make executable and smoke-test the harness**

Run:
```bash
chmod +x docs/superpowers/scripts/*.sh
docs/superpowers/scripts/make-samples.sh
docs/superpowers/scripts/vlc-xvfb.sh start
docs/superpowers/scripts/vlc-xvfb.sh shot /tmp/redesign-base-home.png
docs/superpowers/scripts/vlc-xvfb.sh click 60 122     # sidebar "Video" in the current UI
sleep 3; docs/superpowers/scripts/vlc-xvfb.sh shot /tmp/redesign-base-video.png
docs/superpowers/scripts/vlc-xvfb.sh stop
```
Expected: `samples ready`, `ready`, two `saved …` lines; viewing `/tmp/redesign-base-video.png` shows the Video page (proves clicks are delivered). If `Xvfb` is missing: `sudo dnf install -y xorg-x11-server-Xvfb`.

- [ ] **Step 7: Commit**

```bash
git add docs/superpowers/scripts docs/superpowers/specs docs/superpowers/plans
git commit -m "doc: add redesign spec, plan and screenshot harness"
```

---

### Task 1: Figma dark-theme colour tokens

**Files:**
- Modify: `modules/gui/qt/style/systempalette.hpp:114` (default accent)
- Modify: `modules/gui/qt/style/systempalette.cpp` (`makeDarkPalette`, View/Window/Item/Slider sections)
- Test: `docs/superpowers/scripts/px.sh` against a home-screen capture

**Interfaces:**
- Produces: dark palette values later tasks rely on —
  `View.bg.primary=#0E0E0E`, `View.fg.primary=#C6C6C6`, `View.fg.secondary=#8F8F8F`, `View.separator=#222222`,
  `Window.bg.primary=#0E0E0E`, `Window.bg.secondary=#191919`, `accent=#D37918`.

- [ ] **Step 1: Write the failing visual check**

Capture the current home screen and assert the Figma page background (content area at 800,450) and title-bar
tint (top strip at 800,10):
```bash
S=docs/superpowers/scripts
$S/vlc-xvfb.sh start && $S/vlc-xvfb.sh shot /tmp/t1.png && $S/vlc-xvfb.sh stop
$S/px.sh /tmp/t1.png 800 450 '#0E0E0E'
```

- [ ] **Step 2: Run it to verify it fails**

Expected: `FAIL (800,450): got #2xxxxx want #0E0E0E` (current View bg is `darkGrey300`).

- [ ] **Step 3: Implement the tokens**

In `systempalette.hpp` change the dark accent default:
```cpp
    COLOR_DEFINITION(orange500, "#D37918");
```
In `systempalette.cpp`, inside `makeDarkPalette()` → View block, replace these lines:
```cpp
        setColor(CS, C::Bg, C::Primary, C::Normal, QColor("#0E0E0E") );
        setColor(CS, C::Bg, C::Secondary, C::Normal, Qt::black );

        setColor(CS, C::Fg, C::Primary, C::Normal, QColor("#C6C6C6") );
        setColor(CS, C::Fg, C::Primary, C::Disabled, setColorAlpha(QColor("#C6C6C6"), 0.3) );

        setColor(CS, C::Fg, C::Secondary, C::Normal, QColor("#8F8F8F"));
```
and further down in the same block:
```cpp
        setColor(CS, C::Decoration, C::Separator, C::Normal, QColor("#222222"));
```
Window block:
```cpp
    //window banner & miniplayer
    {
        C::ColorSet CS = C::Window;
        setColor(CS, C::Bg, C::Primary, C::Normal, QColor("#0E0E0E"));
        setColor(CS, C::Bg, C::Secondary, C::Normal, QColor("#191919"));
        setColor(CS, C::Decoration, C::Border, C::Normal, darkGrey800); //FIXME not a predef
    }
```
Item block (list text):
```cpp
        setColor(CS, C::Fg, C::Primary, C::Normal, QColor("#C6C6C6"));
        setColor(CS, C::Fg, C::Secondary, C::Normal, QColor("#8F8F8F"));
```
TabButton block (sidebar labels) — unselected `#8F8F8F`, focused/hovered `#C6C6C6`, checked label colour is `fg.secondary` in `SideNavigationDelegate` so set it to `#C6C6C6`:
```cpp
        setColor(CS, C::Fg, C::Primary, C::Normal, QColor("#8F8F8F"));
        setColor(CS, C::Fg, C::Primary, C::Focused, QColor("#C6C6C6"));
        setColor(CS, C::Fg, C::Primary, C::Hovered, QColor("#C6C6C6"));
        setColor(CS, C::Fg, C::Primary, C::Disabled, setColorAlpha(Qt::white, 0.2));
        setColor(CS, C::Fg, C::Secondary, C::Normal, QColor("#C6C6C6"));
```

- [ ] **Step 4: Rebuild and re-run the check**

```bash
ninja -C build && S=docs/superpowers/scripts
$S/vlc-xvfb.sh start && $S/vlc-xvfb.sh shot /tmp/t1.png && $S/vlc-xvfb.sh stop
$S/px.sh /tmp/t1.png 800 450 '#0E0E0E' && $S/px.sh /tmp/t1.png 800 10 '#0E0E0E' 10
```
Expected: two `ok` lines. Open `/tmp/t1.png` and confirm the sidebar's selected Home icon is the muted orange `#D37918`.

- [ ] **Step 5: Run the Qt test suite (no regressions)**

Run: `meson test -C build --suite qt`
Expected: `Ok: 7  Fail: 0`

- [ ] **Step 6: Commit**

```bash
git add modules/gui/qt/style/systempalette.hpp modules/gui/qt/style/systempalette.cpp
git commit -m "qt: use the redesign colour tokens in the dark palette"
```

---

### Task 2: Forward navigation in `NavigationHistory`

**Files:**
- Modify: `modules/gui/qt/util/navigation_history.hpp`
- Modify: `modules/gui/qt/util/navigation_history.cpp`
- Create: `modules/gui/qt/tests/test_navigation_history.cpp`
- Modify: `modules/gui/qt/meson.build` (register test after `test_qt_navigation_model`, ~line 1361)

**Interfaces:**
- Produces (QML singleton `History`):
  - `Q_PROPERTY(bool nextEmpty READ isNextEmpty NOTIFY nextEmptyChanged FINAL)`
  - `Q_INVOKABLE void next(Qt::FocusReason = Qt::OtherFocusReason)`
  - `push()` clears the forward stack; `previous()` moves the popped node onto it.

- [ ] **Step 1: Write the failing test**

`modules/gui/qt/tests/test_navigation_history.cpp`:
```cpp
/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *****************************************************************************/
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QTest>
#include <QSignalSpy>

#include "../util/navigation_history.hpp"

class TestNavigationHistory : public QObject
{
    Q_OBJECT
private slots:
    void init() { m_h = new NavigationHistory(this); m_h->update({"home"}); }
    void cleanup() { delete m_h; m_h = nullptr; }

    void testInitiallyNoForward() {
        QVERIFY(m_h->isNextEmpty());
        m_h->next();
        QCOMPARE(m_h->viewPath(), QStringList{"home"});
    }

    void testPreviousThenNextRoundTrip() {
        m_h->push({"video"});
        m_h->push({"video", "all"});
        QSignalSpy nextEmpty(m_h, &NavigationHistory::nextEmptyChanged);

        m_h->previous();
        QCOMPARE(m_h->viewPath(), (QStringList{"video"}));
        QVERIFY(!m_h->isNextEmpty());
        QCOMPARE(nextEmpty.count(), 1);

        m_h->next();
        QCOMPARE(m_h->viewPath(), (QStringList{"video", "all"}));
        QVERIFY(m_h->isNextEmpty());
        QVERIFY(!m_h->isPreviousEmpty());
        QCOMPARE(nextEmpty.count(), 2);
    }

    void testPushClearsForward() {
        m_h->push({"video"});
        m_h->previous();
        QVERIFY(!m_h->isNextEmpty());
        m_h->push({"music"});
        QVERIFY(m_h->isNextEmpty());
        m_h->next();
        QCOMPARE(m_h->viewPath(), QStringList{"music"});
    }

    void testNextKeepsProperties() {
        m_h->push({"video"}, QVariantMap{{"initialIndex", 3}});
        m_h->previous();
        m_h->next();
        QCOMPARE(m_h->viewProp()->value("initialIndex").toInt(), 3);
    }

private:
    NavigationHistory* m_h = nullptr;
};

QTEST_GUILESS_MAIN(TestNavigationHistory)
#include "test_navigation_history.moc"
```

Register it in `modules/gui/qt/meson.build`, right after the `test_qt_navigation_model` block:
```meson
        vlc_tests += {
            'name': 'test_qt_navigation_history',
            'sources': files(
                'tests/test_navigation_history.cpp',
                'util/navigation_history.hpp',
                'util/navigation_history.cpp'
            ),
            'moc_sources': files(
                'tests/test_navigation_history.cpp'
            ),
            'moc_headers': files(
                'util/navigation_history.hpp'
            ),
            'suite': ['qt'],
            'include_directories' : qt_include_dir,
            'link_with': [libvlccore, libvlc],
            'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep]
        }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ninja -C build && meson test -C build test_qt_navigation_history`
Expected: compile FAIL — `'class NavigationHistory' has no member named 'isNextEmpty'`.
(If the link instead fails on `NetworkTreeItem`/`MLItemId` symbols, add `'tests/vlc_stub_modules.cpp'` to `sources` as the navigation-model test does.)

- [ ] **Step 3: Implement**

`navigation_history.hpp` — add next to the existing `previousEmpty` property, signal and slot:
```cpp
    Q_PROPERTY(bool nextEmpty READ isNextEmpty NOTIFY nextEmptyChanged FINAL)
```
```cpp
    bool isNextEmpty() const;
```
```cpp
    void nextEmptyChanged(bool empty);
```
```cpp
    /// Go to the page left by the last previous()
    Q_INVOKABLE void next(Qt::FocusReason = Qt::OtherFocusReason);
```
and the member:
```cpp
    std::vector<std::pair<QStringList, std::unique_ptr<QQmlPropertyMap>>> m_forward;
```
`previous` needs no change — it is already in `public slots:`, which QML can call.

`navigation_history.cpp`:
```cpp
bool NavigationHistory::isNextEmpty() const
{
    return m_forward.empty();
}

void NavigationHistory::next(Qt::FocusReason reason)
{
    if (m_forward.empty())
        return;

    m_history.push_back(std::move(m_forward.back()));
    m_forward.pop_back();

    if (m_history.size() == 2)
        emit previousEmptyChanged(false);
    if (m_forward.empty())
        emit nextEmptyChanged(true);

    updateCurrent();
    emit navigate(reason);
}
```
At the top of **both** `push()` overloads, before `m_history.emplace_back(...)`:
```cpp
    if (!m_forward.empty())
    {
        m_forward.clear();
        emit nextEmptyChanged(true);
    }
```
In `previous()`, replace the first `m_history.pop_back();` with:
```cpp
    const bool wasNextEmpty = m_forward.empty();
    m_forward.push_back(std::move(m_history.back()));
    m_history.pop_back();
    if (wasNextEmpty)
        emit nextEmptyChanged(false);
```
(The following `while (!isNodeValid…)` loop keeps discarding invalid nodes without pushing them forward.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `ninja -C build && meson test -C build --suite qt`
Expected: `Ok: 8  Fail: 0`

- [ ] **Step 5: Commit**

```bash
git add modules/gui/qt/util/navigation_history.* modules/gui/qt/tests/test_navigation_history.cpp modules/gui/qt/meson.build
git commit -m "qt: add forward navigation to NavigationHistory"
```

---

### Task 3: Sidebar — labels and Figma card styling

**Files:**
- Modify: `modules/gui/qt/tests/test_navigation_model.cpp:177-225` (expected titles)
- Modify: `modules/gui/qt/maininterface/navigationmodel.cpp:272,286`
- Modify: `modules/gui/qt/maininterface/qml/SideNavigationPane.qml` (background, fading edge)
- Modify: `modules/gui/qt/maininterface/qml/SideNavigationDelegate.qml` (sizes, indicator, colours)

**Interfaces:**
- Consumes: Task 1 tokens (`Window.bg.secondary=#191919`, TabButton fg colours, accent).
- Produces: sidebar titles `Home, Videos, Music, Network, Discover` (URIs unchanged: `home, video, music, network, discover`).

- [ ] **Step 1: Update the model test to the new labels (failing)**

In `test_navigation_model.cpp` replace every `COMPARE_ROW(i++, "Video", …)` with `"Videos"` and every
`COMPARE_ROW(i++, "Browse", …)` with `"Network"` (lines 178, 180, 190, 218, 224 and the same pattern in the
music-expansion tests further down — use `sed -i 's/"Video", /"Videos", /; s/"Browse", /"Network", /'`).

- [ ] **Step 2: Run to verify it fails**

Run: `meson test -C build test_qt_navigation_model`
Expected: FAIL — `Compared values are not the same  Actual: "Video"  Expected: "Videos"`.

- [ ] **Step 3: Rename the entries**

`navigationmodel.cpp`:
```cpp
            ModelEntry videoEntry{ qtr("Videos"), "video", VLCIcons::topbar_video, QStringLiteral(":/icons/ic_fluent_filmstrip.svg") };
```
```cpp
        m_model.children.emplace_back(qtr("Network"), "network", VLCIcons::topbar_network, QStringLiteral(":/icons/ic_fluent_wifi_1.svg"));
```

- [ ] **Step 4: Run to verify it passes**

Run: `ninja -C build && meson test -C build test_qt_navigation_model`
Expected: `OK`

- [ ] **Step 5: Card background in `SideNavigationPane.qml`**

Replace the `background:` block:
```qml
    background: Item {
        Widgets.AcrylicBackground {
            anchors.fill: parent
            enabled: root.useAcrylic
            tintColor: theme.bg.primary
        }

        // Figma: rounded inner card behind the expanded sidebar items
        Rectangle {
            anchors.fill: parent
            anchors.margins: VLCStyle.margin_xsmall
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: theme.bg.secondary
            visible: root.delegateShowText
        }
    }
```
and change the list's fading edge (the background is no longer a single coloured item):
```qml
                fadingEdge.backgroundColor: root.delegateShowText ? theme.bg.secondary : "transparent"
```
Increase inner padding so items sit inside the card (Figma 12/16):
```qml
    padding: VLCStyle.margin_normal
    topPadding: VLCStyle.margin_xsmall + VLCStyle.margin_small
```
(`MainDisplay.qml` overrides `topPadding: 0` on the sidebar instance — change that line to
`topPadding: VLCStyle.margin_xsmall + VLCStyle.margin_small` as well.)

- [ ] **Step 6: Delegate per Figma in `SideNavigationDelegate.qml`**

- Row height 32 and 14 px spacing: set `implicitTopInset`/`implicitBottomInset` to `VLCStyle.dp(7, VLCStyle.scale)` and
  add `implicitHeight: VLCStyle.dp(32, VLCStyle.scale) + topInset + bottomInset` replacing the computed one.
- Icon 24 px, 8 px gap: `Layout.preferredWidth: VLCStyle.icon_normal`, `font.pixelSize: VLCStyle.icon_normal`, `spacing: VLCStyle.margin_xsmall`.
- Remove the left indicator: delete the `Widgets.CurrentIndicator { … }` child of the background.
- Label: `font.weight: Font.Normal` (Figma uses Regular for the selected item too); keep
  `color: control.checked ? theme.fg.secondary : theme.fg.primary` (Task 1 maps these to `#C6C6C6` / `#8F8F8F`).
- Background: no fill unless hovered/focused — keep `AnimatedBackground` but its colour now comes from TabButton bg (transparent normal).

- [ ] **Step 7: Visual check**

```bash
ninja -C build && S=docs/superpowers/scripts
$S/vlc-xvfb.sh start && $S/vlc-xvfb.sh shot /tmp/t3.png && $S/vlc-xvfb.sh stop
$S/px.sh /tmp/t3.png 4 450 '#0E0E0E' 10 && $S/px.sh /tmp/t3.png 100 450 '#191919' 10
```
Expected: two `ok` lines (outer strip and inner card). Open `/tmp/t3.png`: labels read Home / Videos / Music /
Network / Discover, Home's icon is accent, no orange bar left of it.

- [ ] **Step 8: Collapsed-rail check (Review Focus 5)**

```bash
$S/vlc-xvfb.sh start && $S/vlc-xvfb.sh click 52 49   # panel toggle, collapses the sidebar
sleep 2; $S/vlc-xvfb.sh shot /tmp/t3b.png; $S/vlc-xvfb.sh stop
$S/px.sh /tmp/t3b.png 30 450 '#0E0E0E' 10
```
Expected: `ok` (no card colour in the icon rail). The toggle position moves in Task 4; if this runs after Task 4
use the toggle's new position from the Task 4 screenshot.

- [ ] **Step 9: Commit**

```bash
git add modules/gui/qt/maininterface modules/gui/qt/tests/test_navigation_model.cpp
git commit -m "qml: restyle the sidebar after the redesign"
```

---

### Task 4: Title bar — logo + `…` left, centred title, fullscreen button

**Files:**
- Modify: `modules/gui/qt/maininterface/qml/LocalTopbar.qml`

**Interfaces:**
- Consumes: `MainCtx.toggleInterfaceFullScreen()` (slot), `MainCtx.intfMainWindow.title`, `VLCIcons.ellipsis`, `VLCIcons.fullscreen`/`defullscreen`.
- Produces: `historyBack` removed from the title bar (Task 5 owns back/forward). `navigationButton` alias still points at the panel toggle.

- [ ] **Step 1: Write the failing visual check**

The centred title text is grey `#8F8F8F`; today nothing is drawn at the centre of the 40 px bar:
```bash
S=docs/superpowers/scripts
$S/vlc-xvfb.sh start && $S/vlc-xvfb.sh shot /tmp/t4.png && $S/vlc-xvfb.sh stop
magick /tmp/t4.png -crop 300x40+650+0 -fuzz 12% -fill white -opaque '#8F8F8F' -fill black +opaque white -format '%[fx:mean>0.01]' info:
```
Expected now: second command prints `0` (no title pixels). It must print `1` after Step 3.

- [ ] **Step 2: Restructure the left row**

In `navigationButtonsRow`, order the children **logo → menu → panel toggle**, and delete `historyBack`:
```qml
                Widgets.BannerCone {
                    id: logo

                    sourceSize.width: VLCStyle.icon_normal
                    sourceSize.height: VLCStyle.icon_normal
                    color: theme.accent
                }

                Widgets.IconToolButton {
                    id: menuBtn

                    visible: !MainCtx.hasToolbarMenu
                    font.pixelSize: VLCStyle.icon_banner
                    text: VLCIcons.ellipsis
                    description: qsTr("Menu")
                    width: VLCStyle.bannerButton_width
                    height: VLCStyle.bannerButton_height
                    checked: contextMenu.shown

                    Navigation.parentItem: navigationButtons
                    Navigation.rightItem: navigationVisibilty

                    onClicked: contextMenu.popup(this.mapToGlobal(0, height))

                    Menus.QmlGlobalMenu {
                        id: contextMenu
                        ctx: MainCtx
                    }
                }

                Widgets.IconToolButton {
                    id: navigationVisibilty
                    // … unchanged body, but:
                    Navigation.leftItem: menuBtn
                    Navigation.rightItem: playlistBtn
                }
```
Set the row `spacing: VLCStyle.margin_xsmall` (Figma gap 7–10). Remove the old `menuBtn` from
`playqueueButtonsTopRow` and set `playlistBtn`'s `Navigation.leftItem: navigationVisibilty`, `Navigation.rightItem: fullscreenBtn`.

- [ ] **Step 3: Centred window title and fullscreen button**

Add inside `contentItem` (after the two `Item`s):
```qml
        T.Label {
            id: windowTitle

            anchors.centerIn: parent
            width: Math.min(implicitWidth,
                            playqueueButtonsTop.x - (navigationButtons.x + navigationButtons.width) - VLCStyle.margin_large * 2)

            text: MainCtx.intfMainWindow.title
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            elide: Text.ElideRight
            visible: width > VLCStyle.dp(40, VLCStyle.scale)

            Accessible.ignored: true
        }
```
Append to `playqueueButtonsTopRow`, after `playlistBtn`:
```qml
                Widgets.IconToolButton {
                    id: fullscreenBtn

                    font.pixelSize: VLCStyle.icon_banner
                    width: VLCStyle.bannerButton_width
                    height: VLCStyle.bannerButton_height
                    text: (MainCtx.intfMainWindow.visibility === Window.FullScreen) ? VLCIcons.defullscreen
                                                                                     : VLCIcons.fullscreen
                    description: qsTr("Fullscreen")

                    Navigation.parentItem: playqueueButtonsTop
                    Navigation.leftItem: playlistBtn

                    onClicked: MainCtx.toggleInterfaceFullScreen()
                }
```
Title bar background tint: change `tintColor: theme.bg.primary` to `tintColor: theme.bg.secondary` (Figma `#191919`).

- [ ] **Step 4: Rebuild and re-run the check**

```bash
ninja -C build && S=docs/superpowers/scripts
$S/vlc-xvfb.sh start && $S/vlc-xvfb.sh shot /tmp/t4.png && $S/vlc-xvfb.sh stop
magick /tmp/t4.png -crop 300x40+650+0 -fuzz 12% -fill white -opaque '#8F8F8F' -fill black +opaque white -format '%[fx:mean>0.01]' info:
```
Expected: `1`. Open `/tmp/t4.png`: left shows cone, `…`, panel toggle; centre "VLC media player"; right shows
play-queue, fullscreen, then window buttons.

- [ ] **Step 5: Menu still opens**

```bash
$S/vlc-xvfb.sh start && $S/vlc-xvfb.sh click 50 20 && sleep 1 && $S/vlc-xvfb.sh shot /tmp/t4m.png && $S/vlc-xvfb.sh stop
```
Expected: `/tmp/t4m.png` shows the global menu dropped under the `…` button.

- [ ] **Step 6: Commit**

```bash
git add modules/gui/qt/maininterface/qml/LocalTopbar.qml
git commit -m "qml: rearrange the title bar after the redesign"
```

---

### Task 5: Page header — back/forward, title, item count, divider

**Files:**
- Modify: `modules/gui/qt/widgets/qml/PageExt.qml` (`DefaultPageHeader`)

**Interfaces:**
- Consumes: `History.previous()`, `History.previousEmpty`, `History.next()`, `History.nextEmpty` (Task 2); `_firstChild.count` (exposed by `MainViewLoader.count`).
- Produces: `PageExt.itemCount` (`int`, `-1` when unknown).

- [ ] **Step 1: Write the failing visual check**

The header must show the Figma divider (`#222222`, 1 px) under the header row on the Home page:
```bash
S=docs/superpowers/scripts
$S/vlc-xvfb.sh start && $S/vlc-xvfb.sh shot /tmp/t5.png && $S/vlc-xvfb.sh stop
magick /tmp/t5.png -crop 1x120+900+40 -fuzz 3% -fill white -opaque '#222222' -fill black +opaque white -format '%[fx:maxima.r]' info:
```
Expected now: `0` (no divider). Must be `1` after Step 3.

- [ ] **Step 2: Add `itemCount` to `PageExt`**

Next to `hasGridListMode`:
```qml
    // number of items in the current subview, -1 when the subview has no model count
    readonly property int itemCount: (typeof _firstChild?.count === "number") ? _firstChild.count : -1
```

- [ ] **Step 3: Rebuild `DefaultPageHeader`'s row**

Replace the `RowLayout { id: row … }` with:
```qml
        ColumnLayout {
            anchors.fill: parent
            spacing: VLCStyle.dp(17, VLCStyle.scale)

            RowLayout {
                spacing: VLCStyle.dp(20, VLCStyle.scale)
                Layout.fillWidth: true

                Row {
                    spacing: VLCStyle.margin_small

                    IconToolButton {
                        id: backBtn
                        text: VLCIcons.back
                        description: qsTr("Previous")
                        font.pixelSize: VLCStyle.icon_normal
                        enabled: !History.previousEmpty
                        onClicked: History.previous()
                    }

                    IconToolButton {
                        id: forwardBtn
                        text: VLCIcons.back
                        rotation: 180
                        description: qsTr("Next")
                        font.pixelSize: VLCStyle.icon_normal
                        enabled: !History.nextEmpty
                        onClicked: History.next()
                    }
                }

                T.Label {
                    id: label
                    Layout.fillWidth: true
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                    elide: Text.ElideRight
                }

                T.Label {
                    visible: root.itemCount >= 0
                    text: qsTr("%n item(s)", "", root.itemCount)
                    color: theme.fg.secondary.alpha(0.75)
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                }

                GridSortFilterControls {
                    id: gridSortFilter
                    focus: true
                    sort: _sortCtx
                    search: _searchCtx
                    Navigation.parentItem: defaultPageHeader
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: VLCStyle.dp(1, VLCStyle.scale)
                color: theme.separator
            }
        }
```
Keep `property alias text: label.text`. Change `topPadding` to `VLCStyle.dp(20, VLCStyle.scale)` and
`bottomPadding` to `VLCStyle.dp(17, VLCStyle.scale)` (Figma frame padding 20, gap 17). Add `import VLC.Widgets`
is not needed (file is in that module); `History` comes from `VLC.Util` (already imported).

- [ ] **Step 4: Rebuild and re-run the check**

```bash
ninja -C build && S=docs/superpowers/scripts
$S/vlc-xvfb.sh start && $S/vlc-xvfb.sh shot /tmp/t5.png && $S/vlc-xvfb.sh stop
magick /tmp/t5.png -crop 1x120+900+40 -fuzz 3% -fill white -opaque '#222222' -fill black +opaque white -format '%[fx:maxima.r]' info:
```
Expected: `1`.

- [ ] **Step 5: Back/forward behaviour on a real page**

```bash
$S/vlc-xvfb.sh start
$S/vlc-xvfb.sh click 60 140; sleep 3   # sidebar "Videos" (after Task 3 spacing; adjust from /tmp/t3.png)
$S/vlc-xvfb.sh shot /tmp/t5a.png
$S/vlc-xvfb.sh key alt+Left; sleep 2; $S/vlc-xvfb.sh shot /tmp/t5b.png
$S/vlc-xvfb.sh stop
```
Expected: `/tmp/t5a.png` header reads "Videos" with a count like "6 items" (the samples) and enabled ←;
after `alt+Left` (or clicking ←) `/tmp/t5b.png` is Home with → enabled.

- [ ] **Step 6: Commit**

```bash
git add modules/gui/qt/widgets/qml/PageExt.qml
git commit -m "qml: redesign the page header with back/forward and item count"
```

---

### Task 6: Flat `…` main menu

**Files:**
- Modify: `modules/gui/qt/menus/menus.hpp` (declare `MainMenu`)
- Modify: `modules/gui/qt/menus/menus.cpp` (implement `MainMenu`)
- Modify: `modules/gui/qt/menus/qml_menu_wrapper.cpp:244-292` (`QmlGlobalMenu::popup`)

**Interfaces:**
- Consumes: `addDPStaticEntry`, `DialogsProvider` slots, existing `NavigMenu/AudioMenu/VideoMenu/SubtitleMenu/ToolsMenu/ViewMenu/HelpMenu`.
- Produces: `static void VLCMenuBar::MainMenu(qt_intf_t*, QMenu*)`.

- [ ] **Step 1: Write the failing visual check**

```bash
S=docs/superpowers/scripts
$S/vlc-xvfb.sh start && $S/vlc-xvfb.sh click 50 20 && sleep 1 && $S/vlc-xvfb.sh shot /tmp/t6.png && $S/vlc-xvfb.sh stop
```
Expected now: the menu's first row is "Media ›" (a submenu). After Step 3 the first row must be "Open File(s)… Ctrl+O".

- [ ] **Step 2: Declare and implement `MainMenu`**

`menus.hpp`, next to `FileMenu`:
```cpp
    static void MainMenu( qt_intf_t *, QMenu * );
```
`menus.cpp`, after `FileMenu`:
```cpp
/**
 * Flat main ("…") menu of the redesigned interface
 **/
void VLCMenuBar::MainMenu( qt_intf_t *p_intf, QMenu *menu )
{
    auto mi = p_intf->p_mi;

    addDPStaticEntry( menu, qtr( "Open &File(s)..." ),
        ":/menu/file.svg", []() { THEDP->simpleOpenDialog(); }, "Ctrl+O" );
    addDPStaticEntry( menu, qtr( "Open F&older..." ),
        ":/menu/folder.svg", &DialogsProvider::PLOpenDir, "Ctrl+F" );
    addDPStaticEntry( menu, qtr( "Open &Network Stream..." ),
        ":/menu/network.svg", &DialogsProvider::openNetDialog, "Ctrl+N" );
    addDPStaticEntry( menu, qtr( "Open &Disc..." ),
        ":/menu/disc.svg", &DialogsProvider::openDiscDialog, "Ctrl+D" );
    addDPStaticEntry( menu, qtr( "Open &Capture Device..." ),
        ":/menu/capture-card.svg", &DialogsProvider::openCaptureDialog, "Ctrl+C" );
    addDPStaticEntry( menu, qtr( "Conve&rt..." ), "",
        &DialogsProvider::openAndTranscodingDialogs, "Ctrl+R" );

    if( mi && var_InheritBool( p_intf, "save-recentplay" ) && mi->hasMediaLibrary() )
    {
        MLRecentMediaModel* recentModel = new MLRecentMediaModel(nullptr);
        recentModel->setMl(mi->getMediaLibrary());
        recentModel->setLimit(10);
        QMenu* recentsMenu = new RecentMenu(recentModel, mi->getMediaLibrary(), menu);
        recentsMenu->setTitle(qtr( "Open &Recent" ) );
        recentModel->setParent(recentsMenu);
        menu->addMenu( recentsMenu );
    }

    menu->addSeparator();

    if( !p_intf->b_isDialogProvider )
        addDPStaticEntry( menu, qtr( "Customi&ze Player..." ),
            ":/menu/preferences.svg", &DialogsProvider::showToolbarEditorDialog );
    addDPStaticEntry( menu, qtr( "&Settings" ),
        ":/menu/preferences.svg", &DialogsProvider::prefsDialog, "Ctrl+P", QAction::PreferencesRole );
    addDPStaticEntry( menu, qfut( I_MENU_ABOUT ), ":/menu/info.svg",
        &DialogsProvider::aboutDialog, "Shift+F1", QAction::AboutRole );

    /* Everything the redesign does not list stays reachable */
    menu->addSeparator();
    QMenu* more = menu->addMenu( qtr( "&More" ) );
    NavigMenu( p_intf, more->addMenu( qtr( "P&layback" ) ) );
    AudioMenu( p_intf, more->addMenu( qtr( "&Audio" ) ) );
    VideoMenu( p_intf, more->addMenu( qtr( "&Video" ) ) );
    SubtitleMenu( p_intf, more->addMenu( qtr( "Subti&tle" ) ) );
    ToolsMenu( p_intf, more->addMenu( qtr( "Tool&s" ) ) );
    ViewMenu( p_intf, more->addMenu( qtr( "V&iew" ) ) );
    HelpMenu( p_intf, more->addMenu( qtr( "&Help" ) ) );
    addDPStaticEntry( menu, qtr( "&Quit" ), ":/menu/exit.svg", &DialogsProvider::quit, "Ctrl+Q" );
}
```
`qml_menu_wrapper.cpp` — in `QmlGlobalMenu::popup`, replace everything between the two `connect(...)` calls
and `m_menu->popup(pos);` with:
```cpp
    MainMenu( p_intf, m_menu.get() );
```
(delete the now-unused `QMenu* submenu;` line).

- [ ] **Step 3: Rebuild and re-check**

```bash
ninja -C build && S=docs/superpowers/scripts
$S/vlc-xvfb.sh start && $S/vlc-xvfb.sh click 50 20 && sleep 1 && $S/vlc-xvfb.sh shot /tmp/t6.png
$S/vlc-xvfb.sh click 60 400 ; sleep 1 ; $S/vlc-xvfb.sh shot /tmp/t6b.png   # hover/click "More"
$S/vlc-xvfb.sh stop
```
Expected: `/tmp/t6.png` lists Open File(s)… Ctrl+O, Open Folder… Ctrl+F, Open Network Stream… Ctrl+N, Open
Disc… Ctrl+D, Open Capture Device… Ctrl+C, Convert… Ctrl+R, Open Recent ›, —, Customize Player…, Settings
Ctrl+P, About, —, More ›, Quit Ctrl+Q. `/tmp/t6b.png` shows the More submenu with Playback…Help (adjust the
click coordinate to the More row seen in `/tmp/t6.png`).

- [ ] **Step 4: Run the Qt suite**

Run: `meson test -C build --suite qt` — Expected: all OK.

- [ ] **Step 5: Commit**

```bash
git add modules/gui/qt/menus
git commit -m "qt: flatten the global menu after the redesign"
```

---

### Task 7: Compact mini-player bar (inline block seek bar, play pill)

**Files:**
- Modify: `modules/gui/qt/player/qml/ControlRepeater.qml` (forward `compactStyle`)
- Modify: `modules/gui/qt/player/qml/ControlLayout.qml` (forward `compactStyle`)
- Modify: `modules/gui/qt/player/qml/PlayerControlLayout.qml` (`compactStyle`, `fillerItem`)
- Modify: `modules/gui/qt/player/qml/controlbarcontrols/PlayButton.qml` (pill variant)
- Modify: `modules/gui/qt/player/qml/SliderBar.qml` (`blockStyle`, `progressColor`)
- Modify: `modules/gui/qt/player/qml/ControlBar.qml` (`TimeTextPosition.Inline`, `compactStyle`)
- Modify: `modules/gui/qt/player/qml/MiniPlayer.qml`
- Modify: `modules/gui/qt/dialogs/toolbar/controlbar_profile_model.cpp:145-165` (Default style Miniplayer layout)

**Interfaces:**
- Consumes: Task 1 accent; existing `ControlBar.TimeTextPosition`.
- Produces:
  - `ControlBar.TimeTextPosition.Inline` (enum value 3), `ControlBar.compactStyle: bool`
  - `PlayerControlLayout.compactStyle: bool`, `PlayerControlLayout.fillerItem: Item` (null when centre section is used)
  - `ControlRepeater.compactStyle` / `ControlLayout.compactStyle` → assigned to any control exposing `compactStyle`
  - `SliderBar.blockStyle: bool`, `SliderBar.progressColor: color`
  - `PlayButton.compactStyle: bool`

- [ ] **Step 1: New default Miniplayer layout (Figma: prev/play/next … volume, tracks, settings, queue)**

In `controlbar_profile_model.cpp`, `DEFAULT_STYLE` → `PlayerControlbarModel::Miniplayer` block becomes:
```cpp
                    {
                        PlayerControlbarModel::Miniplayer,
                        {
                            {
                                {
                                    ControlListModel::PREVIOUS_BUTTON,
                                    ControlListModel::PLAY_BUTTON,
                                    ControlListModel::NEXT_BUTTON
                                },
                                {

                                },
                                {
                                    ControlListModel::VOLUME,
                                    ControlListModel::LANG_BUTTON,
                                    ControlListModel::EXTENDED_BUTTON,
                                    ControlListModel::PLAYLIST_BUTTON
                                }
                            }
                        }
                    }
```

- [ ] **Step 2: Write the failing visual check**

Play a clip, go back to the library so the mini player shows, and sample the play pill (accent) at the bar's left:
```bash
rm -rf build/redesign-profile/config/vlc   # fresh profile → new default layout
S=docs/superpowers/scripts
$S/vlc-xvfb.sh start "build/redesign-media/Shows/The Clip/S01/The_Clip_S01E01.mp4"
$S/vlc-xvfb.sh key space; sleep 1            # pause so the pill shows the accent "play" state
$S/vlc-xvfb.sh click 20 20; sleep 3          # player top-left back button → library
$S/vlc-xvfb.sh shot /tmp/t7.png; $S/vlc-xvfb.sh stop
$S/px.sh /tmp/t7.png 85 873 '#D37918' 12
```
Expected now: FAIL (round white play button / different layout).

- [ ] **Step 3: Forward `compactStyle` through the repeaters**

`ControlRepeater.qml` — add `property bool compactStyle: false` next to `alignment`, and in the delegate's
`onLoaded` after the `item.visible` binding:
```qml
            if (typeof item.compactStyle === "boolean")
                item.compactStyle = Qt.binding(function() { return repeater.compactStyle })
```
`ControlLayout.qml` — add `property bool compactStyle: false` and on its `ControlRepeater {` add
`compactStyle: <ControlLayout root id>.compactStyle` (the root id is the one used for `model:` in that file).

`PlayerControlLayout.qml`:
```qml
    property bool compactStyle: false

    // Spacer between left and right sections when there is no centre section;
    // ControlBar may place an inline seek bar inside it.
    property Item fillerItem: null
```
Add `compactStyle: playerControlLayout.compactStyle` to both `ControlRepeater`s in `loaderLeftRight` and to the
three `ControlLayout`s. In `loaderLeftRight`'s filler `Item { … Layout.fillWidth: true … }` add:
```qml
                implicitHeight: parent.height
                Layout.fillHeight: true
                Component.onCompleted: playerControlLayout.fillerItem = this
                Component.onDestruction: {
                    if (playerControlLayout.fillerItem === this)
                        playerControlLayout.fillerItem = null
                }
```

- [ ] **Step 4: Pill variant of `PlayButton`**

Add `property bool compactStyle: false`. In `background: Item {`:
```qml
        implicitWidth: root.compactStyle ? VLCStyle.dp(54, VLCStyle.scale) : height
        implicitHeight: root.compactStyle ? VLCStyle.dp(28, VLCStyle.scale) : VLCStyle.icon_medium

        Rectangle {
            visible: root.compactStyle
            anchors.fill: parent
            radius: VLCStyle.dp(6, VLCStyle.scale)
            readonly property bool _playing: Player.playingState === Player.PLAYING_STATE_PLAYING
            color: _playing ? "#6B6B6B" : theme.accent
            border.color: root.visualFocus ? theme.visualFocus : "transparent"
        }
```
Give the existing `Widgets.AnimatedBackground` and round gradient `Rectangle` `visible: !root.compactStyle`.
In `contentItem`, size the glyph from the pill height:
```qml
        font.pixelSize: root.compactStyle ? VLCStyle.icon_normal * 0.8 : Math.round(parent.height / 1.7)
        color: root.compactStyle ? "black" : (cursorInside ? theme.accent : "black")
```

- [ ] **Step 5: Block style in `SliderBar.qml`**

```qml
    property bool blockStyle: false
    property color progressColor: theme.fg.primary

    readonly property real _hoveredScalingFactor: blockStyle ? 1.0 : 1.8
    readonly property real _blockInset: VLCStyle.dp(2, VLCStyle.scale)
```
`sliderRect`: `radius: control.blockStyle ? VLCStyle.dp(6, VLCStyle.scale) : implicitHeight`.
`progressRect`:
```qml
            x: control.blockStyle ? control._blockInset : 0
            y: control.blockStyle ? control._blockInset : 0
            width: control.visualPosition * (parent.width - x * 2)
            height: control.blockStyle ? control.barHeight - control._blockInset * 2 : control.barHeight
            radius: control.blockStyle ? VLCStyle.dp(4, VLCStyle.scale) : control._seekPointsRadius
            color: control.progressColor
```
`sliderHandle`:
```qml
        implicitWidth: control.blockStyle ? VLCStyle.dp(8, VLCStyle.scale) : sliderHandle._size
        implicitHeight: control.blockStyle ? control.barHeight - control._blockInset * 2 : sliderHandle._size
        radius: control.blockStyle ? VLCStyle.dp(4, VLCStyle.scale) : VLCStyle.margin_small
        color: control.blockStyle ? theme.accent : theme.fg.primary
        state: control.blockStyle ? "" : ((hoverHandler.hovered || control.visualFocus) ? (/* existing expression */) : "hidden")
```
(`x` stays `visualPosition * availableWidth - width / 2`; clamp for block style:
`x: Math.max(0, Math.min(control.availableWidth - width, (control.visualPosition * control.availableWidth) - width / 2))` when `blockStyle`.)

- [ ] **Step 6: `ControlBar.qml` Inline mode**

```qml
    enum TimeTextPosition {
        Hide,
        AboveSlider,
        LeftRightSlider,
        Inline
    }

    property bool compactStyle: false
    property color backgroundColor: theme.bg.primary

    // Inline needs the spacer slot; fall back when a custom profile fills the centre section
    readonly property int _textPosition: (textPosition === ControlBar.TimeTextPosition.Inline
                                          && !contentItem.playerControlLayout.fillerItem)
                                         ? ControlBar.TimeTextPosition.LeftRightSlider
                                         : textPosition
```
- Replace every `textPosition` read inside the file (the `switch`es, `Layout.preferredWidth` conditions,
  `timeTextMetrics.font.pixelSize`) with `root._textPosition`, treating `Inline` like `LeftRightSlider`
  for widths; font for Inline: `VLCStyle.dp(15, VLCStyle.scale)`.
- `background: Rectangle { color: root.backgroundColor }`.
- `mediaTime.color` / `mediaRemainingTime.color`: `root.compactStyle ? theme.fg.secondary : theme.fg.primary`.
- `trackPositionSlider`: add `blockStyle: root.compactStyle`,
  `backgroundColor: root.compactStyle ? "#090909" : theme.bg.primary` and
  `progressColor: root.compactStyle ? Qt.tint("#090909", Qt.alpha(theme.accent, 0.26)) : theme.fg.primary`.
- `bookmarksLoader.active: MainCtx.mediaLibraryAvailable && root._textPosition !== ControlBar.TimeTextPosition.Inline`.
- `playerControlLayout`: add `compactStyle: root.compactStyle`; `Layout.leftMargin/rightMargin: root.compactStyle ? VLCStyle.dp(20, VLCStyle.scale) : VLCStyle.margin_large`; `spacing: root.compactStyle ? VLCStyle.margin_xsmall : VLCStyle.margin_normal`.
- New inline row, appended to `strayItems`'s siblings in `contentItem`:
```qml
        RowLayout {
            id: inlineRow
            parent: contentItem.playerControlLayout.fillerItem
            anchors.fill: parent ?? undefined
            anchors.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
            spacing: VLCStyle.margin_xsmall
            visible: root._textPosition === ControlBar.TimeTextPosition.Inline
            children: visible ? [mediaTime, trackPositionSlider, mediaRemainingTime] : []
        }
```
  and make `row2.children` / `pseudoRow.children` return `[]` for `Inline` (both `switch`es get `case ControlBar.TimeTextPosition.Inline:` grouped with `Hide`).

- [ ] **Step 7: `MiniPlayer.qml` uses the compact Inline style**

```qml
    compactStyle: true
    textPosition: ControlBar.TimeTextPosition.Inline
    sliderHeight: VLCStyle.dp(28, VLCStyle.scale)
    backgroundColor: colorContext.palette.isDark ? "#1B1B1B" : colorContext.bg.primary
    topPadding: VLCStyle.dp(11, VLCStyle.scale)
    bottomPadding: VLCStyle.dp(11, VLCStyle.scale)
```
and delete the now-unused `bookmarksHeight` conditional and the old `textPosition`/`sliderHeight` bindings.

Fallback check (Review Focus 1): in the toolbar editor ("…" → Customize Player…) put any button in the Mini
player's centre section; the time/seek row must appear above the buttons (`LeftRightSlider`) instead of
disappearing. Screenshot it with the harness after adding the button by drag (or by editing
`build/redesign-profile/config/vlc/vlc-qt-interface.conf` `[MainWindow]` profile string, moving one control id
into the centre field).

- [ ] **Step 8: Rebuild and re-run the check**

```bash
ninja -C build
rm -rf build/redesign-profile/config/vlc
S=docs/superpowers/scripts
$S/vlc-xvfb.sh start "build/redesign-media/Shows/The Clip/S01/The_Clip_S01E01.mp4"
$S/vlc-xvfb.sh key space; sleep 1; $S/vlc-xvfb.sh click 20 20; sleep 3
$S/vlc-xvfb.sh shot /tmp/t7.png; $S/vlc-xvfb.sh stop
$S/px.sh /tmp/t7.png 85 873 '#D37918' 12      # play pill (paused → accent)
$S/px.sh /tmp/t7.png 800 873 '#090909' 8      # seek track, middle of the bar
```
Expected: two `ok` lines. Open `/tmp/t7.png`: bar = ⏮ [▶ pill] ⏭ 00:00 ▬▬▬▬▬ 00:20 🔊 … ⚙ ☰, height ≈ 54 px.
If the pill is not at x≈85, read its position from the image and update both commands (layout margins differ by font metrics).

- [ ] **Step 9: Chapters check (Review Focus 4)**

```bash
$S/vlc-xvfb.sh start build/redesign-media/chapters.mkv
$S/vlc-xvfb.sh click 20 20; sleep 3; $S/vlc-xvfb.sh shot /tmp/t7c.png; $S/vlc-xvfb.sh stop
```
Expected: two chapter segments visible in the mini bar and the accent handle visible.

- [ ] **Step 10: Full player unaffected**

```bash
$S/vlc-xvfb.sh start --start-paused "build/redesign-media/Shows/The Clip/S01/The_Clip_S01E02.mp4"
sleep 2; $S/vlc-xvfb.sh shot /tmp/t7p.png; $S/vlc-xvfb.sh stop
```
Expected: `/tmp/t7p.png` still shows the thin seek bar with times above and the round white play button.

- [ ] **Step 11: Qt suite and commit**

```bash
meson test -C build --suite qt
git add modules/gui/qt/player modules/gui/qt/dialogs/toolbar/controlbar_profile_model.cpp
git commit -m "qml: compact mini player bar with inline seek bar"
```

---

## Out of scope (slice 2+)

Home page sections (Continue Watching / Listen Again / Frequently Visited), floating mini-player card,
multi-level breadcrumbs, always-visible search field, Playlists/Recent/Add-item sidebar entries, gradient volume
meter, sort/view popup restyle, Settings window, Open Network Stream / new-playlist dialogs, onboarding, light theme.
