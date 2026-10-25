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
#include "settings_bridge.hpp"

#include "dialogs/extensions/extensions_manager.hpp"
#include "dialogs/plugins/plugins.hpp"

// Kept apart from settings_bridge.cpp: the extensions manager and the plugins dialog's list model drag in the rest of
// the interface, which the bridge's test does not link (it stubs these two).
QAbstractItemModel* SettingsBridge::extensions()
{
    if (!m_extensions)
    {
        ExtensionsManager* em = ExtensionsManager::getInstance(m_intf);
        // loads the extensions if needed; one update now for an already loaded manager
        m_extensions = new ExtensionListModel(this, em);
        emit em->extensionsUpdated();
    }
    return m_extensions;
}

void SettingsBridge::reloadExtensions()
{
    ExtensionsManager::getInstance(m_intf)->reloadExtensions();
}
