/*****************************************************************************
 * menus.cpp : Qt menus
 *****************************************************************************
 * Copyright © 2006-2011 the VideoLAN team
 *
 * Authors: Clément Stenac <zorglub@videolan.org>
 *          Jean-Baptiste Kempf <jb@videolan.org>
 *          Jean-Philippe André <jpeg@videolan.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
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

/** \todo
 * - Remove static currentGroup
 */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <vlc_common.h>
#include <vlc_intf_strings.h>
#include <vlc_aout.h>                             /* audio_output_t */
#include <vlc_interface.h>

#include "menus.hpp"

#include "maininterface/mainctx.hpp"                     /* View modifications */
#include "maininterface/mainctx_submodels.hpp"
#include "dialogs/dialogs_provider.hpp"                   /* Dialogs display */
#include "dialogs/help/help.hpp"
#include "player/player_controller.hpp"                      /* Input Management */
#include "playlist/playlist_controller.hpp"
#include "dialogs/extensions/extensions_manager.hpp"                 /* Extensions menu */
#include "dialogs/extended/extended_panels.hpp"
#include "dialogs/systray/systray.hpp"
#include "dialogs/toolbar/controlbar_profile_model.hpp"
#include "dialogs/preferences/simple_preferences.hpp"
#include "util/varchoicemodel.hpp"
#include "util/color_scheme_model.hpp"
#include "util/colorizedsvgicon.hpp"
#include "style/menustyle.hpp"
#include "medialibrary/medialib.hpp"
#include "medialibrary/mlrecentmediamodel.hpp"
#include "medialibrary/mlbookmarkmodel.hpp"


#include <QMenu>
#include <QMenuBar>
#include <QAction>
#include <QActionGroup>
#include <QSignalMapper>

using namespace vlc::playlist;

/*
  This file defines the main menus and the pop-up menu (right-click menu)
  and the systray menu (in that order in the file)

  There are 4 menus that have to be rebuilt every time there are called:
  Audio, Video, Navigation, view
  4 functions are building those menus: AudioMenu, VideoMenu, NavigMenu, View

  */

RendererMenu *VLCMenuBar::rendererMenu = NULL;

/**
 * @brief Add static entries to DP in menus
 **/
template<typename Functor>
QAction *addDPStaticEntry( QMenu *menu,
                       const QString& text,
                       const char *icon,
                       const Functor member,
                       const char *shortcut = NULL,
                       QAction::MenuRole role = QAction::NoRole
                       )
{
    QAction *action = NULL;
#ifndef __APPLE__ /* We don't set icons in menus in MacOS X */
    if( !EMPTY_STR( icon ) )
    {
        action = menu->addAction( ColorizedSvgIcon::colorizedIconForWidget( icon, menu ), text, THEDP, member );
    }
    else
#endif
    {
        action = menu->addAction( text, THEDP, member );
    }
    if( !EMPTY_STR( shortcut ) )
        action->setShortcut( qfut( shortcut ) );
#ifdef __APPLE__
    action->setMenuRole( role );
#else
    Q_UNUSED( role );
#endif
    return action;
}

/**
 * @brief DP entry with one of the redesign's icons: already two-tone, so a plain QIcon
 **/
template<typename Functor>
static QAction *addDPIconEntry( QMenu *menu, const QString& text, const char *icon,
                                const Functor member, const char *shortcut = nullptr,
                                QAction::MenuRole role = QAction::NoRole )
{
    QAction *a = addDPStaticEntry( menu, text, "", member, shortcut, role );
    a->setIcon( QIcon( icon ) );
    return a;
}

/**
 * @brief Add static entries to MIM in menus
 **/
template<typename Fun>
static QAction* addMIMStaticEntry( qt_intf_t *p_intf,
                            QMenu *menu,
                            const QString& text,
                            const char *icon,
                            Fun member )
{
    QAction *action;
#ifndef __APPLE__ /* We don't set icons in menus in MacOS X */
    if( !EMPTY_STR( icon ) )
    {
        action = menu->addAction( text, THEMIM,  member );
        action->setIcon( ColorizedSvgIcon::colorizedIconForWidget( icon, menu ) );
    }
    else
#endif
    {
        action = menu->addAction( text, THEMIM, member );
    }
    return action;
}

/*****************************************************************************
 * All normal menus
 * Simple Code
 *****************************************************************************/

/**
 * Main Menu Bar Creation
 **/
VLCMenuBar::VLCMenuBar(QObject* parent)
    : QObject(parent)
{}


/**
 * Media ( File ) Menu
 * Opening, streaming and quit
 **/
