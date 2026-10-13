/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *****************************************************************************/
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QTest>

#include "../util/ui_font.hpp"

class TestUiFont : public QObject
{
    Q_OBJECT
private slots:
    void prefersInter() {
        QCOMPARE(vlc::preferredUiFontFamily({"DejaVu Sans", "Inter", "Noto Sans"}), QString("Inter"));
    }
    void acceptsVariableInter() {
        QCOMPARE(vlc::preferredUiFontFamily({"Inter Variable"}), QString("Inter Variable"));
    }
    void emptyWhenMissing() {
        QVERIFY(vlc::preferredUiFontFamily({"DejaVu Sans"}).isEmpty());
    }
};

QTEST_GUILESS_MAIN(TestUiFont)
#include "test_ui_font.moc"
