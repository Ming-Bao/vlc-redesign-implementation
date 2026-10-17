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
#include "mlfrequentartistmodel.hpp"
#include "mlhelper.hpp"
#include "util/frequency_rank.hpp"

// Ctor / dtor

MLFrequentArtistModel::MLFrequentArtistModel(QObject * parent) : MLArtistModel(parent) {}

// Protected MLBaseModel implementation

std::unique_ptr<MLListCacheLoader>
MLFrequentArtistModel::createMLLoader() const
/* override */
{
    return std::make_unique<MLListCacheLoader>(m_mediaLib, std::make_shared<MLFrequentArtistModel::Loader>(*this));
}

// Protected MLArtistModel reimplementation

void MLFrequentArtistModel::onVlcMlEvent(const MLEvent & event) /* override */
{
    switch (event.i_type)
    {
        case VLC_ML_EVENT_HISTORY_CHANGED:
            emit resetRequested();
            return;
        default:
            break;
    }

    MLArtistModel::onVlcMlEvent(event);
}

// Loader

std::vector<std::unique_ptr<MLArtist>>
MLFrequentArtistModel::Loader::rankedArtists(vlc_medialibrary_t* ml, const char* pattern) const
{
    vlc_ml_query_params_t params = vlc_ml_query_params_create();
    params.i_nbResults = 100;
    ml_unique_ptr<vlc_ml_media_list_t> history {
        vlc_ml_list_audio_history(ml, &params)
    };

    if (history == nullptr)
        return {};

    std::vector<int64_t> artistIds;
    for (const vlc_ml_media_t & media : ml_range_iterate<vlc_ml_media_t>(history))
        artistIds.push_back(media.album_track.i_artist_id);

    const QString needle = QString::fromUtf8(pattern ? pattern : "");

    std::vector<std::unique_ptr<MLArtist>> res;
    for (int64_t id : rankByFrequency<int64_t>(artistIds, 0))
    {
        ml_unique_ptr<vlc_ml_artist_t> artist(vlc_ml_get_artist(ml, id));
        if (!artist)
            continue;
        auto item = std::make_unique<MLArtist>(artist.get());
        if (item->getName().contains(needle, Qt::CaseInsensitive))
            res.push_back(std::move(item));
    }
    return res;
}

size_t MLFrequentArtistModel::Loader::count(vlc_medialibrary_t* ml, const vlc_ml_query_params_t* queryParams) const /* override */
{
    return rankedArtists(ml, queryParams->psz_pattern).size();
}

std::vector<std::unique_ptr<MLItem>>
MLFrequentArtistModel::Loader::load(vlc_medialibrary_t* ml, const vlc_ml_query_params_t* queryParams) const /* override */
{
    auto ranked = rankedArtists(ml, queryParams->psz_pattern);

    // a limit of 0 means no limit
    const size_t offset = std::min<size_t>(queryParams->i_offset, ranked.size());
    const size_t end = queryParams->i_nbResults
        ? std::min<size_t>(offset + queryParams->i_nbResults, ranked.size())
        : ranked.size();

    std::vector<std::unique_ptr<MLItem>> res;
    for (size_t i = offset; i < end; ++i)
        res.push_back(std::move(ranked[i]));
    return res;
}

std::unique_ptr<MLItem>
MLFrequentArtistModel::Loader::loadItemById(vlc_medialibrary_t* ml, MLItemId itemId) const /* override */
{
    assert(itemId.type == VLC_ML_PARENT_ARTIST);
    ml_unique_ptr<vlc_ml_artist_t> artist(vlc_ml_get_artist(ml, itemId.id));
    if (!artist)
        return nullptr;
    return std::make_unique<MLArtist>(artist.get());
}
