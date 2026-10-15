# VLC Redesign: Slice 3d, Music Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Audio-only media get the Figma music player. It has:
- a large rounded cover over the blurred art, with one "title - artist" line;
- a music control bar with ±15 s skips and an audio-tracks button;
- a seek bar drawn as the track's real waveform, decoded silently in the background.

**Architecture:**
- **Pure helpers.** `player/waveform_util.{hpp,cpp}` folds samples into 1024 peak buckets, resamples and snaps bar heights. They are unit-tested.
- **Decode.** `PlayerWaveform` (QML type `Waveform` in `VLC.Player`) runs a hidden `vlc_player_t`, the same pattern as `modules/misc/fingerprinter.c`. Its sout chain is `#transcode{…mono 8 kHz float…}:smem{…,no-time-sync}`, so it decodes faster than real time with no audio output. A GUI timer publishes the peaks every 100 ms.
- **Seek bar.** `SliderBar.qml` gains a visual-only `waveform` mode: two Canvas layers, with the orange one clipped at the progress point.
- **Music view.** `Player.qml`'s audio branch is reduced to the Figma layout.
- **Control bar.** The default Audioplayer profile, the skip buttons and `LangButton` get the music bar's controls and glyphs.

**Tech Stack:**
- Qt 6 QML (QtQuick, Templates, Canvas) and C++17 QObject.
- libvlccore: `vlc_player_*`, `input_item_*`, `vlc_object_create`, and the sout modules `transcode` and `smem`.
- QTest via meson `vlc_tests`; the Xvfb and Wayland harness.

