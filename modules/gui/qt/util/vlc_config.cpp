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
#include "util/vlc_config.hpp"

#include "qt.hpp"

#include <QColor>

#include <vlc_configuration.h>

QString vlcConfigString(const char* name)
{
    char* s = config_GetPsz(name);
    QString out = qfu(s ? s : "");
    free(s);
    return out;
}

QVariant vlcConfigValue(const QString& name)
{
    switch (config_GetType(qtu(name)))
    {
    case VLC_VAR_FLOAT:   return config_GetFloat(qtu(name));
    case VLC_VAR_INTEGER: return QVariant::fromValue<qlonglong>(config_GetInt(qtu(name)));
    case VLC_VAR_BOOL:    return config_GetInt(qtu(name)) != 0;
    case VLC_VAR_STRING:  return vlcConfigString(qtu(name));
    }
    return {};
}

bool vlcSetConfigValue(const QString& name, const QVariant& v)
{
    switch (config_GetType(qtu(name)))
    {
    case VLC_VAR_FLOAT:   config_PutFloat(qtu(name), v.toFloat()); return true;
    case VLC_VAR_BOOL:    config_PutInt(qtu(name), v.toBool()); return true;
    case VLC_VAR_STRING:  config_PutPsz(qtu(name), qtu(v.toString())); return true;
    case VLC_VAR_INTEGER:
        // colour options take "#RRGGBB" from the text fields
        if (v.typeId() == QMetaType::QString && v.toString().startsWith('#'))
            config_PutInt(qtu(name), QColor(v.toString()).rgb() & 0xFFFFFF);
        else
            config_PutInt(qtu(name), v.toLongLong());
        return true;
    }
    return false;
}
