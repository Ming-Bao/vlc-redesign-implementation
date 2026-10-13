/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *****************************************************************************/
#ifndef VLC_QT_UI_FONT_HPP
#define VLC_QT_UI_FONT_HPP

#include <QStringList>

namespace vlc {

/// font family the redesigned interface uses, or empty when it is not installed
QString preferredUiFontFamily(const QStringList& installed);

}

#endif // VLC_QT_UI_FONT_HPP
