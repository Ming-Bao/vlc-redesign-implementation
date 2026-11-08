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
#include "seek_preview_util.hpp"

#include <QStringList>
#include <QTransform>
#include <algorithm>
#include <cmath>

namespace seekpreview
{
bool previewableScheme(const QString& scheme)
{
    static const QStringList disc{ "dvd", "dvdsimple", "bluray", "vcd", "cdda" };
    return !disc.contains(scheme, Qt::CaseInsensitive);
}

double clampPosition(double p)
{
    return std::isnan(p) ? 0.0 : std::clamp(p, 0.0, 0.999);
}

QSize fitInto(QSize src, QSize box)
{
    if (!src.isValid() || src.isEmpty())
        return box;
    const double s = std::min(double(box.width()) / src.width(), double(box.height()) / src.height());
    return { std::max(1, qRound(src.width() * s)), std::max(1, qRound(src.height() * s)) };
}

QImage oriented(const QImage& img, int orientation)
{
    // QTransform only (QImage::mirrored is deprecated in 6.9, flipped is 6.9+)
    const QTransform hflip = QTransform::fromScale(-1, 1);
    const QTransform vflip = QTransform::fromScale(1, -1);
    const QTransform r90 = QTransform().rotate(90);
    switch (orientation)
    {
    case 1: return img.transformed(hflip);
    case 2: return img.transformed(vflip);
    case 3: return img.transformed(QTransform().rotate(180));
    case 4: return img.transformed(r90).transformed(hflip);   // transposed
    case 5: return img.transformed(QTransform().rotate(270));
    case 6: return img.transformed(r90);
    case 7: return img.transformed(r90).transformed(vflip);   // anti-transposed
    default: return img;
    }
}

bool LatestOnly::request(double p)
{
    if (m_busy)
    {
        m_pending = p;
        return false;
    }
    m_busy = true;
    return true;
}

std::optional<double> LatestOnly::finished()
{
    std::optional<double> next;
    next.swap(m_pending);
    m_busy = next.has_value();
    return next;
}

void LatestOnly::reset()
{
    m_busy = false;
    m_pending.reset();
}
}
