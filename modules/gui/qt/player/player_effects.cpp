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
#include "player_effects.hpp"

#include "player/player_controller.hpp"
#include "player/effects_util.hpp"
#include "../../../audio_filter/equalizer_presets.h"

#include <vlc_aout.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_player.h>
#include <vlc_plugin.h>
#include <vlc_vout.h>

#include <QColor>
#include <algorithm>

PlayerEffects::PlayerEffects(qt_intf_t* intf, PlayerController* player, QObject* parent)
    : QObject(parent), m_intf(intf), m_player(player)
{
    connect(player, &PlayerController::voutListChanged, this, &PlayerEffects::outputsChanged);
    connect(player, &PlayerController::inputChanged, this, &PlayerEffects::outputsChanged);
    connect(this, &PlayerEffects::outputsChanged, this, &PlayerEffects::touch);
}

void PlayerEffects::touch() { ++m_revision; emit changed(); }

bool PlayerEffects::hasVideo() const { return !m_player->getVouts().isEmpty(); }
bool PlayerEffects::hasAudio() const { return m_player->getAout() != nullptr; }

QStringList PlayerEffects::equalizerPresets() const
{
    QStringList out;
    for (int i = 0; i < NB_PRESETS; ++i)
        out << qfut(preset_list_text[i]);
    return out;
}

PlayerEffects::Kind PlayerEffects::kindOf(const QString& module, const char** varName) const
{
    module_t* m = module_find(qtu(module));
    if (!m) { msg_Err(m_intf, "Unable to find filter module \"%s\".", qtu(module)); return Kind::None; }
    const char* var = nullptr;
    Kind kind = Kind::Video;
    if (module_provides(m, "audio filter")) { var = "audio-filter"; kind = Kind::Audio; }
    else if (module_provides(m, "video filter")) var = "video-filter";
    else if (module_provides(m, "sub source")) var = "sub-source";
    else if (module_provides(m, "sub filter")) var = "sub-filter";
    else return Kind::None;
    if (varName) *varName = var;
    return kind;
}

static QString configString(const char* name)
{
    char* s = config_GetPsz(name);
    QString out = qfu(s ? s : "");
    free(s);
    return out;
}

bool PlayerEffects::filterEnabled(const QString& module) const
{
    const char* var = nullptr;
    const Kind kind = kindOf(module, &var);
    if (kind == Kind::None) return false;
    QString list;
    const auto vouts = m_player->getVouts();
    if (kind == Kind::Video && !vouts.isEmpty())
    {
        char* s = var_GetString(vouts.first().get(), var);
        list = qfu(s ? s : "");
        free(s);
    }
    else
        list = configString(var);
    return list.split(':', Qt::SkipEmptyParts).contains(module);
}

void PlayerEffects::setFilterEnabled(const QString& module, bool on)
{
    const char* var = nullptr;
    const Kind kind = kindOf(module, &var);
    if (kind == Kind::None) return;
    if (kind == Kind::Audio)
        vlc_player_aout_EnableFilter(m_player->getPlayer(), qtu(module), on);
    else
        for (const auto& vout : m_player->getVouts())
        {
            char* s = var_GetString(vout.get(), var);
            const QString list = effects::toggleModule(qfu(s ? s : ""), module, on);
            free(s);
            var_SetString(vout.get(), var, qtu(list));
        }
    config_PutPsz(var, qtu(effects::toggleModule(configString(var), module, on)));
    touch();
}

static QVariant readVar(vlc_object_t* obj, const char* name, int type)
{
    switch (type)
    {
    case VLC_VAR_FLOAT:   return var_GetFloat(obj, name);
    case VLC_VAR_INTEGER: return QVariant::fromValue<qlonglong>(var_GetInteger(obj, name));
    case VLC_VAR_BOOL:    return bool(var_GetBool(obj, name));
    case VLC_VAR_STRING: { char* s = var_GetString(obj, name); QString v = qfu(s ? s : ""); free(s); return v; }
    }
    return {};
}

QVariant PlayerEffects::configValue(const QString& name) const
{
    switch (config_GetType(qtu(name)))
    {
    case VLC_VAR_FLOAT:   return config_GetFloat(qtu(name));
    case VLC_VAR_INTEGER: return QVariant::fromValue<qlonglong>(config_GetInt(qtu(name)));
    case VLC_VAR_BOOL:    return config_GetInt(qtu(name)) != 0;
    case VLC_VAR_STRING:  return configString(qtu(name));
    }
    return {};
}

QVariant PlayerEffects::value(const QString& name) const
{
    const int type = config_GetType(qtu(name));
    if (auto aout = m_player->getAout(); aout && var_Type(aout.get(), qtu(name)))
        return readVar(VLC_OBJECT(aout.get()), qtu(name), type);
    const auto vouts = m_player->getVouts();
    if (!vouts.isEmpty() && var_Type(vouts.first().get(), qtu(name)))
        return readVar(VLC_OBJECT(vouts.first().get()), qtu(name), type);
    return configValue(name);
}

static vlc_value_t toVlcValue(const QVariant& v, int type, QByteArray& keep)
{
    vlc_value_t val{};
    switch (type)
    {
    case VLC_VAR_FLOAT:   val.f_float = v.toFloat(); break;
    case VLC_VAR_BOOL:    val.b_bool = v.toBool(); break;
    case VLC_VAR_STRING:  keep = v.toString().toUtf8(); val.psz_string = keep.data(); break;
    case VLC_VAR_INTEGER:
        // colour options take "#RRGGBB" from the text fields
        if (v.typeId() == QMetaType::QString && v.toString().startsWith('#'))
            val.i_int = QColor(v.toString()).rgb() & 0xFFFFFF;
        else
            val.i_int = v.toLongLong();
        break;
    }
    return val;
}