void VLCMenuBar::FileMenu(qt_intf_t *p_intf, QMenu *menu)
{
    auto mi = p_intf->p_mi;
    QAction *action;

    //use a lambda here as the Triggrered signal is emiting and it will pass false (checked) as a first argument
    addDPStaticEntry( menu, qtr( "Open &File..." ),
        ":/menu/file.svg", []() { THEDP->simpleOpenDialog(); } , "Ctrl+O" );
    addDPStaticEntry( menu, qtr( "&Open Multiple Files..." ),
        ":/menu/file.svg", &DialogsProvider::openFileDialog, "Ctrl+Shift+O" );
    addDPStaticEntry( menu, qfut( I_OP_OPDIR ),
        ":/menu/folder.svg", &DialogsProvider::PLOpenDir, "Ctrl+F" );
    addDPStaticEntry( menu, qtr( "Open &Disc..." ),
        ":/menu/disc.svg", &DialogsProvider::openDiscDialog, "Ctrl+D" );
    addDPStaticEntry( menu, qtr( "Open &Network Stream..." ),
        ":/menu/network.svg", &DialogsProvider::openNetDialog, "Ctrl+N" );
    addDPStaticEntry( menu, qtr( "Open &Capture Device..." ),
        ":/menu/capture-card.svg", &DialogsProvider::openCaptureDialog, "Ctrl+C" );

    addDPStaticEntry( menu, qtr( "Open &Location from clipboard" ),
                      NULL, &DialogsProvider::openUrlDialog, "Ctrl+V" );

    if( mi && var_InheritBool( p_intf, "save-recentplay" ) && mi->hasMediaLibrary() )
    {
        MLRecentMediaModel* recentModel = new MLRecentMediaModel(nullptr);
        recentModel->setMl(mi->getMediaLibrary());
        recentModel->setLimit(10);
        QMenu* recentsMenu = new RecentMenu(recentModel, mi->getMediaLibrary(), menu);
        recentsMenu->setTitle(qtr( "Open &Recent Media" ) );
        recentModel->setParent(recentsMenu);
        menu->addMenu( recentsMenu );
    }

    menu->addSeparator();

    addDPStaticEntry( menu, qfut( I_PL_SAVE ), "", &DialogsProvider::savePlayingToPlaylist,
        "Ctrl+Y" );

    addDPStaticEntry( menu, qtr( "Conve&rt / Save..." ), "",
        &DialogsProvider::openAndTranscodingDialogs, "Ctrl+R" );
    addDPStaticEntry( menu, qtr( "&Stream..." ),
        ":/menu/stream.svg", &DialogsProvider::openAndStreamingDialogs, "Ctrl+S" );
    menu->addSeparator();

    action = menu->addAction( qtr( "Quit at the end of play queue" ), [playlist = THEMPL](bool checked){
        if (checked)
            playlist->setMediaStopAction(PlaylistController::MEDIA_STOPPED_EXIT);
        else
            playlist->setMediaStopAction(PlaylistController::MEDIA_STOPPED_CONTINUE);
    });
    action->setCheckable( true );
    action->setChecked( THEMPL->getMediaStopAction() ==  PlaylistController::MEDIA_STOPPED_EXIT);

    VLCSystray* systray = mi ? mi->getSysTray() : nullptr;
    if( systray )
    {
        action = menu->addAction( qtr( "Close to systray"), systray,
                                 &VLCSystray::toggleUpdateMenu );
    }

    addDPStaticEntry( menu, qtr( "&Quit" ) ,
        ":/menu/exit.svg", &DialogsProvider::quit, "Ctrl+Q" );
}

/**
 * Flat main ("…") menu of the redesigned interface
 **/
