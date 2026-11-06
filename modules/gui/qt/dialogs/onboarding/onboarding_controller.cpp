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
#include "onboarding_controller.hpp"
#include "onboarding_folders.hpp"

#include "maininterface/mainctx.hpp"
#include "medialibrary/medialib.hpp"
#include "util/color_scheme_model.hpp"

#include <QDir>
#include <QFileDialog>
#include <QUrl>

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_cxx_helpers.hpp>
#include <vlc_media_library.h>

static QString userDir(vlc_userdir_t kind)
{
    auto dir = vlc::wrap_cptr(config_GetUserDir(kind));
    return dir ? QDir::cleanPath(qfu(dir.get())) : QString();
}

OnboardingController::OnboardingController(qt_intf_t* intf, QObject* parent)
    : QObject(parent), m_intf(intf)
{
}

bool OnboardingController::hasMediaLibrary() const
{
    return vlc_ml_instance_get(m_intf) != nullptr;
}

QString OnboardingController::defaultFolder() const
{
    const QString videos = userDir(VLC_VIDEOS_DIR);
    return QFileInfo(videos).isDir() ? onboarding::displayPath(videos, QDir::homePath()) : QString();
}

// the effective value, command line included
QString OnboardingController::currentAccent() const
{
    auto accent = vlc::wrap_cptr(var_InheritString(m_intf, "qt-accent-color"));
    return accent ? QString::fromUtf8(accent.get()) : QStringLiteral("default");
}

bool OnboardingController::folderValid(const QString& text) const
{
    return onboarding::fieldValid(text, QDir::homePath());
}

QString OnboardingController::pickFolder(const QString& text)
{
    const QString home = QDir::homePath();
    const QString start = onboarding::expandHome(text, home);
    const QString dir = QFileDialog::getExistingDirectory(nullptr, qtr("Choose a folder"),
                                                         start.isEmpty() ? home : start);
    return dir.isEmpty() ? QString() : onboarding::displayPath(QDir::cleanPath(dir), home);
}

void OnboardingController::addFolder(const QString& path)
{
    MediaLib* ml = m_intf->p_mi->getMediaLibrary();
    if (!ml)
        return;
    const QUrl url = QUrl::fromLocalFile(path);
    // same call as DialogsProvider::addFolderToLibrary
    ml->runOnMLThread(this, [url](vlc_medialibrary_t* p_ml) {
        vlc_ml_add_folder(p_ml, qtu(url.toString(QUrl::FullyEncoded)));
    }, "ML_FOLDER_ADD_QUEUE");
}

void OnboardingController::markDone()
{
    config_PutInt("qt-privacy-ask", 0);
    if (MediaLib* ml = m_intf->p_mi->getMediaLibrary())
        ml->reload();
    config_SaveConfigFile(m_intf);
}

void OnboardingController::finish(int scheme, const QString& accent, const QString& folderText)
{
    MainCtx* mi = m_intf->p_mi;
    mi->getColorScheme()->setScheme(static_cast<ColorSchemeModel::ColorScheme>(scheme));
    config_PutPsz("qt-accent-color", qtu(accent));

    if (hasMediaLibrary())
    {
        const QString music = userDir(VLC_MUSIC_DIR);
        const QStringList folders = onboarding::foldersToAdd(
            onboarding::expandHome(folderText, QDir::homePath()),
            QFileInfo(music).isDir() ? music : QString());
        for (const QString& f : folders)
            addFolder(f);
    }

    markDone();
    mi->reloadAccentColor();
}

void OnboardingController::skip()
{
    markDone();
}
