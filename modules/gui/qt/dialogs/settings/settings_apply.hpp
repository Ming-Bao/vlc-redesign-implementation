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
#ifndef VLC_QT_SETTINGS_APPLY_HPP
#define VLC_QT_SETTINGS_APPLY_HPP

#include <QObject>

#include "qt.hpp"

class SettingsBridge;
class PlayerEffects;

// pushes each Settings write to the media that is playing now
class SettingsApplier : public QObject
{
    Q_OBJECT
public:
    SettingsApplier(qt_intf_t* intf, SettingsBridge* bridge, PlayerEffects* effects, QObject* parent);

private slots:
    void apply(const QString& option);

private:
    void applyPlayer(const QString& option, const QVariant& value);
    void applyInterface(const QString& option);

    qt_intf_t* m_intf;
    SettingsBridge* m_bridge;
    PlayerEffects* m_effects;
};

#endif
