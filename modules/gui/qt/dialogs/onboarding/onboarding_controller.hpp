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
#ifndef VLC_QT_ONBOARDING_CONTROLLER_HPP
#define VLC_QT_ONBOARDING_CONTROLLER_HPP

#include <QObject>
#include <QString>

#include "qt.hpp"

// backs the first-run onboarding card's QML (singleton "Onboarding")
class OnboardingController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool hasMediaLibrary READ hasMediaLibrary CONSTANT FINAL)
    Q_PROPERTY(QString defaultFolder READ defaultFolder CONSTANT FINAL)
    Q_PROPERTY(QString currentAccent READ currentAccent CONSTANT FINAL)

public:
    explicit OnboardingController(qt_intf_t* intf, QObject* parent = nullptr);

    bool hasMediaLibrary() const;
    QString defaultFolder() const;
    QString currentAccent() const;

    Q_INVOKABLE bool folderValid(const QString& text) const;
    Q_INVOKABLE QString pickFolder(const QString& text);
    Q_INVOKABLE void finish(int scheme, const QString& accent, const QString& folderText);
    Q_INVOKABLE void skip();

private:
    void addFolder(const QString& path);
    void markDone();

    qt_intf_t* m_intf;
};

#endif
