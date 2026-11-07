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
#include "player/player_effects.hpp"

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

void SettingsApplier::applyPlayer(const QString&, const QVariant&) {}

void SettingsApplier::applyInterface(const QString&) {}
