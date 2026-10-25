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
#ifndef VLC_QT_VLC_CONFIG_HPP
#define VLC_QT_VLC_CONFIG_HPP

#include <QString>
#include <QVariant>

// core config options (vlcrc) as QVariants; "#RRGGBB" strings are accepted for integer options (colours)
QVariant vlcConfigValue(const QString& name);
// false when there is no such option
bool vlcSetConfigValue(const QString& name, const QVariant& v);
QString vlcConfigString(const char* name);

struct qt_intf_t;
// config_ResetAll + save, clear the Qt settings, flag the pending restart, reload prefs on MainCtx (preferences.cpp)
void qtResetAllPreferences(qt_intf_t* p_intf);
class QWidget;
// "restart now?" after a reset: quits, or drops the pending flag (preferences.cpp)
void qtPromptRestartAfterReset(QWidget* parent, qt_intf_t* p_intf);

#endif
