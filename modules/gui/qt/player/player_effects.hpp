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
#ifndef VLC_QT_PLAYER_EFFECTS_HPP
#define VLC_QT_PLAYER_EFFECTS_HPP

#include <QHash>
#include <QObject>
#include <QPair>
#include <QStringList>
#include <QVariant>

#include "qt.hpp"

class PlayerController;

// live audio/video/subtitle effects for the player's settings panel (QML singleton "Effects")
class PlayerEffects : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool hasVideo READ hasVideo NOTIFY outputsChanged FINAL)
    Q_PROPERTY(bool hasAudio READ hasAudio NOTIFY outputsChanged FINAL)
    Q_PROPERTY(QStringList equalizerPresets READ equalizerPresets CONSTANT FINAL)
    Q_PROPERTY(int revision READ revision NOTIFY changed FINAL)

public:
    PlayerEffects(qt_intf_t* intf, PlayerController* player, QObject* parent = nullptr);

    bool hasVideo() const;
    bool hasAudio() const;
    QStringList equalizerPresets() const;
    int revision() const { return m_revision; }

    Q_INVOKABLE bool filterEnabled(const QString& module) const;
    Q_INVOKABLE void setFilterEnabled(const QString& module, bool on);
    Q_INVOKABLE QVariant value(const QString& name) const;
    Q_INVOKABLE void setValue(const QString& name, const QVariant& v);
    Q_INVOKABLE QVariant configValue(const QString& name) const;
    Q_INVOKABLE void setConfigValue(const QString& name, const QVariant& v);

    Q_INVOKABLE double equalizerBand(int band) const;
    // re-read every binding that follows `revision` (values may change while the panel is closed)
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setEqualizerBand(int band, double db);
    Q_INVOKABLE int equalizerPresetIndex() const;
    Q_INVOKABLE void applyEqualizerPreset(int index);

    Q_INVOKABLE int transformFlip() const;
    Q_INVOKABLE int transformRotation() const;
    Q_INVOKABLE void setTransform(int flip, int rotation);

    Q_INVOKABLE int voutCrop(const QString& side) const;
    Q_INVOKABLE void setVoutCrop(const QString& side, int px);

    Q_INVOKABLE int subtitleTextScale() const;
    Q_INVOKABLE void setSubtitleTextScale(int percent);

    Q_INVOKABLE void resetToDefaults(const QStringList& names, const QStringList& modules);

signals:
    void outputsChanged();
    void changed();

private:
    enum class Kind { None, Audio, Video };
    Kind kindOf(const QString& module, const char** varName = nullptr) const;
    void touch();
    mutable QHash<QString, QPair<Kind, const char*>> m_kindCache;   // per module: module_find is costly and logs when missing

    qt_intf_t* m_intf;
    PlayerController* m_player;
    int m_revision = 0;
};

#endif
