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
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "playlist_cover.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>

#include <vlc_common.h>
#include <vlc_configuration.h>


QString coverDir()
{
    char* userdata = config_GetUserDir(VLC_USERDATA_DIR);
    const QString dir = QString::fromUtf8(userdata) + "/playlist-covers";
    free(userdata);
    return dir;
}

// "7.*" does not match "70.png"
static QStringList coverFiles(const QString& dir, int64_t playlistId)
{
    return QDir(dir).entryList({ QString::number(playlistId) + ".*" }, QDir::Files);
}

QString customCoverPath(const QString& dir, int64_t playlistId)
{
    const QStringList files = coverFiles(dir, playlistId);
    return files.isEmpty() ? QString{} : QDir(dir).filePath(files.first());
}

void removeCustomCover(const QString& dir, int64_t playlistId)
{
    for (const QString& f : coverFiles(dir, playlistId))
        QFile::remove(QDir(dir).filePath(f));
}

bool storeCustomCover(const QString& dir, int64_t playlistId, const QUrl& image)
{
    const QString src = image.toLocalFile();
    if (src.isEmpty() || !QFileInfo(src).isFile() || !QDir().mkpath(dir))
        return false;

    const QString suffix = QFileInfo(src).suffix().toLower();
    const QDir d(dir);
    const QString tmp = d.filePath(QStringLiteral(".cover.tmp"));
    QFile::remove(tmp);
    if (!QFile::copy(src, tmp))
        return false;

    removeCustomCover(dir, playlistId);
    const QString dst = d.filePath(QString::number(playlistId) + (suffix.isEmpty() ? QString{} : "." + suffix));
    if (QFile::rename(tmp, dst))
        return true;
    QFile::remove(tmp);
    return false;
}
