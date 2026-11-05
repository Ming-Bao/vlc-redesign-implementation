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
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "add_subtitles_controller.hpp"
#include "subtitle_matching.hpp"

#include "maininterface/mainctx.hpp"
#include "medialibrary/medialib.hpp"
#include "medialibrary/mlhelper.hpp"
#include "player/player_controller.hpp"
#include "util/folder_tree.hpp"

#include <vlc_interface.h> // EXTENSIONS_SUBTITLE
#include <vlc_configuration.h>
#include <vlc_url.h>

#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>

namespace {

// everything the (possibly ML thread) scan reads, copied
struct ScanInput
{
    AddSubtitlesController::Target target;
    QString mrl, folderMrl, dirOverride;
    qint64 mlId, playlistId;
    bool reloadMedia;
};

struct ScanResult
{
    QVariantList media;
    QString dir;
    QStringList candidates;
};

QVariantMap mediaItem(const QString& name, const QString& mrl, qint64 id)
{
    return {{"name", name}, {"mrl", mrl}, {"id", id}};
}

QVariantList listMedia(vlc_ml_media_list_t* list)
{
    QVariantList out;
    if (!list)
        return out;
    ml_unique_ptr<vlc_ml_media_list_t> owned{list};
    for (const vlc_ml_media_t& m : ml_range_iterate<vlc_ml_media_t>(owned)) {
        QString mrl;
        for (const vlc_ml_file_t& f : ml_range_iterate<vlc_ml_file_t>(m.p_files))
            if (f.i_type == VLC_ML_FILE_TYPE_MAIN) {
                mrl = QString::fromUtf8(f.psz_mrl);
                break;
            }
        QString name = qfu(m.psz_filename);
        if (name.isEmpty())
            name = QUrl(mrl).fileName();
        out << mediaItem(name, mrl, m.i_id);
    }
    return out;
}

// a library id as QML gives it: an MLItemId, or a plain number
qint64 idOf(const QVariant& v)
{
    if (v.metaType() == QMetaType::fromType<MLItemId>())
        return v.value<MLItemId>().id;
    return v.isValid() ? v.toLongLong() : -1;
}

// the library id of a folder from its mrl, -1 when the library has no such folder
qint64 folderIdOf(vlc_medialibrary_t* ml, const QString& mrl)
{
    const QString wanted = folder_tree::normalized(mrl);
    // a folder holding only audio is as valid a target as one holding videos
    for (auto type : {VLC_ML_MEDIA_TYPE_VIDEO, VLC_ML_MEDIA_TYPE_AUDIO}) {
        ml_unique_ptr<vlc_ml_folder_list_t> folders(vlc_ml_list_folders_by_type(ml, nullptr, type));
        if (folders)
            for (const vlc_ml_folder_t& f : ml_range_iterate<vlc_ml_folder_t>(folders))
                if (f.psz_mrl && folder_tree::normalized(qfu(f.psz_mrl)) == wanted)
                    return f.i_id;
    }
    return -1;
}

// ML thread when there is a library, else the caller's
void scan(vlc_medialibrary_t* ml, const ScanInput& in, ScanResult& out)
{
    if (in.reloadMedia) {
        switch (in.target) {
        case AddSubtitlesController::File:
            if (!in.mrl.isEmpty()) {
                // the Tracks panel only knows the mrl: with the id, a library file keeps its subtitle after this session
                qint64 id = in.mlId;
                if (id < 0 && ml) {
                    ml_unique_ptr<vlc_ml_media_t> media(vlc_ml_get_media_by_mrl(ml, qtu(in.mrl)));
                    if (media)
                        id = media->i_id;
                }
                out.media << mediaItem(QUrl(in.mrl).fileName(), in.mrl, id);
            }
            break;
        case AddSubtitlesController::Folder: {
            // the library id is optional: the folder menus only know the folder's mrl
            const qint64 folderId = !ml ? -1 : in.mlId >= 0 ? in.mlId : folderIdOf(ml, in.folderMrl);
            if (folderId >= 0) {
                vlc_ml_query_params_t q = vlc_ml_query_params_create();
                out.media = listMedia(vlc_ml_list_folder_media(ml, &q, folderId));
                std::stable_sort(out.media.begin(), out.media.end(), [](const QVariant& a, const QVariant& b) {
                    return a.toMap()["name"].toString().compare(b.toMap()["name"].toString(), Qt::CaseInsensitive) < 0;
                });
            }
            break;
        }
        case AddSubtitlesController::Playlist:
            if (ml && in.playlistId >= 0) {
                vlc_ml_query_params_t q = vlc_ml_query_params_create();
                out.media = listMedia(vlc_ml_list_playlist_media(ml, &q, in.playlistId));
            }
            break;
        }
    }

    // the folder to scan: the one chosen, the folder target's own, else the first media's
    out.dir = in.dirOverride;
    if (out.dir.isEmpty() && in.target == AddSubtitlesController::Folder) {
        const QUrl u(in.folderMrl);
        if (u.isLocalFile())
            out.dir = u.toLocalFile();
    }
    if (out.dir.isEmpty() && !out.media.isEmpty()) {
        const QUrl u(out.media.first().toMap()["mrl"].toString());
        if (u.isLocalFile())
            out.dir = QFileInfo(u.toLocalFile()).absolutePath();
    }
    if (!out.dir.isEmpty())
        out.candidates = subtitleCandidates(QDir(out.dir).entryList(QDir::Files), EXTENSIONS_SUBTITLE);
}

} // namespace

