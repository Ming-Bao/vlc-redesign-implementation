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
#include "mlfolderbrowsemodel.hpp"
#include "mlhelper.hpp"
#include "util/folder_tree.hpp"

namespace {

// A child folder of the level, it lives only in the cache
class MLFolderRow : public MLItem
{
public:
    MLFolderRow(const folder_tree::Child & child, size_t index)
        // ponytail: synthetic ids, so a folder row is never updated in place, only by reset.
        : MLItem(MLItemId(-int64_t(index + 1), VLC_ML_PARENT_FOLDER))
        , m_name(child.name)
        , m_mrl(child.mrl)
    {}

    QString name() const { return m_name; }
    QString mrl() const { return m_mrl; }

private:
    QString m_name;
    QString m_mrl;
};

}

// Ctor

MLFolderBrowseModel::MLFolderBrowseModel(QObject * parent) : MLMediaModel(parent) {}

// Properties

void MLFolderBrowseModel::setAudio(bool audio)
{
    if (m_audio == audio)
        return;

    m_audio = audio;
    resetCache();
    m_itemLoader.reset();
    emit audioChanged();
}

void MLFolderBrowseModel::setFolderMrl(const QString & folderMrl)
{
    if (m_folderMrl == folderMrl)
        return;

    m_folderMrl = folderMrl;
    resetCache();
    m_itemLoader.reset();
    emit folderMrlChanged();
}

// Protected MLBaseModel implementation

std::unique_ptr<MLListCacheLoader>
MLFolderBrowseModel::createMLLoader() const /* override */
{
    return std::make_unique<MLListCacheLoader>(m_mediaLib, std::make_shared<MLFolderBrowseModel::Loader>(*this));
}

// Protected MLMediaModel reimplementation

vlc_ml_sorting_criteria_t MLFolderBrowseModel::nameToCriteria(QByteArray name) const /* override */
{
    // the tracks' criteria (MLAudioModel), a superset of the media ones: only Songs offers the extra ones
    return QHash<QByteArray, vlc_ml_sorting_criteria_t> {
        {QByteArrayLiteral("title"), VLC_ML_SORTING_ALPHA},
        {QByteArrayLiteral("album_title"), VLC_ML_SORTING_ALBUM},
        {QByteArrayLiteral("track_number"), VLC_ML_SORTING_TRACKNUMBER},
        {QByteArrayLiteral("release_year"), VLC_ML_SORTING_RELEASEDATE},
        {QByteArrayLiteral("main_artist"), VLC_ML_SORTING_ARTIST},
        {QByteArrayLiteral("duration"), VLC_ML_SORTING_DURATION},
        {QByteArrayLiteral("insertion"), VLC_ML_SORTING_INSERTIONDATE},
    }.value(name, VLC_ML_SORTING_DEFAULT);
}

QHash<int, QByteArray> MLFolderBrowseModel::roleNames() const /* override */
{
    QHash<int, QByteArray> hash = MLMediaModel::roleNames();

    hash.insert({
        {FOLDER_IS_FOLDER, QByteArrayLiteral("isFolder")},
    });

    return hash;
}

QVariant MLFolderBrowseModel::itemRoleData(const MLItem * item, int role) const /* override */
{
    if (item == nullptr)
        return {};

    if (const auto folder = dynamic_cast<const MLFolderRow *>(item))
    {
        switch (role)
        {
            case FOLDER_IS_FOLDER:
                return true;
            case MEDIA_TITLE:
                return folder->name();
            case MEDIA_MRL:
                return folder->mrl();
            default:
                return {};
        }
    }

    switch (role)
    {
        case FOLDER_IS_FOLDER:
            return false;
        default:
            return MLMediaModel::itemRoleData(item, role);
    }
}

void MLFolderBrowseModel::onVlcMlEvent(const MLEvent & event) /* override */
{
    switch (event.i_type)
    {
        case VLC_ML_EVENT_FOLDER_ADDED:
        case VLC_ML_EVENT_FOLDER_DELETED:
        case VLC_ML_EVENT_FOLDER_UPDATED:
        case VLC_ML_EVENT_ENTRY_POINT_ADDED:
        case VLC_ML_EVENT_ENTRY_POINT_REMOVED:
        case VLC_ML_EVENT_ENTRY_POINT_BANNED:
        case VLC_ML_EVENT_ENTRY_POINT_UNBANNED:
        case VLC_ML_EVENT_MEDIA_DELETED:
            emit resetRequested();
            return;
        case VLC_ML_EVENT_MEDIA_ADDED:
            if (event.creation.media.i_type == (m_audio ? VLC_ML_MEDIA_TYPE_AUDIO : VLC_ML_MEDIA_TYPE_VIDEO))
                emit resetRequested();
            return;
        default:
            break;
    }

    MLMediaModel::onVlcMlEvent(event);
}

// Loader

// The folders of the level and the id of the folder the files are listed from
struct MLFolderBrowseModel::Loader::Level
{
    std::vector<folder_tree::Child> folders;
    int64_t folderId = 0;
};