void VLCMenuBar::MainMenu( qt_intf_t *p_intf, QMenu *menu, std::function<void()> onDiscover )
{
    auto mi = p_intf->p_mi;

    auto entry = [menu]( const QString &text, const char *icon, auto member,
                         const char *shortcut = nullptr,
                         QAction::MenuRole role = QAction::NoRole )
    {
        return addDPIconEntry( menu, text, icon, member, shortcut, role );
    };

    entry( qtr( "Open &File(s)" ), ":/redesign/menu/open-file.svg",
           []() { THEDP->simpleOpenDialog(); }, "Ctrl+O" );
    entry( qtr( "Open F&older" ), ":/redesign/menu/open-folder.svg",
           &DialogsProvider::PLOpenDir, "Ctrl+F" );
    entry( qtr( "Open &Network Stream" ), ":/redesign/menu/open-network.svg",
           &DialogsProvider::openNetDialog, "Ctrl+N" );
    entry( qtr( "Open &Disc" ), ":/redesign/menu/open-disc.svg",
           &DialogsProvider::openDiscDialog, "Ctrl+D" );
    entry( qtr( "Open &Capture Device" ), ":/redesign/menu/open-capture.svg",
           &DialogsProvider::openCaptureDialog, "Ctrl+C" );
    entry( qtr( "Con&vert" ), ":/redesign/menu/convert.svg",
           &DialogsProvider::openAndTranscodingDialogs, "Ctrl+R" );

    if( mi && var_InheritBool( p_intf, "save-recentplay" ) && mi->hasMediaLibrary() )
    {
        MLRecentMediaModel* recentModel = new MLRecentMediaModel(nullptr);
        recentModel->setMl(mi->getMediaLibrary());
        recentModel->setLimit(10);
        QMenu* recentsMenu = new RecentMenu(recentModel, mi->getMediaLibrary(), menu);
        recentsMenu->setTitle(qtr( "Open &Recent" ) );
        recentsMenu->menuAction()->setIcon( QIcon( ":/redesign/menu/open-recent.svg" ) );
        recentModel->setParent(recentsMenu);
        menu->addMenu( recentsMenu );
    }

    menu->addSeparator();

    /* Profiles are the control bar layouts of Customize Player */
    if( ControlbarProfileModel *profiles = mi ? mi->controlbarProfileModel() : nullptr )
    {
        const int selected = profiles->selectedProfile();
        /* a lone '&' is a mnemonic marker, so it is doubled to show */
        auto profileName = [profiles]( int row ) {
            return profiles->data( profiles->index( row ), Qt::DisplayRole )
                       .toString().replace( '&', QStringLiteral( "&&" ) );
        };
        const QString current = profileName( selected );
        QMenu *profileMenu = menu->addMenu( current.isEmpty()
            ? qtr( "&Profile" ) : qtr( "&Profile (%1)" ).arg( current ) );
        profileMenu->menuAction()->setIcon( QIcon( ":/redesign/menu/profile.svg" ) );
        auto *group = new QActionGroup( profileMenu );
        group->setExclusive( true );
        for( int row = 0; row < profiles->rowCount(); ++row )
        {
            QAction *a = profileMenu->addAction( profileName( row ) );
            a->setCheckable( true );
            a->setChecked( row == selected );
            group->addAction( a );
            connect( a, &QAction::triggered, profiles, [profiles, row]() {
                profiles->setSelectedProfile( row );
            } );
        }
        profileMenu->addSeparator();
        QAction *add = addDPStaticEntry( profileMenu, qtr( "&New" ), "",
                                         &DialogsProvider::showToolbarEditorDialog );
        add->setIcon( QIcon( ":/redesign/menu/add.svg" ) );
    }

    entry( qtr( "&Keyboard Shortcuts" ), ":/redesign/menu/keyboard.svg",
           []() { THEDP->prefsDialog( SPrefsHotkeys ); } );
    if( !p_intf->b_isDialogProvider )
        entry( qtr( "Customi&ze Player" ), ":/redesign/menu/customize.svg",
               &DialogsProvider::showToolbarEditorDialog );
    entry( qtr( "&Settings" ), ":/redesign/menu/settings.svg",
           QOverload<>::of(&DialogsProvider::prefsDialog), "Ctrl+P", QAction::PreferencesRole );
    entry( qtr( "&About VLC" ), ":/redesign/menu/about.svg",
           &DialogsProvider::aboutDialog, "Shift+F1", QAction::AboutRole );

    /* Everything the redesign does not list stays reachable */
    menu->addSeparator();
    QMenu* more = menu->addMenu( qtr( "&More" ) );
    /* Discover left the redesign's sidebar; the QML side shows the page */
    if( onDiscover )
    {
        more->addAction( qtr( "&Discover" ), onDiscover );
        more->addSeparator();
    }
    FileMenu( p_intf, more->addMenu( qtr( "&Media" ) ) );
    NavigMenu( p_intf, more->addMenu( qtr( "P&layback" ) ) );
    AudioMenu( p_intf, more->addMenu( qtr( "&Audio" ) ) );
    VideoMenu( p_intf, more->addMenu( qtr( "&Video" ) ) );
    SubtitleMenu( p_intf, more->addMenu( qtr( "Subti&tle" ) ) );
    ToolsMenu( p_intf, more->addMenu( qtr( "Tool&s" ) ) );
    ViewMenu( p_intf, more->addMenu( qtr( "V&iew" ) ) );
    HelpMenu( p_intf, more->addMenu( qtr( "&Help" ) ) );
}

/**
 * Tools, like Media Information, Preferences or Messages
 **/
void VLCMenuBar::ToolsMenu( qt_intf_t *p_intf, QMenu *menu )
{
    addDPStaticEntry( menu, qtr( "&Effects and Filters"), ":/menu/ic_fluent_options.svg",
            &DialogsProvider::extendedDialog, "Ctrl+E" );

    addDPStaticEntry( menu, qtr( "&Track Synchronization"), ":/menu/ic_fluent_options.svg",
            &DialogsProvider::synchroDialog, "" );

    addDPStaticEntry( menu, qfut( I_MENU_INFO ) , ":/menu/info.svg",
        QOverload<>::of(&DialogsProvider::mediaInfoDialog), "Ctrl+I" );

    addDPStaticEntry( menu, qfut( I_MENU_CODECINFO ) ,
        ":/menu/info.svg", &DialogsProvider::mediaCodecDialog, "Ctrl+J" );

#ifdef ENABLE_VLM
    addDPStaticEntry( menu, qfut( I_MENU_VLM ), "", &DialogsProvider::vlmDialog,
        "Ctrl+Shift+W" );
#endif

    addDPStaticEntry( menu, qtr( "Program Guide" ), "", &DialogsProvider::epgDialog,
        "" );

    addDPStaticEntry( menu, qfut( I_MENU_MSG ),
        ":/menu/messages.svg", &DialogsProvider::messagesDialog, "Ctrl+M" );

    addDPStaticEntry( menu, qtr( "Plu&gins and extensions" ),
        "", &DialogsProvider::pluginDialog );
    menu->addSeparator();

    if( !p_intf->b_isDialogProvider )
        addDPStaticEntry( menu, qtr( "Customi&ze Interface..." ),
            ":/menu/preferences.svg", &DialogsProvider::showToolbarEditorDialog);

    addDPStaticEntry( menu, qtr( "&Preferences" ),
        ":/menu/preferences.svg", QOverload<>::of(&DialogsProvider::prefsDialog), "Ctrl+P", QAction::PreferencesRole );
}

/**
 * View Menu
 * Interface modification, load other interfaces, activate Extensions
 * \param menu, a fresh menu
 **/
