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
