# VLC Redesign — Slice 3c: Player Settings Tabs and Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The player's gear panel gains Video, Audio and Subtitles *settings* tabs after Playback, as in Figma. They hold defaults, synchronisation, the filters as collapsible accordions, and an "Open Advanced Settings" footer. Together they replace the Qt Widgets "Effects and Filters" dialog for everything Figma designs.

**Architecture:**
- **C++ bridge.** One new QObject, `PlayerEffects`, is registered as the QML singleton `Effects` in `VLC.Player`. Through a small generic API, QML can:
  - switch audio, video and sub filters on and off;
  - read and write their float/int/bool/string vars live on the aout or vout, and persist them to the config;
  - drive the equalizer, the transform (flip and rotate), the vout crop borders and the subtitle text scale.
- **Pure helpers.** The string logic lives in `player/effects_util.{hpp,cpp}` and is unit-tested without a player: the filter-list edits, the equalizer band string, and the flip+rotation ↔ `transform-type` mapping.
- **QML controls.** Each Figma control is one file in `player/qml/settings/`. The three pages are new files that `PlaybackPanel.qml` hosts.
- **Existing models are reused** where they exist: `Player.zoom`, `aspectRatio`, `crop`, `audioStereoMode`, `rendererManager`, `audioDelayMS`, `subtitleDelayMS` and `subtitleFPS`.

**Tech Stack:**
- Qt 6.11 QML (QtQuick.Templates, Layouts) and C++17 QObject.
- libvlccore: `var_*`, `config_*`, `vlc_player_aout_EnableFilter` and `vlc_player_SetSubtitleTextScale`.
- QTest via meson `vlc_tests`, plus the Xvfb harness.

**Spec:**
- **Figma file `d9xvroRclV6SaObbcqRmBr`**, Galen's duplicate of "VLC Redesign (Community)". The old key `dSoAm0gN9ZterHSssJU9FN` is not readable from this Figma account; node IDs are the same in both.
- **`Controls` variants:** video settings `498:2937` (card `498:2965`), audio settings `536:1059` (card `536:1087`), subtitle settings `763:1958` (card `763:1986`).
- **Accordions:**
  - Video: Essential `536:1855`, Crop `543:990`, Colors `614:1430`.
  - Audio: Equalizer `6114:13610`, Compressor `536:1513`, Spatializer `536:1703`, Stereo Widener `612:1223`.
- **Reference shots:** `docs/superpowers/figma/3c/` (`c_vset/c_aset/c_sset.png` cards, `fx_*.png` accordions).
- **Roadmap:** `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md`, row 3c.
- **Source video:** `~/Workspace/vlc-redesign-implementation/I-Redesigned-VLC-SnapYT.App.mp4` (21 min, 4K). This is a secondary reference only; Figma wins on any conflict.
- **Memory `figma-is-the-spec`:** the old effects dialog is not a reference for *look*, only for *which VLC var does what*.

## Scope rulings (from Figma vs. what VLC can do)

Kept: every Figma control below that has a VLC feature behind it. Omitted, because nothing in VLC 4 backs them (the same rule as slice 3a):

| Figma control | Ruling |
|---|---|
| Video → **HDR** combo | Omitted. VLC 4 has no core HDR switch, only per-backend `gl-tone-mapping-*`/`d3d11-hdr-mode`, read when the vout opens. |
| Video filters → **Geometry**, **Overlay**, **Advanced** rows | Omitted. Figma draws only a collapsed "Expand Settings" for them and designs no contents. |
| Audio → Stereo Mode **Test** button | Omitted (no test-tone feature). |
| Subtitles → **Embedded Sub Format** toggle | Omitted (no VLC option). |
| Subtitles → **Size Values** Relative/Pixels | Omitted. `freetype-fontsize` (pixels) is obsolete in VLC 4; size is `sub-text-scale` only. |
| Footer **Default Preset** dropdown | Kept as **reset**: the button opens a one-item menu, "Reset to Default Preset". It resets the current tab's persisted values to the module defaults. VLC has no named presets. |

Value mapping decisions:
- Spatializer sliders show VLC's 0–1 values ×10 (Figma "Size 8.0", "Width 10.0").
- Stereo Widener shows the raw VLC values: delay in ms; feedback, crossfeed and dry mix as fractions with the "%" unit Figma prints. Do not ×100: Figma's "0.2 %" for feedback 0.3 shows it is a label, not a percentage.
- Font Size has 6 stops on `sub-text-scale`: 50, 75, 100 ("Auto", the default), 125, 150, 200. These match Figma's six ticks.
- Outline Thickness has 4 stops on `freetype-outline-thickness`: None 0, Thin 2, Normal 4, Thick 6. Background Opacity runs 0–100 % in steps of 10, mapped to `freetype-background-opacity` 0–255.
- **Filters without a toggle in Figma switch on by value:**
  - Essential's `adjust`, `sharpen`, `gradfun` and `grain`, Colors' `sepia`, and Audio's pitch (`scaletempo_pitch`).
  - A filter is on while any of its values differs from its default, and goes off when all are back at default.
- **Persistence:**
  - Filter on/off and filter values are live, and also written to the config at once; there is no Apply button in Figma.
  - Per-media vars are live only: delays, subtitle speed, vout crop borders, and zoom/aspect/crop choices.
  - Defaults-section prefs (`audio-track`, `audio-language`, `sub-track`, `sub-language`, `preferred-resolution`) are config only; they take effect on the next media.

## Global Constraints

- **Card:**
  - The gear panel becomes `fillHeight: true`: full height, so switching tabs never resizes it.
  - 400 px wide, radius 10, `#0E0E0E` at 95 %.
  - 20 px from the player's right edge, 20 px above the control bar, 20 px below the top bar.
- **Tab bar** (4 tabs, Figma `498:2966`):
  - 50 px tall, `#090909`, 6 px side padding, 1 px gap.
  - Tab widths: Playback 107.5, Video 85, Audio 85, Subtitles 107.5.
  - Icons 20 px, an 8 px gap, 12 px labels. Selected `#8F8F8F` with a 2 px `#D37918` underline; others `#6B6B6B`.
- **Section:**
  - A 1 px `#222222` divider above every section except the first.
  - Title 16 px Inter Medium `#969696`, padding top 20, left 24.
- **Row:**
  - Padding 20 px left/right, with a 4 px inner left inset on the label.
  - Label 14 px `#6B6B6B`.
  - Combo rows are 68 px tall, with 20 px bottom padding below a 48 px control; field rows are 48 px tall.
- **Text field** (`text_input`): 140×36, `#090909` fill, 2 px `#191919` border, radius 6, text 14 px `#8F8F8F`, padding left 12, right 18.
- **Combo** (`EQ`):
  - 220×48 in label rows, 360×48 when full width.
  - Radius 6, `#090909` frame, 2 px inset `#191919` face radius 4.
  - Text 14 px `#8F8F8F` at x 18; 24 px chevron 14 px from the right.
- **Segmented** (`Values`):
  - 44 px tall, `#090909`, padding 2, gap 2, radius 6.
  - Selected segment `#371F06` with `#D37918` text; others `#191919` with `#6B6B6B` text; segment radius 4.
- **Toggle:**
  - 68×32, `#090909`, radius 6.
  - Off: knob 26×26 `#404040` at x 3, track 33×26 `#191919` at x 32, "OFF" 12 px `#6B6B6B`.
  - On: knob `#AB6314` at x 39, track `#371F06` at x 3, "ON" `#D37918` at x 10.
  - Knob and track radius 3.
- **Slider** (`range`):
  - Track 16 px tall, `#090909`, radius 6.
  - Fill 12 px tall, `#371F06`, radius 4, inset 2.
  - Handle 8×24, `#AB6314`, radius 4.
  - Ticks 1×6 `#2A2A2A`, centred.
  - Header row: label left, value right, both 14 px `#6B6B6B`, 10 px vertical padding, 5 px gap to the track.
- **Accordion:**
  - Collapsed: 360×48 `#090909` button, radius 6, "Expand Settings" 14 px `#6B6B6B`, padding left 16, right 10, with a right chevron.
  - Expanded: a `#1B1B1B` box, radius 6, bottom padding 10; header "Collapse Settings" with a down chevron, padding 12/16/10. Each slider block has side padding 16 and bottom padding 10.
- **Footer** (`812:1580`):
  - A 1 px `#222222` top border, padding 20, gap 10.
  - Preset button: 360×42 `#090909`, radius 6, padding 2; inner 38 px row with padding 14, text 14 px `#8F8F8F`, and an up chevron.
  - Then a 32 px flat button: a 20 px settings icon, a 6 px gap, "Open Advanced Settings" 14 px `#6B6B6B`.
