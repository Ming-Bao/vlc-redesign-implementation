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
#include <QTest>

#include "dialogs/hotkeys/hotkey_model.hpp"

class TestHotkeyModel : public QObject
{
    Q_OBJECT
private slots:
    void assign_movesAKey() {
        HotkeyModel m({{"key-a","global-key-a","A","","x",""},{"key-b","global-key-b","B","","y\tz",""}});
        QCOMPARE(m.conflict("y", 0, false), QString("B"));
        QCOMPARE(m.conflict("y", 1, false), QString{});
        QCOMPARE(m.conflict("q", 0, false), QString{});
        QVERIFY(!m.dirty());
        m.assign(0, false, "y");
        QCOMPARE(m.data(m.index(0), HotkeyModel::KeysRole).toString(), QString("y"));
        QCOMPARE(m.data(m.index(1), HotkeyModel::KeysRole).toString(), QString("z"));   // the other key stays
        QVERIFY(m.dirty());
    }
    void columnsAreIndependent() {
        HotkeyModel m({{"key-a","global-key-a","A","","x",""},{"key-b","global-key-b","B","","",""}});
        QCOMPARE(m.conflict("x", 1, true), QString{});
        m.assign(1, true, "x");
        QCOMPARE(m.data(m.index(0), HotkeyModel::KeysRole).toString(), QString("x"));
    }
    void clear_and_display() {
        HotkeyModel m({{"key-a","global-key-a","A","","x",""}});
        m.clear(0, false);
        QCOMPARE(m.data(m.index(0), HotkeyModel::KeysRole).toString(), QString{});
        QVERIFY(m.dirty());
        QCOMPARE(HotkeyModel::displayKeys("Esc\tq"), QString("esc, q"));
    }
    void dirty_clearsWhenRestored() {
        HotkeyModel m({{"key-a","global-key-a","A","","x",""}});
        m.clear(0, false);
        m.assign(0, false, "x");
        QVERIFY(!m.dirty());
        QCOMPARE(m.rowOf("key-a"), 0);
        QCOMPARE(m.rowOf("key-nope"), -1);
    }
};

QTEST_GUILESS_MAIN(TestHotkeyModel)
#include "test_hotkey_model.moc"
