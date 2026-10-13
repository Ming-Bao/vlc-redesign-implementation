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

#include "play_session.hpp"

#include <QFileInfo>
#include <QSettings>
#include <QStringList>

#include <vlc_input_item.h>
#include <vlc_player.h>
#include <vlc_playlist.h>

#include <vector>

static const QString itemsKey = QStringLiteral("PlaySession/Items");
static const QString currentKey = QStringLiteral("PlaySession/Current");
static const QString timeKey = QStringLiteral("PlaySession/TimeMs");
// written by ModelRecoveryAgent while a session runs, removed on a clean exit
static const QString recoveryKey = QStringLiteral("Playlist/RecoveryFilePath");

namespace {
struct Snapshot
{
    bool taken = false;
    QStringList uris;
    qint64 current = -1;
    qint64 timeMs = 0;
};
// guarded by the playlist lock while taken
Snapshot snapshot;
}

void snapshotPlaySession(qt_intf_t *intf)
{
    vlc_playlist_t *playlist = intf->p_playlist;
    vlc_playlist_Lock(playlist);
    // the first call of a run wins: later ones (once quitting stopped playback) lost the time
    if (!snapshot.taken)
    {
        snapshot.taken = true;
        const size_t count = vlc_playlist_Count(playlist);
        for (size_t i = 0; i < count; ++i)
        {
            input_item_t *media = vlc_playlist_item_GetMedia(vlc_playlist_Get(playlist, i));
            char *uri = input_item_GetURI(media);
            snapshot.uris.append(uri ? QString::fromUtf8(uri) : QString());
            free(uri);
        }
        snapshot.current = vlc_playlist_GetCurrentIndex(playlist);
        const vlc_tick_t time = vlc_player_GetTime(vlc_playlist_GetPlayer(playlist));
        if (time != VLC_TICK_INVALID)
            snapshot.timeMs = MS_FROM_VLC_TICK(time);
    }
    vlc_playlist_Unlock(playlist);
}

void savePlaySession(qt_intf_t *intf)
{
    snapshotPlaySession(intf);

    vlc_playlist_Lock(intf->p_playlist);
    const Snapshot saved = snapshot;
    vlc_playlist_Unlock(intf->p_playlist);

    msg_Dbg(intf, "saving the play session: %lld items, current %lld at %lld ms",
            static_cast<long long>(saved.uris.size()), static_cast<long long>(saved.current),
            static_cast<long long>(saved.timeMs));
    QSettings *settings = intf->mainSettings;
    if (saved.uris.isEmpty())
    {
        settings->remove(itemsKey);
        settings->remove(currentKey);
        settings->remove(timeKey);
        return;
    }
    settings->setValue(itemsKey, saved.uris);
    settings->setValue(currentKey, saved.current);
    settings->setValue(timeKey, saved.timeMs);
}

void restorePlaySession(qt_intf_t *intf)
{
    QSettings *settings = intf->mainSettings;
    const QStringList uris = settings->value(itemsKey).toStringList();
    if (uris.isEmpty())
        return;

    // after a crash, the play queue recovery offers its own, newer copy
    const QString recoveryFile = settings->value(recoveryKey).toString();
    if (!recoveryFile.isEmpty() && QFileInfo(recoveryFile).size() > 0)
        return;

    std::vector<input_item_t *> medias;
    for (const QString &uri : uris)
    {
        input_item_t *media = input_item_New(qtu(uri), nullptr);
        if (media)
            medias.push_back(media);
    }

    const qint64 current = settings->value(currentKey, -1).toLongLong();
    const qint64 timeMs = settings->value(timeKey, 0).toLongLong();

    vlc_playlist_t *playlist = intf->p_playlist;
    vlc_playlist_Lock(playlist);
    // something was given to play (command line, another instance): leave it alone
    if (vlc_playlist_Count(playlist) == 0
        && vlc_playlist_Append(playlist, medias.data(), medias.size()) == VLC_SUCCESS
        && current >= 0 && static_cast<size_t>(current) < medias.size()
        && vlc_playlist_GoTo(playlist, current) == VLC_SUCCESS)
    {
        vlc_player_t *player = vlc_playlist_GetPlayer(playlist);
        vlc_player_SetStartPaused(player, true);
        if (vlc_playlist_Start(playlist) == VLC_SUCCESS && timeMs > 0)
            vlc_player_SetTime(player, VLC_TICK_FROM_MS(timeMs));
        vlc_player_SetStartPaused(player, false);
    }
    vlc_playlist_Unlock(playlist);

    for (input_item_t *media : medias)
        input_item_Release(media);
}
