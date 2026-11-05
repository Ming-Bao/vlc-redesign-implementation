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
#ifndef VLC_QT_ADD_SUBTITLES_CONTROLLER_HPP
#define VLC_QT_ADD_SUBTITLES_CONTROLLER_HPP

#include <QObject>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

#include "qt.hpp"
#include "opensubtitles_client.hpp"

// State and actions of the Add Subtitles dialog (singleton "AddSubtitlesController")
class AddSubtitlesController : public QObject
{
    Q_OBJECT
public:
    enum Target { File, Folder, Playlist };
    Q_ENUM(Target)
    enum Origin { Computer, OpenSubtitles, Link };
    Q_ENUM(Origin)

    Q_PROPERTY(Target target READ target WRITE setTarget NOTIFY targetChanged FINAL)
    // Link needs the File target: any other target falls back to Computer
    Q_PROPERTY(Origin origin READ origin WRITE setOrigin NOTIFY originChanged FINAL)
    // breadcrumb of the folder the candidates come from, empty when there is none
    Q_PROPERTY(QString location READ location NOTIFY candidatesChanged FINAL)
    Q_PROPERTY(QString link READ link WRITE setLink NOTIFY linkChanged FINAL)
    // [{name, mrl, id}], id is -1 for media outside the library
    Q_PROPERTY(QVariantList mediaItems READ mediaItems NOTIFY mediaItemsChanged FINAL)
    // subtitle file names in the scanned folder
    Q_PROPERTY(QStringList candidates READ candidates NOTIFY candidatesChanged FINAL)
    // per media row: the candidate paired with it, -1 for None (Folder and Playlist)
    Q_PROPERTY(QVector<int> pairs READ pairs NOTIFY pairsChanged FINAL)
    // candidates to attach to the file (File target)
    Q_PROPERTY(QVector<int> ticked READ ticked NOTIFY tickedChanged FINAL)
    // From OpenSubtitles: the search text and language code, the last failure, whether a key is set (Settings > Network)
    // and whether a search is out. The hits are the candidates.
    Q_PROPERTY(QString osQuery READ osQuery WRITE setOsQuery NOTIFY osQueryChanged FINAL)
    Q_PROPERTY(QString osLanguage READ osLanguage WRITE setOsLanguage NOTIFY osLanguageChanged FINAL)
    Q_PROPERTY(QString osError READ osError NOTIFY osStateChanged FINAL)
    Q_PROPERTY(bool hasKey READ hasKey NOTIFY osStateChanged FINAL)
    Q_PROPERTY(bool osSearching READ osSearching NOTIFY osStateChanged FINAL)
    Q_PROPERTY(bool canSave READ canSave NOTIFY canSaveChanged FINAL)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged FINAL)

    explicit AddSubtitlesController(qt_intf_t* intf, QObject* parent = nullptr);

    Target target() const { return m_target; }
    void setTarget(Target t);
    Origin origin() const { return m_origin; }
    void setOrigin(Origin o);
    QString location() const;
    QString link() const { return m_link; }
    void setLink(const QString& l);
    QVariantList mediaItems() const { return m_media; }
    QStringList candidates() const { return m_candidates; }
    QVector<int> pairs() const { return m_pairs; }
    QVector<int> ticked() const { return m_ticked; }
    QString osQuery() const { return m_osQuery; }
    void setOsQuery(const QString& q);
    QString osLanguage() const { return m_osLanguage; }
    void setOsLanguage(const QString& l);
    QString osError() const { return m_osError; }
    bool hasKey() const { return m_hasKey; }
    bool osSearching() const { return m_searching; }
    bool canSave() const { return m_canSave; }
    bool busy() const { return m_busy; }

    // keys: target ("file"|"folder"|"playlist"); file: mrl and mlId (-1 or absent when not in
    // the library); folder: folder (its mrl; the library id is found from it, or given as mlId); playlist: playlistId
    // the context with the folder of a local file added when missing; what setContext works with
    Q_INVOKABLE static QVariantMap completeContext(QVariantMap context);
    Q_INVOKABLE void setContext(const QVariantMap& context);
    // scan another folder for candidates; the media list stays
    Q_INVOKABLE void setFolder(const QUrl& folder);
    Q_INVOKABLE void setPair(int mediaRow, int candidate);
    Q_INVOKABLE void toggle(int candidate);
    Q_INVOKABLE void save();
    // reads the key again (Settings may have changed it) and searches for osQuery
    Q_INVOKABLE void searchOpenSubtitles();

signals:
    void targetChanged();
    void originChanged();
    void linkChanged();
    void mediaItemsChanged();
    void candidatesChanged();
    void pairsChanged();
    void tickedChanged();
    void canSaveChanged();
    void busyChanged();
    void osQueryChanged();
    void osLanguageChanged();
    void osStateChanged();
    void finished(int attached, int failed);

private:
    void refresh(bool reloadMedia);
    // candidates, pairs and ticks from the origin's list (the scanned files or the search hits)
    void applyCandidates();
    void setOsState(const QString& error, bool searching);
    bool readKey(QString* key = nullptr);
    void resetOpenSubtitles();
    void cancelOpenSubtitles();
    void dropClient();
    void saveOpenSubtitles();
    void nextDownload();
    QString downloadPath(const QVariantMap& media, const SubtitleHit& hit) const;
    void setBusy(bool busy);
    void updateCanSave();
    bool validLink() const;
    // attaches one subtitle (a local path or a link) to a media item, true on success
    bool attach(const QVariantMap& media, const QString& subtitle, bool local);

    qt_intf_t* m_intf;
    Target m_target = File;
    Origin m_origin = Computer;
    QString m_link;
    QVariantMap m_context;
    QString m_dir; // folder scanned for candidates, local path
    QVariantList m_media;
    QStringList m_candidates;
    QStringList m_local; // the files found in m_dir
    QVector<SubtitleHit> m_hits;
    QString m_osQuery, m_osLanguage = QStringLiteral("en"), m_osError;
    bool m_hasKey = false;
    bool m_searching = false;
    OpenSubtitlesClient* m_client = nullptr; // the search in flight, or the downloads of a save
    struct Download { QVariantMap media; SubtitleHit hit; };
    QVector<Download> m_downloads;
    Download m_current;
    int m_attached = 0, m_failed = 0;
    bool m_saving = false;
    QVector<int> m_pairs;
    QVector<int> m_ticked;
    bool m_canSave = false;
    bool m_busy = false;
    quint64 m_task = 0;
    bool m_reloadPending = false; // a media reload was requested and has not landed yet
};

#endif
