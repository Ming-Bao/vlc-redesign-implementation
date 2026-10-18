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
#ifndef ML_FOLDER_BROWSE_MODEL_H
#define ML_FOLDER_BROWSE_MODEL_H

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "mlmediamodel.hpp"

// One level of the library's folder tree: the child folders, then the files in the folder.
// With a search pattern the folders are filtered by name and the files are library-wide.
class MLFolderBrowseModel : public MLMediaModel
{
    Q_OBJECT

    Q_PROPERTY(bool audio READ audio WRITE setAudio NOTIFY audioChanged FINAL)
    // "" is the root
    Q_PROPERTY(QString folderMrl READ folderMrl WRITE setFolderMrl NOTIFY folderMrlChanged FINAL)

public:
    enum Roles
    {
        FOLDER_IS_FOLDER = MLMediaModel::MEDIA_ROLES_COUNT,
        FOLDER_IS_NEW,
        FOLDER_ARTIST,
        FOLDER_THUMBNAIL, // same as MEDIA_SMALL_COVER, so the video cards work unchanged
        FOLDER_ROLES_COUNT,
    };

public:
    explicit MLFolderBrowseModel(QObject * parent = nullptr);

    virtual ~MLFolderBrowseModel() = default;

public: // Properties
    bool audio() const { return m_audio; }
    void setAudio(bool audio);

    QString folderMrl() const { return m_folderMrl; }
    void setFolderMrl(const QString & folderMrl);

signals:
    void audioChanged();
    void folderMrlChanged();

protected: // MLBaseModel implementation
    std::unique_ptr<MLListCacheLoader> createMLLoader() const override;

protected: // MLMediaModel reimplementation
    QHash<int, QByteArray> roleNames() const override;

    QVariant itemRoleData(const MLItem * item, int role) const override;

    void onVlcMlEvent(const MLEvent & event) override;

    void thumbnailUpdated(const QModelIndex &, MLItem *, const QString &, vlc_ml_thumbnail_status_t) override;

private:
    struct Loader : public MLListCacheLoader::MLOp
    {
        Loader(const MLFolderBrowseModel & model);

        size_t count(vlc_medialibrary_t* ml, const vlc_ml_query_params_t* queryParams) const override;

        std::vector<std::unique_ptr<MLItem>> load(vlc_medialibrary_t* ml, const vlc_ml_query_params_t* queryParams) const override;

        std::unique_ptr<MLItem> loadItemById(vlc_medialibrary_t* ml, MLItemId itemId) const override;

    private:
        struct Level;

        Level level(vlc_medialibrary_t* ml) const;

        bool m_audio;
        QString m_folderMrl;
    };

    bool m_audio = false;
    QString m_folderMrl;
};

#endif // ML_FOLDER_BROWSE_MODEL_H
