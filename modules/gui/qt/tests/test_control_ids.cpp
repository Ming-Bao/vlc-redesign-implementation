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
#include <QJSEngine>

#include "dialogs/toolbar/controlbar_profile.hpp"
#include "player/control_list_model.hpp"
#include "player/player_controlbar_model.hpp"

class TestControlIds : public QObject
{
    Q_OBJECT
private slots:
    void existingIdsAreStable() {
        QCOMPARE(int(ControlListModel::SPLITTER), 0x20);
        QCOMPARE(int(ControlListModel::VOLUME), 0x21);
        QCOMPARE(int(ControlListModel::NAVIGATION_BOX), 0x2A);
        QCOMPARE(int(ControlListModel::WIDGET_SPACER), 0x40);
        QCOMPARE(int(ControlListModel::WIDGET_SPACER_EXTEND), 0x41);
        QCOMPARE(int(ControlListModel::SEEKBAR), 0x45);
        QCOMPARE(int(ControlListModel::WIDGET_MAX), 0x46);
    }
    void newIdsHaveFixedValues() {
        QCOMPARE(int(ControlListModel::DIVIDER), 0x2B);
        QCOMPARE(int(ControlListModel::SETTINGS_BUTTON), 0x30);
        QCOMPARE(int(ControlListModel::THUMBNAIL_WIDGET), 0x32);
        QCOMPARE(int(ControlListModel::REPLAY_BUTTON), 0x37);
        QCOMPARE(int(ControlListModel::PLAYLISTS_BUTTON), 0x3B);
        QCOMPARE(int(ControlListModel::MORE_MENU), 0x3C);
        QCOMPARE(int(ControlListModel::MEDIA_TITLE), 0x3F);
        QCOMPARE(int(ControlListModel::WINDOW_MINIMIZE), 0x42);
        QCOMPARE(int(ControlListModel::WINDOW_CLOSE), 0x44);
    }
    void newIdsRoundTrip() {
        ControlListModel m;
        m.setControls(QVector<int>{ControlListModel::SEEKBAR, ControlListModel::WINDOW_CLOSE});
        QCOMPARE(m.getControls(), (QVector<int>{0x45, 0x44}));
    }
    void oldProfileGainsDefaults() {
        ControlbarProfile p;
        p.setModelData(PlayerControlbarModel::Videoplayer, {QVector<int>{ControlListModel::PLAY_BUTTON}, {}, {}});
        p.ensureModel(PlayerControlbarModel::SeekRow, {QVector<int>{}, {}, {}});
        p.ensureModel(PlayerControlbarModel::Topbar, {QVector<int>{ControlListModel::MORE_MENU}, {}, {}});
        QVERIFY(p.getModel(PlayerControlbarModel::SeekRow)->empty());
        QCOMPARE(p.getModelData(PlayerControlbarModel::Topbar)[0], QVector<int>{ControlListModel::MORE_MENU});
        // a model already present is left alone
        p.ensureModel(PlayerControlbarModel::Videoplayer, {QVector<int>{}, {}, {}});
        QCOMPARE(p.getModelData(PlayerControlbarModel::Videoplayer)[0], QVector<int>{ControlListModel::PLAY_BUTTON});
    }
    void ensureModelDoesNotMarkDirty() {
        ControlbarProfile p;
        p.setModelData(PlayerControlbarModel::Videoplayer, {QVector<int>{ControlListModel::PLAY_BUTTON}, {}, {}});
        p.resetDirty();
        QVERIFY(!p.dirty());
        p.ensureModel(PlayerControlbarModel::Topbar, {QVector<int>{ControlListModel::MORE_MENU}, {}, {}});
        QVERIFY(!p.dirty());
        QVERIFY(!p.getModel(PlayerControlbarModel::Topbar)->dirty());
    }
};

QTEST_GUILESS_MAIN(TestControlIds)
#include "test_control_ids.moc"