- **Palette:** use the dark hex values only when `palette.isDark`; otherwise use ColorContext colours (light theme is slice 10).
- **Sizes and strings:** sizes as `VLCStyle.dp(n, VLCStyle.scale)`, user strings in `qsTr()`. C++ log strings stay untranslated.
- **New QML files:** list each in `modules/gui/qt/meson.build` (module `VLC.Player`, after `'player/qml/PlaybackPanel.qml'`) and `modules/gui/qt/Makefile.am` (after `player/qml/PlaybackPanel.qml \`), in the order the tasks create them.
- **New C++:**
  - meson: the header goes in `moc_headers` (next to `'player/player_controller.hpp'`), and the `.cpp`/`.hpp` go in `qt_plugin_sources` (next to `'player/player_controller.cpp'`).
  - Makefile.am: add to `libqt_plugin_la_SOURCES` (next to `player/player_controller.cpp …`) and add `player/player_effects.moc.cpp` to `nodist_libqt_plugin_la_SOURCES`.
- **Inline components:** every `component X: …` declaration goes on the root object of its file. Some snippets show one nested for readability; move it to the root when writing the file.
- **Icon font:** keys are append-only (charcodes go by index). This slice reuses existing glyphs, so no font change is expected. If a glyph is missing, append it as in slice 3b Task 1.
- **Where to run:**
  - The build tree (`build/`), the profile (`build/redesign-profile`), sample media (`build/redesign-media`) and the X11/Wayland harness only exist on the Linux build machine used for slices 1–3b. Run this plan there.
  - The macOS checkout has no meson, Qt or VLC contribs.
- **Harness:**
  - `H=docs/superpowers/scripts/vlc-xvfb.sh; L=build/redesign-profile/run/vlc.log`.
  - Before each start: `cp /tmp/conf.bak build/redesign-profile/config/vlc/vlc-qt-interface.conf`. If `/tmp/conf.bak` is gone, run `$H seed` once and copy that conf to `/tmp/conf.bak`.
  - Start with `$H start -vv build/redesign-media/plain.mp4 build/redesign-media/tracks2.mkv; sleep 6`. The driver already passes `--aout=dummy`. Any hand-rolled run must add it too.
  - The vlcrc being edited is `build/redesign-profile/config/vlc/vlcrc`.
- **Coordinates at 1600×900** (computed from Figma; if a click misses, read the real position from a shot and note it in the ledger):
  - Gear button (1515, 873). Card x 1180–1580, y 60–826.
  - Tab centres at y 85: Playback x 1240, Video x 1337, Audio x 1423, Subtitles x 1520.
  - Footer "Open Advanced Settings" at (1380, 806); preset button at (1380, 767).
  - Page content starts at y 111. It scrolls with the wheel: `xdotool mousemove 1380 400 click 5` scrolls down one step.
- **Log check:** every visual check ends with `grep -E "TypeError|ReferenceError|non-existent property|unavailable|Unable to assign|is not a type|Could not convert|Unable to find filter" $L`. Expected: no output.
- **Branch:** `redesign/player-settings` from `master`, one commit per task.
- **Commits:** the repo's configured git identity, with no AI attribution or co-author trailer.

## Review Focus

1. **No media, or audio-only media, while the panel is open.** The Video tab's vout-backed controls (crop px, zoom, aspect, crop) are disabled, and a slider drag logs no error. The filter on/off state and values are still written to the config, so they apply to the next video. Pinned in Task 5, Step 6.
2. **A filter switched on by value goes off again at its default.** Drag Essential → Brightness away and back, then double-click the slider to reset it: `adjust` leaves `video-filter` in vlcrc. Pinned in Task 5, Step 5.
3. **The equalizer combo and the band sliders stay consistent.**
   - Picking a preset moves all 11 sliders.
   - Then moving one band switches the combo to "Custom", not the preset name.
   - Picking "None" disables the `equalizer` filter but keeps the band values.
   - Pinned in Task 7, Step 5.
4. **Typing into text fields.**
   - A field accepts out-of-range or garbage input and clamps it on Enter or focus-out: Rotate "45" snaps to 90, delay "abc" reverts, delay "99" clamps to 10.000 s.
   - It never sends NaN to the player.
   - Pinned in Task 6, Step 4 and Task 4, Step 5.
5. **Hotkeys and the tab state.**
   - With the gear panel open on the Audio tab, VLC's audio-delay hotkeys (`j`/`k`) move the delay field and slider live.
   - Reopening the panel lands on the last tab.
   - Pinned in Task 6, Step 5.

---

### Task 0: Branch, roadmap, Figma key

**Files:**
- Modify: `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md`
- Add: `docs/superpowers/figma/3c/*.png` (already copied into the working tree)

- [ ] **Step 1:** `git switch -c redesign/player-settings master`
- [ ] **Step 2:** In the roadmap header line, replace `` "VLC Redesign (Community)" (`dSoAm0gN9ZterHSssJU9FN`) `` with `` "VLC Redesign (Community)" (`d9xvroRclV6SaObbcqRmBr`; node IDs as in the original `dSoAm0gN9ZterHSssJU9FN`) ``.
- [ ] **Step 3:** In the roadmap row `3c Settings tabs + effects`, append to the Notes cell: ` Plan 2026-10-14-vlc-redesign-player-settings; HDR, Geometry/Overlay/Advanced, stereo Test, embedded sub format and size units omitted (no VLC feature / no design).`
- [ ] **Step 4:** `git add docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md docs/superpowers/figma/3c docs/superpowers/plans/2026-10-14-vlc-redesign-player-settings.md`, then commit `doc: plan the player settings tabs slice`.

### Task 1: Pure effect helpers with unit tests

**Files:**
- Create: `modules/gui/qt/player/effects_util.hpp`, `modules/gui/qt/player/effects_util.cpp`, `modules/gui/qt/tests/test_effects_util.cpp`
- Modify: `modules/gui/qt/meson.build` (the `vlc_tests` block next to `test_qt_renderer_manager`, and `qt_plugin_sources`), `modules/gui/qt/Makefile.am` (a test block next to `test_renderer_manager_model`, and `libqt_plugin_la_SOURCES`)

**Interfaces — produces:**
- `QString effects::toggleModule(const QString& list, const QString& module, bool add)`: edits a colon-separated module list. Adding a present module or removing an absent one returns the list unchanged; empty items are dropped.
- `QString effects::formatBands(const QVector<float>& bands)`: one decimal, C locale, space-separated, always `EQZ_BANDS` (10) values (missing ones are 0).
- `QVector<float> effects::parseBands(const QString& s)`: 10 values. Unparsable or missing entries become 0, and each is clamped to −20…20.
- `QString effects::transformType(int flip, int rotation)`: flip 0 none / 1 horizontal / 2 vertical; rotation 0/90/180/270 (anything else is snapped to the nearest multiple of 90, mod 360). Returns `""` for identity.
- `std::pair<int,int> effects::parseTransform(const QString& type)`: the inverse, giving a canonical `{flip, rotation}`.
- `constexpr int effects::EQZ_BANDS = 10;`

- [ ] **Step 1: Write the failing test** `modules/gui/qt/tests/test_effects_util.cpp`:

```cpp
/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#include <QTest>
#include "player/effects_util.hpp"

using namespace effects;

class TestEffectsUtil : public QObject
{
    Q_OBJECT
private slots:
    void toggleAdds()      { QCOMPARE(toggleModule("", "adjust", true), QString("adjust")); }
    void toggleAppends()   { QCOMPARE(toggleModule("invert", "adjust", true), QString("invert:adjust")); }
    void toggleNoDup()     { QCOMPARE(toggleModule("invert:adjust", "adjust", true), QString("invert:adjust")); }
    void toggleRemoves()   { QCOMPARE(toggleModule("invert:adjust:sepia", "adjust", false), QString("invert:sepia")); }
    void toggleAbsent()    { QCOMPARE(toggleModule("invert", "adjust", false), QString("invert")); }
    void toggleDropsEmpty(){ QCOMPARE(toggleModule("::invert::", "sepia", true), QString("invert:sepia")); }

    void bandsFormat()
    {
        QCOMPARE(formatBands({1.25f, -3.f}), QString("1.2 -3.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0"));
    }
    void bandsParse()
    {
        const auto b = parseBands("1.5 x 30 -25");
        QCOMPARE(b.size(), EQZ_BANDS);
        QCOMPARE(b[0], 1.5f);
        QCOMPARE(b[1], 0.f);   // garbage
        QCOMPARE(b[2], 20.f);  // clamped
        QCOMPARE(b[3], -20.f); // clamped
        QCOMPARE(b[9], 0.f);   // missing
    }

    void transformTable_data()
    {
        QTest::addColumn<int>("flip");
        QTest::addColumn<int>("rot");
        QTest::addColumn<QString>("type");
        QTest::newRow("id")    << 0 << 0   << "";
        QTest::newRow("r90")   << 0 << 90  << "90";
        QTest::newRow("r180")  << 0 << 180 << "180";
        QTest::newRow("r270")  << 0 << 270 << "270";
        QTest::newRow("h")     << 1 << 0   << "hflip";
        QTest::newRow("h90")   << 1 << 90  << "antitranspose";
        QTest::newRow("h180")  << 1 << 180 << "vflip";
        QTest::newRow("h270")  << 1 << 270 << "transpose";
        QTest::newRow("v")     << 2 << 0   << "vflip";
        QTest::newRow("v90")   << 2 << 90  << "transpose";
        QTest::newRow("v180")  << 2 << 180 << "hflip";
        QTest::newRow("v270")  << 2 << 270 << "antitranspose";
        QTest::newRow("snap45")<< 0 << 45  << "90";
        QTest::newRow("snap-90")<< 0 << -90 << "270";
    }
    void transformTable()
    {
        QFETCH(int, flip); QFETCH(int, rot); QFETCH(QString, type);
        QCOMPARE(transformType(flip, rot), type);
    }

    void transformRoundTrip()
    {
        for (int flip = 0; flip < 3; ++flip)
            for (int rot = 0; rot < 360; rot += 90)
            {
                const QString t = transformType(flip, rot);
                const auto [f, r] = parseTransform(t);
                QCOMPARE(transformType(f, r), t);
            }
        QCOMPARE(parseTransform("bogus"), std::make_pair(0, 0));
    }
};

QTEST_GUILESS_MAIN(TestEffectsUtil)
#include "test_effects_util.moc"
```

- [ ] **Step 2: Register the test.**
  - In `meson.build`, add a dict next to `test_qt_renderer_manager`:
```meson
        {
            'name': 'test_qt_effects_util',
            'sources': files(
                'tests/test_effects_util.cpp',
                'player/effects_util.hpp',
                'player/effects_util.cpp'
            ),
            'moc_sources': files('tests/test_effects_util.cpp'),
            'suite': ['qt'],
            'include_directories' : qt_include_dir,
            'link_args': qt_link_args,
            'dependencies': [qt6_dep, qtest_qt6_dep]
        },
```
  - In `Makefile.am`, add next to the renderer test:
```make
# test_effects_util

test_effects_util_SOURCES = \
	tests/test_effects_util.cpp \
	player/effects_util.hpp player/effects_util.cpp
nodist_test_effects_util_SOURCES = tests/test_effects_util.moc
BUILT_SOURCES += tests/test_effects_util.moc
CLEANFILES += tests/test_effects_util.moc
test_effects_util_CPPFLAGS = $(QT_QTEST_COMMON_cppflags)
test_effects_util_CXXFLAGS = $(QT_QTEST_COMMON_cxxflags)
test_effects_util_LDADD = $(QT_QTEST_COMMON_ldadd)
test_effects_util_LDFLAGS = $(QT_QTEST_COMMON_ldflags)
check_PROGRAMS += test_effects_util
TESTS += test_effects_util
```
  - Also add `'player/effects_util.cpp', 'player/effects_util.hpp',` to `qt_plugin_sources` and `player/effects_util.cpp player/effects_util.hpp \` to `libqt_plugin_la_SOURCES`.
  - Create an `effects_util.hpp` that only declares the five functions and the constant, plus an empty `effects_util.cpp`.
- [ ] **Step 3: Run it to verify it fails.**
  - Run: `meson setup --reconfigure build >/dev/null && ninja -C build && meson test -C build test_qt_effects_util`.
  - Expected: a link FAIL with "undefined reference to `effects::toggleModule`".
- [ ] **Step 4: Implement** `effects_util.hpp`:

```cpp
#ifndef VLC_QT_EFFECTS_UTIL_HPP
#define VLC_QT_EFFECTS_UTIL_HPP

#include <QString>
#include <QVector>
#include <utility>

// string helpers behind the player's effects panel; no libvlc dependency so they can be unit tested
namespace effects {

constexpr int EQZ_BANDS = 10;

QString toggleModule(const QString& list, const QString& module, bool add);
QString formatBands(const QVector<float>& bands);
QVector<float> parseBands(const QString& s);
// flip: 0 none, 1 horizontal, 2 vertical; rotation in degrees clockwise, applied after the flip
QString transformType(int flip, int rotation);
std::pair<int, int> parseTransform(const QString& type);

}

#endif
```

and `effects_util.cpp` (licence header as in Step 1):

```cpp
#include "effects_util.hpp"

#include <QStringList>
#include <algorithm>
#include <array>

namespace effects {

QString toggleModule(const QString& list, const QString& module, bool add)
{
    QStringList items = list.split(':', Qt::SkipEmptyParts);
    if (add && !items.contains(module))
        items << module;
    else if (!add)
        items.removeAll(module);
    return items.join(':');
}

QString formatBands(const QVector<float>& bands)
{
    QStringList out;
    for (int i = 0; i < EQZ_BANDS; ++i)
        out << QString::number(i < bands.size() ? bands[i] : 0.f, 'f', 1);
    return out.join(' ');
}

QVector<float> parseBands(const QString& s)
{
    QVector<float> out(EQZ_BANDS, 0.f);
    const QStringList items = s.split(' ', Qt::SkipEmptyParts);
    for (int i = 0; i < EQZ_BANDS && i < items.size(); ++i)
    {
        bool ok = false;
        const float v = items[i].toFloat(&ok);   // QString::toFloat is locale independent
        out[i] = ok ? std::clamp(v, -20.f, 20.f) : 0.f;
    }
    return out;
}

// index = flip * 4 + rotation / 90; flip first, then rotate clockwise
static const std::array<const char*, 12> kTransforms = {
    "", "90", "180", "270",
    "hflip", "antitranspose", "vflip", "transpose",
    "vflip", "transpose", "hflip", "antitranspose",
};

QString transformType(int flip, int rotation)
{
    flip = std::clamp(flip, 0, 2);
    const int steps = ((qRound(rotation / 90.0) % 4) + 4) % 4;
    return QString::fromLatin1(kTransforms[flip * 4 + steps]);
}

std::pair<int, int> parseTransform(const QString& type)
{
    // first match wins: none before horizontal before vertical, so the result is canonical
    for (int i = 0; i < int(kTransforms.size()); ++i)
        if (type == QLatin1String(kTransforms[i]))
            return { i / 4, (i % 4) * 90 };
    return { 0, 0 };
}

}
```

- [ ] **Step 5: Run the tests.**
  - Run: `ninja -C build && meson test -C build test_qt_effects_util`.
  - Expected: PASS.
  - Also `meson test -C build --suite qt`: the previous 9 plus this one pass (10/10).
- [ ] **Step 6:** Commit `qt: add tested string helpers for the player effects panel`.

### Task 2: `PlayerEffects` bridge (`Effects` singleton)

**Files:**
- Create: `modules/gui/qt/player/player_effects.hpp`, `modules/gui/qt/player/player_effects.cpp`
- Modify: `modules/gui/qt/maininterface/mainui.cpp` (VLC.Player block, around line 316), `meson.build`, `Makefile.am` (see Global Constraints → New C++)

**Interfaces:**
- Consumes: Task 1's `effects::*`; `PlayerController::getPlayer()`, `getVouts()`, `getAout()`, `voutListChanged`, `inputChanged`.
- Produces: the QML singleton `Effects` (import `VLC.Player`) with:
  - `Q_PROPERTY(bool hasVideo READ hasVideo NOTIFY outputsChanged FINAL)`, which is true while a vout exists;
  - `Q_PROPERTY(bool hasAudio READ hasAudio NOTIFY outputsChanged FINAL)`, which is true while an aout exists;
  - `Q_PROPERTY(QStringList equalizerPresets READ equalizerPresets CONSTANT FINAL)`, the translated `preset_list_text`, 18 entries;
  - `signal changed()`, emitted after any setter and on `outputsChanged`, so QML bindings can re-read with `void(Effects.revision)`;
  - `Q_PROPERTY(int revision READ revision NOTIFY changed FINAL)`, a counter bumped on every `changed`.
- Q_INVOKABLEs (`name` is a VLC var/config name, `module` a module name):

| Signature | Behaviour |
|---|---|
| `bool filterEnabled(const QString& module) const` | Audio: `module` is in config `audio-filter`. Video: in the first vout's filter-type var if a vout exists, else in config. |
| `void setFilterEnabled(const QString& module, bool on)` | Audio: `vlc_player_aout_EnableFilter` plus config `audio-filter`. Video: the vout var on every vout (not for `video-splitter`) plus config. The type comes from the module capability: `audio filter` → audio; `video filter`/`sub source`/`sub filter` → video var `video-filter`/`sub-source`/`sub-filter`. |
| `QVariant value(const QString& name) const` | Read in order: the aout var, the first vout var, then `config_Get*` by `config_GetType`. |
| `void setValue(const QString& name, const QVariant& v)` | Write to the aout and to every vout that has a var of that name, typed by `config_GetType`, then `config_Put*`. Strings with `#RRGGBB` values for `VLC_VAR_INTEGER` (colour) options are converted to an int. |
| `QVariant configValue(const QString& name) const` / `void setConfigValue(const QString& name, const QVariant& v)` | Config only (Defaults section). |
| `double equalizerBand(int band) const` / `void setEqualizerBand(int band, double db)` | Through `equalizer-bands` (aout var, else config), with `parseBands`/`formatBands`; also sets `equalizer-preset` to `""` ("Custom"). |
| `int equalizerPresetIndex() const` | The index of `equalizer-preset` in `preset_list`, or −1. |
| `void applyEqualizerPreset(int index)` | Sets `equalizer-preamp`, `equalizer-bands` and `equalizer-preset` from `eqz_preset_10b[index]`. |
| `int transformFlip() const` / `int transformRotation() const` / `void setTransform(int flip, int rotation)` | Identity removes `transform`. Otherwise it puts config `transform-type`, then removes and re-adds `transform`, since the filter has no live callback. |
| `int voutCrop(const QString& side) const` / `void setVoutCrop(const QString& side, int px)` | `side` is `top`/`bottom`/`left`/`right`, mapped to the vout var `crop-<side>` on every vout. Live only. |
| `int subtitleTextScale() const` / `void setSubtitleTextScale(int percent)` | `vlc_player_SetSubtitleTextScale`, clamped to 10…500, plus config `sub-text-scale`. |
| `void resetToDefaults(const QStringList& names, const QStringList& modules)` | For each name, put the module default (`config_FindConfig(name)->orig`) back both live and in the config; then switch off each module in `modules`. |

- [ ] **Step 1: Failing check.**
  - Add to `PlaybackPanel.qml`, at the end of its outer `ColumnLayout`: `Component.onCompleted: console.warn("effects-probe", Effects.equalizerPresets.length)`.
  - Build, start the harness and click the gear.
  - Expected: `grep effects-probe $L` shows `ReferenceError: Effects is not defined`.
- [ ] **Step 2: Header** `player_effects.hpp`:

```cpp
#ifndef VLC_QT_PLAYER_EFFECTS_HPP
#define VLC_QT_PLAYER_EFFECTS_HPP

#include <QObject>
#include <QStringList>
#include <QVariant>

#include "qt.hpp"

class PlayerController;

// live audio/video/subtitle effects for the player's settings panel (QML singleton "Effects")
class PlayerEffects : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool hasVideo READ hasVideo NOTIFY outputsChanged FINAL)
    Q_PROPERTY(bool hasAudio READ hasAudio NOTIFY outputsChanged FINAL)
    Q_PROPERTY(QStringList equalizerPresets READ equalizerPresets CONSTANT FINAL)
    Q_PROPERTY(int revision READ revision NOTIFY changed FINAL)

public:
    PlayerEffects(qt_intf_t* intf, PlayerController* player, QObject* parent = nullptr);

    bool hasVideo() const;
    bool hasAudio() const;
    QStringList equalizerPresets() const;
    int revision() const { return m_revision; }

    Q_INVOKABLE bool filterEnabled(const QString& module) const;
    Q_INVOKABLE void setFilterEnabled(const QString& module, bool on);
    Q_INVOKABLE QVariant value(const QString& name) const;
    Q_INVOKABLE void setValue(const QString& name, const QVariant& v);
    Q_INVOKABLE QVariant configValue(const QString& name) const;
    Q_INVOKABLE void setConfigValue(const QString& name, const QVariant& v);

    Q_INVOKABLE double equalizerBand(int band) const;
    Q_INVOKABLE void setEqualizerBand(int band, double db);
    Q_INVOKABLE int equalizerPresetIndex() const;
    Q_INVOKABLE void applyEqualizerPreset(int index);

    Q_INVOKABLE int transformFlip() const;
    Q_INVOKABLE int transformRotation() const;
    Q_INVOKABLE void setTransform(int flip, int rotation);

    Q_INVOKABLE int voutCrop(const QString& side) const;
    Q_INVOKABLE void setVoutCrop(const QString& side, int px);

    Q_INVOKABLE int subtitleTextScale() const;
    Q_INVOKABLE void setSubtitleTextScale(int percent);

    Q_INVOKABLE void resetToDefaults(const QStringList& names, const QStringList& modules);

signals:
    void outputsChanged();
    void changed();

private:
    enum class Kind { None, Audio, Video };
    Kind kindOf(const QString& module, const char** varName = nullptr) const;
    void touch();

    qt_intf_t* m_intf;
    PlayerController* m_player;
    int m_revision = 0;
};

#endif
```

- [ ] **Step 3: Implementation** `player_effects.cpp`: licence header, then:

```cpp
#include "player_effects.hpp"

#include "player/player_controller.hpp"
#include "player/effects_util.hpp"
#include "../../../audio_filter/equalizer_presets.h"

#include <vlc_aout.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_player.h>
#include <vlc_vout.h>

#include <QColor>
#include <algorithm>

PlayerEffects::PlayerEffects(qt_intf_t* intf, PlayerController* player, QObject* parent)
    : QObject(parent), m_intf(intf), m_player(player)
{
    connect(player, &PlayerController::voutListChanged, this, &PlayerEffects::outputsChanged);
    connect(player, &PlayerController::inputChanged, this, &PlayerEffects::outputsChanged);
    connect(this, &PlayerEffects::outputsChanged, this, &PlayerEffects::touch);
}

void PlayerEffects::touch() { ++m_revision; emit changed(); }

bool PlayerEffects::hasVideo() const { return !m_player->getVouts().isEmpty(); }
bool PlayerEffects::hasAudio() const { return m_player->getAout() != nullptr; }

QStringList PlayerEffects::equalizerPresets() const
{
    QStringList out;
    for (int i = 0; i < NB_PRESETS; ++i)
        out << qfut(preset_list_text[i]);
    return out;
}

PlayerEffects::Kind PlayerEffects::kindOf(const QString& module, const char** varName) const
{
    module_t* m = module_find(qtu(module));
    if (!m) { msg_Err(m_intf, "Unable to find filter module \"%s\".", qtu(module)); return Kind::None; }
    const char* var = nullptr;
    Kind kind = Kind::Video;
    if (module_provides(m, "audio filter")) { var = "audio-filter"; kind = Kind::Audio; }
    else if (module_provides(m, "video filter")) var = "video-filter";
    else if (module_provides(m, "sub source")) var = "sub-source";
    else if (module_provides(m, "sub filter")) var = "sub-filter";
    else return Kind::None;
    if (varName) *varName = var;
    return kind;
}

static QString configString(const char* name)
{
    char* s = config_GetPsz(name);
    QString out = qfu(s ? s : "");
    free(s);
    return out;
}

bool PlayerEffects::filterEnabled(const QString& module) const
{
    const char* var = nullptr;
    const Kind kind = kindOf(module, &var);
    if (kind == Kind::None) return false;
    QString list;
    const auto vouts = m_player->getVouts();
    if (kind == Kind::Video && !vouts.isEmpty())
    {
        char* s = var_GetString(vouts.first().get(), var);
        list = qfu(s ? s : "");
        free(s);
    }
    else
        list = configString(var);
    return list.split(':', Qt::SkipEmptyParts).contains(module);
}

void PlayerEffects::setFilterEnabled(const QString& module, bool on)
{
    const char* var = nullptr;
    const Kind kind = kindOf(module, &var);
    if (kind == Kind::None) return;
    if (kind == Kind::Audio)
        vlc_player_aout_EnableFilter(m_player->getPlayer(), qtu(module), on);
    else
        for (const auto& vout : m_player->getVouts())
        {
            char* s = var_GetString(vout.get(), var);
            const QString list = effects::toggleModule(qfu(s ? s : ""), module, on);
            free(s);
            var_SetString(vout.get(), var, qtu(list));
        }
    config_PutPsz(var, qtu(effects::toggleModule(configString(var), module, on)));
    touch();
}

static QVariant readVar(vlc_object_t* obj, const char* name, int type)
{
    switch (type)
    {
    case VLC_VAR_FLOAT:   return var_GetFloat(obj, name);
    case VLC_VAR_INTEGER: return QVariant::fromValue<qlonglong>(var_GetInteger(obj, name));
    case VLC_VAR_BOOL:    return bool(var_GetBool(obj, name));
    case VLC_VAR_STRING: { char* s = var_GetString(obj, name); QString v = qfu(s ? s : ""); free(s); return v; }
    }
    return {};
}

QVariant PlayerEffects::configValue(const QString& name) const
{
    switch (config_GetType(qtu(name)))
    {
    case VLC_VAR_FLOAT:   return config_GetFloat(qtu(name));
    case VLC_VAR_INTEGER: return QVariant::fromValue<qlonglong>(config_GetInt(qtu(name)));
    case VLC_VAR_BOOL:    return config_GetInt(qtu(name)) != 0;
    case VLC_VAR_STRING:  return configString(qtu(name));
    }
    return {};
}

QVariant PlayerEffects::value(const QString& name) const
{
    const int type = config_GetType(qtu(name));
    if (auto aout = m_player->getAout(); aout && var_Type(aout.get(), qtu(name)))
        return readVar(VLC_OBJECT(aout.get()), qtu(name), type);
    const auto vouts = m_player->getVouts();
    if (!vouts.isEmpty() && var_Type(vouts.first().get(), qtu(name)))
        return readVar(VLC_OBJECT(vouts.first().get()), qtu(name), type);
    return configValue(name);
}

static vlc_value_t toVlcValue(const QVariant& v, int type, QByteArray& keep)
{
    vlc_value_t val{};
    switch (type)
    {
    case VLC_VAR_FLOAT:   val.f_float = v.toFloat(); break;
    case VLC_VAR_BOOL:    val.b_bool = v.toBool(); break;
    case VLC_VAR_STRING:  keep = v.toString().toUtf8(); val.psz_string = keep.data(); break;
    case VLC_VAR_INTEGER:
        // colour options take "#RRGGBB" from the text fields
        if (v.typeId() == QMetaType::QString && v.toString().startsWith('#'))
            val.i_int = QColor(v.toString()).rgb() & 0xFFFFFF;
        else
            val.i_int = v.toLongLong();
        break;
    }
    return val;
}

void PlayerEffects::setConfigValue(const QString& name, const QVariant& v)
{
    const int type = config_GetType(qtu(name));
    QByteArray keep;
    const vlc_value_t val = toVlcValue(v, type, keep);
    switch (type)
    {
    case VLC_VAR_FLOAT:   config_PutFloat(qtu(name), val.f_float); break;
    case VLC_VAR_BOOL:    config_PutInt(qtu(name), val.b_bool); break;
    case VLC_VAR_INTEGER: config_PutInt(qtu(name), val.i_int); break;
    case VLC_VAR_STRING:  config_PutPsz(qtu(name), val.psz_string); break;
    default: msg_Warn(m_intf, "no config option \"%s\"", qtu(name)); return;
    }
    touch();
}

void PlayerEffects::setValue(const QString& name, const QVariant& v)
{
    const int type = config_GetType(qtu(name));
    QByteArray keep;
    const vlc_value_t val = toVlcValue(v, type, keep);
    if (auto aout = m_player->getAout(); aout && var_Type(aout.get(), qtu(name)))
        var_SetChecked(aout.get(), qtu(name), type, val);
    for (const auto& vout : m_player->getVouts())
        if (var_Type(vout.get(), qtu(name)))
            var_SetChecked(vout.get(), qtu(name), type, val);
    setConfigValue(name, v);
}

double PlayerEffects::equalizerBand(int band) const
{
    const auto bands = effects::parseBands(value("equalizer-bands").toString());
    return band >= 0 && band < effects::EQZ_BANDS ? bands[band] : 0.;
}

void PlayerEffects::setEqualizerBand(int band, double db)
{
    if (band < 0 || band >= effects::EQZ_BANDS) return;
    auto bands = effects::parseBands(value("equalizer-bands").toString());
    bands[band] = std::clamp(float(db), -20.f, 20.f);
    setValue("equalizer-bands", effects::formatBands(bands));
    setValue("equalizer-preset", QString());
}

int PlayerEffects::equalizerPresetIndex() const
{
    const QString p = value("equalizer-preset").toString();
    for (int i = 0; i < NB_PRESETS; ++i)
        if (p == QLatin1String(preset_list[i])) return i;
    return -1;
}

void PlayerEffects::applyEqualizerPreset(int index)
{
    if (index < 0 || index >= NB_PRESETS) return;
    const eqz_preset_t& p = eqz_preset_10b[index];
    setValue("equalizer-preamp", p.f_preamp);
    setValue("equalizer-bands", effects::formatBands(QVector<float>(p.f_amp, p.f_amp + effects::EQZ_BANDS)));
    setValue("equalizer-preset", QString::fromLatin1(preset_list[index]));
}

int PlayerEffects::transformFlip() const
{
    return filterEnabled("transform") ? effects::parseTransform(configString("transform-type")).first : 0;
}

int PlayerEffects::transformRotation() const
{
    return filterEnabled("transform") ? effects::parseTransform(configString("transform-type")).second : 0;
}

void PlayerEffects::setTransform(int flip, int rotation)
{
    const QString type = effects::transformType(flip, rotation);
    setFilterEnabled("transform", false);
    if (type.isEmpty()) return;
    config_PutPsz("transform-type", qtu(type));
    setFilterEnabled("transform", true);
}

int PlayerEffects::voutCrop(const QString& side) const
{
    const auto vouts = m_player->getVouts();
    return vouts.isEmpty() ? 0 : int(var_GetInteger(vouts.first().get(), qtu("crop-" + side)));
}

void PlayerEffects::setVoutCrop(const QString& side, int px)
{
    for (const auto& vout : m_player->getVouts())
        var_SetInteger(vout.get(), qtu("crop-" + side), std::max(0, px));
    touch();
}

int PlayerEffects::subtitleTextScale() const
{
    vlc_player_t* p = m_player->getPlayer();
    vlc_player_Lock(p);
    const unsigned s = vlc_player_GetSubtitleTextScale(p);
    vlc_player_Unlock(p);
    return int(s);
}

void PlayerEffects::setSubtitleTextScale(int percent)
{
    const unsigned s = unsigned(std::clamp(percent, 10, 500));
    vlc_player_t* p = m_player->getPlayer();
    vlc_player_Lock(p);
    vlc_player_SetSubtitleTextScale(p, s);
    vlc_player_Unlock(p);
    config_PutInt("sub-text-scale", s);
    touch();
}

void PlayerEffects::resetToDefaults(const QStringList& names, const QStringList& modules)
{
    for (const QString& name : names)
    {
        module_config_t* c = config_FindConfig(qtu(name));
        if (!c) continue;
        if (IsConfigFloatType(c->i_type))        setValue(name, c->orig.f);
        else if (IsConfigIntegerType(c->i_type)) setValue(name, QVariant::fromValue<qlonglong>(c->orig.i));
        else if (IsConfigStringType(c->i_type))  setValue(name, qfu(c->orig.psz ? c->orig.psz : ""));
    }
    for (const QString& m : modules)
        setFilterEnabled(m, false);
}
```

- [ ] **Step 4: Register it.**
  - In `mainui.cpp`, add `#include "player/player_effects.hpp"` after `#include "player/delay_estimator.hpp"`.
  - In the VLC.Player block, right after the `Player` singleton line, add:
```cpp
        qmlRegisterSingletonInstance<PlayerEffects>(uri, versionMajor, versionMinor, "Effects",
                                                    new PlayerEffects(m_intf, m_intf->p_mainPlayerController, this));
```
  - Add both files to the meson and Makefile.am lists (Global Constraints → New C++).
- [ ] **Step 5: The check passes.**
  - Rebuild, restart and click the gear.
  - Expected: `grep effects-probe $L` shows `effects-probe 18`. The log check is empty.
  - Remove the probe line.
- [ ] **Step 6: Smoke-test the bridge from QML.**
  - Temporarily add `Component.onCompleted: { Effects.setFilterEnabled("invert", true) }` to the same place, restart, open the gear, and take `$H shot /tmp/inv.png`.
  - Take the same shot without the probe first (`/tmp/plain.png`). Then `count-px.sh` on box `200 200 400 300` against `FFFFFF` with fuzz 30 must differ by more than 20 % between `/tmp/plain.png` and `/tmp/inv.png`, because the inverted video swaps light and dark.
  - Then `grep '^video-filter' build/redesign-profile/config/vlc/vlcrc` shows `video-filter=invert`.
  - Revert the probe. Reset vlcrc with `sed -i '/^video-filter=/d' build/redesign-profile/config/vlc/vlcrc`.
- [ ] **Step 7:** Commit `qt: expose the player's audio and video effects to QML`.

### Task 3: Settings controls, the four tabs and the footer

**Files:**
- Create in `modules/gui/qt/player/qml/settings/`: `SettingsStyle.qml`, `SettingSection.qml`, `SettingRow.qml`, `SettingToggle.qml`, `SettingSlider.qml`, `SettingCombo.qml`, `SettingField.qml`, `SettingSegments.qml`, `EffectAccordion.qml`, `SettingsPage.qml`
- Create: `player/qml/VideoSettingsPage.qml`, `AudioSettingsPage.qml`, `SubtitleSettingsPage.qml`. These are empty pages for now: a `SettingsPage {}` with one `SettingSection { title: qsTr("Defaults"); divider: false }`.
- Modify: `player/qml/PlayerPanel.qml` (footer), `player/qml/PlaybackPanel.qml`, `player/qml/controlbarcontrols/ExtendedSettingsButton.qml`, `meson.build`, `Makefile.am` (register all 13 QML files; the `settings/` files use the path `player/qml/settings/X.qml`)

**Interfaces — produces** (all in module `VLC.Player`; each control carries its own ColorContext with `colorSet: ColorContext.Window` and `_dark: theme.palette.isDark`):
- `SettingsStyle`: a `QtObject` with the Figma colours as readonly properties: `label` #6B6B6B, `value` #8F8F8F, `title` #969696, `field` #090909, `face` #191919, `accentBg` #371F06, `accent` #D37918, `accentDim` #AB6314, `knobOff` #404040, `divider` #222222, `box` #1B1B1B, `tick` #2A2A2A. Light-mode fallbacks come from `ColorContext`.
- `SettingSection { title: string; divider: bool = true; default property alias content }`: a ColumnLayout that fills the width.
- `SettingRow { label: string }`: a RowLayout, 48 dp tall, label inset 4 (the section body supplies the 20 px side padding). The control goes as a child.
- `SettingToggle { checked: bool; signal toggled(bool on) }`: never flips itself; the owner binds `checked`.
- `SettingSlider { label; valueText; from; to; stepSize; value; ticks: int = 0; defaultValue; signal moved(real v) }`: the header row (label + valueText) plus the track. Double-click resets: `moved(defaultValue)`. `showHeader: bool = true`.
- `SettingCombo { model; textRole; currentIndex; fullWidth: bool = false; signal activated(int index) }`.
- `SettingField { text; suffix; validator; signal committed(string text) }`: emits on Enter or focus-out and reverts to `text` on Escape.
- `SettingSegments { model: [string]; currentIndex; signal activated(int index) }`.
- `EffectAccordion { expanded: bool = false; default property alias content }`.
- `SettingsPage`: a Flickable page. `default property alias content` is a ColumnLayout; it scrolls the active focus item into view and has a 16 dp bottom spacer.
- `PlayerPanel` gains `footerIcon: string` (glyph, empty = none), `footerFlat: bool` (transparent, `#6B6B6B` text, a 1 px `#222222` divider above the footer area, padding 20) and `footerHeader: alias` (items placed above the footer button).
- `ExtendedSettingsButton` gains `property int _lastTab`, so the panel reopens on the last tab.

- [ ] **Step 1: Failing check.**
  - Start the harness, click the gear (1515, 873) and take `$H shot /tmp/t3-before.png`.
  - Run `docs/superpowers/scripts/count-px.sh /tmp/t3-before.png 1300 70 260 30 6B6B6B 6`.
  - Expected: under 30 (there is a single "Playback" tab, so no grey tab labels to its right).
- [ ] **Step 2: `settings/SettingsStyle.qml`:**

```qml
import QtQuick
import VLC.Style

// Figma dark tokens for the settings tabs (Dark/FG/A1…A4, Dark/BG/*); light mode falls back to the theme
QtObject {
    id: style
    required property ColorContext theme
    readonly property bool dark: theme.palette.isDark

    readonly property color label:     dark ? "#6B6B6B" : theme.fg.secondary
    readonly property color value:     dark ? "#8F8F8F" : theme.fg.primary
    readonly property color title:     dark ? "#969696" : theme.fg.primary
    readonly property color field:     dark ? "#090909" : theme.bg.secondary
    readonly property color face:      dark ? "#191919" : theme.bg.primary
    readonly property color accentBg:  dark ? "#371F06" : Qt.alpha(theme.accent, 0.25)
    readonly property color accent:    dark ? "#D37918" : theme.accent
    readonly property color accentDim: dark ? "#AB6314" : theme.accent
    readonly property color knobOff:   dark ? "#404040" : theme.fg.secondary
    readonly property color divider:   dark ? "#222222" : theme.separator
    readonly property color box:       dark ? "#1B1B1B" : theme.bg.secondary
    readonly property color tick:      dark ? "#2A2A2A" : theme.separator
}
```

  Each control declares:
```qml
    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Window }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }
```

- [ ] **Step 3: `settings/SettingToggle.qml`** (Figma Toggle `536:1013`/`536:1336`):

```qml
import QtQuick
import QtQuick.Templates as T
import VLC.Style
import VLC.Widgets as Widgets

T.Switch {
    id: root
    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Switch; focused: root.visualFocus }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }
    signal toggled(bool on)

    implicitWidth: VLCStyle.dp(68, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
    // the owner binds `checked` to the real state; a click only asks for the change
    checkable: false
    onClicked: toggled(!checked)

    indicator: Rectangle {
        anchors.fill: parent
        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: root._s.field
        border.width: root.visualFocus ? VLCStyle.focus_border : 0
        border.color: theme.visualFocus

        Rectangle {   // track
            x: VLCStyle.dp(root.checked ? 3 : 32, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(33, VLCStyle.scale); height: VLCStyle.dp(26, VLCStyle.scale)
            radius: VLCStyle.dp(3, VLCStyle.scale)
            color: root.checked ? root._s.accentBg : root._s.face
        }
        Rectangle {   // knob
            x: VLCStyle.dp(root.checked ? 39 : 3, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(26, VLCStyle.scale); height: width
            radius: VLCStyle.dp(3, VLCStyle.scale)
            color: root.checked ? root._s.accentDim : root._s.knobOff
        }
        Widgets.LabelExt {
            x: root.checked ? VLCStyle.dp(10, VLCStyle.scale) : parent.width / 2 + VLCStyle.dp(2, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            text: root.checked ? qsTr("ON") : qsTr("OFF")
            font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
            color: root.checked ? root._s.accent : root._s.label
        }
    }
}
```

- [ ] **Step 4: `settings/SettingSlider.qml`** (Figma `range`, `536:1545`):

```qml
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import VLC.Style
import VLC.Widgets as Widgets

ColumnLayout {
    id: root
    property alias label: lbl.text
    property alias valueText: val.text
    property bool showHeader: true
    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real value: 0
    property real defaultValue: from
    property int ticks: 0          // number of tick marks including both ends; 0 = none
    signal moved(real v)

    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Slider; focused: slider.visualFocus }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    spacing: VLCStyle.dp(5, VLCStyle.scale)
    Layout.fillWidth: true

    RowLayout {
        visible: root.showHeader
        Layout.fillWidth: true
        Layout.topMargin: VLCStyle.dp(10, VLCStyle.scale)
        Layout.bottomMargin: VLCStyle.dp(5, VLCStyle.scale)
        Widgets.LabelExt { id: lbl; Layout.fillWidth: true; font.pixelSize: VLCStyle.dp(14, VLCStyle.scale); color: root._s.label }
        Widgets.LabelExt { id: val; font.pixelSize: VLCStyle.dp(14, VLCStyle.scale); color: root._s.label }
    }

    T.Slider {
        id: slider
        Layout.fillWidth: true
        implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
        from: root.from; to: root.to; stepSize: root.stepSize
        snapMode: root.stepSize > 0 ? T.Slider.SnapAlways : T.Slider.NoSnap
        value: root.value
        onMoved: root.moved(value)
        Accessible.name: root.label

        TapHandler { acceptedButtons: Qt.LeftButton; onDoubleTapped: root.moved(root.defaultValue) }

        background: Rectangle {
            y: (slider.height - height) / 2
            width: slider.width; height: VLCStyle.dp(16, VLCStyle.scale)
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root._s.field
            border.width: slider.visualFocus ? VLCStyle.focus_border : 0
            border.color: theme.visualFocus

            Rectangle {   // fill up to the handle
                x: VLCStyle.dp(2, VLCStyle.scale); y: x
                width: Math.max(0, slider.handle.x + slider.handle.width - x)
                height: parent.height - 2 * y
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: root._s.accentBg
            }
            Repeater {
                model: root.ticks
                Rectangle {
                    required property int index
                    x: VLCStyle.dp(2, VLCStyle.scale) + index / (root.ticks - 1) * (parent.width - VLCStyle.dp(4, VLCStyle.scale))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1; height: VLCStyle.dp(6, VLCStyle.scale)
                    color: root._s.tick
                }
            }
        }
        handle: Rectangle {
            x: slider.visualPosition * (slider.availableWidth - width)
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: VLCStyle.dp(8, VLCStyle.scale); implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: root._s.accentDim
        }
    }
}
```

- [ ] **Step 5: `settings/SettingCombo.qml`, `SettingField.qml`, `SettingSegments.qml`.**

`SettingCombo.qml` (Figma `EQ` `6114:13510`):
```qml
import QtQuick
import QtQuick.Layouts
import VLC.Style
import VLC.Widgets as Widgets

Widgets.ComboBoxExt {
    id: root
    property bool fullWidth: false
    readonly property SettingsStyle _s: SettingsStyle { theme: root.colorContext }

    Layout.preferredWidth: fullWidth ? -1 : VLCStyle.dp(220, VLCStyle.scale)
    Layout.fillWidth: fullWidth
    Layout.preferredHeight: VLCStyle.dp(48, VLCStyle.scale)
    color: _s.value

    background: Rectangle {
        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: root._s.field
        border.width: root.visualFocus ? VLCStyle.focus_border : 0
        border.color: root.colorContext.visualFocus
        Rectangle {
            anchors.fill: parent; anchors.margins: VLCStyle.dp(2, VLCStyle.scale)
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: root._s.face
        }
    }
    contentItem: Widgets.LabelExt {
        leftPadding: VLCStyle.dp(18, VLCStyle.scale)
        rightPadding: root.indicator.width + VLCStyle.dp(14, VLCStyle.scale)
        text: root.displayText
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        color: root._s.value
    }
}
```
  `ComboBoxExt` already declares `colorContext`. If it does not, add the same `ColorContext` block as the other controls and point `_s` at it.

`SettingField.qml` (Figma `text_input`):
```qml
import QtQuick
import QtQuick.Templates as T
import VLC.Style

T.TextField {
    id: root
    property string suffix: ""
    property string committedText: ""     // owner binds the real value here
    signal committed(string text)

    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.TextField; focused: root.activeFocus }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    implicitWidth: VLCStyle.dp(140, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(36, VLCStyle.scale)
    leftPadding: VLCStyle.dp(12, VLCStyle.scale)
    rightPadding: VLCStyle.dp(18, VLCStyle.scale)
    verticalAlignment: TextInput.AlignVCenter
    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
    color: _s.value
    selectByMouse: true
    // shows the live value until edited; editing breaks the binding, commit or Escape restores it
    text: committedText + suffix

    onActiveFocusChanged: if (activeFocus) { text = committedText; selectAll() } else _commit()
    onAccepted: focus = false            // focus-out commits
    Keys.onEscapePressed: (ev) => { _restore(); focus = false; ev.accepted = true }

    function _restore() { text = Qt.binding(() => committedText + suffix) }
    function _commit() {
        const t = (suffix.length ? text.replace(suffix, "") : text).trim()
        _restore()
        if (t !== committedText) committed(t)
    }

    background: Rectangle {
        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: root._s.field
        border.width: VLCStyle.dp(2, VLCStyle.scale)
        border.color: root.activeFocus ? theme.visualFocus : root._s.face
    }
}
```

`SettingSegments.qml` (Figma `Values` `6114:13499`):
```qml
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import VLC.Style
import VLC.Widgets as Widgets

Rectangle {
    id: root
    property var model: []
    property int currentIndex: 0
    signal activated(int index)

    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Window }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    Layout.fillWidth: true
    implicitHeight: VLCStyle.dp(44, VLCStyle.scale)
    radius: VLCStyle.dp(6, VLCStyle.scale)
    color: _s.field

    RowLayout {
        anchors.fill: parent; anchors.margins: VLCStyle.dp(2, VLCStyle.scale)
        spacing: VLCStyle.dp(2, VLCStyle.scale)
        Repeater {
            model: root.model
            T.Button {
                id: seg
                required property int index
                required property string modelData
                Layout.fillWidth: true; Layout.fillHeight: true
                text: modelData
                onClicked: root.activated(index)
                Accessible.name: modelData
                background: Rectangle {
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: seg.index === root.currentIndex ? root._s.accentBg : root._s.face
                    border.width: seg.visualFocus ? VLCStyle.focus_border : 0
                    border.color: theme.visualFocus
                }
                contentItem: Widgets.LabelExt {
                    text: seg.text
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: seg.index === root.currentIndex ? root._s.accent : root._s.label
                }
            }
        }
    }
}
```

- [ ] **Step 6: `SettingSection.qml`, `SettingRow.qml`, `EffectAccordion.qml`, `SettingsPage.qml`.**

`SettingSection.qml`:
```qml
import QtQuick
import QtQuick.Layouts
import VLC.Style
import VLC.Widgets as Widgets

ColumnLayout {
    id: root
    property alias title: titleLabel.text
    property bool divider: true
    default property alias content: body.data

    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Window }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    Layout.fillWidth: true
    spacing: 0

    Rectangle { visible: root.divider; Layout.fillWidth: true; implicitHeight: 1; color: root._s.divider }
    Widgets.LabelExt {
        id: titleLabel
        Layout.leftMargin: VLCStyle.dp(24, VLCStyle.scale)
        Layout.topMargin: VLCStyle.dp(20, VLCStyle.scale)
        font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
        font.weight: Font.Medium
        color: root._s.title
    }
    ColumnLayout {
        id: body
        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.topMargin: VLCStyle.dp(10, VLCStyle.scale)
        Layout.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
        spacing: VLCStyle.dp(10, VLCStyle.scale)
    }
}
```

`SettingRow.qml`:
```qml
import QtQuick
import QtQuick.Layouts
import VLC.Style
import VLC.Widgets as Widgets

RowLayout {
    id: root
    property alias label: lbl.text
    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Window }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    Layout.fillWidth: true
    Layout.preferredHeight: VLCStyle.dp(48, VLCStyle.scale)
    spacing: VLCStyle.dp(12, VLCStyle.scale)

    Widgets.LabelExt {
        id: lbl
        Layout.fillWidth: true
        leftPadding: VLCStyle.dp(4, VLCStyle.scale)
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        color: root._s.label
        elide: Text.ElideRight
    }
}
```
  Combo rows get the 48 px control; the section's 10 px spacing plus the control's height give the Figma 68 px pitch within ±2 px.

`EffectAccordion.qml` (Figma `536:1512`/`536:1514`):
```qml
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import VLC.Style
import VLC.Widgets as Widgets

Rectangle {
    id: root
    property bool expanded: false
    default property alias content: body.data

    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Window }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight
    radius: VLCStyle.dp(6, VLCStyle.scale)
    color: expanded ? _s.box : _s.field

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        T.Button {
            id: header
            Layout.fillWidth: true
            implicitHeight: VLCStyle.dp(48, VLCStyle.scale)
            onClicked: root.expanded = !root.expanded
            Accessible.name: text
            text: root.expanded ? qsTr("Collapse Settings") : qsTr("Expand Settings")
            background: Rectangle {
                color: "transparent"; radius: root.radius
                border.width: header.visualFocus ? VLCStyle.focus_border : 0
                border.color: theme.visualFocus
            }
            contentItem: RowLayout {
                Widgets.LabelExt {
                    Layout.fillWidth: true
                    leftPadding: VLCStyle.dp(16, VLCStyle.scale)
                    text: header.text
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: root._s.label
                }
                Widgets.IconLabel {
                    Layout.rightMargin: VLCStyle.dp(10, VLCStyle.scale)
                    text: root.expanded ? VLCIcons.expand : VLCIcons.expand_inverted
                    rotation: root.expanded ? 0 : -90
                    font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
                    color: root._s.label
                }
            }
        }
        ColumnLayout {
            id: body
            visible: root.expanded
            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.dp(16, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(16, VLCStyle.scale)
            Layout.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
            spacing: VLCStyle.dp(5, VLCStyle.scale)
        }
    }
}
```
  Before writing this, run `grep -n '"expand\|chevron\|dropdown' modules/gui/qt/pixmaps/VLCIcons.json` and use the existing chevron key that the slice 2 ComboBoxExt indicator uses. Figma's chevron is the same `71:869` component. Replace both `VLCIcons.expand*` above with that key, keeping the 0° / −90° rotation (down when expanded, right when collapsed).

`SettingsPage.qml`:
```qml
import QtQuick
import QtQuick.Layouts
import VLC.Style

// a settings tab's page: scrolls by itself because the gear card is full height
Flickable {
    id: root
    default property alias content: col.data
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight + VLCStyle.dp(16, VLCStyle.scale)
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout { id: col; width: root.width; spacing: 0 }

    // keep keyboard focus visible
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            const it = root.Window.activeFocusItem
            if (!it || !root.visible) return
            for (let p = it; p; p = p.parent)
                if (p === col) {
                    const r = it.mapToItem(col, 0, 0, it.width, it.height)
                    if (r.y < root.contentY) root.contentY = r.y
                    else if (r.y + r.height > root.contentY + root.height)
                        root.contentY = Math.min(r.y + r.height - root.height, root.contentHeight - root.height)
                    return
                }
        }
    }
}
```

- [ ] **Step 7: Footer in `PlayerPanel.qml`.**
  - Add the properties `property string footerIcon: ""`, `property bool footerFlat: false` and `property alias footerHeader: footerHeaderHolder.data`.
  - Replace the footer `T.Button { id: footer … }` with:
```qml
        Rectangle {
            visible: root.footerFlat && root.footerText.length > 0
            Layout.fillWidth: true
            implicitHeight: 1
            color: root._dark ? "#222222" : theme.separator
        }

        ColumnLayout {
            id: footerHeaderHolder
            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.topMargin: children.length ? VLCStyle.dp(20, VLCStyle.scale) : 0
            visible: children.length > 0
        }

        T.Button {
            id: footer

            readonly property ColorContext colorContext: ColorContext {
                id: footerTheme
                colorSet: ColorContext.ButtonStandard
                focused: footer.visualFocus
            }

            Layout.fillWidth: true
            Layout.margins: VLCStyle.dp(20, VLCStyle.scale)
            Layout.topMargin: footerHeaderHolder.visible ? VLCStyle.dp(10, VLCStyle.scale) : VLCStyle.dp(20, VLCStyle.scale)
            implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
            visible: root.footerText.length > 0
            text: root.footerText
            onClicked: root.footerClicked()

            background: Rectangle {
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: root.footerFlat ? "transparent" : (root._dark ? "#090909" : theme.bg.secondary)
                border.width: footer.visualFocus ? VLCStyle.focus_border : 0
                border.color: footerTheme.visualFocus
            }

            contentItem: Row {
                spacing: VLCStyle.dp(6, VLCStyle.scale)
                Widgets.IconLabel {
                    visible: root.footerIcon.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.footerIcon
                    font.pixelSize: VLCStyle.dp(20, VLCStyle.scale)
                    color: footerLabel.color
                }
                Widgets.LabelExt {
                    id: footerLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: footer.text
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: root.footerFlat ? (root._dark ? "#6B6B6B" : theme.fg.secondary)
                                           : (root._dark ? "#8F8F8F" : theme.fg.primary)
                }
                // centre the row in the button
                x: (footer.availableWidth - implicitWidth) / 2
            }
        }
```
- [ ] **Step 8: Four tabs in `PlaybackPanel.qml`.**
  - Delete the inline `component SettingRow` and replace the Reverse `T.Switch` with `SettingToggle { checked: Player.rate < 0; onToggled: Player.reverse(); Accessible.name: qsTr("Reverse") }`. Keep the Speed slider and labels as they are: that is the slice 3a design `2238:9432`, not the settings slider.
  - Then set:
```qml
    fillHeight: true
    tabs: [
        { text: qsTr("Playback"),  icon: VLCIcons.effect_filter },
        { text: qsTr("Video"),     icon: VLCIcons.topbar_video },
        { text: qsTr("Audio"),     icon: VLCIcons.topbar_music },
        { text: qsTr("Subtitles"), icon: VLCIcons.audiosub }
    ]
    footerFlat: true
    footerIcon: VLCIcons.preferences
    footerText: qsTr("Open Advanced Settings")
    onFooterClicked: {
        root.close()
        DialogsProvider.prefsDialog()
    }
```
  - Wrap the existing Playback `ColumnLayout` in `SettingsPage { … }`, then add `VideoSettingsPage {}`, `AudioSettingsPage {}` and `SubtitleSettingsPage {}` after it.
  - Before using them, check with `grep -n '"preferences"\|"topbar_video"\|"topbar_music"\|"audiosub"\|"effect_filter"' modules/gui/qt/pixmaps/VLCIcons.json` that the five glyph keys exist. If `preferences` is missing, use the key that the Figma gear icon `44:413` was mapped to in slice 2 (`grep -n settings modules/gui/qt/pixmaps/redesign/mapping.json`).
- [ ] **Step 9: Remember the tab.**
  - In `ExtendedSettingsButton.qml`, add `property int _lastTab: 0` on `extdSettingsBtn`.
  - In the `PlaybackPanel { … }` block add `currentTab: extdSettingsBtn._lastTab` and `onCurrentTabChanged: extdSettingsBtn._lastTab = currentTab`.
- [ ] **Step 10: Register and check.**
  - Add the 13 files to `meson.build` and `Makefile.am`, then `ninja -C build`.
  - Re-run Step 1 and take a shot. Expected:
    - The `count-px` value is above 120 (three more tab labels).
    - The card top is at y 60 ± 2 on every tab: shot each tab and run `count-px.sh shot.png 1180 58 400 4 0E0E0E 6` > 300.
    - The footer shows a gear icon and "Open Advanced Settings"; clicking it opens Preferences.
    - The Playback tab looks as in slice 3a except for the Figma toggle colours. Compare by eye against `/tmp/t3-before.png`.
    - Close and reopen on the Audio tab: it reopens on Audio.
  - The log check is empty.
- [ ] **Step 11:** Commit `qml: give the gear panel the Figma settings tabs and controls`.

### Task 4: Video tab — Defaults

**Files:** Modify `player/qml/VideoSettingsPage.qml`

**Interfaces:** Consumes `Effects.transformFlip/transformRotation/setTransform/configValue/setConfigValue/revision/hasVideo`, `Player.zoom`, `Player.aspectRatio`, `Player.crop`, `Player.rendererManager`; the Task 3 controls.

- [ ] **Step 1: Failing check.**
  - Open the gear, click Video (1337, 85) and take a shot.
  - `count-px.sh shot.png 1196 150 368 50 371F06 6` is under 50: there is no selected "None" segment yet.
- [ ] **Step 2: Write the page:**

```qml
import QtQuick
import QtQuick.Layouts
import VLC.Style
import VLC.Player

// Figma video settings, 498:2965
SettingsPage {
    id: root

    // re-read a VLCVarChoiceModel's checked row when the panel opens or the outputs change
    function checkedRow(model) {
        void(Effects.revision)
        for (let i = 0; i < model.rowCount(); ++i)
            if (model.data(model.index(i, 0), Qt.CheckStateRole))
                return i
        return 0
    }

    SettingSection {
        title: qsTr("Defaults")
        divider: false

        ColumnLayout {
            Layout.fillWidth: true
            spacing: VLCStyle.dp(20, VLCStyle.scale)
            SettingRow { label: qsTr("Flip") }
            SettingSegments {
                model: [qsTr("None"), qsTr("Horizontal"), qsTr("Vertical")]
                currentIndex: { void(Effects.revision); return Effects.transformFlip() }
                onActivated: (i) => Effects.setTransform(i, Effects.transformRotation())
            }
        }

        SettingRow {
            label: qsTr("Rotate")
            SettingField {
                suffix: qsTr(" deg")
                validator: IntValidator { bottom: -360; top: 360 }
                committedText: { void(Effects.revision); return String(Effects.transformRotation()) }
                onCommitted: (t) => Effects.setTransform(Effects.transformFlip(), parseInt(t) || 0)
                Keys.onUpPressed: Effects.setTransform(Effects.transformFlip(), Effects.transformRotation() + 90)
                Keys.onDownPressed: Effects.setTransform(Effects.transformFlip(), Effects.transformRotation() - 90)
            }
        }

        SettingRow {
            label: qsTr("Zoom")
            SettingCombo {
                enabled: Effects.hasVideo
                model: Player.zoom; textRole: "display"
                currentIndex: root.checkedRow(Player.zoom)
                onActivated: (i) => model.setData(model.index(i, 0), true, Qt.CheckStateRole)
            }
        }

        SettingRow {
            label: qsTr("Resolution")
            SettingCombo {
                readonly property var values: [-1, 1080, 720, 576, 360, 240]
                model: [qsTr("Best Available"), qsTr("Full HD (1080p)"), qsTr("HD (720p)"),
                        qsTr("Standard (576p)"), qsTr("Low (360p)"), qsTr("Very Low (240p)")]
                currentIndex: { void(Effects.revision); return Math.max(0, values.indexOf(Number(Effects.configValue("preferred-resolution")))) }
                onActivated: (i) => Effects.setConfigValue("preferred-resolution", values[i])
            }
        }

        SettingRow {
            label: qsTr("Aspect Ratio")
            SettingCombo {
                enabled: Effects.hasVideo
                model: Player.aspectRatio; textRole: "display"
                currentIndex: root.checkedRow(Player.aspectRatio)
                onActivated: (i) => model.setData(model.index(i, 0), true, Qt.CheckStateRole)
            }
        }

        SettingRow {
            label: qsTr("Crop")
            SettingCombo {
                enabled: Effects.hasVideo
                model: Player.crop; textRole: "display"
                currentIndex: root.checkedRow(Player.crop)
                onActivated: (i) => model.setData(model.index(i, 0), true, Qt.CheckStateRole)
            }
        }

        SettingRow {
            label: qsTr("Render")
            SettingCombo {
                id: renderCombo
                // row 0 is this device; the renderer manager's rows follow
                model: ListModel { id: renderers }
                textRole: "name"
                // RendererManager::Roles: NAME = Qt::UserRole (256) … SELECTED = 262
                readonly property int _roleName: 256
                readonly property int _roleSelected: 262
                function rebuild() {
                    const rm = Player.rendererManager
                    renderers.clear()
                    renderers.append({ name: qsTr("Local") })
                    let sel = 0
                    for (let i = 0; i < rm.rowCount(); ++i) {
                        renderers.append({ name: rm.data(rm.index(i, 0), _roleName) })
                        if (rm.data(rm.index(i, 0), _roleSelected)) sel = i + 1
                    }
                    currentIndex = sel
                }
                onActivated: (i) => {
                    const rm = Player.rendererManager
                    if (i === 0) {
                        for (let r = 0; r < rm.rowCount(); ++r)
                            if (rm.data(rm.index(r, 0), _roleSelected)) rm.setData(rm.index(r, 0), false, _roleSelected)
                    } else
                        rm.setData(rm.index(i - 1, 0), true, _roleSelected)
                }
                onPressedChanged: if (pressed) Player.rendererManager.StartScan()
                Connections {
                    target: Player.rendererManager
                    function onRowsInserted() { renderCombo.rebuild() }
                    function onRowsRemoved() { renderCombo.rebuild() }
                    function onDataChanged() { renderCombo.rebuild() }
                }
                Component.onCompleted: rebuild()
            }
        }
    }
}
```
  - **Role numbers** come from `modules/gui/qt/util/renderer_manager.hpp:38-46` (NAME, TYPE, DEMUX_FILTER, SOUT, ICON_URI, FLAGS, SELECTED from `Qt::UserRole`). Re-check them if that enum has changed.
  - **Stop the scan** on panel close: in `PlaybackPanel.qml` add `onClosed: Player.rendererManager.StopScan()`.
- [ ] **Step 3: Check the look.**
  - Take a shot of the Video tab and compare it by eye with `docs/superpowers/figma/3c/c_vset.png`: same order, sizes and colours; no HDR row.
  - `count-px.sh shot.png 1196 150 368 50 371F06 6` > 2000, because the "None" segment is selected.
- [ ] **Step 4: Check the behaviour.**
  - Click "Horizontal" (1400, 146), then shot. `count-px.sh` on the same box gives > 2000 at the middle segment: run `count-px.sh shot.png 1300 150 100 30 371F06 6` > 1000.
  - `grep -E '^(video-filter|transform-type)' build/redesign-profile/config/vlc/vlcrc` shows `transform` in the list and `transform-type=hflip`.
  - Pick Zoom "1:2 Half": the video shrinks. `count-px.sh` of the video corner box (40, 60, 200, 100) against the background `2A2A2A` rises above 15000.
- [ ] **Step 5: Review Focus 4 (Rotate field).**
  - Click the Rotate field (1500, 202), type `45`, press Return. The field shows "90 deg" and vlcrc has `transform-type=antitranspose` (horizontal flip + 90).
  - Type `abc`, Return: it stays "90 deg".
  - Escape while editing restores the old text.
  - Press Up: "180 deg".
  - Reset: click "None" and type `0`, Return. `transform` is gone from `video-filter`.
- [ ] **Step 6:** Log check, then commit `qml: video settings tab defaults (flip, rotate, zoom, resolution, aspect, crop, render)`.

### Task 5: Video tab — Filters (Essential, Crop, Colors)

**Files:** Modify `player/qml/VideoSettingsPage.qml`

**Interfaces:** Consumes `Effects.value/setValue/filterEnabled/setFilterEnabled/voutCrop/setVoutCrop/revision`; `EffectAccordion`, `SettingSlider`, `SettingToggle`, `SettingField`, `SettingCombo`.

- [ ] **Step 1: Failing check.** Scroll the Video tab to the bottom (`xdotool mousemove 1380 400 click 5 click 5 click 5 click 5 click 5`) and take a shot. No "Filters" title: `count-px.sh shot.png 1200 100 360 700 969696 6` stays under 200.
- [ ] **Step 2: Value-driven slider specs.** Add to `root`:

```qml
    // [label, var, module, from, to, step, default, ticks, display(v) -> string]
    readonly property var essential: [
        [qsTr("Hue"),         "hue",             "adjust",  -180, 180, 1,    0,    0, (v) => v.toFixed(0) + "°"],
        [qsTr("Brightness"),  "brightness",      "adjust",  0,    2,   0.01, 1,    0, (v) => v.toFixed(2)],
        [qsTr("Contrast"),    "contrast",        "adjust",  0,    2,   0.01, 1,    0, (v) => v.toFixed(2)],
        [qsTr("Saturation"),  "saturation",      "adjust",  0,    3,   0.01, 1,    3, (v) => v.toFixed(2)],
        [qsTr("Gamma"),       "gamma",           "adjust",  0.01, 10,  0.01, 1,    10, (v) => v.toFixed(2)],
        [qsTr("Sharpen Sigma"), "sharpen-sigma", "sharpen", 0,    2,   0.01, 0.05, 5, (v) => v.toFixed(2)],
        [qsTr("Banding Removal Radius"), "gradfun-radius", "gradfun", 4, 32, 1, 16, 8, (v) => v.toFixed(0)],
        [qsTr("Film Grain Variance"), "grain-variance", "grain", 0, 10, 0.1, 2, 10, (v) => v.toFixed(1)],
    ]

    // a value-driven filter is on while any of its values differs from its default
    function setDriven(specs, idx, v) {
        const s = specs[idx]
        Effects.setValue(s[1], v)
        const on = specs.some((o) => o[2] === s[2] && Math.abs(Number(Effects.value(o[1])) - o[6]) > o[5] / 2)
        if (on !== Effects.filterEnabled(s[2]))
            Effects.setFilterEnabled(s[2], on)
    }
```
  Figma draws no value text on the Essential sliders, so pass `valueText: ""`. Keep the display function for the accessible name only: `Accessible.description: s[8](value)`.
- [ ] **Step 3: Filters section.** Append to the page:

```qml
    SettingSection {
        title: qsTr("Filters")

        SettingRow { label: qsTr("Essential") }
        EffectAccordion {
            Repeater {
                model: root.essential
                SettingSlider {
                    required property var modelData
                    required property int index
                    label: modelData[0]
                    valueText: ""
                    from: modelData[3]; to: modelData[4]; stepSize: modelData[5]
                    defaultValue: modelData[6]; ticks: modelData[7]
                    value: { void(Effects.revision); return Number(Effects.value(modelData[1])) }
                    onMoved: (v) => root.setDriven(root.essential, index, v)
                }
            }
        }
    }

    SettingSection {
        divider: true
        title: ""   // Figma: sub-blocks are separated by a divider and a 14 px label, not a new title
        SettingRow { label: qsTr("Crop") }
        EffectAccordion {
            enabled: Effects.hasVideo
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: VLCStyle.dp(6, VLCStyle.scale)
                columns: 3
                columnSpacing: VLCStyle.dp(8, VLCStyle.scale)
                rowSpacing: VLCStyle.dp(16, VLCStyle.scale)
                property bool linkV: false
                property bool linkH: false
                id: cropGrid

                component CropField: SettingField {
                    required property string side
                    required property string title
                    Layout.fillWidth: true
                    implicitWidth: VLCStyle.dp(141, VLCStyle.scale)
                    implicitHeight: VLCStyle.dp(33, VLCStyle.scale)
                    leftPadding: VLCStyle.dp(72, VLCStyle.scale)
                    suffix: qsTr(" px")
                    validator: IntValidator { bottom: 0; top: 4096 }
                    committedText: { void(Effects.revision); return String(Effects.voutCrop(side)) }
                    onCommitted: (t) => {
                        const px = parseInt(t) || 0
                        Effects.setVoutCrop(side, px)
                        const partner = { top: "bottom", bottom: "top", left: "right", right: "left" }[side]
                        if ((side === "top" || side === "bottom") ? cropGrid.linkV : cropGrid.linkH)
                            Effects.setVoutCrop(partner, px)
                    }
                    Widgets.LabelExt {
                        x: VLCStyle.dp(12, VLCStyle.scale); anchors.verticalCenter: parent.verticalCenter
                        text: parent.title; font.pixelSize: VLCStyle.dp(14, VLCStyle.scale); color: parent._s.label
                    }
                }

                CropField { side: "top"; title: qsTr("Top") }
                CropField { side: "bottom"; title: qsTr("Bottom") }
                Widgets.IconToolButton {
                    text: VLCIcons.link   // see note below
                    checked: cropGrid.linkV; checkable: true
                    onClicked: cropGrid.linkV = !cropGrid.linkV
                    description: qsTr("Link top and bottom")
                }
                CropField { side: "left"; title: qsTr("Left") }
                CropField { side: "right"; title: qsTr("Right") }
                Widgets.IconToolButton {
                    text: VLCIcons.link
                    checked: cropGrid.linkH; checkable: true
                    onClicked: cropGrid.linkH = !cropGrid.linkH
                    description: qsTr("Link left and right")
                }
            }
        }
    }
```
  - **Section structure:** `SettingSection` treats an empty `title` as no title. Add `visible: text.length > 0` to its `titleLabel` in this step. Figma `498:2965` has one "Filters" title, then sub-blocks (Essential, Crop, Colors) each preceded by a divider and a 14 px label row. Use one `SettingSection { title: qsTr("Filters") }` for Essential, and one titleless `SettingSection` per later sub-block.
  - **Link icon:** if `grep -n '"link' modules/gui/qt/pixmaps/VLCIcons.json` finds nothing, export the Figma link glyph. In Figma `543:990` it is the `Icon` instance next to each crop row; get its id with `get_metadata` on `543:990`. Append it as key `link`, following slice 3b Task 1 Steps 2–5 exactly. Add the icon-font files to this task's commit.
  - Add `import VLC.Widgets as Widgets` at the top of the page.
- [ ] **Step 4: Colors.** Append:

```qml
    SettingSection {
        title: ""
        SettingRow { label: qsTr("Colors") }
        EffectAccordion {
            component ColorRow: SettingRow {
                required property string module
                required property string colorVar
                SettingField {
                    implicitWidth: VLCStyle.dp(116, VLCStyle.scale)
                    validator: RegularExpressionValidator { regularExpression: /#?[0-9A-Fa-f]{6}/ }
                    committedText: { void(Effects.revision); return "#" + Number(Effects.value(parent.colorVar)).toString(16).toUpperCase().padStart(6, "0") }
                    onCommitted: (t) => Effects.setValue(parent.colorVar, t.startsWith("#") ? t : "#" + t)
                    Rectangle {   // swatch
                        anchors.right: parent.right; anchors.rightMargin: VLCStyle.dp(6, VLCStyle.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        width: VLCStyle.dp(22, VLCStyle.scale); height: width; radius: VLCStyle.dp(4, VLCStyle.scale)
                        color: parent.committedText
                    }
                }
                SettingToggle {
                    checked: { void(Effects.revision); return Effects.filterEnabled(parent.module) }
                    onToggled: (on) => Effects.setFilterEnabled(parent.module, on)
                }
            }
            component ModuleToggle: SettingRow {
                required property string module
                SettingToggle {
                    checked: { void(Effects.revision); return Effects.filterEnabled(parent.module) }
                    onToggled: (on) => Effects.setFilterEnabled(parent.module, on)
                }
            }

            ColorRow { label: qsTr("Color Extraction"); module: "extract"; colorVar: "extract-component" }
            ColorRow { label: qsTr("Color Threshold"); module: "colorthres"; colorVar: "colorthres-color" }
            SettingSlider {
                label: qsTr("Saturation"); valueText: ""
                from: 0; to: 255; stepSize: 1; defaultValue: 20
                value: { void(Effects.revision); return Number(Effects.value("colorthres-saturationthres")) }
                onMoved: (v) => Effects.setValue("colorthres-saturationthres", Math.round(v))
            }
            SettingSlider {
                label: qsTr("Similarity"); valueText: ""
                from: 0; to: 255; stepSize: 1; defaultValue: 15
                value: { void(Effects.revision); return Number(Effects.value("colorthres-similaritythres")) }
                onMoved: (v) => Effects.setValue("colorthres-similaritythres", Math.round(v))
            }
            ModuleToggle { label: qsTr("Negate Colors"); module: "invert" }
            ModuleToggle { label: qsTr("Posterize"); module: "posterize" }
            ModuleToggle { label: qsTr("Gradient"); module: "gradient" }
            SettingCombo {
                fullWidth: true
                readonly property var modes: ["gradient", "edge", "hough"]
                model: [qsTr("Gradient"), qsTr("Edge"), qsTr("Hough")]
                currentIndex: { void(Effects.revision); return Math.max(0, modes.indexOf(String(Effects.value("gradient-mode")))) }
                onActivated: (i) => Effects.setValue("gradient-mode", modes[i])
            }
            SettingRow {
                label: qsTr("Color")
                SettingToggle {
                    checked: { void(Effects.revision); return Number(Effects.value("gradient-type")) === 1 }
                    onToggled: (on) => Effects.setValue("gradient-type", on ? 1 : 0)
                }
            }
            SettingRow {
                label: qsTr("Cartoon")
                SettingToggle {
                    checked: { void(Effects.revision); return Boolean(Effects.value("gradient-cartoon")) }
                    onToggled: (on) => Effects.setValue("gradient-cartoon", on)
                }
            }
            SettingSlider {
                label: qsTr("Sepia Intensity"); valueText: ""
                from: 0; to: 255; stepSize: 1; defaultValue: 0; ticks: 3
                value: { void(Effects.revision); return Effects.filterEnabled("sepia") ? Number(Effects.value("sepia-intensity")) : 0 }
                onMoved: (v) => {
                    Effects.setValue("sepia-intensity", Math.round(v))
                    if ((v > 0) !== Effects.filterEnabled("sepia")) Effects.setFilterEnabled("sepia", v > 0)
                }
            }
        }
    }
```
  - Confirm the `colorthres-*` defaults (20/15) and the `gradient-type` var name before writing: `grep -n 'add_\(integer\|bool\|string\|rgb\)' modules/video_filter/colorthres.c modules/video_filter/gradient.c`. Use the exact names and defaults found there.
  - Figma `614:1430` separates the colour groups with 1 px dividers inside the box. Put a `Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: _s.divider }` between Threshold/Similarity and Negate, between Negate/Posterize and Gradient, and between Cartoon and Sepia.
- [ ] **Step 5: Behaviour, plus Review Focus 2.**
  - Expand Essential and drag Brightness right to about 1.5. The video brightens: the `count-px` of the video centre box (600, 300, 200, 200) against `FFFFFF` with fuzz 30 rises compared with a shot taken before.
  - `grep '^video-filter' …/vlcrc` contains `adjust`.
  - Double-click the Brightness track: the value is back at 1.00, and `adjust` is gone from `video-filter`.
  - Expand Colors and toggle Negate on: the bright count jumps (as in Task 2, Step 6). Toggle it off again.
  - Crop: link top/bottom, type `40` in Top and press Return. Bottom shows 40 px, and the video loses 40 px rows top and bottom. Check that `count-px` of the strip (300, 62, 1000, 10) against `2A2A2A` rises. Reset both to 0.
- [ ] **Step 6: Review Focus 1.**
  - Restart the harness with only an audio file: `$H start -vv build/redesign-media/tracks2.mkv --no-video; sleep 6`.
  - Open Video → Filters. The Zoom/Aspect/Crop combos and the Crop accordion are disabled (greyed).
  - Drag Brightness: there is no log error, and vlcrc gets `brightness=` and `video-filter=…adjust`.
  - Double-click to reset.
- [ ] **Step 7:** Log check, then commit `qml: video settings filters (essential, crop, colors)`.

### Task 6: Audio tab — Defaults, Synchronization, Pitch

**Files:** Modify `player/qml/AudioSettingsPage.qml`

**Interfaces:** Consumes `Player.audioStereoMode`, `Player.audioDelayMS`, `Effects.configValue/setConfigValue/value/setValue/filterEnabled/setFilterEnabled/revision`.

- [ ] **Step 1: Failing check.** Shot the Audio tab (1423, 85). There is no delay slider: `count-px.sh shot.png 1196 370 368 30 AB6314 6` < 20.
- [ ] **Step 2: Write the page:**

```qml
import QtQuick
import QtQuick.Layouts
import VLC.Style
import VLC.Player

// Figma audio settings, 536:1087
SettingsPage {
    id: root

    SettingSection {
        title: qsTr("Defaults")
        divider: false

        SettingRow {
            label: qsTr("Audio Track")
            SettingField {
                validator: IntValidator { bottom: -1; top: 99 }
                committedText: { void(Effects.revision); const n = Number(Effects.configValue("audio-track")); return n < 0 ? qsTr("Auto") : String(n + 1) }
                onCommitted: (t) => Effects.setConfigValue("audio-track", t === "" || t === qsTr("Auto") ? -1 : Math.max(0, parseInt(t) - 1))
            }
        }
        SettingRow {
            label: qsTr("Audio Language")
            SettingField {
                committedText: { void(Effects.revision); return String(Effects.configValue("audio-language")) }
                onCommitted: (t) => Effects.setConfigValue("audio-language", t)
            }
        }
        SettingRow { label: qsTr("Stereo Mode") }
        SettingCombo {
            fullWidth: true
            enabled: model.rowCount() > 0
            displayText: enabled ? currentText : qsTr("Unavailable")
            model: Player.audioStereoMode; textRole: "display"
            currentIndex: {
                void(Effects.revision)
                for (let i = 0; i < model.rowCount(); ++i)
                    if (model.data(model.index(i, 0), Qt.CheckStateRole)) return i
                return 0
            }
            onActivated: (i) => model.setData(model.index(i, 0), true, Qt.CheckStateRole)
        }
    }

    SettingSection {
        title: qsTr("Synchronization")
        SettingRow {
            label: qsTr("Audio Track Delay")
            SettingField {
                id: delayField
                suffix: " s"
                validator: DoubleValidator { notation: DoubleValidator.StandardNotation; decimals: 3 }
                committedText: (Player.audioDelayMS / 1000).toFixed(3)
                onCommitted: (t) => {
                    const s = parseFloat(t)
                    if (!isNaN(s)) Player.audioDelayMS = Math.round(Math.max(-10, Math.min(10, s)) * 1000)
                }
            }
        }
        DelaySlider { valueMs: Player.audioDelayMS; onMovedMs: (ms) => Player.audioDelayMS = ms }
    }

    SettingSection {
        title: ""
        SettingSlider {
            label: qsTr("Adjust Pitch")
            valueText: qsTr("%1 semitones").arg(value.toFixed(1))
            from: -12; to: 12; stepSize: 0.25; defaultValue: 0; ticks: 3
            value: { void(Effects.revision); return Effects.filterEnabled("scaletempo_pitch") ? Number(Effects.value("pitch-shift")) : 0 }
            onMoved: (v) => {
                Effects.setValue("pitch-shift", v)
                if ((v !== 0) !== Effects.filterEnabled("scaletempo_pitch"))
                    Effects.setFilterEnabled("scaletempo_pitch", v !== 0)
            }
        }
    }
}
```
  - Add `settings/DelaySlider.qml` and register it after `SettingsPage.qml`. Figma `1905:7352` is a slider centred on 0 whose fill runs from the centre to the handle, with "−10 s / 0 s / +10 s" labels below. Figma's right label "-10 s" in the audio variant is a typo; use "+10 s" as in the subtitle variant.
```qml
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import VLC.Style
import VLC.Widgets as Widgets

ColumnLayout {
    id: root
    property int valueMs: 0
    signal movedMs(int ms)
    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Slider; focused: slider.visualFocus }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }
    Layout.fillWidth: true
    spacing: VLCStyle.dp(10, VLCStyle.scale)

    T.Slider {
        id: slider
        Layout.fillWidth: true
        implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
        from: -10000; to: 10000; stepSize: 50
        snapMode: T.Slider.SnapAlways
        value: root.valueMs
        onMoved: root.movedMs(Math.round(value))
        Accessible.name: qsTr("Delay")
        TapHandler { onDoubleTapped: root.movedMs(0) }
        background: Rectangle {
            y: (slider.height - height) / 2
            width: slider.width; height: VLCStyle.dp(16, VLCStyle.scale)
            radius: VLCStyle.dp(6, VLCStyle.scale); color: root._s.field
            border.width: slider.visualFocus ? VLCStyle.focus_border : 0
            border.color: theme.visualFocus
            Rectangle {   // fill from the centre to the handle
                readonly property real c: parent.width / 2
                readonly property real h: slider.handle.x + slider.handle.width / 2
                x: Math.min(c, h); width: Math.abs(h - c)
                y: VLCStyle.dp(2, VLCStyle.scale); height: parent.height - 2 * y
                radius: VLCStyle.dp(4, VLCStyle.scale); color: root._s.accentBg
            }
        }
        handle: Rectangle {
            x: slider.visualPosition * (slider.availableWidth - width)
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: VLCStyle.dp(8, VLCStyle.scale); implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
            radius: VLCStyle.dp(4, VLCStyle.scale); color: root._s.accentDim
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Widgets.LabelExt { text: qsTr("-10 s"); font.pixelSize: VLCStyle.dp(12, VLCStyle.scale); color: root._s.label }
        Item { Layout.fillWidth: true }
        Widgets.LabelExt { text: qsTr("0 s"); font.pixelSize: VLCStyle.dp(12, VLCStyle.scale); color: root._s.label }
        Item { Layout.fillWidth: true }
        Widgets.LabelExt { text: qsTr("+10 s"); font.pixelSize: VLCStyle.dp(12, VLCStyle.scale); color: root._s.label }
    }
}
```
- [ ] **Step 3:** Shot the Audio tab and compare it with `c_aset.png` (no Test button). `count-px.sh shot.png 1196 370 368 30 AB6314 6` > 100 (the handle at the centre).
- [ ] **Step 4: Review Focus 4 (delay field).**
  - Type `0.5` in the delay field and press Return: the field shows "0.500 s" and the handle moves right of centre.
  - Type `99`, Return: "10.000 s".
  - Type `abc`, Return: unchanged.
  - Double-click the slider: "0.000 s".
- [ ] **Step 5: Review Focus 5 (hotkeys).**
  - Keep the panel open on Audio and press `k` twice: `$H key k k`. VLC's default audio-delay-up step is 50 ms, so the field shows "0.100 s".
  - Close the panel with Escape and reopen it with the gear: it opens on Audio.
  - Reset the delay to 0.
- [ ] **Step 6: Pitch.**
  - Drag Adjust Pitch to +4: the label reads "4.0 semitones", and vlcrc's `audio-filter` contains `scaletempo_pitch`.
  - Double-click: back to 0, and `scaletempo_pitch` is removed.
- [ ] **Step 7:** Log check, then commit `qml: audio settings tab (defaults, delay, pitch)`.

### Task 7: Audio tab — Filters (Equalizer, Compressor, Spatializer, Stereo Widener)

**Files:** Modify `player/qml/AudioSettingsPage.qml`

**Interfaces:** Consumes `Effects.equalizerPresets/equalizerPresetIndex/applyEqualizerPreset/equalizerBand/setEqualizerBand/value/setValue/filterEnabled/setFilterEnabled/revision`.

- [ ] **Step 1: Failing check.** Scroll the Audio tab to the end and shot it: no "Filters" title, so `count-px.sh shot.png 1200 100 360 700 969696 6` < 200.
- [ ] **Step 2: Equalizer.** Insert, between the Synchronization section and the pitch section:

```qml
    SettingSection {
        title: qsTr("Filters")

        SettingRow { label: qsTr("Equalizer") }
        SettingCombo {
            id: eqCombo
            fullWidth: true
            // 0 = None (filter off), 1…18 = presets, 19 = Custom (shown only when the bands match no preset)
            model: [qsTr("None")].concat(Effects.equalizerPresets).concat([qsTr("Custom")])
            currentIndex: {
                void(Effects.revision)
                if (!Effects.filterEnabled("equalizer")) return 0
                const p = Effects.equalizerPresetIndex()
                return p < 0 ? model.length - 1 : p + 1
            }
            onActivated: (i) => {
                if (i === 0) { Effects.setFilterEnabled("equalizer", false); return }
                if (i <= Effects.equalizerPresets.length) Effects.applyEqualizerPreset(i - 1)
                if (!Effects.filterEnabled("equalizer")) Effects.setFilterEnabled("equalizer", true)
            }
        }
        EffectAccordion {
            component BandSlider: ColumnLayout {
                id: band
                property string label
                property real value
                signal moved(real v)
                Layout.fillWidth: true
                spacing: VLCStyle.dp(5, VLCStyle.scale)
                SettingRow {
                    label: band.label
                    SettingField {
                        implicitWidth: VLCStyle.dp(140, VLCStyle.scale)
                        suffix: " dB"
                        validator: DoubleValidator { decimals: 1 }
                        committedText: band.value.toFixed(1)
                        onCommitted: (t) => { const v = parseFloat(t); if (!isNaN(v)) band.moved(Math.max(-20, Math.min(20, v))) }
                    }
                }
                SettingSlider {
                    showHeader: false
                    from: -20; to: 20; stepSize: 0.1; defaultValue: 0
                    value: band.value
                    onMoved: (v) => band.moved(v)
                }
            }

            BandSlider {
                label: qsTr("Preamp")
                value: { void(Effects.revision); return Number(Effects.value("equalizer-preamp")) }
                onMoved: (v) => Effects.setValue("equalizer-preamp", v)
            }
            Repeater {
                model: [qsTr("60 Hz"), qsTr("170 Hz"), qsTr("310 Hz"), qsTr("600 Hz"), qsTr("1 KHz"),
                        qsTr("3 KHz"), qsTr("6 KHz"), qsTr("12 KHz"), qsTr("14 KHz"), qsTr("16 KHz")]
                BandSlider {
                    required property int index
                    required property string modelData
                    label: modelData
                    value: { void(Effects.revision); return Effects.equalizerBand(index) }
                    onMoved: (v) => {
                        Effects.setEqualizerBand(index, v)
                        if (!Effects.filterEnabled("equalizer")) Effects.setFilterEnabled("equalizer", true)
                    }
                }
            }
        }
        SettingRow {
            label: qsTr("2 Pass")
            SettingToggle {
                checked: { void(Effects.revision); return Boolean(Effects.value("equalizer-2pass")) }
                onToggled: (on) => Effects.setValue("equalizer-2pass", on)
            }
        }
    }
```
  - The band labels follow VLC's default `equalizer-vlcfreqs` = true. If `Effects.value("equalizer-vlcfreqs")` is false, use the ISO labels 31 Hz, 63 Hz, 125 Hz, 250 Hz, 500 Hz, 1 KHz, 2 KHz, 4 KHz, 8 KHz, 16 KHz. Pick the model with a ternary on that value.
  - Preset values go through `applyEqualizerPreset`, so selecting "Custom" (the last index) is a no-op apart from switching the filter on.
- [ ] **Step 3: Toggled accordions.** Add a reusable in-file component, then the three filters:

```qml
    // [label, var, from, to, step, default, ticks, scale, unit, decimals]
    component FilterBlock: SettingSection {
        id: block
        required property string blockTitle
        required property string module
        required property var specs
        title: ""
        SettingRow {
            label: block.blockTitle
            SettingToggle {
                checked: { void(Effects.revision); return Effects.filterEnabled(block.module) }
                onToggled: (on) => Effects.setFilterEnabled(block.module, on)
            }
        }
        EffectAccordion {
            Repeater {
                model: block.specs
                SettingSlider {
                    required property var modelData
                    readonly property real k: modelData[7]
                    label: modelData[0]
                    from: modelData[2] * k; to: modelData[3] * k; stepSize: modelData[4] * k
                    defaultValue: modelData[5] * k; ticks: modelData[6]
                    value: { void(Effects.revision); return Number(Effects.value(modelData[1])) * k }
                    valueText: value.toFixed(modelData[9]) + modelData[8]
                    onMoved: (v) => Effects.setValue(modelData[1], v / k)
                }
            }
        }
    }

    FilterBlock {
        blockTitle: qsTr("Compressor"); module: "compressor"
        specs: [
            [qsTr("FM5 / Peak"),  "compressor-rms-peak",    0,   1,   0.01, 0.2, 0, 1, "",        1],
            [qsTr("Attack"),      "compressor-attack",      1.5, 400, 0.5,  25,  0, 1, qsTr(" ms"), 1],
            [qsTr("Release"),     "compressor-release",     2,   800, 1,    100, 0, 1, qsTr(" ms"), 1],
            [qsTr("Threshold"),   "compressor-threshold",   -30, 0,   0.5,  -11, 0, 1, qsTr(" dB"), 1],
            [qsTr("Ratio"),       "compressor-ratio",       1,   20,  0.1,  4,   0, 1, " : 1",    1],
            [qsTr("Knee Radius"), "compressor-knee",        1,   10,  0.1,  5,   0, 1, qsTr(" dB"), 1],
            [qsTr("Makeup Gain"), "compressor-makeup-gain", 0,   24,  0.1,  7,   0, 1, qsTr(" dB"), 1],
        ]
    }
    FilterBlock {
        blockTitle: qsTr("Spatializer"); module: "spatializer"
        specs: [
            [qsTr("Size"),  "spatializer-roomsize", 0, 1.1, 0.01, 0.85, 12, 10, "", 1],
            [qsTr("Width"), "spatializer-width",    0, 1,   0.01, 1,    11, 10, "", 1],
            [qsTr("Wet"),   "spatializer-wet",      0, 1,   0.01, 0.4,  11, 10, "", 1],
            [qsTr("Dry"),   "spatializer-dry",      0, 1,   0.01, 0.5,  11, 10, "", 1],
            [qsTr("Damp"),  "spatializer-damp",     0, 1,   0.01, 0.5,  11, 10, "", 1],
        ]
    }
    FilterBlock {
        blockTitle: qsTr("Stereo Widener"); module: "stereo_widen"
        specs: [
            [qsTr("Delay Time"),    "stereowiden-delay",     1, 100, 1,    20,  0,  1, qsTr(" ms"), 1],
            [qsTr("Feedback Gain"), "stereowiden-feedback",  0, 0.9, 0.01, 0.3, 10, 1, " %",       1],
            [qsTr("Crossfeed"),     "stereowiden-crossfeed", 0, 0.8, 0.01, 0.3, 9,  1, " %",       1],
            [qsTr("Dry Mix"),       "stereowiden-dry-mix",   0, 1,   0.01, 0.8, 11, 1, " %",       1],
        ]
    }
```
  - Confirm every var name, range and default against the module sources before writing: `grep -n 'add_float\|add_float_with_range' modules/audio_filter/{compressor,spatializer/spatializer,stereo_widen}.cpp modules/audio_filter/*.c 2>/dev/null`. Fix any table entry that differs: the table uses the module defaults, not the old dialog's.
  - `FilterBlock` is declared inside the page, so add it as `component FilterBlock: …` at the top of `root`, before the sections.
- [ ] **Step 4: Check the look** of each accordion, expanded in turn, against `fx_eq.png`, `fx_comp.png`, `fx_spat.png` and `fx_stereo.png`. Labels, value text and unit must match. Tick counts may differ from Figma, where Figma's own ticks are inconsistent; note any such difference in the ledger.
- [ ] **Step 5: Review Focus 3 (equalizer).**
  - Pick "Rock" in the Equalizer combo.
  - `grep -E '^(audio-filter|equalizer-preset|equalizer-bands)' …/vlcrc` shows `equalizer` in `audio-filter`, `equalizer-preset=rock` and the rock bands.
  - Expand: all 11 sliders are off centre, matching `eqz_preset_10b` rock.
  - Drag 60 Hz: the combo shows "Custom" and vlcrc has `equalizer-preset=` empty.
  - Pick "None": `equalizer` leaves `audio-filter`, but `equalizer-bands` keeps the custom values.
- [ ] **Step 6: Toggles.**
  - Toggle the Compressor on: vlcrc `audio-filter` contains `compressor`.
  - Drag Threshold: the value text updates and vlcrc gets `compressor-threshold=`.
  - Toggle it off.
  - Repeat for Spatializer and Stereo Widener.
- [ ] **Step 7:** Log check, then commit `qml: audio settings filters (equalizer, compressor, spatializer, stereo widener)`.

### Task 8: Subtitles tab

**Files:** Modify `player/qml/SubtitleSettingsPage.qml`

**Interfaces:** Consumes `Player.subtitleDelayMS`, `Player.subtitleFPS`, `Effects.*`; `DelaySlider` from Task 6.

- [ ] **Step 1: Failing check.** Shot the Subtitles tab (1520, 85): there is no Synchronization title. `count-px.sh shot.png 1200 180 200 40 969696 6` < 20.
- [ ] **Step 2: Write the page:**

```qml
import QtQuick
import QtQuick.Layouts
import VLC.Style
import VLC.Player

// Figma subtitle settings, 763:1986
SettingsPage {
    id: root

    SettingSection {
        title: qsTr("Defaults")
        divider: false
        SettingRow {
            label: qsTr("Subtitle Track")
            SettingField {
                validator: IntValidator { bottom: -1; top: 99 }
                committedText: { void(Effects.revision); const n = Number(Effects.configValue("sub-track")); return n < 0 ? qsTr("Auto") : String(n + 1) }
                onCommitted: (t) => Effects.setConfigValue("sub-track", t === "" || t === qsTr("Auto") ? -1 : Math.max(0, parseInt(t) - 1))
            }
        }
        SettingRow {
            label: qsTr("Subtitle Language")
            SettingField {
                committedText: { void(Effects.revision); return String(Effects.configValue("sub-language")) }
                onCommitted: (t) => Effects.setConfigValue("sub-language", t)
            }
        }
    }

    SettingSection {
        title: qsTr("Synchronization")
        SettingRow {
            label: qsTr("Subtitle Track Delay")
            SettingField {
                suffix: " s"
                validator: DoubleValidator { notation: DoubleValidator.StandardNotation; decimals: 3 }
                committedText: (Player.subtitleDelayMS / 1000).toFixed(3)
                onCommitted: (t) => { const s = parseFloat(t); if (!isNaN(s)) Player.subtitleDelayMS = Math.round(Math.max(-10, Math.min(10, s)) * 1000) }
            }
        }
        DelaySlider { valueMs: Player.subtitleDelayMS; onMovedMs: (ms) => Player.subtitleDelayMS = ms }

        SettingRow {
            label: qsTr("Subtitle Speed")
            SettingField {
                suffix: qsTr(" fps")
                validator: DoubleValidator { bottom: 1; top: 100; decimals: 3 }
                committedText: Player.subtitleFPS.toFixed(3)
                onCommitted: (t) => { const v = parseFloat(t); if (!isNaN(v)) Player.subtitleFPS = Math.max(1, Math.min(100, v)) }
            }
        }
        SettingSlider {
            showHeader: false
            from: 1; to: 100; stepSize: 0.2; defaultValue: 1
            value: Player.subtitleFPS
            onMoved: (v) => Player.subtitleFPS = v
        }

        SettingRow {
            label: qsTr("Subtitle Duration Factor")
            SettingField {
                validator: DoubleValidator { bottom: 0; top: 20; decimals: 3 }
                committedText: { void(Effects.revision); return Effects.filterEnabled("subsdelay") ? Number(Effects.value("subsdelay-factor")).toFixed(3) : "0.000" }
                onCommitted: (t) => { const v = parseFloat(t); if (!isNaN(v)) root.setDuration(Math.max(0, Math.min(20, v))) }
            }
        }
        SettingSlider {
            showHeader: false
            from: 0; to: 20; stepSize: 0.2; defaultValue: 0
            value: { void(Effects.revision); return Effects.filterEnabled("subsdelay") ? Number(Effects.value("subsdelay-factor")) : 0 }
            onMoved: (v) => root.setDuration(v)
        }
    }

    function setDuration(v) {
        Effects.setValue("subsdelay-factor", v)
        if ((v > 0) !== Effects.filterEnabled("subsdelay")) Effects.setFilterEnabled("subsdelay", v > 0)
    }

    SettingSection {
        title: qsTr("Appearance")

        SettingRow {
            label: qsTr("Subtitle Font")
            SettingField {
                committedText: { void(Effects.revision); return String(Effects.configValue("freetype-font")) }
                onCommitted: (t) => Effects.setConfigValue("freetype-font", t)
            }
        }
        component ColorField: SettingRow {
            id: cf
            required property string colorVar
            SettingField {
                validator: RegularExpressionValidator { regularExpression: /#?[0-9A-Fa-f]{6}/ }
                committedText: { void(Effects.revision); return "#" + Number(Effects.configValue(cf.colorVar)).toString(16).toUpperCase().padStart(6, "0") }
                onCommitted: (t) => Effects.setConfigValue(cf.colorVar, t.startsWith("#") ? t : "#" + t)
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: VLCStyle.dp(7, VLCStyle.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.dp(22, VLCStyle.scale); height: width; radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: parent.committedText
                    border.width: 1; border.color: "#404040"
                }
            }
        }
        ColorField { label: qsTr("Text Color"); colorVar: "freetype-color" }
        ColorField { label: qsTr("Outline Color"); colorVar: "freetype-outline-color" }
        SettingRow {
            label: qsTr("Subtitle Offset")
            SettingField {
                suffix: qsTr("px")
                validator: IntValidator { bottom: 0; top: 2000 }
                committedText: { void(Effects.revision); return String(Effects.value("sub-margin")) }
                onCommitted: (t) => Effects.setValue("sub-margin", parseInt(t) || 0)
            }
        }

        SettingSlider {
            readonly property var stops: [50, 75, 100, 125, 150, 200]
            readonly property var names: [qsTr("Smaller"), qsTr("Small"), qsTr("Auto"), qsTr("Large"), qsTr("Larger"), qsTr("Largest")]
            label: qsTr("Font Size")
            from: 0; to: 5; stepSize: 1; defaultValue: 2; ticks: 6
            value: { void(Effects.revision); const s = Effects.subtitleTextScale(); let best = 0
                     for (let i = 1; i < stops.length; ++i) if (Math.abs(stops[i] - s) < Math.abs(stops[best] - s)) best = i
                     return best }
            valueText: names[Math.round(value)]
            onMoved: (v) => Effects.setSubtitleTextScale(stops[Math.round(v)])
        }
        SettingSlider {
            readonly property var stops: [0, 2, 4, 6]
            readonly property var names: [qsTr("None"), qsTr("Thin"), qsTr("Normal"), qsTr("Thick")]
            label: qsTr("Outline Thickness")
            from: 0; to: 3; stepSize: 1; defaultValue: 2; ticks: 4
            value: { void(Effects.revision); return Math.max(0, stops.indexOf(Number(Effects.configValue("freetype-outline-thickness")))) }
            valueText: names[Math.round(value)]
            onMoved: (v) => Effects.setConfigValue("freetype-outline-thickness", stops[Math.round(v)])
        }
        SettingSlider {
            label: qsTr("Background Opacity")
            from: 0; to: 100; stepSize: 10; defaultValue: 0; ticks: 11
            value: { void(Effects.revision); return Math.round(Number(Effects.configValue("freetype-background-opacity")) / 2.55) }
            valueText: qsTr("%1 %").arg(Math.round(value))
            onMoved: (v) => Effects.setConfigValue("freetype-background-opacity", Math.round(v * 2.55))
        }
    }
}
```
  - Note under the Font and Outline Color rows (as a `Widgets.LabelExt`, 12 px `#6B6B6B`): "Applies to the next video". `freetype-font` and `freetype-outline-color` are read when the text renderer opens. Text colour, outline thickness and background opacity apply on the next rendered subtitle, so they get no note.
  - Confirm that `sub-margin` is a vout var with `var_Type` on the running vout (`grep -n '"sub-margin"' src/video_output/vout_intf.c`). If it is not, call `Effects.setConfigValue` plus `Effects.setValue` anyway; `setValue` already falls through to the config.
- [ ] **Step 3: Check the look.** Shot the tab, scrolled top and bottom, and compare with `c_sset.png`: no Embedded Sub Format row and no Size Values row.
- [ ] **Step 4: Behaviour.**
  - Play `tracks2.mkv` (it has a subtitle track) and select it in the tracks panel.
  - Type `-4` in the subtitle delay field and press Return: "−4.000 s", with the fill from the handle to the centre as in Figma `1905:7367`.
  - Move Font Size to "Larger" and shot. The subtitle text is visibly bigger: the `count-px` of the subtitle band (300, 700, 1000, 120) against `FFFFFF` with fuzz 20 grows by more than 30 % from a shot at "Auto".
  - Set Background Opacity to 50 %: a dark box appears behind the subtitles on the next subtitle line.
  - Reset all of them to their defaults.
- [ ] **Step 5:** Log check, then commit `qml: subtitle settings tab (defaults, sync, appearance)`.

### Task 9: Preset reset, final verification, handoff

**Files:**
- Modify: `player/qml/PlaybackPanel.qml`, `player/qml/VideoSettingsPage.qml`, `AudioSettingsPage.qml`, `SubtitleSettingsPage.qml`
- Modify: `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md`

**Interfaces:** Each settings page gains `readonly property var resetNames: [...]` and `readonly property var resetModules: [...]`, the persisted vars and value-driven modules it owns. Consumes `Effects.resetToDefaults`.

- [ ] **Step 1: Failing check.** Shot any settings tab: no preset button above the footer. `count-px.sh shot.png 1200 748 360 40 090909 4` < 5000.
- [ ] **Step 2: Reset lists:**
  - **Video:**
    - `resetNames: ["hue","brightness","contrast","saturation","gamma","sharpen-sigma","gradfun-radius","grain-variance","extract-component","colorthres-color","colorthres-saturationthres","colorthres-similaritythres","gradient-mode","gradient-type","gradient-cartoon","sepia-intensity","preferred-resolution"]`
    - `resetModules: ["adjust","sharpen","gradfun","grain","extract","colorthres","invert","posterize","gradient","sepia","transform"]`
  - **Audio:**
    - `resetNames: ["audio-track","audio-language","equalizer-preamp","equalizer-bands","equalizer-preset","equalizer-2pass","compressor-rms-peak","compressor-attack","compressor-release","compressor-threshold","compressor-ratio","compressor-knee","compressor-makeup-gain","spatializer-roomsize","spatializer-width","spatializer-wet","spatializer-dry","spatializer-damp","stereowiden-delay","stereowiden-feedback","stereowiden-crossfeed","stereowiden-dry-mix","pitch-shift"]`
    - `resetModules: ["equalizer","compressor","spatializer","stereo_widen","scaletempo_pitch"]`
  - **Subtitles:**
    - `resetNames: ["sub-track","sub-language","subsdelay-factor","freetype-font","freetype-color","freetype-outline-color","sub-margin","freetype-outline-thickness","freetype-background-opacity","sub-text-scale"]`
    - `resetModules: ["subsdelay"]`. For `sub-text-scale`, also call `Effects.setSubtitleTextScale(100)` after `resetToDefaults`, so the live player follows.
- [ ] **Step 3: Preset button in `PlaybackPanel.qml`:**

```qml
    footerHeader: T.Button {
        id: presetBtn
        visible: root.currentTab > 0
        Layout.fillWidth: true
        implicitHeight: VLCStyle.dp(42, VLCStyle.scale)
        text: qsTr("Default Preset")
        onClicked: presetMenu.open()
        readonly property SettingsStyle _s: SettingsStyle { theme: root.colorContext }
        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale); color: presetBtn._s.field
            border.width: presetBtn.visualFocus ? VLCStyle.focus_border : 0
            border.color: root.colorContext.visualFocus
        }
        contentItem: RowLayout {
            Widgets.LabelExt {
                Layout.fillWidth: true; leftPadding: VLCStyle.dp(16, VLCStyle.scale)
                text: presetBtn.text; font.pixelSize: VLCStyle.dp(14, VLCStyle.scale); color: presetBtn._s.value
            }
            Widgets.IconLabel {
                Layout.rightMargin: VLCStyle.dp(16, VLCStyle.scale)
                text: VLCIcons.expand_inverted   // use the chevron key chosen in Task 3, Step 6, rotated 180° (up)
                rotation: 180
                font.pixelSize: VLCStyle.dp(24, VLCStyle.scale); color: presetBtn._s.value
            }
        }
        T.Menu {
            id: presetMenu
            y: -height - VLCStyle.dp(4, VLCStyle.scale)
            width: presetBtn.width
            background: Rectangle { color: presetBtn._s.field; radius: VLCStyle.dp(6, VLCStyle.scale) }
            T.MenuItem {
                id: resetItem
                width: parent ? parent.width : implicitWidth
                implicitHeight: VLCStyle.dp(38, VLCStyle.scale)
                text: qsTr("Reset to Default Preset")
                onTriggered: {
                    const page = pageHolderPages[root.currentTab]
                    Effects.resetToDefaults(page.resetNames, page.resetModules)
                    if (root.currentTab === 3) Effects.setSubtitleTextScale(100)
                }
                contentItem: Widgets.LabelExt {
                    leftPadding: VLCStyle.dp(16, VLCStyle.scale); verticalAlignment: Text.AlignVCenter
                    text: resetItem.text; font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: resetItem.highlighted ? presetBtn._s.accent : presetBtn._s.value
                }
                background: Rectangle { color: resetItem.highlighted ? presetBtn._s.face : "transparent"; radius: VLCStyle.dp(4, VLCStyle.scale) }
            }
        }
    }
```
  - Give the three page instances ids (`videoPage`, `audioPage`, `subtitlePage`) and add `readonly property var pageHolderPages: [null, videoPage, audioPage, subtitlePage]` to `root`.
  - **Popup stacking:** the `T.Menu` is a popup above a modal popup. `PlayerPanel._otherPopupOpen` (slice 3b) counts popups above the card, so a click on the menu must not close the card. Verify this in Step 4.
- [ ] **Step 4: Check.**
  - Change Brightness and Compressor Threshold, then open Video → Default Preset → "Reset to Default Preset".
  - Brightness is back at 1.00 and `adjust` is out of `video-filter`.
  - The Compressor value is untouched: the reset is per tab.
  - The card stays open after the menu click.
- [ ] **Step 5: Full pass.**
  - `meson test -C build --suite qt`: 10/10 pass.
  - For each of the 4 tabs, at the top and scrolled to the bottom, shot it and compare with the Figma shots. Record each difference in the ledger as fixed or accepted, with the reason.
  - Run the Review Focus checks 1–5 again in one session.
  - The log check is empty.
- [ ] **Step 6: Roadmap.** Mark the row `3c Settings tabs + effects (done)`.
- [ ] **Step 7:** Commit `qml: reset a settings tab to its defaults from the preset button`.
- [ ] **Step 8:** Write the session handoff with the `handoff-doc:handoff` skill. Merging `redesign/player-settings` into `master` is the user's call.