AddSubtitlesController::AddSubtitlesController(qt_intf_t* intf, QObject* parent)
    : QObject(parent), m_intf(intf)
{
}

QString AddSubtitlesController::location() const
{
    return locationBreadcrumb(m_dir, QDir::homePath());
}

void AddSubtitlesController::setTarget(Target t)
{
    if (t == m_target)
        return;
    m_target = t;
    emit targetChanged();
    if (t != File && m_origin == Link)
        setOrigin(Computer);
    updateCanSave();
}

void AddSubtitlesController::setOrigin(Origin o)
{
    if (o == Link && m_target != File)
        o = Computer;
    if (o == m_origin)
        return;
    const bool wasSearch = m_origin == OpenSubtitles;
    m_origin = o;
    emit originChanged();
    if (o == OpenSubtitles) {
        readKey();
        if (m_osQuery.isEmpty() && !m_media.isEmpty()) {
            // the media's name, or the folder's, as the search text
            const QVariantMap first = m_media.first().toMap();
            QString q = m_target == File ? QFileInfo(first["name"].toString()).completeBaseName()
                      : m_target == Folder ? QDir(m_dir).dirName() : QString();
            m_osQuery = q.replace(QRegularExpression(QStringLiteral("[._]+")), QStringLiteral(" ")).trimmed();
            emit osQueryChanged();
        }
        // no search yet: the file name leaves this machine only when the user asks (Enter, or a pause in typing)
        applyCandidates();
    } else if (wasSearch) {
        cancel();
        setOsState({}, false);
        applyCandidates();
    }
    updateCanSave();
}

bool AddSubtitlesController::readKey(QString* key)
{
    char* k = var_InheritString(m_intf, "qt-opensubtitles-key");
    const QString v = qfu(k).trimmed();
    free(k);
    if (key)
        *key = v;
    const bool has = !v.isEmpty();
    if (has != m_hasKey) {
        m_hasKey = has;
        emit osStateChanged();
    }
    return has;
}

void AddSubtitlesController::setOsState(const QString& error, bool searching)
{
    if (error == m_osError && searching == m_searching)
        return;
    m_osError = error;
    m_searching = searching;
    emit osStateChanged();
}

void AddSubtitlesController::setOsQuery(const QString& q)
{
    if (q == m_osQuery)
        return;
    m_osQuery = q;
    emit osQueryChanged();
}

void AddSubtitlesController::setOsLanguage(const QString& l)
{
    if (l == m_osLanguage)
        return;
    m_osLanguage = l;
    emit osLanguageChanged();
    if (m_origin == OpenSubtitles)
        searchOpenSubtitles();
}

