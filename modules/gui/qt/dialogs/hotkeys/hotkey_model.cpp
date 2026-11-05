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
#include "hotkey_model.hpp"

#include <QKeyEvent>
#include <QRegularExpression>

#include "qt.hpp"
#include <vlc_modules.h>
#include <vlc_plugin.h>
#include "util/vlchotkeyconverter.hpp"

HotkeyModel::HotkeyModel(qt_intf_t* intf, QObject* parent)
    : QAbstractListModel(parent)
    , m_intf(intf)
{
    module_t* main = module_get_main();
    assert(main);
    unsigned size;
    module_config_t* config = module_config_get(main, &size);

    // as KeySelectorControl::finish: the global-* items are paired by name afterwards
    QVector<const module_config_t*> globals;
    for (unsigned i = 0; i < size; i++)
    {
        const module_config_t* item = config + i;
        if (item->i_type != CONFIG_ITEM_KEY)
            continue;
        if (strncmp(item->psz_name, "global-", 7) == 0)
        {
            globals.append(item);
            continue;
        }
        m_rows.append({qfu(item->psz_name), {}, qfut(item->psz_text),
                       item->psz_longtext ? qfut(item->psz_longtext) : QString{},
                       qfu(item->value.psz ? item->value.psz : ""), {}});
    }
    for (const module_config_t* g : globals)
    {
        const int row = rowOf(qfu(g->psz_name + 7)); // global-key-x pairs with key-x
        if (row < 0)
            continue;
        m_rows[row].globalOption = qfu(g->psz_name);
        m_rows[row].globalKeys = qfu(g->value.psz ? g->value.psz : "");
    }
    module_config_free(config);
    m_saved = m_rows;
}

HotkeyModel::HotkeyModel(QVector<HotkeyRow> rows, QObject* parent)
    : QAbstractListModel(parent)
    , m_rows(std::move(rows))
    , m_saved(m_rows)
{
}

int HotkeyModel::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant HotkeyModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= m_rows.size())
        return {};
    const HotkeyRow& r = m_rows.at(index.row());
    switch (role)
    {
    case OptionRole: return r.option;
    case LabelRole: return r.label;
    case LongTextRole: return r.longText;
    case KeysRole: return r.keys;
    case GlobalKeysRole: return r.globalKeys;
    }
    return {};
}

QHash<int, QByteArray> HotkeyModel::roleNames() const
{
    return {{OptionRole, "option"}, {LabelRole, "label"}, {LongTextRole, "longText"},
            {KeysRole, "keys"}, {GlobalKeysRole, "globalKeys"}};
}

int HotkeyModel::rowOf(const QString& option) const
{
    for (int i = 0; i < m_rows.size(); i++)
        if (m_rows[i].option == option)
            return i;
    return -1;
}

QVariantMap HotkeyModel::rowAt(int row) const
{
    if (row < 0 || row >= m_rows.size())
        return {};
    const HotkeyRow& r = m_rows.at(row);
    return {{"option", r.option}, {"label", r.label}, {"keys", r.keys}, {"globalKeys", r.globalKeys}, {"hasGlobal", !r.globalOption.isEmpty()}};
}

QString& HotkeyModel::cell(int row, bool global)
{
    return global ? m_rows[row].globalKeys : m_rows[row].keys;
}

int HotkeyModel::conflictRow(const QString& key, int row, bool global) const
{
    for (int i = 0; i < m_rows.size(); i++)
        if (i != row && (global ? m_rows[i].globalKeys : m_rows[i].keys).split('\t', Qt::SkipEmptyParts).contains(key))
            return i;
    return -1;
}

QString HotkeyModel::conflict(const QString& key, int row, bool global) const
{
    const int i = conflictRow(key, row, global);
    return i < 0 ? QString{} : m_rows[i].label;
}

void HotkeyModel::setCell(int row, bool global, const QString& keys)
{
    if (cell(row, global) == keys)
        return;
    cell(row, global) = keys;
    const QModelIndex i = index(row);
    emit dataChanged(i, i, {global ? GlobalKeysRole : KeysRole});
}

void HotkeyModel::assign(int row, bool global, const QString& key)
{
    if (row < 0 || row >= m_rows.size())
        return;
    for (int i = 0; i < m_rows.size(); i++)
    {
        if (i == row)
            continue;
        QStringList keys = cell(i, global).split('\t', Qt::SkipEmptyParts);
        if (keys.removeAll(key))
            setCell(i, global, keys.join('\t'));
    }
    setCell(row, global, key);
    updateDirty();
}

void HotkeyModel::clear(int row, bool global)
{
    if (row < 0 || row >= m_rows.size())
        return;
    setCell(row, global, {});
    updateDirty();
}

void HotkeyModel::updateDirty()
{
    bool dirty = false;
    for (int i = 0; i < m_rows.size() && !dirty; i++)
        dirty = m_rows[i].keys != m_saved[i].keys || m_rows[i].globalKeys != m_saved[i].globalKeys;
    if (dirty == m_dirty)
        return;
    m_dirty = dirty;
    emit dirtyChanged();
}

QString HotkeyModel::keyFromEvent(int qtKey, int modifiers, const QString& text) const
{
    QKeyEvent e(QEvent::KeyPress, qtKey, Qt::KeyboardModifiers(modifiers), text);
    return VLCKeyToString(qtEventToVLCKey(&e), false);
}

QString HotkeyModel::displayKeys(const QString& keys)
{
    QStringList l = keys.split('\t', Qt::SkipEmptyParts);
    l.replaceInStrings(QRegularExpression("^Esc$"), "esc");
    return l.join(", ");
}

void HotkeyModel::save()
{
    for (int i = 0; i < m_rows.size(); i++)
    {
        if (m_rows[i].keys != m_saved[i].keys)
            config_PutPsz(qtu(m_rows[i].option), qtu(m_rows[i].keys));
        if (!m_rows[i].globalOption.isEmpty() && m_rows[i].globalKeys != m_saved[i].globalKeys)
            config_PutPsz(qtu(m_rows[i].globalOption), qtu(m_rows[i].globalKeys));
    }
    config_SaveConfigFile(m_intf);
    m_saved = m_rows;
    updateDirty();
}
