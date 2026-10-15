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