**Spec:** `docs/superpowers/specs/2026-10-16-vlc-redesign-music-player-design.md`. Read it first.
- **Figma file:** `dSoAm0gN9ZterHSssJU9FN`. This account can read it; Galen's `d9xvroRclV6SaObbcqRmBr` cannot be read here.
- **Frames:** `Player - Music` `4767:23726`, `Controls` music `4778:26181`, waveform geometry `2139:8124`.
- **Reference shots:** in `docs/superpowers/figma/3d/`:
  - `player_music.png` (full frame, 1600×900 render);
  - `controls_music.png` (the bar);
  - `before_music.png` (today's build).

## Global Constraints

- **Branch** `redesign/music-player` (it already exists and holds the spec commit). One commit per task, with the repo's configured git identity (`ming <mingbao2891@gmail.com>`) and no AI attribution or co-author trailer.
- **Palette:** use the Figma dark hex values only when `palette.isDark`; otherwise use ColorContext colours (light theme is slice 10).
- **Sizes and strings:** sizes as `VLCStyle.dp(n, VLCStyle.scale)`, user strings in `qsTr()`. C++ log strings stay untranslated.
- **New C++ files:**
  - **meson** (`modules/gui/qt/meson.build`): headers with `Q_OBJECT` go in `moc_headers` after `'player/player_effects.hpp',`. Sources and headers go in `qt_plugin_sources` after `'player/player_effects.hpp',`.
  - **Makefile.am** (`modules/gui/qt/Makefile.am`): add them to `libqt_plugin_la_SOURCES` after `player/player_effects.cpp player/player_effects.hpp \`. Add moc outputs to `nodist_libqt_plugin_la_SOURCES` after `player/player_effects.moc.cpp \`.
- **Icon font:** keys are append-only (charcodes go by index). Changing an existing key's SVG path is allowed; renumbering is not.
- **Silence:** every run uses `--aout=dummy` (the harness adds it). The hidden decode player never creates an aout: it has a sout chain, and its parent object has `aout=dummy`.
- **Harness:**
  - `H=docs/superpowers/scripts/vlc-xvfb.sh; L=build/redesign-profile/run/vlc.log`.
  - Before each start: `cp /tmp/conf.bak build/redesign-profile/config/vlc/vlc-qt-interface.conf`. If `/tmp/conf.bak` is gone, run `$H seed` once and copy the seeded conf to `/tmp/conf.bak`.
  - Start: `$H start -vv build/redesign-music/waveform.mp3; sleep 6`, where `waveform.mp3` is made in Task 2.
  - Shots: `$H shot <png>`. Stop: `$H stop`.
  - Use the scratchpad for shots, never the repo, except the final ones in Task 7.
- **Log check:** every visual check ends with `grep -E "TypeError|ReferenceError|non-existent property|unavailable|Unable to assign|is not a type|Could not convert|Cannot assign|waveform: failed" $L`. Expected: no output.
- **Process check:** after `$H stop`, `pgrep -x vlc-static` prints nothing.
- **Build and test:** `ninja -C build` must be clean. `meson test -C build --suite qt` must pass every test (10 before this slice, 11 after Task 1).
- **Scratchpad:** `S` is the session scratchpad directory; every shot and temp file goes there.

## Review Focus

1. **Skipping tracks quickly while a decode runs.**
   - Press `n` three times within a second on a queue of music files.
   - Expected: no crash and no hang. The bars that end up showing belong to the last track, never the previous one. The log shows one `waveform: … ms` line per finished decode and none for the cancelled ones.
   - Pinned in Task 5, Step 6.
2. **Quitting VLC in the middle of a decode.**
   - Start a long file (`build/redesign-music/long.mp3`, 20 min) and stop the harness within 1 s.
   - Expected: VLC exits within the harness's 1 s grace (no `kill -9` needed) and leaves no core dump.
   - Pinned in Task 2, Step 7.
3. **A video right after a song.**
   - Expected: no `Waveform` stays alive for the video. Its decode is cancelled, the video bar keeps the plain seek bar, and there are no stray `vlc-static` threads or audio.
   - Pinned in Task 5, Step 6.
4. **Media with nothing to decode.**
   - Cases: a network URI, a file with no audio track, and a corrupt file.
   - Expected: flat 2 px bars, the waveform is still clickable to seek, and the log is clean.
   - Pinned in Task 2, Step 7 (no decode is started for `http://`) and Task 5, Step 6 (flat bars).
5. **Resizing the window.**
   - At 1000×700 and at 1600×900, the bars keep a 5 px pitch and fill the track. They are re-sampled, not stretched.
   - Pinned in Task 5, Step 5.

---

### Task 1: Waveform helpers with unit tests

**Files:**
- Create: `modules/gui/qt/player/waveform_util.hpp`, `modules/gui/qt/player/waveform_util.cpp`
- Create: `modules/gui/qt/tests/test_waveform_util.cpp`
- Modify: `modules/gui/qt/meson.build` (plugin sources, and a test entry after `test_qt_effects_util`), `modules/gui/qt/Makefile.am` (plugin sources, and a test block after `# test_effects_util`)

**Interfaces:** produces namespace `waveform`:
- `constexpr int BUCKETS = 1024;`
- `void foldSamples(QList<float>& buckets, const float* samples, int count, qint64 startUs, unsigned rate, qint64 lengthUs);` keeps `max |x|` per bucket; samples at or past `lengthUs` are dropped.
- `QList<float> resample(const QList<float>& peaks, int count);` takes the max over each of `count` spans; empty `peaks` gives `count` zeros.
- `void normalize(QList<float>& peaks);` divides by the max (a no-op when the max is 0).
- `qreal barHeight(float peak, qreal minH, qreal maxH, qreal step);` returns `minH + round(peak·(maxH−minH)/step)·step`, clamped to [minH, maxH].

- [x] **Step 1: Write the failing test** `modules/gui/qt/tests/test_waveform_util.cpp`. Use the same GPL header as `tests/test_effects_util.cpp`, year 2026.

```cpp
#include <QTest>
#include <algorithm>
#include "player/waveform_util.hpp"

using namespace waveform;

class TestWaveformUtil : public QObject
{
    Q_OBJECT
private slots:
    void foldBucketsByTime()
    {
        QList<float> b(BUCKETS, 0.f);
        // 8 Hz over a 1 s media: sample i sits at i/8 s, i.e. bucket i*128
        const float s[8] = { 0.1f, -0.5f, 0.2f, 0.f, 0.f, 0.f, 0.f, -0.9f };
        foldSamples(b, s, 8, 0, 8, 1000000);
        QCOMPARE(b[0], 0.1f);
        QCOMPARE(b[128], 0.5f);   // absolute value
        QCOMPARE(b[256], 0.2f);
        QCOMPARE(b[896], 0.9f);
        QCOMPARE(b[1], 0.f);
    }
    void foldKeepsMax()
    {
        QList<float> b(BUCKETS, 0.f);
        const float loud[1] = { 0.8f }, quiet[1] = { 0.3f };
        foldSamples(b, loud, 1, 0, 8, 1000000);
        foldSamples(b, quiet, 1, 0, 8, 1000000);
        QCOMPARE(b[0], 0.8f);
    }
    void foldDropsPastLength()
    {
        QList<float> b(BUCKETS, 0.f);
        const float s[2] = { 1.f, 1.f };
        foldSamples(b, s, 2, 1000000, 8, 1000000);   // starts at the end
        QCOMPARE(*std::max_element(b.cbegin(), b.cend()), 0.f);
    }
    void foldIgnoresBadInput()
    {
        QList<float> b(BUCKETS, 0.f);
        const float s[1] = { 1.f };
        foldSamples(b, s, 1, 0, 0, 1000000);   // no rate
        foldSamples(b, s, 1, 0, 8, 0);         // no length
        foldSamples(b, s, 1, -1, 8, 1000000);  // before the start
        QCOMPARE(*std::max_element(b.cbegin(), b.cend()), 0.f);
    }

    void resampleKeepsSpanPeak()
    {
        const QList<float> p { 0.f, 1.f, 0.f, 0.f, 0.f, 0.f, 0.5f, 0.f };
        QCOMPARE(resample(p, 2), (QList<float>{ 1.f, 0.5f }));
    }
    void resampleUpsamples()
    {
        const QList<float> p { 0.2f, 0.4f };
        QCOMPARE(resample(p, 4), (QList<float>{ 0.2f, 0.2f, 0.4f, 0.4f }));
    }
    void resampleEmpty()
    {
        QCOMPARE(resample({}, 3), (QList<float>{ 0.f, 0.f, 0.f }));
        QCOMPARE(resample({ 1.f }, 0), QList<float>{});
    }

    void normalizeScales()
    {
        QList<float> p { 0.25f, 0.5f };
        normalize(p);
        QCOMPARE(p, (QList<float>{ 0.5f, 1.f }));
        QList<float> z { 0.f, 0.f };
        normalize(z);
        QCOMPARE(z, (QList<float>{ 0.f, 0.f }));
    }

    void barHeightSnaps_data()
    {
        QTest::addColumn<float>("peak");
        QTest::addColumn<qreal>("h");
        QTest::newRow("silent") << 0.f   << 2.;
        QTest::newRow("full")   << 1.f   << 14.;
        QTest::newRow("half")   << 0.5f  << 8.;
        QTest::newRow("tiny")   << 0.04f << 2.;
        QTest::newRow("small")  << 0.09f << 4.;
        QTest::newRow("over")   << 1.5f  << 14.;
        QTest::newRow("under")  << -1.f  << 2.;
    }
    void barHeightSnaps()
    {
        QFETCH(float, peak);
        QFETCH(qreal, h);
        QCOMPARE(barHeight(peak, 2., 14., 2.), h);
    }
};

QTEST_GUILESS_MAIN(TestWaveformUtil)
#include "test_waveform_util.moc"
```

- [x] **Step 2: Register the test.**
  - **meson.build:** after the whole `test_qt_effects_util` block:

```meson
        vlc_tests += {
            'name': 'test_qt_waveform_util',
            'sources': files(
                'tests/test_waveform_util.cpp',
                'player/waveform_util.hpp',
                'player/waveform_util.cpp'
            ),
            'moc_sources': files('tests/test_waveform_util.cpp'),
            'suite': ['qt'],
            'include_directories' : qt_include_dir,
            'link_args': qt_link_args,
            'dependencies': [qt6_dep, qtest_qt6_dep]
        }
```

  - **Makefile.am:** after the `TESTS += test_effects_util` line:

```make

# test_waveform_util

test_waveform_util_SOURCES = \
	tests/test_waveform_util.cpp \
	player/waveform_util.hpp player/waveform_util.cpp
nodist_test_waveform_util_SOURCES = tests/test_waveform_util.moc
BUILT_SOURCES += tests/test_waveform_util.moc
CLEANFILES += tests/test_waveform_util.moc
test_waveform_util_CPPFLAGS = $(QT_QTEST_COMMON_cppflags)
test_waveform_util_CXXFLAGS = $(QT_QTEST_COMMON_cxxflags)
test_waveform_util_LDADD = $(QT_QTEST_COMMON_ldadd)
test_waveform_util_LDFLAGS = $(QT_QTEST_COMMON_ldflags)
check_PROGRAMS += test_waveform_util
TESTS += test_waveform_util
```

  - Also add `'player/waveform_util.cpp', 'player/waveform_util.hpp',` to meson `qt_plugin_sources` (after `'player/effects_util.hpp',`).
  - And add `player/waveform_util.cpp player/waveform_util.hpp \` to Makefile.am `libqt_plugin_la_SOURCES` (after `player/effects_util.cpp player/effects_util.hpp \`).

- [x] **Step 3: Run it and see it fail.** `ninja -C build 2>&1 | tail -5`. Expected: FAIL, because `player/waveform_util.hpp` does not exist.

- [x] **Step 4: Implement.**
  - `modules/gui/qt/player/waveform_util.hpp`, with the GPL header:

```cpp
#ifndef VLC_QT_WAVEFORM_UTIL_HPP
#define VLC_QT_WAVEFORM_UTIL_HPP

#include <QList>
#include <QtGlobal>

// peak data for the music player's waveform seek bar
namespace waveform
{
constexpr int BUCKETS = 1024;

// fold `count` mono samples, the first at `startUs` from the media start, into `buckets` as max |x|
void foldSamples(QList<float>& buckets, const float* samples, int count,
                 qint64 startUs, unsigned rate, qint64 lengthUs);
// `count` values, each the max of its span of `peaks` (zeros when `peaks` is empty)
QList<float> resample(const QList<float>& peaks, int count);
// scale so the loudest value is 1 (no-op on silence)
void normalize(QList<float>& peaks);
// bar height for a 0..1 peak, snapped to `step` and clamped to [minH, maxH]
qreal barHeight(float peak, qreal minH, qreal maxH, qreal step);
}

#endif
```

  - `modules/gui/qt/player/waveform_util.cpp`:

```cpp
#include "waveform_util.hpp"

#include <algorithm>
#include <cmath>

namespace waveform
{
void foldSamples(QList<float>& buckets, const float* samples, int count,
                 qint64 startUs, unsigned rate, qint64 lengthUs)
{
    if (buckets.isEmpty() || rate == 0 || lengthUs <= 0)
        return;
    const qsizetype n = buckets.size();
    for (int i = 0; i < count; ++i)
    {
        const qint64 t = startUs + qint64(i) * 1000000 / rate;
        if (t < 0)
            continue;
        if (t >= lengthUs)
            break;
        float& b = buckets[qsizetype(t * n / lengthUs)];
        b = std::max(b, std::fabs(samples[i]));
    }
}

QList<float> resample(const QList<float>& peaks, int count)
{
    QList<float> out(std::max(count, 0), 0.f);
    const qsizetype n = peaks.size();
    if (n == 0)
        return out;
    for (int i = 0; i < count; ++i)
    {
        const qsizetype from = qsizetype(i) * n / count;
        const qsizetype to = std::max(from + 1, qsizetype(i + 1) * n / count);
        out[i] = *std::max_element(peaks.cbegin() + from, peaks.cbegin() + to);
    }
    return out;
}

void normalize(QList<float>& peaks)
{
    if (peaks.isEmpty())
        return;
    const float max = *std::max_element(peaks.cbegin(), peaks.cend());
    if (max <= 0.f)
        return;
    for (float& p : peaks)
        p /= max;
}

qreal barHeight(float peak, qreal minH, qreal maxH, qreal step)
{
    const qreal p = std::clamp<qreal>(peak, 0., 1.);
    return std::clamp(minH + std::round(p * (maxH - minH) / step) * step, minH, maxH);
}
}
```

- [x] **Step 5: Run the tests and see them pass.**
  - `ninja -C build && meson test -C build --suite qt test_qt_waveform_util -v 2>&1 | tail -20`. Expected: `Totals: … passed, 0 failed`.
  - Then run `meson test -C build --suite qt`. Expected: 11/11 OK.
- [x] **Step 6: Commit** `qt: add tested helpers for the music player's waveform`.

---

### Task 2: `PlayerWaveform`, a background decode into peaks

**Files:**
- Create: `modules/gui/qt/player/player_waveform.hpp`, `modules/gui/qt/player/player_waveform.cpp`
- Modify: `modules/gui/qt/maininterface/mainui.cpp` (register the type), `meson.build`, `Makefile.am`
- Modify: `docs/superpowers/scripts/make-samples.sh` (new samples `waveform.mp3` and `long.mp3`)

**Interfaces:**
- Consumes: Task 1's `waveform::BUCKETS`, `foldSamples`, `resample`, `normalize`, `barHeight`.
- Produces: QML type **`Waveform`** in `VLC.Player`:
  - `property MainCtx ctx`, required; set it to `MainCtx`.
  - `property url uri`: a new value cancels any running decode and starts a new one. Only `file://` URIs are decoded.
  - `readonly property list<real> peaks`: 1024 values from 0 to 1 (normalised), empty before data arrives. `peaksChanged` fires at most every 100 ms.
  - `readonly property bool ready`: the decode has finished (or could not start).
  - `Q_INVOKABLE list<real> heights(int count, real minH, real maxH, real step)`: bar heights in px. Flat `minH` bars while there are no peaks.
  - Log: `msg_Dbg` `waveform: <N> ms` when a decode finishes. `msg_Err` `waveform: failed to start` on a start failure.

- [x] **Step 1: Sample media.** Append to `docs/superpowers/scripts/make-samples.sh`, before `echo samples ready`:

```sh
# music player: a shaped envelope (silence, ramp, bursts) with an embedded cover, and a long file for cancel tests
ffmpeg -v error -y -f lavfi -i "testsrc2=size=600x600:duration=1" -frames:v 1 "$M/cover.png"
ffmpeg -v error -y \
       -f lavfi -i "aevalsrc='if(lt(t,3),0,if(lt(t,13),(t-3)/10*sin(2*PI*220*t),if(lt(mod(t-13,2),1),0.9*sin(2*PI*330*t),0.05*sin(2*PI*330*t))))':d=40:s=44100" \
       -i "$M/cover.png" -map 0:a -map 1:v -c:a libmp3lame -q:a 6 -c:v png -disposition:v attached_pic \
       -id3v2_version 3 -metadata title=waveform -metadata artist=Tester "$M/waveform.mp3"
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.5*sin(2*PI*220*t)*sin(2*PI*0.05*t)':d=1200:s=22050" \
       -c:a libmp3lame -q:a 9 -metadata title=long -metadata artist=Tester "$M/long.mp3"
rm -f "$M/cover.png"
```

  - Generate only these two files, by running the three ffmpeg lines from that block by hand with `M=build/redesign-music`. Rerunning the whole script would rewrite the other samples and the library's file dates.
  - Check: `ffprobe -v error -show_entries stream=codec_type:format=duration -of csv=p=0 build/redesign-music/waveform.mp3` prints `audio`, `video` (the attached picture) and `40.0…`.

- [x] **Step 2: Failing check.**
  - Add the registration line to `maininterface/mainui.cpp`, right after the `qmlRegisterSingletonInstance<PlayerEffects>(…);` statement:

```cpp
        qmlRegisterType<PlayerWaveform>(uri, versionMajor, versionMinor, "Waveform");
```

  - Add `#include "player/player_waveform.hpp"` next to the existing `#include "player/player_effects.hpp"`.
  - `ninja -C build 2>&1 | tail -3`. Expected: FAIL, because `player/player_waveform.hpp` is not found.

- [x] **Step 3: Header** `modules/gui/qt/player/player_waveform.hpp`, with the GPL header:

```cpp
#ifndef VLC_QT_PLAYER_WAVEFORM_HPP
#define VLC_QT_PLAYER_WAVEFORM_HPP

#include <QElapsedTimer>
#include <QList>
#include <QObject>
#include <QTimer>
#include <QUrl>

#include "qt.hpp"
#include "maininterface/mainctx.hpp"

struct WaveformJob;

// peaks of a local audio file for the music player's seek bar (QML type "Waveform"),
// decoded faster than real time by a hidden player with no audio output
class PlayerWaveform : public QObject
{
    Q_OBJECT
    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    Q_PROPERTY(QUrl uri READ uri WRITE setUri NOTIFY uriChanged FINAL)
    Q_PROPERTY(QList<float> peaks READ peaks NOTIFY peaksChanged FINAL)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged FINAL)

public:
    explicit PlayerWaveform(QObject* parent = nullptr);
    ~PlayerWaveform() override;

    MainCtx* ctx() const { return m_ctx; }
    void setCtx(MainCtx* ctx);
    QUrl uri() const { return m_uri; }
    void setUri(const QUrl& uri);
    QList<float> peaks() const { return m_peaks; }
    bool ready() const { return m_ready; }

    // `count` bar heights in px from the current peaks (flat `minH` bars while there are none)
    Q_INVOKABLE QList<qreal> heights(int count, qreal minH, qreal maxH, qreal step) const;

signals:
    void ctxChanged();
    void uriChanged();
    void peaksChanged();
    void readyChanged();

private:
    void restart();
    void stop();
    void poll();
    void setReady(bool ready);

    MainCtx* m_ctx = nullptr;
    QUrl m_uri;
    QList<float> m_peaks;
    bool m_ready = false;
    WaveformJob* m_job = nullptr;
    QTimer m_poll;
    QElapsedTimer m_clock;
};

#endif
```

- [x] **Step 4: Implementation** `modules/gui/qt/player/player_waveform.cpp`, with the GPL header.

  **Why it is shaped this way:**
  - The hidden player's parent object pins `aout`/`vout` to `dummy`, as the fingerprinter does.
  - Its sout chain transcodes to mono 8 kHz native float, and smem hands each block to our callbacks.
  - `no-time-sync` is how a chain bool is switched off: the `no-` prefix sets it false, and the value is ignored. It makes smem report "not synchronous", so the input runs as fast as possible.

```cpp
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "player_waveform.hpp"
#include "waveform_util.hpp"

#include <vlc_common.h>
#include <vlc_fourcc.h>
#include <vlc_input_item.h>
#include <vlc_player.h>

#include <algorithm>
#include <atomic>
#include <mutex>
#include <vector>

struct WaveformJob
{
    vlc_object_t* obj = nullptr;
    vlc_player_t* player = nullptr;
    vlc_player_listener_id* listener = nullptr;
    std::vector<float> pcm;                    // smem copies each block here (sout thread only)
    std::mutex lock;                           // guards buckets and firstPts
    QList<float> buckets = QList<float>(waveform::BUCKETS, 0.f);
    vlc_tick_t firstPts = VLC_TICK_INVALID;
    std::atomic<vlc_tick_t> length { 0 };
    std::atomic<bool> done { false };
    bool started = false;                      // player thread only
};

namespace
{
void onState(vlc_player_t*, enum vlc_player_state state, void* data)
{
    auto job = static_cast<WaveformJob*>(data);
    if (state == VLC_PLAYER_STATE_STARTED)
        job->started = true;
    else if (state == VLC_PLAYER_STATE_STOPPED && job->started)
        job->done = true;
}

void onLength(vlc_player_t*, vlc_tick_t length, void* data)
{
    static_cast<WaveformJob*>(data)->length = length;
}

void prerender(void* data, uint8_t** buffer, size_t size)
{
    auto job = static_cast<WaveformJob*>(data);
    job->pcm.resize(size / sizeof(float) + 1);
    *buffer = reinterpret_cast<uint8_t*>(job->pcm.data());
}

void postrender(void* data, uint8_t* buffer, unsigned channels, unsigned rate, unsigned samples,
                unsigned bits, size_t, vlc_tick_t pts)
{
    auto job = static_cast<WaveformJob*>(data);
    const vlc_tick_t length = job->length;
    if (channels != 1 || bits != 32 || length <= 0 || pts == VLC_TICK_INVALID)
        return;
    std::lock_guard<std::mutex> guard(job->lock);
    if (job->firstPts == VLC_TICK_INVALID)
        job->firstPts = pts;
    waveform::foldSamples(job->buckets, reinterpret_cast<const float*>(buffer), int(samples),
                          pts - job->firstPts, rate, length);   // vlc_tick_t is in µs
}

const vlc_player_cbs* playerCallbacks()
{
    static const vlc_player_cbs cbs = [] {
        vlc_player_cbs c {};
        c.on_state_changed = onState;
        c.on_length_changed = onLength;
        return c;
    }();
    return &cbs;
}
}

PlayerWaveform::PlayerWaveform(QObject* parent)
    : QObject(parent)
{
    m_poll.setInterval(100);
    connect(&m_poll, &QTimer::timeout, this, &PlayerWaveform::poll);
}

PlayerWaveform::~PlayerWaveform()
{
    stop();
}

void PlayerWaveform::setCtx(MainCtx* ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
    restart();
}

void PlayerWaveform::setUri(const QUrl& uri)
{
    if (m_uri == uri)
        return;
    m_uri = uri;
    emit uriChanged();
    restart();
}

void PlayerWaveform::setReady(bool ready)
{
    if (m_ready == ready)
        return;
    m_ready = ready;
    emit readyChanged();
}

QList<qreal> PlayerWaveform::heights(int count, qreal minH, qreal maxH, qreal step) const
{
    QList<qreal> out;
    out.reserve(std::max(count, 0));
    for (float p : waveform::resample(m_peaks, count))
        out.append(waveform::barHeight(p, minH, maxH, step));
    return out;
}

void PlayerWaveform::restart()
{
    stop();
    m_peaks.clear();
    emit peaksChanged();
    setReady(false);

    // ponytail: local files only, a stream would be downloaded a second time
    if (!m_ctx || !m_uri.isLocalFile())
        return;

    qt_intf_t* intf = m_ctx->getIntf();
    auto job = new WaveformJob;
    job->obj = static_cast<vlc_object_t*>(vlc_object_create(intf, sizeof(vlc_object_t)));
    if (job->obj)
    {
        var_Create(job->obj, "vout", VLC_VAR_STRING);
        var_SetString(job->obj, "vout", "dummy");
        var_Create(job->obj, "aout", VLC_VAR_STRING);
        var_SetString(job->obj, "aout", "dummy");
        job->player = vlc_player_New(job->obj, VLC_PLAYER_LOCK_NORMAL);
    }
    input_item_t* item = job->player
        ? input_item_New(qtu(m_uri.toString(QUrl::FullyEncoded)), nullptr) : nullptr;
    if (!item)
    {
        if (job->player)
            vlc_player_Delete(job->player);
        if (job->obj)
            vlc_object_delete(job->obj);
        delete job;
        msg_Err(intf, "waveform: failed to start");
        setReady(true);
        return;
    }

    const QString sout = QStringLiteral(
        "sout=#transcode{acodec=%1,channels=1,samplerate=8000}"
        ":smem{audio-prerender-callback=%2,audio-postrender-callback=%3,audio-data=%4,no-time-sync}")
        .arg(VLC_CODEC_FL32 == VLC_CODEC_F32L ? "f32l" : "f32b")
        .arg(qlonglong(reinterpret_cast<intptr_t>(&prerender)))
        .arg(qlonglong(reinterpret_cast<intptr_t>(&postrender)))
        .arg(qlonglong(reinterpret_cast<intptr_t>(job)));
    input_item_AddOption(item, qtu(sout), VLC_INPUT_OPTION_TRUSTED);
    input_item_AddOption(item, "no-sout-video", VLC_INPUT_OPTION_TRUSTED);
    input_item_AddOption(item, "no-sout-spu", VLC_INPUT_OPTION_TRUSTED);

    vlc_player_Lock(job->player);
    job->listener = vlc_player_AddListener(job->player, playerCallbacks(), job);
    int ret = job->listener ? vlc_player_SetCurrentMedia(job->player, item) : VLC_ENOMEM;
    if (ret == VLC_SUCCESS)
        ret = vlc_player_Start(job->player);
    vlc_player_Unlock(job->player);
    input_item_Release(item);

    m_job = job;
    if (ret != VLC_SUCCESS)
    {
        msg_Err(intf, "waveform: failed to start");
        stop();
        setReady(true);
        return;
    }
    m_clock.start();
    m_poll.start();
}

void PlayerWaveform::stop()
{
    m_poll.stop();
    if (!m_job)
        return;
    vlc_player_Lock(m_job->player);
    if (m_job->listener)
        vlc_player_RemoveListener(m_job->player, m_job->listener);
    vlc_player_Unlock(m_job->player);
    // ponytail: Delete joins the decode threads on the GUI thread (milliseconds for a local file);
    // hand it to a worker thread if a cancel ever shows up as a stall
    vlc_player_Delete(m_job->player);
    vlc_object_delete(m_job->obj);
    delete m_job;
    m_job = nullptr;
}

void PlayerWaveform::poll()
{
    if (!m_job)
        return;
    const bool done = m_job->done;   // read first, so a finished decode's last block is in the copy
    {
        std::lock_guard<std::mutex> guard(m_job->lock);
        m_peaks = m_job->buckets;
    }
    waveform::normalize(m_peaks);
    emit peaksChanged();
    if (done)
    {
        msg_Dbg(m_ctx->getIntf(), "waveform: %lld ms", static_cast<long long>(m_clock.elapsed()));
        stop();
        setReady(true);
    }
}
```

- [x] **Step 5: Build registration.**
  - **meson.build:** add `'player/player_waveform.hpp',` to `moc_headers` after `'player/player_effects.hpp',`. Add `'player/player_waveform.cpp', 'player/player_waveform.hpp',` to `qt_plugin_sources` after `'player/player_effects.hpp',`.
  - **Makefile.am:** add `player/player_waveform.cpp player/player_waveform.hpp \` to `libqt_plugin_la_SOURCES` after `player/player_effects.cpp player/player_effects.hpp \`. Add `player/player_waveform.moc.cpp \` to `nodist_libqt_plugin_la_SOURCES` after `player/player_effects.moc.cpp \`.
  - `ninja -C build 2>&1 | tail -3` must be clean, with no warnings in the new files. If `vlc_player_cbs` value-initialisation warns about missing field initialisers, keep the lambda form: C++17 has no designated initialisers.

- [x] **Step 6: Temporary probe.** Shows the decode works before any UI uses it.
  - Add this to the end of `ControlBar.qml`'s `contentItem` `ColumnLayout`, then build:

```qml
        Waveform {   // TEMP probe for Task 2, removed in Step 8
            ctx: MainCtx
            uri: Player.url
            onReadyChanged: if (ready) console.warn("WAVEFORM", peaks.length, Math.max(...peaks), peaks.slice(0, 70).filter(p => p > 0.02).length, peaks.slice(400).filter(p => p > 0.5).length)
        }
```

  - Run `cp /tmp/conf.bak build/redesign-profile/config/vlc/vlc-qt-interface.conf; $H start -vv build/redesign-music/waveform.mp3; sleep 4`, then `grep -E "waveform:|WAVEFORM" $L; $H stop; pgrep -x vlc-static`.
  - **Expected:**
    - `waveform: <N> ms` with N < 2000 (a 40 s file decoded far faster than real time).
    - `WAVEFORM 1024 1 0 <k>` with `k` > 100. The first 3 s of 40 s (buckets 0–76) are silence, so none of the first 70 passes 0.02. From 13 s (bucket 333) the loud 1 s bursts alternate with quiet ones, so about half of the buckets from 400 on are near 1.
    - `pgrep` prints nothing.
  - **If N is about 40000,** the input is pacing in real time, i.e. `no-time-sync` didn't take. Check the log for `set config option: sout-smem-time-sync`. Fix the chain option before going on.
  - **If `WAVEFORM` never prints,** grep the log for `smem` and `transcode` errors. A `Smem does only support raw audio format` error means the `acodec` did not resolve.

- [x] **Step 7: Review Focus 2 and 4 (cancel and no-decode).**
  - **Quit mid-decode:** `$H start -vv build/redesign-music/long.mp3; sleep 1; $H stop`. Then `pgrep -x vlc-static` must print nothing, and `coredumpctl list vlc-static 2>/dev/null | tail -1` must show no new entry from today. Also check `$L` for `waveform:`: there must be no `waveform: <N> ms` line, because the decode was cancelled.
  - **Network URI:** `$H start -vv http://127.0.0.1:9/none.mp3; sleep 4; grep -c "waveform:" $L; $H stop`. Expected: `0`. No decode is attempted (the playback itself fails, which is expected).
- [x] **Step 8:** Remove the probe from `ControlBar.qml` and rebuild. Run the log check on a fresh run. Commit `qt: decode a waveform of the playing audio file in the background` (C++, build files, `make-samples.sh`).

---

### Task 3: Icons, the 15 s skips and audio tracks

**Files:**
- Create: `modules/gui/qt/pixmaps/redesign/backward-15-sec.svg`, `forward-15-sec.svg`, `audio-tracks.svg`
- Modify: `modules/gui/qt/pixmaps/redesign/mapping.json`, `modules/gui/qt/pixmaps/VLCIcons.json`
- Regenerate: `modules/gui/qt/pixmaps/VLCIcons.ttf`, `modules/gui/qt/style/vlcicons.hpp` (and `vlcicons.cpp` if the generator touches it)

**Interfaces:** produces
- `VLCIcons.skip_back` and `VLCIcons.skip_for`, which now draw Figma's "15" arrows. Same keys, new SVGs.
- `VLCIcons.audio_tracks`, a new key appended last: Figma's audio-tracks (waveform) glyph.

- [x] **Step 1: Failing check.**
  - Edit `mapping.json`: change `"backward-10-sec.svg": ["skip_back"]` to `"backward-15-sec.svg": ["skip_back"]`, change `"forward-10-sec.svg": ["skip_for"]` to `"forward-15-sec.svg": ["skip_for"]`, and add `"audio-tracks.svg": ["audio_tracks"]`.
  - Run `python3 -I docs/superpowers/scripts/check-icon-font.py modules/gui/qt/pixmaps`. Expected: FAIL, because the SVGs are missing.
- [x] **Step 2: Export from Figma.**
  - Load the `figma:figma-use` skill, then run `use_figma` on file `dSoAm0gN9ZterHSssJU9FN`:

```js
const ids = {
  'backward-15-sec': '45:36',
  'forward-15-sec': '45:33',
  'audio-tracks': 'I4767:23748;4778:26442;177:88;44:408',
};
const out = {};
for (const [name, id] of Object.entries(ids)) {
  const n = await figma.getNodeByIdAsync(id);
  out[name] = n ? await n.exportAsync({ format: 'SVG_STRING', svgOutlineText: true }) : null;
}
return out;
```

  - Write each string to `modules/gui/qt/pixmaps/redesign/<name>.svg`.
  - `45:36` is the backward variant: its inner frame is mirrored, and the export bakes that in. Check it points left and its "15" reads normally, not mirrored.
  - If an id is null, get the node's parent: run `get_metadata` on `4778:26181` and look for the `Icon` instances in `Frame 12` (back), `Frame 11` (forward) and the first `Icon Wrapper` of `Frame 23` (audio tracks). Export those instance ids instead.
- [x] **Step 3: Clean and flatten.** The "15" must end up as filled outlines and the strokes must be expanded, or FontForge drops them:

```sh
python3 -I docs/superpowers/scripts/clean-figma-svg.py modules/gui/qt/pixmaps/redesign/{backward-15-sec,forward-15-sec,audio-tracks}.svg
python3 -I docs/superpowers/scripts/flatten-figma-svg.py modules/gui/qt/pixmaps/redesign/{backward-15-sec,forward-15-sec,audio-tracks}.svg
```

- [x] **Step 4: Point the keys and regenerate.**
  - In `VLCIcons.json`, change the two existing entries' paths: `skip_back` → `./redesign/backward-15-sec.svg`, `skip_for` → `./redesign/forward-15-sec.svg`.
  - Append `{"key":"audio_tracks", "path": "./redesign/audio-tracks.svg"}` after the `link` entry, which is the current last.
  - From `modules/gui/qt/pixmaps`, run `python3 makeIconFont.py VLCIcons.json`.
  - Leave the old `backward-10-sec.svg`/`forward-10-sec.svg` in place: they are unreferenced, and deleting them is churn.
- [x] **Step 5: Check.**
  - `check-icon-font.py` must print `icon font OK`.
  - `git diff modules/gui/qt/style/vlcicons.hpp` must show exactly one added key (`audio_tracks`) and no renumbered key.
  - Render the three glyphs: `python3 -I -c "import fontforge,json;m=json.load(open('modules/gui/qt/pixmaps/VLCIcons.json'));o=[g['key'] for g in m['glyphs']];f=fontforge.open('modules/gui/qt/pixmaps/VLCIcons.ttf');[f[0xE000+o.index(k)].export(f'$S/g_{k}.png',64) for k in ('skip_back','skip_for','audio_tracks')]"`. Compare them by eye with `docs/superpowers/figma/3d/controls_music.png`: the 2nd and 4th icons of the left group, and the first icon after the volume meter.
- [x] **Step 6:** `ninja -C build`, then commit `qt: use the redesign's 15 second skip icons and add the audio tracks icon`.

---

### Task 4: Music control bar

**Files:**
- Modify: `modules/gui/qt/dialogs/toolbar/controlbar_profile_model.cpp` (the `DEFAULT_STYLE` `Audioplayer` entry only)
- Modify: `modules/gui/qt/player/player_controller.hpp` / `.cpp` (new slot `jumpBySeconds`)
- Modify: `modules/gui/qt/player/qml/controlbarcontrols/SkipBackButton.qml`, `SkipForwardButton.qml`, `LangButton.qml`

**Interfaces:**
- Consumes: Task 3's `VLCIcons.skip_back`/`skip_for` (15 s glyphs) and `VLCIcons.audio_tracks`.
- Produces: `PlayerController::jumpBySeconds(int seconds)` (a public slot, callable from QML as `Player.jumpBySeconds(n)`).

- [x] **Step 1: Failing check.**
  - `cp /tmp/conf.bak …; $H start -vv build/redesign-music/waveform.mp3; sleep 6; $H shot $S/t4_before.png; $H stop`.
  - The left group shows only prev, play and next. The right group shows the subtitles glyph, as in `docs/superpowers/figma/3d/before_music.png`.
- [x] **Step 2: Default Audioplayer layout.** In `controlbar_profile_model.cpp`, edit the `Style::DEFAULT_STYLE` → `PlayerControlbarModel::Audioplayer` entry (the second entry of `DEFAULT_STYLE`) to read:

```cpp
                    {
                        PlayerControlbarModel::Audioplayer,
                        {
                            {
                                {
                                    ControlListModel::PREVIOUS_BUTTON,
                                    ControlListModel::SKIP_BACK_BUTTON,
                                    ControlListModel::PLAY_BUTTON,
                                    ControlListModel::SKIP_FW_BUTTON,
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
                    },
```

  Leave the `Videoplayer` and `Miniplayer` entries, and every other style, as they are.

- [x] **Step 3: `jumpBySeconds`.**
  - In `player_controller.hpp`, next to `void jumpTime( VLCTime i_time );` (the public slots), add `void jumpBySeconds( int seconds );`.
  - In `player_controller.cpp`, right after `PlayerController::jumpBwd()`:

```cpp
void PlayerController::jumpBySeconds( int seconds )
{
    Q_D(PlayerController);
    vlc_player_locker lock{ d->m_player };
    if( !d->isCurrentItemSynced() )
        return;
    vlc_player_JumpTime( d->m_player, vlc_tick_from_sec( seconds ) );
}
```

- [x] **Step 4: Skip buttons jump ±15 s, as their glyphs say.** `SkipBackButton.qml`: `onClicked: Player.jumpBySeconds(-15)` and `description: qsTr("Back 15 seconds")`. `SkipForwardButton.qml`: `onClicked: Player.jumpBySeconds(15)` and `description: qsTr("Forward 15 seconds")`. Keep `enabled: Player.seekable` and the accessibility ids. The keyboard shortcuts keep VLC's `short-jump-size`; they don't go through these buttons.
- [x] **Step 5: Audio-tracks glyph on the music bar.** In `LangButton.qml`, replace `text: VLCIcons.audiosub` with:

```qml
    // Figma Controls music 4778:26181: the music bar's tracks button shows the audio glyph
    text: Player.hasVideoOutput ? VLCIcons.audiosub : VLCIcons.audio_tracks
```

  `Player.hasVideoOutput` is the same condition `Player.qml` uses to choose the Audioplayer layout.
- [x] **Step 6: Check.**
  - Run with the same start as Step 1. In the shot, the left group is prev, back-15, play, forward-15, next, and the right group starts with the audio-tracks glyph.
  - Click forward-15: read its x from the shot (the 4th left icon, y ≈ 873) and run `$H click <x> 873`. The time label moves forward by 15 s (shot before and after, with playback paused: `$H key space` first).
  - Click back-15: the time moves back by 15 s.
  - The log check is empty.
- [x] **Step 7:** Commit `qml: music control bar with 15 second skips and the audio tracks button`.

---

### Task 5: Waveform seek bar

**Files:**
- Modify: `modules/gui/qt/player/qml/SliderBar.qml`
- Modify: `modules/gui/qt/player/qml/ControlBar.qml`
- Modify: `modules/gui/qt/player/qml/Player.qml` (one line: `musicMode` on the `ControlBar`)

**Interfaces:**
- Consumes: Task 2's `Waveform { ctx; uri; peaks; ready; heights(count, minH, maxH, step) }`.
- Produces:
  - `SliderBar.waveform` (bool) and `SliderBar.waveformSource` (a `Waveform` or null).
  - `ControlBar.musicMode` (bool).

- [x] **Step 1: Failing check.**
  - Shot the music player (as in Task 4). The seek bar is a solid `#371F06` fill.
  - `count-px.sh $S/t5_before.png 280 862 1000 22 404040 4` prints fewer than 200. There are no grey bars yet.
  - Read the seek bar's x-range from the shot first, and adjust `280`/`1000` to lie inside it.
- [x] **Step 2: `SliderBar.qml` properties.** Add them after `property real touchHandlerMargin: …`:

```qml
    // Figma Controls 4778:26181 / 2139:8124: the music bar seeks on the track's waveform.
    // Only the look changes; seeking, keys, the tooltip and chapter snapping work as before.
    property bool waveform: false
    property var waveformSource: null   // a VLC.Player Waveform, or null for flat bars
    readonly property real _wavePitch: VLCStyle.dp(5, VLCStyle.scale)
    readonly property real _waveBarWidth: VLCStyle.dp(2, VLCStyle.scale)
    readonly property int _waveBars: waveform ? Math.max(0, Math.floor((width - VLCStyle.dp(12, VLCStyle.scale) - _waveBarWidth) / _wavePitch) + 1)
                                              : 0
    readonly property var _waveHeights: {
        if (_waveBars <= 0)
            return []
        const minH = VLCStyle.dp(2, VLCStyle.scale)
        const src = waveformSource
        void (src?.peaks)   // re-evaluate when the peaks change
        return src ? src.heights(_waveBars, minH, VLCStyle.dp(14, VLCStyle.scale), VLCStyle.dp(2, VLCStyle.scale))
                   : Array(_waveBars).fill(minH)
    }

    function _paintWave(ctx, w, h, color) {
        ctx.reset()
        ctx.fillStyle = color
        const hs = _waveHeights
        const n = hs.length
        const x0 = (w - ((n - 1) * _wavePitch + _waveBarWidth)) / 2
        for (let i = 0; i < n; ++i) {
            ctx.beginPath()
            ctx.roundedRect(x0 + i * _wavePitch, (h - hs[i]) / 2, _waveBarWidth, hs[i], _waveBarWidth / 2, _waveBarWidth / 2)
            ctx.fill()
        }
    }

    on_WaveHeightsChanged: {
        waveUnplayed.requestPaint()
        wavePlayed.requestPaint()
    }
```

- [x] **Step 3: `SliderBar.qml` visuals.** These changes are in `background: Item { … }` and the handle.
  - `sliderRect`: `visible: !Player.hasChapters || control.waveform`. It stays the `#090909` track, radius 6 in block style.
  - `seekpointsRptr`: `visible: Player.hasChapters && !control.waveform`. Chapter segments are not drawn on a waveform; chapter names in the tooltip and click-snapping still work.
  - `progressRect`: `visible: !Player.hasChapters && !control.waveform`.
  - `bufferRect`: replace `opacity: 0.4` with `opacity: control.waveform ? 0 : 0.4`.
  - After `progressRect`, add the two bar layers:

```qml
        Canvas {
            id: waveUnplayed
            anchors.fill: parent
            visible: control.waveform
            onPaint: control._paintWave(getContext("2d"), width, height,
                                        theme.palette.isDark ? "#404040" : theme.fg.secondary)
            onWidthChanged: requestPaint()
        }

        Item {
            // the played bars: the same drawing in the accent shade, clipped at the progress point
            width: control.visualPosition * parent.width
            height: parent.height
            clip: true
            visible: control.waveform

            Canvas {
                id: wavePlayed
                width: waveUnplayed.width
                height: waveUnplayed.height
                onPaint: control._paintWave(getContext("2d"), width, height,
                                            theme.palette.isDark ? "#AB6314" : theme.accent)
                onWidthChanged: requestPaint()
            }
        }
```

  - **`sliderHandle`:** in the waveform look the handle is Figma's 4×24 `#D37918` bar. Change `implicitWidth` to:

```qml
        implicitWidth: control.waveform ? VLCStyle.dp(4, VLCStyle.scale)
                     : control.blockStyle ? VLCStyle.dp(8, VLCStyle.scale) : sliderHandle._size
```

    The height (`barHeight − 4` = 24), radius 4 and accent colour already come from `blockStyle`, which the music bar has.

- [x] **Step 4: Wiring.**
  - **`ControlBar.qml`:** add `property bool musicMode: false` next to `property bool compactStyle: false`.
  - In the `SliderBar { id: trackPositionSlider … }` declaration, add:

```qml
                waveform: root.musicMode && root._compact
                waveformSource: waveformLoader.item

                Loader {
                    id: waveformLoader
                    // no decode for videos, even during the moment before their video output appears
                    active: trackPositionSlider.waveform && Player.videoTracks.count === 0
                    sourceComponent: Waveform {
                        ctx: MainCtx
                        uri: Player.url
                    }
                }
```

  - **`Player.qml`:** in `ControlBar { id: controlBar … }`, next to the `identifier:` binding, add `musicMode: !Player.hasVideoOutput`.

- [x] **Step 5: Check the look** (Review Focus 5).
  - `$H start -vv build/redesign-music/waveform.mp3; sleep 6`, then `$H key space` (pause) and shoot `$S/t5_wave.png`.
  - **Expected:**
    - Grey bars across the track: `count-px.sh` on the track box (as in Step 1) for `404040` prints > 1000.
    - The first ~7 % of the track (3 s of 40) shows only flat 2 px bars.
    - The bursts from 13 s on alternate tall and flat.
    - The played part left of the playhead is orange (`AB6314` count > 50 after a few seconds of playback).
  - Put the shot next to `docs/superpowers/figma/3d/controls_music.png` and compare bar pitch, bar width, colours and playhead size.
  - **Resize:** `xdotool search --class vlc | while read w; do xdotool windowsize $w 1000 700; done; sleep 2`, then shoot. The bars keep their 5 px pitch: crop the track and count the bars per 100 px, which must be 20 ± 1. They still fill the track.
- [x] **Step 6: Check behaviour** (Review Focus 1, 3 and 4).
  - **Seek:** click at 50 % of the track. The time label jumps to about 00:20, and the orange part reaches the click.
  - **Fast skips:** `$H start -vv build/redesign-music/waveform.mp3 build/redesign-music/long.mp3 build/redesign-music/untangle.mp3 build/redesign-music/waveform.mp3; sleep 5`, then `$H key n n n; sleep 3`, then shoot.
    - VLC is alive (`pgrep -x vlc-static`).
    - The bars are the `waveform.mp3` shape (flat start, bursts).
    - `grep -c "waveform: .* ms" $L` is at most 2 (the first file, and the last one); the cancelled ones log nothing.
  - **Video after a song:** start with `build/redesign-music/waveform.mp3 build/redesign-media/plain.mp4`, `sleep 5`, `$H key n`, `sleep 4`, then shoot. The video bar has the plain seek bar (no grey bars), and the log has no `waveform:` line after the switch.
  - **Flat bars:** start `build/redesign-music/untangle.mp3`, a pure sine. The bars are all the same height, either all max or all flat: a steady sine normalises to 1 everywhere. The bar is clickable.
  - The log check is empty. After `$H stop`, `pgrep -x vlc-static` prints nothing.
- [x] **Step 7:** Commit `qml: music player seek bar drawn as the track's waveform`.

---

### Task 6: Music view

**Files:**
- Modify: `modules/gui/qt/player/qml/Player.qml` (the `audioComponent` only, plus one navigation line)

**Interfaces:** consumes `Player.artwork`, `Player.title`, `Player.artist`, `Widgets.ImageExt` (`radius`, `fillMode`, `textureProviderItem`, `status`) and `Widgets.RoundedRectangleShadow`.

- [x] **Step 1: Failing check.** Shoot the music player paused. The cover is a square with no rounding, under it is "Tester", and there is a 4-button row; compare `before_music.png`. Note the cover's corner pixel: `magick $S/t6_before.png -crop 1x1+<cover x>+<cover y> txt:` is the cover colour, not the background.
- [x] **Step 2: Remove the lyrics state.** In `audioFocusScope`, delete the `lyricsMode` and `lyricsLayoutActive` properties and the `onLyricsModeChanged` handler (the block from `// Whether the full lyrics view is active` to the end of `onLyricsModeChanged`).
- [x] **Step 3: Replace the centre content.** Inside `MouseArea { id: centerContent … }`, delete everything from the line `// ── Two-panel lyrics layout ────────────────────────` down to the closing `}` of the `ColumnLayout` that holds `coverItem`, `albumLabel`, `artistLabel`, `lyricsLabel`, `audioControls` and `syncToPlaybackCheckBox`. Keep `Widgets.SubtitleLabel { id: labelVolume … }` after it. Put this in its place:

```qml
                    // Figma Player - Music 4767:23726: the cover, then "title - artist", spaced
                    // evenly between the title bar and the control bar (73 px gaps at 1080p)
                    Item {
                        id: musicView

                        anchors.fill: parent

                        readonly property real gap: Math.round(height * 0.074)
                        readonly property real coverSide: Math.max(0, Math.min(height - titleLabel.height - gap * 3,
                                                                                width - gap * 2))
                        readonly property real top: (height - (coverSide + gap + titleLabel.height)) / 2
                        readonly property bool hasArt: Player.artwork.toString().length > 0
                                                       && cover.status !== Image.Error

                        Widgets.ImageExt {
                            id: cover

                            // source aspect ratio, for the blurred background
                            readonly property real sar: (implicitHeight > 0) ? implicitWidth / implicitHeight : 1
                            readonly property real eDPR: MainCtx.effectiveDevicePixelRatio(Window.window)
                            readonly property int maximumSize: Math.min(Helpers.alignUp(Screen.desktopAvailableWidth * eDPR / 2, 32),
                                                                        Helpers.alignUp(Screen.desktopAvailableHeight * eDPR / 2, 32))

                            x: (parent.width - width) / 2
                            y: musicView.top
                            width: musicView.coverSide
                            height: musicView.coverSide

                            visible: musicView.hasArt
                            source: Player.artwork.toString().length > 0 ? VLCAccessImage.uri(Player.artwork) : ""
                            sourceSize: Qt.size(maximumSize, maximumSize)
                            fillMode: Image.PreserveAspectCrop
                            radius: VLCStyle.dp(20, VLCStyle.scale)
                            cache: false

                            onSourceChanged: liveTimer.transientTurnOnLive()

                            Accessible.role: Accessible.Graphic
                            Accessible.name: qsTr("Cover")

                            // Figma: 0 0 90.5px 64px rgba(255,255,255,0.03)
                            Widgets.RoundedRectangleShadow {
                                color: Qt.rgba(1, 1, 1, 0.03)
                                blurRadius: VLCStyle.dp(90, VLCStyle.scale)
                                implicitWidth: parent.width + VLCStyle.dp(128, VLCStyle.scale) + blurRadius * compensationFactor * 2
                                implicitHeight: parent.height + VLCStyle.dp(128, VLCStyle.scale) + blurRadius * compensationFactor * 2
                            }
                        }

                        Rectangle {
                            // no artwork: a dark tile instead of the light placeholder
                            x: cover.x
                            y: cover.y
                            width: cover.width
                            height: cover.height
                            visible: !musicView.hasArt
                            radius: cover.radius
                            color: centerTheme.palette.isDark ? "#191919" : centerTheme.bg.secondary

                            Widgets.IconLabel {
                                anchors.centerIn: parent
                                text: VLCIcons.topbar_music
                                font.pixelSize: VLCStyle.dp(96, VLCStyle.scale)
                                color: centerTheme.palette.isDark ? "#404040" : centerTheme.fg.secondary
                            }
                        }

                        T.Label {
                            id: titleLabel

                            x: (parent.width - width) / 2
                            y: cover.y + cover.height + musicView.gap
                            width: Math.min(implicitWidth, Math.max(musicView.coverSide, VLCStyle.dp(200, VLCStyle.scale)))

                            text: Player.artist ? qsTr("%1 - %2").arg(Player.title).arg(Player.artist) : Player.title
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
                            font.weight: Font.Medium
                            color: centerTheme.palette.isDark ? "#969696" : centerTheme.fg.secondary

                            Accessible.role: Accessible.StaticText
                            Accessible.name: text
                        }
                    }
```

- [x] **Step 4: Point the blur at the new cover.**
  - In `blurredBackground`, set `TextureProviderIndirection { … source: cover.textureProviderItem }`. It was `cover`.
  - Add `visible: musicView.hasArt` to `blurredBackground`. Insert, as the first child of `audioFocusScope` (before `blurredBackground`), the no-art background:

```qml
                Rectangle {
                    // Figma frame background, seen when there is no artwork to blur
                    anchors.fill: parent
                    color: bgtheme.palette.isDark ? "#1B1B1B" : bgtheme.bg.primary
                }
```

  - `cover.sar` keeps working: Step 3 defines `sar` on the `ImageExt`.
  - In the old `Image`'s `Component.onCompleted` there was the hookup `blurredBackground.sourceTextureProviderObserver.hasMipmapsChanged.connect(…)`. Move that block into `cover`'s (`ImageExt`) `Component.onCompleted`, unchanged.
- [x] **Step 5: Navigation.**
  - The audio view has no focusable items any more. In `ControlBar { id: controlBar }`'s `Navigation.upItem`, delete the two lines `if (!MainCtx.hasEmbededVideo)` / `return playerSpecializationLoader`, so it falls through to `topBar`.
  - Grep the file for `audioControls`, `syncToPlaybackCheckBox`, `lyricsLoader`, `leftSideParent`, `albumLabel`, `artistLabel` and `lyricsLabel`. There must be no matches.
- [x] **Step 6: Check.**
  - Shoot `waveform.mp3`, paused. Compare with `docs/superpowers/figma/3d/player_music.png`:
    - The cover is square, rounded and centred. A corner pixel shows the background, not the cover.
    - The title reads `waveform - Tester` in grey, centred under the cover.
    - The gaps above the cover, between cover and title, and below the title are equal within ±4 px.
    - There's no button row.
  - Shoot `untangle.mp3`, which has no artwork: a dark tile with a grey music glyph on a plain `#1B1B1B` background.
  - Resize to 1000×700 (as in Task 5): the cover shrinks and the gaps stay equal.
  - Keyboard: with focus on the control bar, `$H key Up` reaches the top bar (shot shows its focus ring), and `$H key Down` comes back.
  - The log check is empty.
- [x] **Step 7:** Commit `qml: music player view after the redesign (cover, title line)`.

---

### Task 7: Final pass, roadmap, handoff

**Files:**
- Modify: `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md` (row 3d)
- Create: `docs/superpowers/figma/3d/after_music.png` (final Xvfb shot)

- [x] **Step 1: Full test pass.** `ninja -C build && meson test -C build --suite qt`: 11/11 OK. `python3 -I docs/superpowers/scripts/check-icon-font.py modules/gui/qt/pixmaps`: `icon font OK`.
- [x] **Step 2: Xvfb pass.** In one session, with `waveform.mp3`:
  - Shoot it playing and paused.
  - Seek by click, ±15 s, open the audio-tracks panel, then open the queue.
  - Save the paused shot as `docs/superpowers/figma/3d/after_music.png`.
  - In a ledger at the end of this plan (a `## Ledger` section), record every visible difference from `player_music.png` and `controls_music.png` as fixed, or as accepted with the reason. For example: the title bar shows "Tester - waveform" while Figma shows the title only (out of scope, slice 2's title rule).
- [x] **Step 3: Wayland pass.** Run `dbus-run-session -- docs/superpowers/scripts/wl-drive.py $S/wl vlc:--aout=dummy,build/redesign-music/waveform.mp3 max sleep:6 shot:music key:space sleep:1 shot:paused`.
  - `$S/wl/music.png` shows the cover, the title and the waveform bars.
  - `grep -E "TypeError|ReferenceError|waveform: failed" $S/wl/vlc.log` is empty.
- [x] **Step 4: Silence and leftovers.** `pgrep -x vlc-static` prints nothing. `grep -c "aout" $L` shows only the `dummy` aout lines, and nothing from the hidden player: `grep "waveform" $L` has no `aout` neighbour lines.
- [x] **Step 5: Roadmap.** Change the 3d row's first cell to `3d Music player (done)`. Change its Notes cell to `Plan 2026-10-16-vlc-redesign-music-player; waveform via hidden-player decode (transcode→smem), music only; lyrics/visualisation row dropped (pure Figma).`
- [x] **Step 6:** Commit `doc: finish the music player slice` (roadmap, after shot, plan ledger).
- [ ] **Step 7:** Write the session handoff with the `handoff-doc:handoff` skill. Merging `redesign/music-player` into `master` is the user's call.

## Ledger

Compared `docs/superpowers/figma/3d/after_music.png` (Xvfb 1600x900, `waveform.mp3`, paused; Wayland gives the same view) with `player_music.png` and `controls_music.png`.

**Scale note:** every Figma reference is a 1920-wide frame rendered at 1600 wide (x0.833), while our window is 1600x900 at VLCStyle scale 1. Fixed-size elements (title text, bars, buttons, icons) therefore look about 1.2x larger in our shot than in the reference even when their values equal the Figma node; layout-proportional elements (cover, gaps) do not. Size differences below are read with this in mind.

- **Cover:** rounded square, radius 20, faint glow, centred: matches. The side is 594 px against Figma's 614 px because the chrome around it is taller (see the bar heights below); the cover fills the same share of the space between the bars. Accepted.
- **Title line:** one "title - artist" line, centred under the cover, Inter Medium 24, #969696: these values are the Figma node's (4778:24351). It looks ~20 % larger than in `player_music.png` only because of the reference's 1920 to 1600 render scale (see the scale note), not a size error. Its glyph-to-glyph gaps look ~7 px wider than the box gaps because of font insets while the layout gaps are equal. Accepted.
- **No-art tile:** #191919 with a music glyph (Figma only shows a cover). Fixed in this slice (added so a track without art is not a hole).
- **Background blur:** Figma 10 px on dark art; ours keeps VLC's stronger blur plus a 50 % black tint so bright covers stay readable. Accepted (spec decision).
- **Seek bar:** 2 px bars on a 5 px pitch, 2-14 px tall, #404040 unplayed, #AB6314 played, 4x24 #D37918 playhead, on the rounded dark track: matches. Figma's waveform is denser and more irregular because its sample is real music; ours is a test tone with sparse peaks. Accepted.
- **Control order:** prev, back-15, play, forward-15, next | time, seek bar, duration | volume, audio tracks, settings, queue: matches. Skips jump exactly 15 s (checked paused: 00:20, +15 gives 00:35, -15 gives 00:20).
- **Time labels:** Figma shows `00:02:10` / `00:25:40` (a long track); ours shows `00:13` / `00:40` for a 40 s file. VLC drops the hours field for short tracks. Accepted.
- **Play button:** Figma shows the orange play button; ours is orange while paused and a grey pause button while playing (Figma has no playing frame for music). Accepted.
- **Volume slider:** the Figma frame shows a filled volume slider; the dummy-audio test profile shows it empty with the 100 % tick. The slider itself is slice 2's and this slice did not touch it. Accepted.
- **Window title bar:** shows "Tester - waveform" while Figma shows just the title; the bar also carries the queue and fullscreen buttons and no sidebar toggle. Slice 2's title and top-bar rules, out of scope. Accepted.
- **Bar heights:** title bar 40 px and control bar 54 px against 33 px and 45 px in the reference: in the 1920 frame they are 40 px and 54 px (33 and 45 at x0.833), the same values ours has at scale 1. They come from slice 2's chrome sizing, which this slice only fills between. The cover is smaller than the reference (594 vs 614 px) as a consequence. Accepted.
- **Audio-tracks panel:** the button opens the 3a tracks panel, which always starts on its Subtitles tab (`currentTab: 2`), not on Audio. Not changed here (slice 3a behaviour); worth a follow-up so the music bar's button opens on Audio.
- **Queue card:** opens from the queue button and matches slice 3b. After opening it with the mouse, the first Escape did nothing and the second closed it (the tracks panel closes on the first Escape). Seen under Xvfb only; not checked in the video player, so it may be slice 3b behaviour.
- **Prev / next:** dimmed in ours, bright in Figma. The test queue holds one item, so both are correctly disabled; Figma shows them enabled. Accepted (test data, correct disabled state).
- **Settings button:** `player_music.png`'s bar has no gear, `controls_music.png` does. Ours follows `controls_music.png` (gear present).
- **Background brightness:** on the bright colour-bar test art ours is much brighter and more saturated than Figma's near-black background. Accepted (spec decision: VLC's blur plus 50 % black tint; Figma's sample art is itself dark).
