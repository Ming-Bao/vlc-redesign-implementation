/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *****************************************************************************/
#include "ui_font.hpp"

QString vlc::preferredUiFontFamily(const QStringList& installed)
{
    for (const char* family : { "Inter", "Inter Variable" })
        if (installed.contains(QLatin1String(family)))
            return QLatin1String(family);
    return {};
}