MLFolderBrowseModel::Loader::Loader(const MLFolderBrowseModel & model)
    : MLOp(model)
    , m_audio(model.m_audio)
    , m_folderMrl(model.m_folderMrl)
{}

MLFolderBrowseModel::Loader::Level
MLFolderBrowseModel::Loader::level(vlc_medialibrary_t* ml) const
{
    QStringList roots;
    ml_unique_ptr<vlc_ml_folder_list_t> entryPoints(vlc_ml_list_entry_points(ml, nullptr));
    if (entryPoints)
        for (const vlc_ml_folder_t & folder : ml_range_iterate<vlc_ml_folder_t>(entryPoints))
            roots << qfu(folder.psz_mrl);

    QStringList mrls;
    QList<int64_t> ids;
    ml_unique_ptr<vlc_ml_folder_list_t> mediaFolders(vlc_ml_list_folders_by_type(
        ml, nullptr, m_audio ? VLC_ML_MEDIA_TYPE_AUDIO : VLC_ML_MEDIA_TYPE_VIDEO));
    if (mediaFolders)
        for (const vlc_ml_folder_t & folder : ml_range_iterate<vlc_ml_folder_t>(mediaFolders))
        {
            mrls << qfu(folder.psz_mrl);
            ids << folder.i_id;
        }

    Level res;
    res.folders = folder_tree::children(roots, mrls, m_folderMrl);

    const QString wanted = folder_tree::normalized(m_folderMrl);
    for (qsizetype i = 0; i < mrls.size(); ++i)
        if (folder_tree::normalized(mrls[i]) == wanted)
        {
            res.folderId = ids[i];
            break;
        }

    // searching keeps the folders whose name matches, the files become library-wide
    if (!m_searchPattern.isEmpty())
    {
        const QString needle = QString::fromUtf8(m_searchPattern);
        res.folders.erase(std::remove_if(res.folders.begin(), res.folders.end(),
            [&](const folder_tree::Child & child) {
                return !child.name.contains(needle, Qt::CaseInsensitive);
            }), res.folders.end());
    }

    return res;
}

size_t MLFolderBrowseModel::Loader::count(vlc_medialibrary_t* ml, const vlc_ml_query_params_t* queryParams) const /* override */
{
    const Level l = level(ml);
    size_t media = 0;

    if (!m_searchPattern.isEmpty())
        media = m_audio ? vlc_ml_count_audio_media(ml, queryParams)
                        : vlc_ml_count_video_media(ml, queryParams);
    else if (l.folderId != 0)
        media = m_audio ? vlc_ml_count_audio_of(ml, queryParams, VLC_ML_PARENT_FOLDER, l.folderId)
                        : vlc_ml_count_video_of(ml, queryParams, VLC_ML_PARENT_FOLDER, l.folderId);

    return l.folders.size() + media;
}

std::vector<std::unique_ptr<MLItem>>
MLFolderBrowseModel::Loader::load(vlc_medialibrary_t* ml, const vlc_ml_query_params_t* queryParams) const /* override */
{
    const Level l = level(ml);
    const folder_tree::Range range = folder_tree::splitRange(l.folders.size(), queryParams->i_offset,
                                                              queryParams->i_nbResults);

    std::vector<std::unique_ptr<MLItem>> res;
    for (size_t i = range.folderBegin; i < range.folderEnd; ++i)
        res.push_back(std::make_unique<MLFolderRow>(l.folders[i], i));

    const bool searching = !m_searchPattern.isEmpty();
    if (!range.media || (!searching && l.folderId == 0))
        return res;

    vlc_ml_query_params_t params = *queryParams;
    params.i_offset = range.mediaOffset;
    params.i_nbResults = range.mediaLimit;

    ml_unique_ptr<vlc_ml_media_list_t> list;
    if (searching)
        list.reset(m_audio ? vlc_ml_list_audio_media(ml, &params) : vlc_ml_list_video_media(ml, &params));
    else
        list.reset(m_audio ? vlc_ml_list_audio_of(ml, &params, VLC_ML_PARENT_FOLDER, l.folderId)
                           : vlc_ml_list_video_of(ml, &params, VLC_ML_PARENT_FOLDER, l.folderId));

    if (list == nullptr)
        return res;

    for (const vlc_ml_media_t & media : ml_range_iterate<vlc_ml_media_t>(list))
    {
        if (m_audio)
            res.push_back(std::make_unique<MLAudio>(ml, &media));
        else
            res.push_back(std::make_unique<MLVideo>(&media));
    }

    return res;
}

std::unique_ptr<MLItem>
MLFolderBrowseModel::Loader::loadItemById(vlc_medialibrary_t* ml, MLItemId itemId) const /* override */
{
    // folder rows are synthetic
    if (itemId.type == VLC_ML_PARENT_FOLDER)
        return nullptr;

    ml_unique_ptr<vlc_ml_media_t> media(vlc_ml_get_media(ml, itemId.id));
    if (!media)
        return nullptr;

    if (m_audio)
        return std::make_unique<MLAudio>(ml, media.get());
    return std::make_unique<MLVideo>(media.get());
}
