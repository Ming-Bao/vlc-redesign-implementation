/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#include "settings_apply.hpp"
#include "settings_apply_kind.hpp"
#include "settings_bridge.hpp"
#include "maininterface/mainctx.hpp"
#include "player/player_controller.hpp"
#include "player/player_effects.hpp"
#include "playlist/playlist_controller.hpp"

SettingsApplier::SettingsApplier(qt_intf_t* intf, SettingsBridge* bridge, PlayerEffects* effects, QObject* parent)
    : QObject(parent), m_intf(intf), m_bridge(bridge), m_effects(effects)
{
    connect(bridge, &SettingsBridge::changed, this, &SettingsApplier::apply);
}

void SettingsApplier::apply(const QString& option)
{
    // an empty name is resetAll: nothing to push, the next media reads the defaults
    switch (settingsapply::kindOf(option))
    {
    case settingsapply::Kind::OutputVar:
        m_effects->pushToOutputs(option, m_bridge->value(option));
        break;
    case settingsapply::Kind::Player:
        applyPlayer(option, m_bridge->value(option));
        break;
    case settingsapply::Kind::Interface:
        applyInterface(option);
        break;
    case settingsapply::Kind::None:
        break;
    }
}

void SettingsApplier::applyPlayer(const QString& option, const QVariant& value)
{
    PlayerController* player = m_intf->p_mainPlayerController;
    using vlc::playlist::PlaylistController;
    PlaylistController* queue = m_intf->p_mainPlaylistController;
    if (!player || !queue)
        return;

    if (option == "rate")
        player->setRate(value.toFloat());
    else if (option == "audio-desync")
        player->setAudioDelayMS(value.toInt());
    else if (option == "sub-delay")
        player->setSubtitleDelayMS(value.toInt() * 100);   // the option is in 1/10 s
    else if (option == "sub-text-scale")
        m_effects->setSubtitleTextScale(value.toInt());
    else if (option == "video" || option == "audio" || option == "spu")
    {
        const es_format_category_e cat = option == "video" ? VIDEO_ES : option == "audio" ? AUDIO_ES : SPU_ES;
        vlc_player_t* p = player->getPlayer();
        vlc_player_Lock(p);
        vlc_player_SetTrackCategoryEnabled(p, cat, value.toBool());
        // turning a category off unselects its tracks and turning it back on does not select any: bring back the first
        // one (ponytail: not the track that was selected before, which the player does not keep)
        const size_t n = vlc_player_GetTrackCount(p, cat);
        if (value.toBool() && n > 0)
        {
            bool any = false;
            for (size_t i = 0; i < n; ++i)
                any = any || vlc_player_GetTrackAt(p, cat, i)->selected;
            if (!any)
                vlc_player_SelectTrack(p, vlc_player_GetTrackAt(p, cat, 0), VLC_PLAYER_SELECT_EXCLUSIVE);
        }
        vlc_player_Unlock(p);
    }
    else if (option == "audio-track" || option == "sub-track")
    {
        // -1 or a number past the last track: leave the selection to the player
        const es_format_category_e cat = option == "audio-track" ? AUDIO_ES : SPU_ES;
        const int n = value.toInt();
        vlc_player_t* p = player->getPlayer();
        vlc_player_Lock(p);
        if (n >= 0 && size_t(n) < vlc_player_GetTrackCount(p, cat))
            vlc_player_SelectTrack(p, vlc_player_GetTrackAt(p, cat, n), VLC_PLAYER_SELECT_EXCLUSIVE);
        vlc_player_Unlock(p);
    }
    else if (option == "repeat" || option == "loop")
    {
        // RepeatRow writes both options, one after the other: always read the pair
        queue->setRepeatMode(m_bridge->value("repeat").toBool() ? PlaylistController::PLAYBACK_REPEAT_CURRENT
                           : m_bridge->value("loop").toBool() ? PlaylistController::PLAYBACK_REPEAT_ALL
                           : PlaylistController::PLAYBACK_REPEAT_NONE);
    }
    else if (option == "audio-language" || option == "sub-language")
    {
        // the player var shadows the option for every later input; the rules pick a track when tracks appear
        vlc_player_t* p = player->getPlayer();
        vlc_player_Lock(p);
        vlc_player_SelectCategoryLanguage(p, option == "audio-language" ? AUDIO_ES : SPU_ES, qtu(value.toString()));
        vlc_player_Unlock(p);
    }
    else if (option == "random")
        queue->setRandom(value.toBool());
    else if (option == "play-and-stop" || option == "play-and-exit")
        queue->setMediaStopAction(m_bridge->value("play-and-exit").toBool() ? PlaylistController::MEDIA_STOPPED_EXIT
                                : m_bridge->value("play-and-stop").toBool() ? PlaylistController::MEDIA_STOPPED_STOP
                                : PlaylistController::MEDIA_STOPPED_CONTINUE);
}

void SettingsApplier::applyInterface(const QString& option)
{
    if (m_intf->p_mi)
        m_intf->p_mi->onSettingChanged(option);
}
