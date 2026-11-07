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
#ifndef VLC_QT_SETTINGS_APPLY_KIND_HPP
#define VLC_QT_SETTINGS_APPLY_KIND_HPP

#include <QSet>
#include <QString>

// how a Settings write reaches the running player; pure, so it is testable without a player
namespace settingsapply {

enum class Kind { None, OutputVar, Player, Interface };

inline Kind kindOf(const QString& option)
{
    // OutputVar: variable on the aout/vouts. Player: through PlayerController. Interface: the GUI itself
    static const QSet<QString> outputVars = {
        "aspect-ratio", "crop", "zoom", "autoscale", "deinterlace", "deinterlace-mode", "video-wallpaper",
        "sub-margin", "stereo-mode", "audio-filter", "video-filter", "equalizer-bands", "equalizer-preamp",
        "equalizer-2pass", "pitch-shift", "audio-replay-gain-mode", "hue", "brightness",
        "contrast", "saturation", "gamma" };
    static const QSet<QString> player = {
        "rate", "audio-desync", "sub-delay", "sub-text-scale", "video", "audio", "spu", "audio-track",
        "sub-track", "repeat", "loop", "random", "play-and-stop", "play-and-exit" };
    static const QSet<QString> interface = {
        "qt-video-autoresize", "video-on-top", "qt-name-in-title", "mouse-hide-timeout", "qt-system-tray",
        "qt-notification", "qt-opacity", "qt-pause-minimized", "qt-bgcone", "qt-fs-opacity", "qt-max-volume",
        "qt-error-dialogs", "qt-fs-controller" };
    if (outputVars.contains(option)) return Kind::OutputVar;
    if (player.contains(option)) return Kind::Player;
    if (interface.contains(option)) return Kind::Interface;
    return Kind::None;
}

}

#endif