void AddSubtitlesController::searchOpenSubtitles()
{
    if (m_origin != OpenSubtitles || m_busy)
        return;
    dropClient();
    m_hits.clear();
    applyCandidates();
    QString key;
    const QString query = m_osQuery.trimmed();
    if (!readKey(&key) || query.isEmpty()) {
        setOsState({}, false);
        return;
    }
    // the base URL is fixed: no option may point the key somewhere else
    m_client = new OpenSubtitlesClient(key, OpenSubtitlesClient::defaultBaseUrl(), this);
    connect(m_client, &OpenSubtitlesClient::results, this, [this](const QVector<SubtitleHit>& hits) {
        m_hits = hits;
        applyCandidates();
        setOsState(hits.isEmpty() ? tr("No subtitles found") : QString(), false);
    });
    connect(m_client, &OpenSubtitlesClient::failed, this, [this](const QString& message) {
        setOsState(message, false);
    });
    setOsState({}, true);
    m_client->search(query, m_osLanguage);
}

// the client is gone for good: nothing it already queued may reach this object
void AddSubtitlesController::dropClient()
{
    if (!m_client)
        return;
    m_client->abort();
    m_client->disconnect(this);
    m_client->deleteLater();
    m_client = nullptr;
}

// stops a search or a save in flight; a save that was running no longer holds the dialog busy
void AddSubtitlesController::cancel()
{
    dropClient();
    m_downloads.clear();
    if (m_saving) {
        m_saving = false;
        setBusy(false);
    }
}

void AddSubtitlesController::refreshKey()
{
    readKey();
    updateCanSave();
}

void AddSubtitlesController::resetOpenSubtitles()
{
    cancel();
    m_hits.clear();
    m_osQuery.clear();
    emit osQueryChanged();
    setOsState({}, false);
}

void AddSubtitlesController::setLink(const QString& l)
{
    if (l == m_link)
        return;
    m_link = l;
    emit linkChanged();
    updateCanSave();
}

bool AddSubtitlesController::validLink() const
{
    const QUrl u(m_link.trimmed(), QUrl::StrictMode);
    return u.isValid() && !u.scheme().isEmpty() && !u.host().isEmpty();
}

void AddSubtitlesController::updateCanSave()
{
    bool can = false;
    switch (m_origin) {
    case OpenSubtitles:
        if (!m_hasKey)
            break;
        [[fallthrough]];
    case Computer:
        can = m_target == File ? !m_ticked.isEmpty() && !m_media.isEmpty()
                               : std::any_of(m_pairs.begin(), m_pairs.end(), [](int p) { return p >= 0; });
        break;
    case Link:
        can = validLink() && !m_media.isEmpty();
        break;
    }
    if (can != m_canSave) {
        m_canSave = can;
        emit canSaveChanged();
    }
}

