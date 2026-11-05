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
#ifndef VLC_QT_ONBOARDING_FOLDERS_HPP
#define VLC_QT_ONBOARDING_FOLDERS_HPP

#include <QString>
#include <QStringList>

// pure path rules of the onboarding card's folder field (no VLC deps)
namespace onboarding {

QString expandHome(const QString& text, const QString& home);
QString displayPath(const QString& path, const QString& home);
bool fieldValid(const QString& text, const QString& home);
QStringList foldersToAdd(const QString& chosen, const QString& music);

}

#endif