void VLCMenuBar::ViewMenu(qt_intf_t *p_intf, QMenu *menu)
{
    QAction *action;

    MainCtx *mi = p_intf->p_mi;
    assert( mi );
    assert(menu);

    action = menu->addAction(
#ifndef __APPLE__
            ColorizedSvgIcon::colorizedIconForWidget( ":/menu/ic_playlist.svg", menu ),
#endif
            qtr( "Play &Queue" ));
    action->setShortcut(QString( "Ctrl+L" ));
    action->setCheckable( true );
    connect( action, &QAction::triggered, mi->getPlayqueuePanel(), &SidePanelCtx::setVisible );
    action->setChecked( mi->getPlayqueuePanel()->isVisible() );

    /* Docked Play Queue */
    action = menu->addAction( qtr( "Docked Play Queue" ) );
    action->setCheckable( true );
    connect( action, &QAction::triggered, mi->getPlayqueuePanel(), &SidePanelCtx::setDocked );
    action->setChecked( mi->getPlayqueuePanel()->isDocked() );

    menu->addSeparator();

    action = menu->addAction( qtr( "Always on &top" ) );
    action->setCheckable( true );
    action->setChecked( mi->isInterfaceAlwaysOnTop() );
    connect( action, &QAction::triggered, mi, &MainCtx::setInterfaceAlwaysOnTop );

    menu->addSeparator();

    {
        bool isPlayerVisible = mi->getMainInterfaceModes() & MainCtx::MAININTERFACE_MODE_PLAYER;
        action = menu->addAction(qtr("&Big Player View"));
        action->setCheckable( true );
        action->setChecked( isPlayerVisible );
        connect( action, &QAction::triggered, mi, &MainCtx::setPlayerView);
    }

    /* FullScreen View */
    action = menu->addAction( qtr( "&Fullscreen Interface" ), mi,
            &MainCtx::toggleInterfaceFullScreen );
    action->setShortcut( QString( "F11" ) );
    action->setCheckable( true );
    action->setChecked( mi->interfaceVisibility() == QWindow::FullScreen );

    /*Minimal View*/
    action = menu->addAction( qtr( "&Minimal View" ) );
    action->setShortcut(QString( "Ctrl+H" ));
    action->setCheckable( true );
    connect( action, &QAction::triggered, mi, &MainCtx::setMinimalView );
    action->setChecked( mi->isMinimalView() );

    action = menu->addAction( qtr( "&View Items as Grid" ), mi,
            &MainCtx::setGridView );
    action->setCheckable( true );
    action->setChecked( mi->hasGridView() );

    menu->addMenu( new CheckableListMenu(qtr( "&Color Scheme" ), mi->getColorScheme(), QActionGroup::ExclusionPolicy::Exclusive, menu) );

    menu->addSeparator();

    InterfacesMenu( p_intf, menu );
    menu->addSeparator();

    /* Extensions */
    ExtensionsMenu( p_intf, menu );
}

/**
 * Interface Sub-Menu, to list extras interface and skins
 **/
void VLCMenuBar::InterfacesMenu( qt_intf_t *p_intf, QMenu *current )
{
    assert(current);
    VLCVarChoiceModel* model = new VLCVarChoiceModel(VLC_OBJECT(p_intf->intf), "intf-add", current);
    CheckableListMenu* submenu = new CheckableListMenu(qtr("Interfaces"), model, QActionGroup::ExclusionPolicy::None, current);
    current->addMenu(submenu);
}

/**
 * Extensions menu: populate the current menu with extensions
 **/
void VLCMenuBar::ExtensionsMenu( qt_intf_t *p_intf, QMenu *extMenu )
{
    /* Get ExtensionsManager and load extensions if needed */
    ExtensionsManager *extMgr = ExtensionsManager::getInstance( p_intf );

    if( !var_InheritBool( p_intf, "qt-autoload-extensions")
        && !extMgr->isLoaded() )
    {
        return;
    }

    if( !extMgr->isLoaded() && !extMgr->cannotLoad() )
    {
        extMgr->loadExtensions();
    }

    /* Let the ExtensionsManager build itself the menu */
    extMenu->addSeparator();
    extMgr->menu( extMenu );
}

void VLCMenuBar::VolumeEntries( qt_intf_t *p_intf, QMenu *current )
{
    current->addSeparator();

    current->addAction( QIcon( ":/menu/volume-high.svg" ), qtr( "&Increase Volume" ), THEMIM, &PlayerController::setVolumeUp );
    current->addAction( QIcon( ":/menu/volume-low.svg" ), qtr( "&Decrease Volume" ), THEMIM, &PlayerController::setVolumeDown );
    current->addAction( QIcon( ":/menu/volume-muted.svg" ), qtr( "&Mute" ), THEMIM, &PlayerController::toggleMuted );
}

/**
 * Main Audio Menu
 **/
void VLCMenuBar::AudioMenu( qt_intf_t *p_intf, QMenu * current )
{
    if( current->isEmpty() )
    {
        current->addMenu(new CheckableListMenu(qtr( "Audio &Track" ), THEMIM->getAudioTracks(), QActionGroup::ExclusionPolicy::ExclusiveOptional, current));

        current->addMenu(new CheckableListMenu(qtr( "&Audio Device" ), THEMIM->getAudioDevices(), QActionGroup::ExclusionPolicy::Exclusive, current));

        VLCVarChoiceModel *mix_mode = THEMIM->getAudioMixMode();
        if (mix_mode->rowCount() == 0)
            current->addMenu( new CheckableListMenu(qtr( "&Stereo Mode" ), THEMIM->getAudioStereoMode(), QActionGroup::ExclusionPolicy::Exclusive, current) );
        else
            current->addMenu( new CheckableListMenu(qtr( "&Mix Mode" ), mix_mode, QActionGroup::ExclusionPolicy::Exclusive, current) );
        current->addSeparator();

        current->addMenu( new CheckableListMenu(qtr( "&Visualizations" ), THEMIM->getAudioVisualizations(), QActionGroup::ExclusionPolicy::Exclusive, current) );
        VolumeEntries( p_intf, current );
    }
}