void AddSubtitlesController::setBusy(bool busy)
{
    if (busy == m_busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

QVariantMap AddSubtitlesController::completeContext(QVariantMap context)
{
    // a local file's folder is its directory, so every target a file opener can reach is offered
    const QUrl mrl(context.value("mrl").toString());
    if (!context.contains("folder") && mrl.isLocalFile())
        context["folder"] = mrl.adjusted(QUrl::RemoveFilename).toString(QUrl::FullyEncoded);
    return context;
}

void AddSubtitlesController::setContext(const QVariantMap& ctx)
{
    const QVariantMap context = completeContext(ctx);
    m_context = context;
    const QString t = context.value("target").toString();
    setTarget(t == "folder" ? Folder : t == "playlist" ? Playlist : File);
    // the singleton outlives the dialog: nothing of the last session may stay saveable
    m_dir.clear();
    setOrigin(Computer);
    resetOpenSubtitles();
    setLink({});
    m_media.clear();
    m_local.clear();
    m_candidates.clear();
    m_pairs.clear();
    m_ticked.clear();
    emit mediaItemsChanged();
    emit candidatesChanged();
    emit pairsChanged();
    emit tickedChanged();
    updateCanSave();
    refresh(true);
}

void AddSubtitlesController::setFolder(const QUrl& folder)
{
    if (!folder.isLocalFile())
        return;
    m_dir = folder.toLocalFile();
    refresh(false);
}

void AddSubtitlesController::refresh(bool reloadMedia)
{
    MediaLib* ml = m_intf->p_mi ? m_intf->p_mi->getMediaLibrary() : nullptr;
    if (ml && m_task)
        ml->cancelMLTask(this, m_task);
    // a cancelled scan may have been the one reloading the media
    reloadMedia = reloadMedia || m_reloadPending;
    m_reloadPending = reloadMedia;

    const ScanInput in{
        m_target,
        m_context.value("mrl").toString(),
        m_context.value("folder").toString(),
        m_dir,
        idOf(m_context.value("mlId")),
        m_context.value("playlistId", -1).toLongLong(),
        reloadMedia
    };

    auto apply = [this, reloadMedia](ScanResult& r) {
        if (reloadMedia) {
            m_media = r.media;
            emit mediaItemsChanged();
        }
        m_dir = r.dir;
        m_local = r.candidates;
        applyCandidates();
        m_reloadPending = false;
        setBusy(false);
    };

    setBusy(true);
    if (!ml) { // no library: only the File target has media, and nothing needs the ML thread
        ScanResult r;
        scan(nullptr, in, r);
        apply(r);
        return;
    }
    m_task = ml->runOnMLThread<ScanResult>(this,
        //ML thread
        [in](vlc_medialibrary_t* mlt, ScanResult& r) { scan(mlt, in, r); },
        //UI thread
        [this, apply](quint64 task, ScanResult& r) {
            if (task != m_task)
                return;
            m_task = 0;
            apply(r);
        });
}

void AddSubtitlesController::applyCandidates()
{
    if (m_origin == OpenSubtitles) {
        m_candidates.clear();
        for (const SubtitleHit& h : std::as_const(m_hits))
            m_candidates << h.fileName;
    } else {
        m_candidates = m_local;
    }
    emit candidatesChanged();

    QStringList names;
    for (const QVariant& m : m_media)
        names << m.toMap()["name"].toString();
    m_pairs = matchSubtitles(names, m_candidates);
    emit pairsChanged();
    // a file matching the media starts ticked
    m_ticked.clear();
    if (m_target == File && !m_pairs.isEmpty() && m_pairs.first() >= 0)
        m_ticked << m_pairs.first();
    emit tickedChanged();
    updateCanSave();
}

void AddSubtitlesController::setPair(int mediaRow, int candidate)
{
    if (mediaRow < 0 || mediaRow >= m_pairs.size() || candidate < -1 || candidate >= m_candidates.size()
        || m_pairs[mediaRow] == candidate)
        return;
    m_pairs[mediaRow] = candidate;
    emit pairsChanged();
    updateCanSave();
}

void AddSubtitlesController::toggle(int candidate)
{
    if (candidate < 0 || candidate >= m_candidates.size())
        return;
    if (!m_ticked.removeOne(candidate))
        m_ticked << candidate;
    emit tickedChanged();
    updateCanSave();
}

bool AddSubtitlesController::attach(const QVariantMap& media, const QString& subtitle, bool local)
{
    MediaLib* ml = m_intf->p_mi ? m_intf->p_mi->getMediaLibrary() : nullptr;
    const QUrl url = local ? QUrl::fromLocalFile(subtitle) : QUrl(subtitle);
    const qint64 mediaId = media["id"].toLongLong(); // -1 outside the library
    const bool playing = sameMedia(media["mrl"].toString(), m_intf->p_mainPlayerController->getUrl().toString(QUrl::FullyEncoded));
    bool ok = false;

    if (ml && mediaId > 0) {
        ml->addExternalTrack(MLItemId(mediaId, VLC_ML_PARENT_UNKNOWN), url, true);
        ok = true;
    }
    // ponytail: the player only takes subtitles for the media it plays, so media outside the
    // library that is not playing cannot be attached and counts as failed
    if (playing) {
        QString uri = url.toString(QUrl::FullyEncoded);
        if (local) {
            char* u = vlc_path2uri(qtu(subtitle), nullptr);
            uri = qfu(u);
            free(u);
        }
        ok = m_intf->p_mainPlayerController->AddAssociatedMedia(SPU_ES, uri, true, true, false) == VLC_SUCCESS || ok;
    }
    return ok;
}

void AddSubtitlesController::save()
{
    if (!m_canSave || m_busy || m_media.isEmpty())
        return;
    if (m_origin == OpenSubtitles)
        return saveOpenSubtitles();
    int attached = 0, failed = 0;
    auto count = [&](bool ok) { ok ? ++attached : ++failed; };

    if (m_origin == Link) {
        count(attach(m_media.first().toMap(), m_link.trimmed(), false));
    } else if (m_target == File) {
        for (int c : std::as_const(m_ticked))
            count(attach(m_media.first().toMap(), QDir(m_dir).filePath(m_candidates[c]), true));
    } else {
        for (int row = 0; row < m_pairs.size(); ++row)
            if (m_pairs[row] >= 0)
                count(attach(m_media[row].toMap(), QDir(m_dir).filePath(m_candidates[m_pairs[row]]), true));
    }
    emit finished(attached, failed);
}

// beside the media when that folder takes a file, else <userdata>/subtitles/; "<stem>.<lang>.srt", and a number
// before .srt when that name is taken, so nothing the user has is overwritten
QString AddSubtitlesController::downloadPath(const QVariantMap& media, const SubtitleHit& hit) const
{
    const QUrl mrl(media["mrl"].toString());
    QString dir;
    if (mrl.isLocalFile() && QFileInfo(QFileInfo(mrl.toLocalFile()).absolutePath()).isWritable())
        dir = QFileInfo(mrl.toLocalFile()).absolutePath();
    else {
        char* userdata = config_GetUserDir(VLC_USERDATA_DIR);
        dir = qfu(userdata) + QStringLiteral("/subtitles");
        free(userdata);
        if (!QDir().mkpath(dir))
            return {};
    }
    const QString stem = QFileInfo(media["name"].toString()).completeBaseName();
    const QString name = OpenSubtitlesClient::subtitleFileName(stem, hit.language);
    QString path = QDir(dir).filePath(name);
    for (int n = 2; QFileInfo::exists(path) && n < 1000; ++n)
        path = QDir(dir).filePath(QFileInfo(name).completeBaseName() + QStringLiteral(".%1.srt").arg(n));
    return QFileInfo::exists(path) ? QString() : path;
}

void AddSubtitlesController::saveOpenSubtitles()
{
    QString key;
    if (!readKey(&key))
        return;
    m_downloads.clear();
    if (m_target == File) {
        for (int c : std::as_const(m_ticked))
            m_downloads.append({m_media.first().toMap(), m_hits[c]});
    } else {
        for (int row = 0; row < m_pairs.size(); ++row)
            if (m_pairs[row] >= 0)
                m_downloads.append({m_media[row].toMap(), m_hits[m_pairs[row]]});
    }
    dropClient();
    m_client = new OpenSubtitlesClient(key, OpenSubtitlesClient::defaultBaseUrl(), this);
    // a downloaded file is attached; a failed one is skipped and counted
    connect(m_client, &OpenSubtitlesClient::downloaded, this, [this](const QString& path) {
        attach(m_current.media, path, true) ? ++m_attached : ++m_failed;
        nextDownload();
    });
    connect(m_client, &OpenSubtitlesClient::downloadFailed, this, [this](const QString&) {
        ++m_failed;
        nextDownload();
    });
    m_attached = m_failed = 0;
    m_saving = true;
    setBusy(true);
    nextDownload();
}

void AddSubtitlesController::nextDownload()
{
    if (!m_client)
        return;
    while (!m_downloads.isEmpty()) {
        m_current = m_downloads.takeFirst();
        const QString path = downloadPath(m_current.media, m_current.hit);
        if (!path.isEmpty()) {
            m_client->download(m_current.hit.fileId, path);
            return;
        }
        ++m_failed;
    }
    dropClient();
    m_saving = false;
    setBusy(false);
    emit finished(m_attached, m_failed);
}
