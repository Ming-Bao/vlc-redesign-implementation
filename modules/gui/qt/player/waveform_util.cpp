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