/* Subtitles */
void VLCMenuBar::SubtitleMenu( qt_intf_t *p_intf, QMenu *current, bool b_popup )
{
    if( current->isEmpty() || b_popup )
    {
        addDPStaticEntry( current, qtr( "Add &Subtitle File..." ), "",
                &DialogsProvider::loadSubtitlesFile);
        current->addMenu(new CheckableListMenu(qtr( "Sub &Track" ), THEMIM->getSubtitleTracks(), QActionGroup::ExclusionPolicy::ExclusiveOptional, current));
        current->addSeparator();
    }
}

/**
 * Main Video Menu
 * Subtitles are part of Video.
 **/
void VLCMenuBar::VideoMenu( qt_intf_t *p_intf, QMenu *current )
{
    if( current->isEmpty() )
    {
        current->addMenu(new CheckableListMenu(qtr( "Video &Track" ), THEMIM->getVideoTracks(), QActionGroup::ExclusionPolicy::None, current));

        current->addSeparator();
        current->addMenu( new CheckableListMenu(qtr( "&3D Output" ), THEMIM->getVideoStereoMode(), QActionGroup::ExclusionPolicy::Exclusive, current) );

        current->addSeparator();
        /* Surface modifiers */
        current->addAction(new BooleanPropertyAction(qtr( "&Fullscreen"), THEMIM, "fullscreen", current));
        QAction* action = new BooleanPropertyAction(qtr( "Always Fit &Window"), THEMIM, "autoscale", current);
        action->setEnabled( THEMIM->hasVideoOutput() );
        connect(THEMIM, &PlayerController::hasVideoOutputChanged, action, &QAction::setEnabled);
        current->addAction(action);
        current->addAction(new BooleanPropertyAction(qtr( "Set as Wall&paper"), THEMIM, "wallpaperMode", current));

        current->addSeparator();
        /* Size modifiers */
        current->addMenu( new CheckableListMenu(qtr( "&Zoom" ), THEMIM->getZoom(), QActionGroup::ExclusionPolicy::Exclusive, current) );
        current->addMenu( new CheckableListMenu(qtr( "&Aspect Ratio" ), THEMIM->getAspectRatio(), QActionGroup::ExclusionPolicy::Exclusive, current) );
        current->addMenu( new CheckableListMenu(qtr( "&Crop" ), THEMIM->getCrop(), QActionGroup::ExclusionPolicy::Exclusive, current) );
        current->addMenu( new CheckableListMenu(qtr( "&Fit" ), THEMIM->getFit(), QActionGroup::ExclusionPolicy::Exclusive, current) );

        current->addSeparator();
        /* Rendering modifiers */
        current->addMenu( new CheckableListMenu(qtr( "&Deinterlace" ), THEMIM->getDeinterlace(), QActionGroup::ExclusionPolicy::Exclusive, current) );
        current->addMenu( new CheckableListMenu(qtr( "&Deinterlace mode" ), THEMIM->getDeinterlaceMode(), QActionGroup::ExclusionPolicy::Exclusive, current) );

        current->addSeparator();
        /* Other actions */
        QAction* snapshotAction = new QAction(qtr( "Take &Snapshot" ), current);
        connect(snapshotAction, &QAction::triggered, THEMIM, &PlayerController::snapshot);
        current->addAction(snapshotAction);
    }
}

/**
 * Navigation Menu
 * For DVD, MP4, MOV and other chapter based format
 **/
void VLCMenuBar::NavigMenu( qt_intf_t *p_intf, QMenu *menu, bool b_popup )
{
    QAction *action;
    QMenu *submenu;

    menu->addMenu( new CheckableListMenu( qtr( "T&itle" ), THEMIM->getTitles(), QActionGroup::ExclusionPolicy::Exclusive, menu) );
    submenu = new CheckableListMenu( qtr( "&Chapter" ), THEMIM->getChapters(), QActionGroup::ExclusionPolicy::Exclusive, menu );
    submenu->setTearOffEnabled( true );
    menu->addMenu( submenu );
    menu->addMenu( new CheckableListMenu( qtr("&Program") , THEMIM->getPrograms(), QActionGroup::ExclusionPolicy::Exclusive, menu) );

    MainCtx * mi = p_intf->p_mi;

    if (mi && p_intf->p_mi->hasMediaLibrary() )
    {
        MediaLib * mediaLib = mi->getMediaLibrary();

        BookmarkMenu * bookmarks = new BookmarkMenu(mediaLib, p_intf->p_player, menu);

        bookmarks->setTitle(qfut(I_MENU_BOOKMARK));

        action = menu->addMenu(bookmarks);

        action->setData("bookmark");
    }

    menu->addSeparator();

    if ( !VLCMenuBar::rendererMenu )
        VLCMenuBar::rendererMenu = new RendererMenu( NULL, p_intf, p_intf->p_mainPlayerController );

    menu->addMenu( VLCMenuBar::rendererMenu );
    menu->addSeparator();


    PopupMenuControlEntries( menu, p_intf );

    RebuildNavigMenu( p_intf, menu, !b_popup );
}