void PlayerEffects::setConfigValue(const QString& name, const QVariant& v)
{
    const int type = config_GetType(qtu(name));
    QByteArray keep;
    const vlc_value_t val = toVlcValue(v, type, keep);
    switch (type)
    {
    case VLC_VAR_FLOAT:   config_PutFloat(qtu(name), val.f_float); break;
    case VLC_VAR_BOOL:    config_PutInt(qtu(name), val.b_bool); break;
    case VLC_VAR_INTEGER: config_PutInt(qtu(name), val.i_int); break;
    case VLC_VAR_STRING:  config_PutPsz(qtu(name), val.psz_string); break;
    default: msg_Warn(m_intf, "no config option \"%s\"", qtu(name)); return;
    }
    touch();
}

void PlayerEffects::setValue(const QString& name, const QVariant& v)
{
    const int type = config_GetType(qtu(name));
    QByteArray keep;
    const vlc_value_t val = toVlcValue(v, type, keep);
    if (auto aout = m_player->getAout(); aout && var_Type(aout.get(), qtu(name)))
        var_SetChecked(aout.get(), qtu(name), type, val);
    for (const auto& vout : m_player->getVouts())
        if (var_Type(vout.get(), qtu(name)))
            var_SetChecked(vout.get(), qtu(name), type, val);
    setConfigValue(name, v);
}

double PlayerEffects::equalizerBand(int band) const
{
    const auto bands = effects::parseBands(value("equalizer-bands").toString());
    return band >= 0 && band < effects::EQZ_BANDS ? bands[band] : 0.;
}

void PlayerEffects::setEqualizerBand(int band, double db)
{
    if (band < 0 || band >= effects::EQZ_BANDS) return;
    auto bands = effects::parseBands(value("equalizer-bands").toString());
    bands[band] = std::clamp(float(db), -20.f, 20.f);
    setValue("equalizer-bands", effects::formatBands(bands));
    setValue("equalizer-preset", QString());
}

int PlayerEffects::equalizerPresetIndex() const
{
    const QString p = value("equalizer-preset").toString();
    for (int i = 0; i < NB_PRESETS; ++i)
        if (p == QLatin1String(preset_list[i])) return i;
    return -1;
}

void PlayerEffects::applyEqualizerPreset(int index)
{
    if (index < 0 || index >= NB_PRESETS) return;
    const eqz_preset_t& p = eqz_preset_10b[index];
    setValue("equalizer-preamp", p.f_preamp);
    setValue("equalizer-bands", effects::formatBands(QVector<float>(p.f_amp, p.f_amp + effects::EQZ_BANDS)));
    setValue("equalizer-preset", QString::fromLatin1(preset_list[index]));
}

int PlayerEffects::transformFlip() const
{
    return filterEnabled("transform") ? effects::parseTransform(configString("transform-type")).first : 0;
}

int PlayerEffects::transformRotation() const
{
    return filterEnabled("transform") ? effects::parseTransform(configString("transform-type")).second : 0;
}

void PlayerEffects::setTransform(int flip, int rotation)
{
    const QString type = effects::transformType(flip, rotation);
    setFilterEnabled("transform", false);
    if (type.isEmpty()) return;
    config_PutPsz("transform-type", qtu(type));
    setFilterEnabled("transform", true);
}

int PlayerEffects::voutCrop(const QString& side) const
{
    const auto vouts = m_player->getVouts();
    return vouts.isEmpty() ? 0 : int(var_GetInteger(vouts.first().get(), qtu("crop-" + side)));
}

void PlayerEffects::setVoutCrop(const QString& side, int px)
{
    for (const auto& vout : m_player->getVouts())
        var_SetInteger(vout.get(), qtu("crop-" + side), std::max(0, px));
    touch();
}

int PlayerEffects::subtitleTextScale() const
{
    vlc_player_t* p = m_player->getPlayer();
    vlc_player_Lock(p);
    const unsigned s = vlc_player_GetSubtitleTextScale(p);
    vlc_player_Unlock(p);
    return int(s);
}

void PlayerEffects::setSubtitleTextScale(int percent)
{
    const unsigned s = unsigned(std::clamp(percent, 10, 500));
    vlc_player_t* p = m_player->getPlayer();
    vlc_player_Lock(p);
    vlc_player_SetSubtitleTextScale(p, s);
    vlc_player_Unlock(p);
    config_PutInt("sub-text-scale", s);
    touch();
}

void PlayerEffects::resetToDefaults(const QStringList& names, const QStringList& modules)
{
    for (const QString& name : names)
    {
        module_config_t* c = config_FindConfig(qtu(name));
        if (!c) continue;
        if (IsConfigFloatType(c->i_type))        setValue(name, c->orig.f);
        else if (IsConfigIntegerType(c->i_type)) setValue(name, QVariant::fromValue<qlonglong>(c->orig.i));
        else if (IsConfigStringType(c->i_type))  setValue(name, qfu(c->orig.psz ? c->orig.psz : ""));
    }
    for (const QString& m : modules)
        setFilterEnabled(m, false);
}
