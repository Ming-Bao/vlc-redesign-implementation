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
#ifndef VLC_QT_HOTKEY_MODEL_HPP
#define VLC_QT_HOTKEY_MODEL_HPP

#include <QAbstractListModel>
#include <QVariantMap>
#include <QVector>

typedef struct qt_intf_t qt_intf_t;

struct HotkeyRow
{
    QString option;       // "key-..."
    QString globalOption; // "global-key-...", empty when the build has none
    QString label, longText;
    QString keys, globalKeys; // VLC key names, tab separated
};

// The key-* options of the main module, one row per action, with its hotkey and global hotkey cells.
// Edits stay in the model until save() (DialogsProvider.loadHotkeyModel() gives the dialog a fresh one each time it opens)
class HotkeyModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(bool dirty READ dirty NOTIFY dirtyChanged FINAL)

public:
    enum Roles { OptionRole = Qt::UserRole + 1, LabelRole, LongTextRole, KeysRole, GlobalKeysRole };

    // loads from the main module; intf is only needed by save()
    explicit HotkeyModel(qt_intf_t* intf, QObject* parent = nullptr);
    // for tests
    explicit HotkeyModel(QVector<HotkeyRow> rows, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool dirty() const { return m_dirty; }

    Q_INVOKABLE int rowOf(const QString& option) const;
    // { option, label, keys, globalKeys, hasGlobal } of a row, for delegates that are not driven by the model's roles
    Q_INVOKABLE QVariantMap rowAt(int row) const;
    // the other row that has key in this column, or -1
    Q_INVOKABLE int conflictRow(const QString& key, int row, bool global) const;
    // the label of that row, or empty
    Q_INVOKABLE QString conflict(const QString& key, int row, bool global) const;
    // replaces the cell with key alone and removes key from every other row of the column
    Q_INVOKABLE void assign(int row, bool global, const QString& key);
    Q_INVOKABLE void clear(int row, bool global);
    Q_INVOKABLE QString keyFromEvent(int qtKey, int modifiers, const QString& text) const;
    // "Esc\tq" -> "esc, q"
    Q_INVOKABLE static QString displayKeys(const QString& keys);
    // writes the changed cells; they apply on the next start
    Q_INVOKABLE void save();

signals:
    void dirtyChanged();

private:
    QString& cell(int row, bool global);
    void setCell(int row, bool global, const QString& keys);
    void updateDirty();

    qt_intf_t* m_intf = nullptr;
    QVector<HotkeyRow> m_rows;
    QVector<HotkeyRow> m_saved; // the values as loaded or last saved
    bool m_dirty = false;
};

#endif