void VLCMenuBar::RebuildNavigMenu( qt_intf_t *p_intf, QMenu *menu, bool b_transport )
{
    QAction* action;

#define ADD_ACTION( title, slot, visibleSignal, visible ) \
    action = menu->addAction( title, THEMIM,  slot ); \
    if (! visible)\
        action->setVisible(false); \
    connect( THEMIM, visibleSignal, action, &QAction::setVisible );

    ADD_ACTION( qtr("Previous Title"), &PlayerController::titlePrev, &PlayerController::hasTitlesChanged, THEMIM->hasTitles() );
    ADD_ACTION( qtr("Next Title"), &PlayerController::titleNext, &PlayerController::hasTitlesChanged, THEMIM->hasTitles() );
    ADD_ACTION( qtr("Previous Chapter"), &PlayerController::chapterPrev, &PlayerController::hasChaptersChanged, THEMIM->hasChapters() );
    ADD_ACTION( qtr("Next Chapter"), &PlayerController::chapterNext, &PlayerController::hasChaptersChanged, THEMIM->hasChapters() );

#undef ADD_ACTION

    /* the right-click menu has these at its top level */
    if( b_transport )
        PopupMenuPlaylistEntries( menu, p_intf );
}

/**
 * Help/About Menu
**/
void VLCMenuBar::HelpMenu(qt_intf_t *p_intf, QMenu *menu )
{
    addDPStaticEntry( menu, qtr( "&Help" ) ,
        ":/menu/help.svg", &DialogsProvider::helpDialog, "F1" );
#ifdef UPDATE_CHECK
    addDPStaticEntry( menu, qtr( "Check for &Updates..." ) , "",
                     [ctx = QPointer(p_intf->p_mi)]() {
        if (Q_LIKELY(ctx))
        {
            const auto updateModel = ctx->getUpdateModel();
            assert(updateModel);
            updateModel->checkUpdate(true);
        }
    });
#endif
    menu->addSeparator();
    addDPStaticEntry( menu, qfut( I_MENU_ABOUT ), ":/menu/info.svg",
            &DialogsProvider::aboutDialog, "Shift+F1", QAction::AboutRole );
}

/*****************************************************************************
 * Popup menus - Right Click menus                                           *
 *****************************************************************************/

void VLCMenuBar::PopupMenuPlaylistEntries( QMenu *menu, qt_intf_t *p_intf )
{
    QAction *action;
    bool hasInput = THEMIM->hasInput();

    /* Play or Pause action and icon */
    if( !hasInput || THEMIM->getPlayingState() != PlayerController::PLAYING_STATE_PLAYING )
    {
        action = menu->addAction( qtr( "&Play" ), [p_intf]() {
            if ( THEMPL->isEmpty() )
                THEDP->openFileDialog();
            else
                THEMPL->togglePlayPause();
        });
        action->setIcon( QIcon( ":/redesign/menu/play.svg" ) );
    }
    else
    {
        action = menu->addAction( qtr( "&Pause" ), THEMPL, &PlaylistController::togglePlayPause );
        action->setIcon( QIcon( ":/redesign/menu/pause.svg" ) );
    }
    menuShowKey( action, QKeySequence( "Space" ) );

    /* Stop */
    action = menu->addAction( QIcon( ":/redesign/menu/stop.svg" ), qtr( "&Stop" ),
                              THEMPL, &PlaylistController::stop );
    menuShowKey( action, QKeySequence( "S" ) );
    if( !hasInput )
        action->setEnabled( false );

    /* Next / Previous */
    bool bPlaylistEmpty = THEMPL->isEmpty();
    QAction* previousAction = menu->addAction( QIcon( ":/redesign/menu/previous.svg" ),
                                  qtr( "Previo&us Item" ), THEMPL, &PlaylistController::prev );
    menuShowKey( previousAction, QKeySequence( "P" ) );
    previousAction->setEnabled( !bPlaylistEmpty );
    connect( THEMPL, &PlaylistController::isEmptyChanged, previousAction, &QAction::setDisabled);

    QAction* nextAction = menu->addAction( QIcon( ":/redesign/menu/next.svg" ),
                              qtr( "&Next Item" ), THEMPL, &PlaylistController::next );
    menuShowKey( nextAction, QKeySequence( "N" ) );
    nextAction->setEnabled( !bPlaylistEmpty );
    connect( THEMPL, &PlaylistController::isEmptyChanged, nextAction, &QAction::setDisabled);

    action = menu->addAction( QIcon( ":/redesign/menu/record.svg" ), qtr( "&Record" ),
                              THEMIM, &PlayerController::toggleRecord );
    menuShowKey( action, QKeySequence( "Shift+R" ) );
    if( !hasInput )
        action->setEnabled( false );
    menu->addSeparator();
}

