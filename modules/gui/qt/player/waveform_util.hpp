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
