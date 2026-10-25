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
#include "settings_bridge.hpp"

#include "player/effects_util.hpp"
#include "util/vlc_config.hpp"

#include <QDesktopServices>
#include <QDir>
#include <QFileDialog>
#include <QFontDatabase>
#include <QUrl>

#include <algorithm>

#include <vlc_configuration.h>
#include <vlc_iso_lang.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>

#ifdef _WIN32
#include <windows.h>
#endif

// the language table lives in the core, which does not export it
#include "../../../../../src/text/iso-639_def.h"

SettingsBridge::SettingsBridge(qt_intf_t* intf, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
{
}

void SettingsBridge::touch(const QString& name)
{
    ++m_revision;
    emit changed(name);
}

bool SettingsBridge::exists(const QString& name) const
{
    if (config_GetType(qtu(name)) == 0)
        return false;
    // removed options stay registered, but only so that old config files still load: they have no text
    const module_config_t* item = config_FindConfig(qtu(name));
    return item && item->psz_text;
}

QVariant SettingsBridge::value(const QString& name) const
{
    return vlcConfigValue(name);
}

void SettingsBridge::setValue(const QString& name, const QVariant& v)
{
    if (vlcSetConfigValue(name, v))
        touch(name);
}

QVariant SettingsBridge::defaultValue(const QString& name) const
{
    const module_config_t* item = config_FindConfig(qtu(name));
    if (!item)
        return {};
    switch (config_GetType(qtu(name)))
    {
    case VLC_VAR_FLOAT:   return item->orig.f;
    case VLC_VAR_INTEGER: return QVariant::fromValue<qlonglong>(item->orig.i);
    case VLC_VAR_BOOL:    return item->orig.i != 0;
    case VLC_VAR_STRING:  return qfu(item->orig.psz ? item->orig.psz : "");
    }
    return {};
}

void SettingsBridge::reset(const QString& name)
{
    setValue(name, defaultValue(name));
}

QVariantList SettingsBridge::choices(const QString& name) const
{
    QVariantList out;
    char** texts = nullptr;
    ssize_t n;
    if (config_GetType(qtu(name)) == VLC_VAR_STRING)
    {
        char** values = nullptr;
        n = config_GetPszChoices(qtu(name), &values, &texts);
        for (ssize_t i = 0; i < n; i++)
        {
            out.push_back(QVariantMap{{"value", qfu(values[i])}, {"label", qfut(texts[i])}});
            free(values[i]);
            free(texts[i]);
        }
        free(values);
    }
    else
    {
        int64_t* values = nullptr;
        n = config_GetIntChoices(qtu(name), &values, &texts);
        for (ssize_t i = 0; i < n; i++)
        {
            out.push_back(QVariantMap{{"value", QVariant::fromValue<qlonglong>(values[i])}, {"label", qfut(texts[i])}});
            free(texts[i]);
        }
        free(values);
    }
    free(texts);
    return out;
}

QString SettingsBridge::help(const QString& name) const
{
    const module_config_t* item = config_FindConfig(qtu(name));
    if (!item)
        return {};
    if (item->psz_longtext)
        return qfut(item->psz_longtext);
    return item->psz_text ? qfut(item->psz_text) : QString();
}

bool SettingsBridge::listHas(const QString& name, const QString& module) const
{
    if (config_GetType(qtu(name)) != VLC_VAR_STRING)   // config_GetPsz asserts on anything else
        return false;
    return vlcConfigString(qtu(name)).split(':', Qt::SkipEmptyParts).contains(module);
}

void SettingsBridge::setListHas(const QString& name, const QString& module, bool on)
{
    if (config_GetType(qtu(name)) != VLC_VAR_STRING)
        return;
    setValue(name, effects::toggleModule(vlcConfigString(qtu(name)), module, on));
}

void SettingsBridge::resetPrefixes(const QStringList& prefixes)
{
    unsigned count = 0;
    module_config_t* items = module_config_get(module_get_main(), &count);
    QStringList names;
    for (unsigned i = 0; i < count; i++)
    {
        if (!items[i].psz_name)
            continue;
        const QString n = qfu(items[i].psz_name);
        if (std::any_of(prefixes.begin(), prefixes.end(), [&](const QString& p) { return n.startsWith(p); }))
            names.push_back(n);
    }
    module_config_free(items);
    for (const QString& n : names)
        reset(n);
}

void SettingsBridge::resetAll()
{
    config_ResetAll();
    config_SaveConfigFile(m_intf);
    touch({});
}

void SettingsBridge::save()
{
    config_SaveConfigFile(m_intf);
}

void SettingsBridge::openConfigFolder()
{
    char* dir = config_GetUserDir(VLC_CONFIG_DIR);
    if (!dir)
        return;
    QDesktopServices::openUrl(QUrl::fromLocalFile(qfu(dir)));
    free(dir);
}

QString SettingsBridge::pickPath(const QString& current, bool folder, bool save) const
{
    const QString start = current.isEmpty() ? QDir::homePath() : current;
    if (folder)
        return QFileDialog::getExistingDirectory(nullptr, qtr("Select Directory"), start);
    if (save)
        return QFileDialog::getSaveFileName(nullptr, qtr("Save File"), start);
    return QFileDialog::getOpenFileName(nullptr, qtr("Select File"), start);
}

QVariantList SettingsBridge::languages() const
{
    QVector<QPair<QString, QString>> langs;   // {label, code}
    for (const iso639_lang_t* l = p_languages; l->psz_eng_name; l++)
        langs.push_back({qfu(l->psz_eng_name), qfu(l->psz_iso639_2T)});
    std::sort(langs.begin(), langs.end());

    QVariantList out{QVariantMap{{"value", QString()}, {"label", qtr("System language")}}};
    for (const auto& l : langs)
        out.push_back(QVariantMap{{"value", l.second}, {"label", l.first}});
    return out;
}

QStringList SettingsBridge::fontFamilies() const
{
    return QFontDatabase::families();
}

QStringList SettingsBridge::opticalDrives() const
{
    QStringList out;
#ifdef _WIN32
    for (const QFileInfo& d : QDir::drives())
        if (GetDriveTypeW(reinterpret_cast<const wchar_t*>(d.absoluteFilePath().utf16())) == DRIVE_CDROM)
            out.push_back(QDir::toNativeSeparators(d.absoluteFilePath()));
#else
    for (const QString& n : QDir("/dev").entryList({"sr*"}, QDir::System, QDir::Name))
        out.push_back("/dev/" + n);
    if (QFileInfo::exists("/dev/cdrom"))
        out.push_back("/dev/cdrom");
#endif
    return out;
}
