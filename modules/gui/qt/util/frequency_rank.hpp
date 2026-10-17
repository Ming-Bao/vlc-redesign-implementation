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
#ifndef VLC_QT_FREQUENCY_RANK_HPP
#define VLC_QT_FREQUENCY_RANK_HPP

#include <algorithm>
#include <unordered_map>
#include <vector>

// Distinct keys, most frequent first. Ties keep the key seen earliest in the
// input (the most recent one). Keys equal to `skip` are dropped.
template <typename T>
std::vector<T> rankByFrequency(const std::vector<T>& keysMostRecentFirst, const T& skip = T{})
{
    std::unordered_map<T, size_t> counts;
    std::vector<T> res;
    for (const T& key : keysMostRecentFirst)
    {
        if (key == skip)
            continue;
        if (counts[key]++ == 0)
            res.push_back(key);
    }
    std::stable_sort(res.begin(), res.end(),
                     [&counts](const T& a, const T& b) { return counts[a] > counts[b]; });
    return res;
}

#endif // VLC_QT_FREQUENCY_RANK_HPP