void VLCMenuBar::PopupMenuControlEntries( QMenu *menu, qt_intf_t *p_intf,
                                        bool b_normal )
{
    QAction *action;
    QMenu *rateMenu = new QMenu( qtr( "Sp&eed" ), menu );
    rateMenu->setTearOffEnabled( true );

    if( b_normal )
    {
        /* Faster/Slower */
        action = rateMenu->addAction( qtr( "&Faster" ), THEMIM,
                                  &PlayerController::faster );
#ifndef __APPLE__ /* No icons in menus in Mac */
        action->setIcon( ColorizedSvgIcon::colorizedIconForWidget( ":/menu/ic_fluent_fast_forward.svg", rateMenu ) );
#endif
    }

    action = rateMenu->addAction( ColorizedSvgIcon::colorizedIconForWidget( ":/menu/ic_fluent_fast_forward.svg", rateMenu ), qtr( "Faster (fine)" ), THEMIM,
                              &PlayerController::littlefaster );

    action = rateMenu->addAction( qtr( "N&ormal Speed" ), THEMIM,
                              &PlayerController::normalRate );

    action = rateMenu->addAction( ColorizedSvgIcon::colorizedIconForWidget( ":/menu/ic_fluent_rewind.svg", rateMenu ), qtr( "Slower (fine)" ), THEMIM,
                              &PlayerController::littleslower );

    if( b_normal )
    {
        action = rateMenu->addAction( qtr( "Slo&wer" ), THEMIM,
                                  &PlayerController::slower );
#ifndef __APPLE__ /* No icons in menus in Mac */
        action->setIcon( ColorizedSvgIcon::colorizedIconForWidget( ":/menu/ic_fluent_rewind.svg", rateMenu ) );
#endif
    }

    action = menu->addMenu( rateMenu );

    menu->addSeparator();

    if( !b_normal ) return;

    action = menu->addAction( qtr( "&Jump Forward" ), THEMIM,
             &PlayerController::jumpFwd );
#ifndef __APPLE__ /* No icons in menus in Mac */
    action->setIcon( ColorizedSvgIcon::colorizedIconForWidget( ":/menu/ic_fluent_skip_forward_10.svg", menu ) );
#endif

    action = menu->addAction( qtr( "Jump Bac&kward" ), THEMIM,
             &PlayerController::jumpBwd );
#ifndef __APPLE__ /* No icons in menus in Mac */
    action->setIcon( ColorizedSvgIcon::colorizedIconForWidget( ":/menu/ic_fluent_skip_back_10.svg", menu ) );
#endif

    action = menu->addAction( qfut( I_MENU_GOTOTIME ), THEDP, &DialogsProvider::gotoTimeDialog );
    action->setShortcut( QKeySequence( "Ctrl+T" ) );

    menu->addSeparator();
}

void VLCMenuBar::PopupMenuStaticEntries( QMenu *menu )
{
    QMenu *openmenu = menu->addMenu( QIcon( ":/redesign/menu/open-media.svg" ), qtr( "&Open Media" ) );
    addDPIconEntry( openmenu, qtr( "Open &File(s)" ), ":/redesign/menu/open-file.svg",
                    &DialogsProvider::openFileDialog );
    addDPIconEntry( openmenu, qtr( "Open F&older" ), ":/redesign/menu/open-folder.svg",
                    &DialogsProvider::PLOpenDir );
    addDPIconEntry( openmenu, qtr( "Open &Network Stream" ), ":/redesign/menu/open-network.svg",
                    &DialogsProvider::openNetDialog );
    addDPIconEntry( openmenu, qtr( "Open &Disc" ), ":/redesign/menu/open-disc.svg",
                    &DialogsProvider::openDiscDialog );
    addDPIconEntry( openmenu, qtr( "Open &Capture Device" ), ":/redesign/menu/open-capture.svg",
                    &DialogsProvider::openCaptureDialog );

    addDPIconEntry( menu, qtr( "&Quit VLC" ), ":/redesign/menu/quit.svg",
                    &DialogsProvider::quit, "Ctrl+Q", QAction::QuitRole );
}

/* Video Tracks and Subtitles tracks */
QMenu* VLCMenuBar::VideoPopupMenu( qt_intf_t *p_intf, bool show )
{
    QMenu* menu = new VLCMenu(p_intf);
    VideoMenu(p_intf, menu);
    if( show )
        menu->popup( QCursor::pos() );
    return menu;
}

/* Audio Tracks */
QMenu* VLCMenuBar::AudioPopupMenu( qt_intf_t *p_intf, bool show )
{
    QMenu* menu = new VLCMenu(p_intf);
    AudioMenu(p_intf, menu);
    if( show )
        menu->popup( QCursor::pos() );
    return menu;
}

/* Navigation stuff, and general menus ( open ), used only for skins */
QMenu* VLCMenuBar::MiscPopupMenu( qt_intf_t *p_intf, bool show )
{
    QMenu* menu = new VLCMenu(p_intf);

    menu->addSeparator();
    PopupMenuPlaylistEntries( menu, p_intf );

    menu->addSeparator();
    PopupMenuControlEntries( menu, p_intf );

    menu->addSeparator();
    PopupMenuStaticEntries( menu );

    if( show )
        menu->popup( QCursor::pos() );
    return menu;
}

