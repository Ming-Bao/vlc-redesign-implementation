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
#ifndef VLC_QT_PLAY_SESSION_HPP
#define VLC_QT_PLAY_SESSION_HPP

#include "qt.hpp"

// Capture the play queue, its current item and time while still playing (any thread; the first
// call of a run counts)
void snapshotPlaySession(qt_intf_t *intf);

// Keep the snapshot across a clean exit (UI thread)
void savePlaySession(qt_intf_t *intf);

// Bring the last session back, paused, when VLC starts without anything to play
void restorePlaySession(qt_intf_t *intf);

#endif
