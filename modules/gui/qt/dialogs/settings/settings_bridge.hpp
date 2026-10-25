/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#ifndef VLC_QT_SETTINGS_BRIDGE_HPP
#define VLC_QT_SETTINGS_BRIDGE_HPP

#include <QAbstractItemModel>
#include <QObject>
#include <QUrl>
#include <QStringList>
#include <QVariant>

#include "qt.hpp"

// VLC config (vlcrc) access for the settings window's QML (singleton "SettingsBridge")
class SettingsBridge : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY changed FINAL)
    // the installed Lua extensions (ExtensionListModel; roles title, summary, version, author, filename)
    Q_PROPERTY(QAbstractItemModel* extensions READ extensions CONSTANT FINAL)

public:
    explicit SettingsBridge(qt_intf_t* intf, QObject* parent = nullptr);

    int revision() const { return m_revision; }

    // false for an unknown or obsolete option (builds without the owning module have no such option)
    Q_INVOKABLE bool exists(const QString& name) const;
    Q_INVOKABLE QVariant value(const QString& name) const;
    Q_INVOKABLE void setValue(const QString& name, const QVariant& v);
    Q_INVOKABLE QVariant defaultValue(const QString& name) const;
    Q_INVOKABLE void reset(const QString& name);
    // {min, max} of an integer or float option; empty for any other
    Q_INVOKABLE QVariantMap range(const QString& name) const;
    // [{value, label}], empty when the option has no list of choices
    Q_INVOKABLE QVariantList choices(const QString& name) const;
    Q_INVOKABLE QString help(const QString& name) const;

    // membership of a module in a colon separated list option (e.g. "audio-filter")
    Q_INVOKABLE bool listHas(const QString& name, const QString& module) const;
    Q_INVOKABLE void setListHas(const QString& name, const QString& module, bool on);

    Q_INVOKABLE void resetPrefixes(const QStringList& prefixes);
    Q_INVOKABLE void resetAll();
    Q_INVOKABLE void save();
    Q_INVOKABLE void openConfigFolder();
    // a native file (or folder) picker starting at `current`; "" when cancelled
    Q_INVOKABLE QString pickPath(const QString& current, bool folder, bool save) const;

    // Extensions: the user folder is <userdata>/lua/extensions. add copies a .lua file there, remove deletes a file
    // from there (false for any other); both reload the list
    QAbstractItemModel* extensions();
    Q_INVOKABLE bool addExtension(const QUrl& luaFile);
    Q_INVOKABLE bool canRemoveExtension(int row);
    Q_INVOKABLE QString extensionFile(int row);
    Q_INVOKABLE bool removeExtensionFile(const QString& path);
    Q_INVOKABLE QUrl pickLuaFile() const;   // empty when cancelled
    // copies a .lua file into `dir` (replacing an older copy; the file already there is left alone)
    static bool installExtensionFile(const QString& srcPath, const QString& dir);

    Q_INVOKABLE QVariantList languages() const;
    Q_INVOKABLE QStringList fontFamilies() const;
    Q_INVOKABLE QStringList opticalDrives() const;

signals:
    void changed(const QString& name);

private:
    void touch(const QString& name);
    void reloadExtensions();   // settings_extensions.cpp (needs the extensions manager, not linked into the test)

    qt_intf_t* m_intf;
    int m_revision = 0;
    QAbstractItemModel* m_extensions = nullptr;
};

#endif