/* Main Menu that sticks everything together  */
QMenu* VLCMenuBar::PopupMenu( qt_intf_t *p_intf, bool show )
{
    /* */
    QMenu* menu = new VLCMenu(p_intf);
    input_item_t* p_input = THEMIM->getInput();
    MainCtx *mi = p_intf->p_mi;

    PopupMenuPlaylistEntries( menu, p_intf );

    if( !p_intf->b_isDialogProvider )
    {
        QAction *action = menu->addAction( QIcon( ":/redesign/menu/hide-ui.svg" ), qtr( "&Hide UI" ) );
        menuShowKey( action, QKeySequence( "Ctrl+H" ) );
        action->setCheckable( true );
        action->setChecked( mi->isMinimalView() );
        connect( action, &QAction::triggered, mi, &MainCtx::setMinimalView );
        menu->addSeparator();
    }

    /* The track menus show without an input too, but empty and disabled */
    auto trackMenu = [menu, p_input]( const QString &title, const char *icon, auto fill ) {
        QMenu *submenu = menu->addMenu( QIcon( icon ), title );
        if( p_input )
            fill( submenu );
        submenu->menuAction()->setEnabled( !submenu->isEmpty() );
    };

    trackMenu( qtr( "Play&back" ), ":/redesign/menu/playback.svg", [p_intf]( QMenu *m ) {
        NavigMenu( p_intf, m, true );
    } );
    trackMenu( qtr( "&Video" ), ":/redesign/menu/video.svg", [p_intf]( QMenu *m ) {
        VideoMenu( p_intf, m );
        /* the fullscreen toggle goes first, it is the most used function */
        const auto actions = m->actions();
        for( QAction *a : actions )
            if( qobject_cast<BooleanPropertyAction*>( a ) )
            {
                m->insertAction( actions.first(), a );
                m->insertSeparator( actions.first() );
                break;
            }
    } );
    trackMenu( qtr( "&Audio" ), ":/redesign/menu/audio.svg", [p_intf]( QMenu *m ) {
        AudioMenu( p_intf, m );
    } );
    trackMenu( qtr( "Subti&tle" ), ":/redesign/menu/subtitles.svg", [p_intf]( QMenu *m ) {
        SubtitleMenu( p_intf, m, true );
    } );
    menu->addSeparator();

    /* Add some special entries for windowed mode: Interface Menu */
    if( p_intf->b_isDialogProvider )
    {
        // same as Tool menu but with extra entries
        QMenu* submenu = new QMenu( qtr( "&Interface" ), menu );
        ToolsMenu( p_intf, submenu );
        submenu->addSeparator();

        vlc_object_t* p_object = vlc_object_parent(p_intf->intf);

        /* Open skin dialog box */
        if (var_Type(p_object, "intf-skins-interactive") & VLC_VAR_ISCOMMAND)
        {
            QAction* openSkinAction = new QAction(qtr("Open skin..."), menu);
            openSkinAction->setShortcut( QKeySequence( "Ctrl+Shift+S" ));
            connect(openSkinAction, &QAction::triggered, [=]() {
                var_TriggerCallback(p_object, "intf-skins-interactive");
            });
            submenu->addAction(openSkinAction);
        }

        VLCVarChoiceModel* skinmodel = new VLCVarChoiceModel(p_object, "intf-skins", submenu);
        CheckableListMenu* skinsubmenu = new CheckableListMenu(qtr("Interface"), skinmodel, QActionGroup::ExclusionPolicy::ExclusiveOptional, submenu);
        submenu->addMenu(skinsubmenu);

        submenu->addSeparator();

        /* list of extensions */
        ExtensionsMenu( p_intf, submenu );

        menu->addMenu( submenu );
    }
    else
    {
        QMenu* more = menu->addMenu( QIcon( ":/redesign/menu/more-settings.svg" ), qtr( "&More Settings" ) );
        ToolsMenu( p_intf, more );
        more->addSeparator();
        ViewMenu( p_intf, more );

        /* whatever of Show/Shuffle/Repeat/Save/Clear the player already has */
        QMenu* queue = menu->addMenu( QIcon( ":/redesign/menu/playlist.svg" ), qtr( "Play&list" ) );
        QAction *action = queue->addAction( qtr( "Play &Queue" ) );
        menuShowKey( action, QKeySequence( "Ctrl+L" ) );
        action->setCheckable( true );
        action->setChecked( mi->getPlayqueuePanel()->isVisible() );
        connect( action, &QAction::triggered, mi->getPlayqueuePanel(), &SidePanelCtx::setVisible );

        action = queue->addAction( QIcon( ":/redesign/menu/shuffle.svg" ), qtr( "S&huffle" ) );
        action->setCheckable( true );
        action->setChecked( THEMPL->isRandom() );
        connect( action, &QAction::triggered, THEMPL, &PlaylistController::setRandom );

        /* ponytail: on/off for all, the cycle through repeat-one lives on the control bar button */
        action = queue->addAction( qtr( "&Repeat" ) );
        action->setCheckable( true );
        action->setChecked( THEMPL->getRepeatMode() != PlaylistController::PLAYBACK_REPEAT_NONE );
        connect( action, &QAction::triggered, THEMPL, [playlist = THEMPL](bool on) {
            playlist->setRepeatMode( on ? PlaylistController::PLAYBACK_REPEAT_ALL
                                      : PlaylistController::PLAYBACK_REPEAT_NONE );
        } );

        queue->addSeparator();
        addDPIconEntry( queue, qtr( "&Save Play Queue to File" ), ":/redesign/menu/export.svg",
                        &DialogsProvider::savePlayingToPlaylist, "Ctrl+Y" );
        queue->addAction( qtr( "&Clear" ), THEMPL, &PlaylistController::clear );
    }

    /* Static entries for ending, like open */
    if( p_intf->b_isDialogProvider )
    {

        QMenu* openmenu = menu->addMenu( QIcon( ":/redesign/menu/open-media.svg" ), qtr( "&Open Media" ) );
        FileMenu( p_intf, openmenu );

        menu->addSeparator();

        QMenu* helpmenu = new QMenu( qtr( "&Help" ), menu );
        HelpMenu( p_intf, helpmenu );
        menu->addMenu( helpmenu );

        addDPIconEntry( menu, qtr( "&Quit VLC" ), ":/redesign/menu/quit.svg",
                        &DialogsProvider::quit, "Ctrl+Q", QAction::QuitRole );
    }
    else
        PopupMenuStaticEntries( menu );

    if( show )
        menu->popup( QCursor::pos() );
    return menu;
}
