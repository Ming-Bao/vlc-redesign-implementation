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
    // several (flip, rotation) pairs give the same transform: prefer the smallest rotation, then no flip
    std::pair<int, int> best{ 0, 0 };
    bool found = false;
    for (int i = 0; i < int(kTransforms.size()); ++i)
        if (type == QLatin1String(kTransforms[i]))
        {
            const std::pair<int, int> cand{ i / 4, (i % 4) * 90 };
            if (!found || cand.second < best.second) { best = cand; found = true; }
        }
    return best;
}

}
