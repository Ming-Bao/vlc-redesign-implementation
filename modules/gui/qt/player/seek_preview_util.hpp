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
#ifndef VLC_QT_SEEK_PREVIEW_UTIL_HPP
#define VLC_QT_SEEK_PREVIEW_UTIL_HPP

#include <QImage>
#include <QSize>
#include <QString>
#include <optional>

// pure helpers for the seek bar hover preview
namespace seekpreview
{
// false for optical-disc schemes, where decoding a frame would spin up the drive
bool previewableScheme(const QString& scheme);
// clamp to [0, 0.999] (NaN gives 0): position 1.0 would seek past the last frame
double clampPosition(double p);
// largest size with the aspect of `src` that fits `box`, at least 1 px per axis; `box` if `src` is invalid
QSize fitInto(QSize src, QSize box);
// `img` as displayed for a VLC orientation (ORIENT_* in vlc_es.h, 0..7); 4..7 swap width and height
QImage oriented(const QImage& img, int orientation);

// coalesces requests while one is in flight: only the newest pending one is kept
class LatestOnly
{
public:
    // true: nothing was in flight, start `p` now; false: stored as pending
    bool request(double p);
    // the in-flight one is done; returns the pending value (now in flight), if any
    std::optional<double> finished();
    void reset();
private:
    bool m_busy = false;
    std::optional<double> m_pending;
};
}

#endif
