/*****************************************************************************
 * Copyright (C) 2023 VLC authors and VideoLAN
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
import QtQuick
import QtTest

import "qrc:/qt/qml/VLC/Dialogs/SettingsData.js" as Data

TestCase {
    name: "SettingsData"

    function test_presetFor() {
        const d = [1000, 300, 1000, 300]
        compare(Data.presetFor([1000, 300, 1000, 300], d), "normal")
        compare(Data.presetFor([500, 150, 500, 150], d), "low")
        compare(Data.presetFor([2000, 600, 2000, 600], d), "high")
        compare(Data.presetFor([2000, 300, 1000, 300], d), "custom")
    }
}
