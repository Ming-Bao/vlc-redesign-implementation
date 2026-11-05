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
import QtQuick
import QtTest

import "qrc:/qt/qml/VLC/Dialogs/OnboardingKeys.js" as Keys

TestCase {
    name: "OnboardingKeys"

    function test_caps() {
        compare(Keys.caps("Space"), ["Space"])
        compare(Keys.caps("Shift+s"), ["SHIFT", "S"])
        compare(Keys.caps("Ctrl+Alt+Left"), ["CTRL", "ALT", "←"])
        compare(Keys.caps("Up"), ["↑"])
        compare(Keys.caps("n\tMedia Next Track"), ["N"])      // first binding only
        compare(Keys.caps("Esc"), ["esc"])                     // as HotkeyModel::displayKeys
        compare(Keys.caps(""), ["—"])
        compare(Keys.caps(undefined), ["—"])
        compare(Keys.caps("+"), ["+"])
        compare(Keys.caps("Ctrl++"), ["CTRL", "+"])
        compare(Keys.caps("Shift+Ctrl++"), ["SHIFT", "CTRL", "+"])
        compare(Keys.caps("Command+Shift+r"), ["COMMAND", "SHIFT", "R"])
        compare(Keys.caps("Page Up"), ["Page Up"])
        compare(Keys.caps(" f "), ["F"])
    }
    function test_rows() {
        compare(Keys.rows.length, 12)
        compare(Keys.rows[1].keys, ["key-jump-extrashort", "key-jump+extrashort"])
        compare(Keys.rows[8].keys, ["=Ctrl+L"])
    }
}
