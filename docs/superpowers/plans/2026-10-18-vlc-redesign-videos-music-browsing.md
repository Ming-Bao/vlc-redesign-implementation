# Videos & Music browsing (slice 4c) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Videos and Music into the Figma folder browsers.
- **Videos:** library folders ▸ subfolders ▸ files.
- **Music:** Songs / Albums / Artists / Genres, where Songs is the same folder browser over audio.
- **Both:** folder breadcrumbs, the Figma grid card, and the 4-column compact list. 4a's temporary tabs go away.

**Architecture:**
- **Data:** a new C++ model, `MLFolderBrowseModel` (a subclass of `MLMediaModel`), lists one level: child folders first, then files.
  - The folder derivation is a pure, header-only function in `util/folder_tree.hpp`, with a C++ test.
- **UI:** one QML page, `LibraryFolderPage.qml`, renders a level for either media type.
  - Grid view is an `ExpandGridView` of 4b's cards; list view is an `ExpandGridView` of compact rows.
  - Crumbs travel in the History props as a `trail`.
- **Navigation:**
  - `VideoDisplay` routes `["video"]` / `["video","folder"]` to the page.
  - `MusicDisplay` gets a root page of category tiles plus `songs` / `songs/folder`, and keeps the albums, artists and genres pages.

**Tech Stack:** Qt 6 / QML, the C++ media-library models (`MLBaseModel` / `MLListCacheLoader` / `MLMediaModel`), meson. Tests: plain C++ QtTest executables and `qml_test`.

**Spec:** `docs/superpowers/specs/2026-10-18-vlc-redesign-videos-music-browsing-design.md`

## Global Constraints

- **Figma is the source of truth** (`dSoAm0gN9ZterHSssJU9FN`).
  - Frames: grid `970:4028`, list `970:3792`, and the sidebar variants `848:1997`, `4778:25847`, `4778:25957`, `858:5001`, `4767:23606` and `4778:24990`.
  - Reference shots are in `docs/superpowers/figma/4c/`. VLC 4's Videos and Music pages are not references.
- **Sizes:** all Figma px go through `VLCStyle.dp(<px>, VLCStyle.scale)`.
- **Colours:** dark values are:
  - `#969696` for titles and list text;
  - `#6B6B6B` for played titles and subtitles;
  - `#171717` for the image backing;
  - `#1E1E1E` for folder tiles;
  - `#303030` for the list thumbnail backing;
  - `#D37918` for progress and the playing item.

  Light mode uses the `theme.palette?.isDark ? <figma> : <theme role>` pattern already in the Home cards.
- **Harness runs** are silent and isolated:
  - always `--aout=dummy` (built into `docs/superpowers/scripts/vlc-xvfb.sh`);
  - xdotool only through `vlc-xvfb.sh click|key`, or with `DISPLAY=:77` set explicitly. **Never** touch the user's `:0`, and never the vlc-static process with PID 2956754.
- **The test library** is `build/redesign-media` (videos; it already contains `Shows/The Clip/S01/…`) and `build/redesign-music`, made by `docs/superpowers/scripts/make-samples.sh`.
  - Extra fixtures (for example a second video folder) are copies or symlinks of those clips, made inside `build/`. Never use the user's real media.
- **Log check after every UI task:** run `-vv`, then grep `build/redesign-profile/run/vlc.log` for `TypeError|ReferenceError|non-existent property|unavailable`. Ignore the known, pre-existing `ExpandGridView.qml … 'layout'` line.
- **Commits:** as the global git user, with no Claude attribution. The message style is `qt: …` or `doc: …`.
- **Build:** `ninja -C build`. **Tests:** `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt`.
- **Comments:** mark deliberate shortcuts `ponytail: <ceiling>, <upgrade path>`. For example, multi-selection is dropped (spec, Behaviour).

## Review Focus

1. **An entry point that holds media directly, with no subfolders.** The root shows that folder, and opening it lists its files. Pinned by `test_folder_tree` (`rootIsMediaFolder`), Task 1.
2. **Folder names with spaces, accents or a malformed escape** (`My%20Shows`, `Caf%C3%A9`, `Bad%E9`). They show decoded, or raw when the escape is malformed, and never empty. Pinned by `test_folder_tree` (`decodesNames`), Task 1.
3. **A level with more files than one cache page.** Paging across the folder/file boundary must neither duplicate nor skip items. Pinned by `test_folder_tree` (`splitRange_*`), Task 1, and checked in the harness with ≥ 2 folders and files at one level in Task 3.
4. **A folder path without props** (a restored History path, or a crumb pushed with no `mrl`): it shows the root level, with no TypeError. Task 3 checks this in the harness.
5. **A level changing while open**: a folder added through Add, or files deleted on disk followed by a rescan. The level refreshes without navigating away; an emptied level shows "No results". Task 2 resets on `VLC_ML_EVENT_FOLDER_*`, `VLC_ML_EVENT_ENTRY_POINT_*` and `VLC_ML_EVENT_MEDIA_*`, and Task 3 checks it in the harness.

---

### Task 1: Folder-tree derivation

**Files:**
- Create: `modules/gui/qt/util/folder_tree.hpp`, `modules/gui/qt/tests/test_folder_tree.cpp`
- Modify: `modules/gui/qt/meson.build` (a test entry next to `test_qt_frequency_rank`, line ~1503), `modules/gui/qt/Makefile.am` (a block copied from `test_frequency_rank`, line ~1884)

**Interfaces:**
- Produces:
  ```cpp
  namespace folder_tree {
  struct Child { QString name; QString mrl; };   // mrl has no trailing slash
  QString normalized(const QString &mrl);         // drops one trailing '/'
  // root level when parent is empty
  std::vector<Child> children(const QStringList &roots, const QStringList &mediaFolders, const QString &parent);
  // one page [offset, offset+limit) over "nFolders folders then files"; limit 0 = unlimited
  struct Range { size_t folderBegin, folderEnd, mediaOffset, mediaLimit; };
  Range splitRange(size_t nFolders, size_t offset, size_t limit);
  }
  ```
  In `Range`, `mediaLimit` 0 means no media is requested, except when the caller's `limit` was 0 (unlimited): then `mediaLimit` is 0 and means unlimited. Add `bool media;` to the struct if that reads clearer; it's the builder's call, but the tests below must express it.

- [ ] **Step 1: Write the failing test** (QtTest, `class TestFolderTree`, the same shape as `test_frequency_rank.cpp`). The cases use `const QString R = "file:///lib/Videos"`:
  - `rootFilter`:
    - Input: roots `{R + "/", "file:///lib/Empty/"}`, media folders `{R + "/Shows/The Wand/S01/"}`, parent `""`.
    - Expected: exactly one child, `{ "Videos", R }`.
  - `nextSegment`:
    - Input: the same media folders plus `R + "/Shows/The Wand/S02/"` and `R + "/Films/"`, parent `R`.
    - Expected: children `Films`, `Shows`, in that order. Each `mrl` is `R + "/Films"` / `R + "/Shows"`, and there are no duplicates.
  - `trailingSlashParent`: parent `R + "/Shows/"` gives the same result as `R + "/Shows"` (child `The Wand`).
  - `segmentBoundary`:
    - Input: media folders `{R + "/Shows2/a/"}`, parent `R + "/Shows"`.
    - Expected: empty.
  - `rootIsMediaFolder`:
    - Input: roots `{R + "/"}`, media folders `{R + "/"}`. At parent `""`, one child, `R`. At parent `R`, empty.
  - `decodesNames`:
    - Input: media folders `{R + "/My%20Shows/x/", R + "/Caf%C3%A9/", R + "/Bad%E9/"}`.
    - Expected at parent `R`, as a set of names: `My Shows`, `Café`, and a non-empty name for `Bad%E9`. The sort must be case-insensitive: add `R + "/apple/"` and expect it before `Bad…`.
  - `outsideRoots`: parent `"file:///elsewhere"` gives empty.
  - `splitRange_foldersOnly`: `splitRange(5, 0, 3)` gives folders [0,3), no media.
  - `splitRange_straddle`: `splitRange(5, 3, 4)` gives folders [3,5), media offset 0, limit 2.
  - `splitRange_mediaOnly`: `splitRange(5, 7, 4)` gives no folders, media offset 2, limit 4.
  - `splitRange_unlimited`: `splitRange(5, 0, 0)` gives folders [0,5), media offset 0, unlimited.

- [ ] **Step 2:** Register the test in `meson.build` (`'name': 'test_qt_folder_tree'`) and in `Makefile.am`. Then run `ninja -C build && QT_QPA_PLATFORM=offscreen meson test -C build test_qt_folder_tree`. **Expected:** it fails to compile (no header).

- [ ] **Step 3: Implement `folder_tree.hpp`** (header-only, `inline`).
  - Match at segment boundaries, using `normalized(parent) + '/'` as the prefix.
  - Decode names with `QUrl::fromPercentEncoding(segment.toUtf8())`. If that yields a string containing U+FFFD, keep the raw segment.
  - Sort with `QString::compare(a, b, Qt::CaseInsensitive)`.
  - Root children: each root `r` for which some media folder `m` has `normalized(m) == normalized(r)` or starts with `normalized(r) + '/'`. The name is `r`'s last segment.

- [ ] **Step 4:** Run the test. **Expected:** PASS. Then run the full qt suite. **Expected:** 14/14.

- [ ] **Step 5: Commit** `qt: derive library folder levels from media folders`.

### Task 2: `MLFolderBrowseModel`

**Files:**
- Create: `modules/gui/qt/medialibrary/mlfolderbrowsemodel.{hpp,cpp}`
- Modify: `meson.build` (hpp in the moc list near line 94, sources near 345), `Makefile.am` (sources and `.moc.cpp`, next to `mlfrequentartistmodel`), `maininterface/mainui.cpp` (register `MLFolderBrowseModel` beside `MLFrequentArtistModel`, line ~484). If `MLMediaModel`'s `onVlcMlEvent` or loader members are private, change them to `protected` (4b did the same for `MLAudioModel`).

**Interfaces:**
- Consumes: `folder_tree::children`, `folder_tree::splitRange` and `folder_tree::normalized` (Task 1).
- Produces, as the QML type `MLFolderBrowseModel` (all `MLBaseModel` properties: `ml`, `searchPattern`, `sortCriteria`, `sortOrder`, `count`, `loading`, `getDataFlat`):
  - **Properties:**
    - `Q_PROPERTY(bool audio …)`: false for video.
    - `Q_PROPERTY(QString folderMrl …)`: `""` is the root.
    - Changing either resets the model.
  - **Roles:**
    - Every `MLMediaModel` role.
    - Plus `isFolder` (bool), `isNew` (bool; video files: playcount == 0) and `main_artist` (QString; audio files).
    - **Folder rows answer** `isFolder` true, `title` = the decoded name, `mrl` = the folder MRL, and an invalid `QVariant` for everything else.
  - **Sort criteria** are `MLMediaModel`'s: `title`, `duration`, `insertion`.

- [ ] **Step 1: Loader** (`MLListCacheLoader::MLOp` subclass, which carries `audio`, `folderMrl` and the search pattern).
  - Build the level once per call:
    - `roots`: the MRLs from `vlc_ml_list_entry_points(ml, nullptr)`.
    - `mediaFolders`: `{mrl, id}` from `vlc_ml_list_folders_by_type(ml, nullptr, audio ? VLC_ML_MEDIA_TYPE_AUDIO : VLC_ML_MEDIA_TYPE_VIDEO)`.
    - `folders`: `folder_tree::children(roots, mrls, folderMrl)`.
    - `folderId`: the id whose normalized MRL equals the normalized `folderMrl`, else 0.
  - **Search:** with a non-empty pattern, keep only the folders whose name contains it, case-insensitively. The media becomes library-wide: `vlc_ml_list_video_media` / `vlc_ml_list_audio_media` and their counts, with `queryParams`.
  - **No search:** the media is `vlc_ml_list_video_of` / `vlc_ml_list_audio_of(ml, params, VLC_ML_PARENT_FOLDER, folderId)`, or none when `folderId` is 0.
  - **`count`:** `folders.size()` + the media count.
  - **`load`:**
    - Use `splitRange(folders.size(), params->i_offset, params->i_nbResults)`.
    - Folder rows are an `MLItem` subclass, local to the cpp, holding the name and MRL. The id is `MLItemId(-(index + 1), VLC_ML_PARENT_FOLDER)`. *(ponytail: synthetic ids, so a folder row is never updated in place, only by reset.)*
    - Then the media with a copy of the params whose offset and nbResults come from the range. Each file is an `MLVideo` (video) or an `MLAudio(ml, &media)` (audio).
  - **`loadItemById`:** returns `nullptr` for `VLC_ML_PARENT_FOLDER`. Otherwise it returns the media as in `MLVideoModel` / `MLAudioModel`.

- [ ] **Step 2: Roles.** `itemRoleData` checks for a folder row first (`dynamic_cast`). Then it answers `isNew` through `MLVideo` and `main_artist` through `MLAudio`, and finally falls back to `MLMediaModel::itemRoleData`. Guard every other `MLMediaModel` method that casts items (for example the favourite and played setters) so it returns early on a folder row.

- [ ] **Step 3: Events.** In `onVlcMlEvent`, emit `resetRequested()` for these events, then defer to the base:
  - `VLC_ML_EVENT_FOLDER_ADDED/DELETED`
  - `VLC_ML_EVENT_ENTRY_POINT_ADDED/REMOVED/BANNED/UNBANNED`
  - `VLC_ML_EVENT_MEDIA_ADDED` (of the model's type)
  - `VLC_ML_EVENT_MEDIA_DELETED`

- [ ] **Step 4: Register, build, and run the suite.** **Expected:** a clean build and 14/14.

- [ ] **Step 5: Smoke check in the harness.**
  - Temporarily make `VideoDisplay.qml`'s first page a `ListView` over `MLFolderBrowseModel { ml: MediaLib }` that prints `title`/`isFolder` with `console.warn`.
  - Run with `-vv`. **Expected in `vlc.log`:** the root lists `redesign-media` as a folder.
  - With `folderMrl` set to that MRL, it lists `Shows`. At `…/Shows/The Clip/S01`, it lists the clip files with `isFolder` false.
  - **Revert the temporary QML** before committing.

- [ ] **Step 6: Commit** `qt: add a media library folder browse model`.

### Task 3: Videos folder browser

**Files:**
- Create: `modules/gui/qt/medialibrary/qml/LibraryFolderPage.qml`
- Modify:
  - `medialibrary/qml/VideoDisplay.qml` (new `pageModel`);
  - `medialibrary/qml/HomeVideoCard.qml`, `HomeSquareCard.qml`, `HomeListRow.qml` (additive properties, as below);
  - `widgets/qml/PageExt.qml` (drop the `video` entry from `_tabs`; crumb labels);
  - the QML resource lists in `meson.build` / `Makefile.am` (wherever `HomeFolderModel.qml` is listed).

**Interfaces:**
- Consumes: `MLFolderBrowseModel` (Task 2).
- Produces:
  - **`LibraryFolderPage`** (a `Widgets.PageExt`). Properties:
    - `audio: bool`
    - `mrl: string` (default `""`)
    - `trail: var` (default `[]`, `[{ name, mrl }]`)
    - `rootCrumbs: var` (the fixed leading crumbs, `[{ title, path }]`)
    - `folderPath: var` (the History path for a child folder)
    - `showAdd: bool`

    Opening a child folder calls:
    ```js
    History.push(folderPath, { mrl: child.mrl, trail: [...trail, { name: child.title, mrl: child.mrl }] }, reason)
    ```
  - **Card additions:**
    - `HomeVideoCard`: `property bool dimmed: false`. When true, the title uses `#6B6B6B`.
    - `HomeSquareCard`: `property real artHeight: width`. The art box is `width × artHeight`; the card's `width` stays overridable.
    - `HomeListRow`: `property bool compact: false`, `property bool dimmed: false`, `property bool playing: false`. `compact` sets the `970:3792` metrics:
      - height 32;
      - thumbnail radius 2 on `#303030`;
      - text `#969696`;
      - a progress mark 3 px tall, ending 4 px before the thumbnail's right edge.

      `dimmed` sets the text to `#6B6B6B`. `playing` sets the text to `#D37918` and lays a 70 % black veil with the accent `play` glyph over the thumbnail.

      With all three false, Home must render exactly as before.

- [ ] **Step 1: Card props.** Add the properties above.
  - **Check:** the Home grid and list harness shots match `docs/superpowers/figma/4b/after_home_*.png` (Home unchanged).
- [ ] **Step 2: `LibraryFolderPage.qml` structure.**
  - **Model:** one `MLFolderBrowseModel` with:
    - `audio` and `folderMrl: mrl ?? ""`;
    - `searchPattern: search.pattern`, `sortCriteria: sort.criteria`, `sortOrder: sort.order`;
    - `sortModel: [{ text: qsTr("Alphabetic"), criteria: "title" }, { text: qsTr("Duration"), criteria: "duration" }, { text: qsTr("Date added"), criteria: "insertion" }]`.
  - **Views:**
    - **Grid:** `Widgets.ExpandGridView`, with:
      - **On video levels:**
        - `cellWidth` = the column width from the 316 base: columns `max(1, floor((avail + 20) / (316 + 20)))`; the width is `(avail + 20) / columns − 20`.
        - `cellHeight` = `cellWidth * 9/16 + 20 + title line`.
        - `horizontalSpacing` 20 and `verticalSpacing` 40.
      - **On audio levels:** the same with base 200, square art, plus the subtitle line.
    - **List:** `Widgets.ExpandGridView` with base width 400, `cellHeight` 32, and both spacings 10.
    - **Top/bottom margin** 20 (`970:4079`) on both.
    - Switch on `MainCtx.gridView`, like `HomePage`.
  - **Delegates:** a small wrapper `Item` sized to the cell, with a `Loader` choosing by `model.isFolder` and the view:
    - **Grid, folder on a video level:** `HomeSquareCard`, with:
      - `width: cellWidth`, `artHeight: cellWidth * 9 / 16`;
      - `glyph: VLCIcons.folder`, `backing: "#1E1E1E"` (light: `theme.bg.secondary`);
      - `title: model.title`, no subtitle.
    - **Grid, folder on an audio level:** the same, square (`artHeight: width`).
    - **Grid, video file:** `HomeVideoCard`, with `width: cellWidth`, `contextModel: browseModel` and `dimmed: model.isNew === false`.
    - **Grid, audio file:** `HomeSquareCard`, with:
      - `image: model.small_cover`, `title: model.title`, `subtitle: model.main_artist`;
      - `onActivated` → `MediaLib.addAndPlay(model.id)`;
      - `onMenuRequested` → an `MLContextMenu` (`model: browseModel`), popped up on `[browseModel.index(index, 0)]`.
    - **List, every kind:** `HomeListRow`, with `compact: true` and:
      - **Folders:** `glyph: VLCIcons.folder`.
      - **Files:** `image: model.small_cover`, `progress: model.progress > 0 ? model.progress : -1` and `dimmed: model.isNew === false` (video).
        - `text`: the title on video levels; `title + " - " + main_artist` on audio levels.
        - `playing: model.mrl?.toString() === Player.url.toString()`.

    A folder's `activated` opens the child (as in Interfaces). A file's `activated` plays it.
  - **Header:**
    - `breadcrumbs: rootCrumbs.concat(trail.map((c, i) => ({ title: c.name, path: folderPath, props: { mrl: c.mrl, trail: trail.slice(0, i + 1) } })))`.
    - `itemCount: browseModel.count`.
- [ ] **Step 3: The Add tile.** When `showAdd` is set and there is no search:
  - It is the grid's `headerDelegate`, one tile in the folder-tile style, with `glyph: VLCIcons.add` and the title "Add".
  - Its `activated` calls `DialogsProvider.addFolderToLibrary()`.
  - **Navigation:** down from the tile goes to the grid; up from the grid's first row goes to the tile, then to the page header. Use the `Navigation` attached API, as 4b's `HomeSection` does.
  - The Add tile isn't counted.
- [ ] **Step 4: Empty states.**
  - **Root, no search, count 0:** below the Add tile, the existing `Widgets.EmptyLabelButton` from `VideoAll.qml` ("No video found\nPlease try adding sources"; Browse → `History.push(["network"])`).
  - **Any other count 0:** a centred "No results" label, `#6B6B6B`, 16 px. It doesn't auto-navigate back.
- [ ] **Step 5: Routing.**
  - `VideoDisplay.qml`'s `pageModel` becomes:
    - `[{ name: "base", default: true, component: <LibraryFolderPage { audio: false; showAdd: true } at mrl "">}, { name: "folder", component: <LibraryFolderPage { audio: false } with mrl/trail from props> }]`;
    - both with `rootCrumbs: [{ title: qsTr("Videos"), path: ["video"] }]` and `folderPath: [...root.pagePrefix, "folder"]`.
  - A missing `mrl` prop means `""`, and a missing `trail` means `[]`.
  - In `PageExt._crumbLabels`, delete `"video/playlists"`. In `_tabs`, delete `"video"`.
- [ ] **Step 6: Keyboard.**
  - Up from the first grid row (or from the Add tile) reaches the page header.
  - Escape in the search field drops to the first item. Use 4a's `escaped()` → `defaultNavigationDown`, with `Navigation.downItem`/`downAction` aimed at the view.
- [ ] **Step 7: Harness.**
  - Add a second video folder, `build/redesign-media/Films/` (a copy of one clip), and rescan by restarting.
  - Shots to `docs/superpowers/figma/4c/after_videos_root.png`, `after_videos_s01_grid.png` and `after_videos_s01_list.png`. Before taking the shots, play one clip part-way, so a card shows dimming and progress.
  - Check:
    - the crumbs read Videos ▸ redesign-media ▸ Shows ▸ The Clip ▸ S01, and clicking "Shows" goes back to that level;
    - the arrows walk the grid;
    - search "Clip" at the root lists the clips library-wide;
    - Review Focus 3 holds at the `redesign-media` level (folders `Films`, `Shows` plus any files);
    - Review Focus 4 holds: run `History.push(["video","folder"])` from a temporary key handler, or reach it through a crumb whose props are empty, and see the root with no TypeError.
  - Log grep clean.
- [ ] **Step 8: Commit** `qt: browse videos by library folder`.

### Task 4: Music root, Songs and the end of the tabs

**Files:**
- Create: `modules/gui/qt/pixmaps/redesign/artist.svg`, `genre.svg` (exported from Figma `858:5001`'s Artists and Genres row icons, 24 px, through `get_design_context` asset download)
- Modify:
  - `pixmaps/redesign/mapping.json`, `pixmaps/VLCIcons.json`; regenerate `pixmaps/VLCIcons.ttf` and `style/vlcicons.hpp` with `python3 makeIconFont.py VLCIcons.json` from `modules/gui/qt/pixmaps`;
  - `medialibrary/qml/MusicDisplay.qml`;
  - `widgets/qml/PageExt.qml`.

**Interfaces:**
- Consumes: `LibraryFolderPage` (Task 3).
- Produces: the icon keys `VLCIcons.artist` and `VLCIcons.genre`, appended after the current last key in `VLCIcons.json`. `docs/superpowers/scripts/check-icon-font.py` must print `icon font OK`.

- [ ] **Step 1: Icons.** Add the two glyphs, as the 4a plan did for `playlists` (`docs/superpowers/plans/2026-10-16-vlc-redesign-library-shell.md`, Task 2). Render both to PNG with the fontforge one-liner from that task, and eyeball them against `sb_music_1.png`.
- [ ] **Step 2: `MusicDisplay.qml` `pageModel`.**
  - **`base` (default): the root page.** A `Widgets.PageExt` titled "Music", with `isSearchable: false`, no sort model, no view toggle, and `itemCount: 4`.
    - Its body is a wrapped row (grid view) or a column (list view) of five tiles: Add, then Songs (`VLCIcons.topbar_music`), Albums (`VLCIcons.album_cover`), Artists (`VLCIcons.artist`) and Genres (`VLCIcons.genre`).
    - **Grid:** `HomeSquareCard` folder-style tiles (200, `#1E1E1E`) with a 20 gap.
    - **List:** `HomeListRow { compact: true }`.
    - **Actions:**
      - Add → `DialogsProvider.addFolderToLibrary()`.
      - Songs → `History.push([...pagePrefix, "songs"])`.
      - Albums / Artists / Genres → `[...pagePrefix, "albums" | "artists" | "genres"]`.
    - **Navigation:** arrow keys move through the tiles with the `Navigation` API; up goes to the header.
  - **`songs`:** `LibraryFolderPage`, with:
    - `audio: true`, `mrl: ""`;
    - `rootCrumbs: [{ title: qsTr("Music"), path: ["music"] }, { title: qsTr("Songs"), path: ["music", "songs"] }]`;
    - `folderPath: [...pagePrefix, "songs", "folder"]`.

    Nest it as a `songs` PageLoader holding `base` and `folder`, or as two sibling entries, `songs` and `songs_folder`. Pick whichever `Widgets.PageLoader` supports for a three-level path, and record the choice in the report.
  - **`albums`, `artists`, `genres`:** the existing entries, unchanged. The `tracks` and `playlists` entries go.
- [ ] **Step 3: `PageExt`.**
  - Delete `_tabs`, the tab row and their properties (`tabs`, `tabRoot`, `currentTab`, `contentUpItem`'s tab case).
  - Delete the `"music/tracks"` and `"music/playlists"` labels, and add `"music/songs": qsTr("Songs")`.
  - Grep for every reader of the deleted properties and fix each one.
- [ ] **Step 4: Harness.**
  - Shots to `after_music_root.png`, `after_music_songs.png` (the `redesign-music` folder), `after_music_songs_level.png` (tracks, grid) and `after_music_songs_list.png`.
  - Check that Albums / Artists / Genres still open, with crumbs Music ▸ Albums and so on.
  - Check that the sidebar Music entry lands on the root.
  - Log grep clean.
- [ ] **Step 5: Commit** `qt: music root and songs folder browser`.

### Task 5: Remove the old pages, ledger, roadmap

**Files:**
- Delete only the QML files that no longer have a reference outside themselves (`grep -rn "<Name>" modules/gui/qt --include='*.qml' --include='*.cpp' --include='*.build' --include='*.am' --include='*.qrc'`). Candidates:
  - `VideoAllDisplay.qml`, `VideoPlaylistsDisplay.qml`, `VideoGroupDisplay.qml`, `VideoAllSubDisplay.qml`;
  - `MusicTracksDisplay.qml`, `MusicPlaylistsDisplay.qml`.

  Remove each one's resource-list entries too. `VideoAll.qml` stays: Home's `continueWatching` page uses it.
- Modify: this plan (append `## Ledger`) and `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md`.
  - Mark row 4c done, with its departures.
  - Also mark rows 2 and 3b "(done)": they shipped earlier, but their marks are missing.

- [ ] **Step 1:** Grep, delete and list what was kept and why. Then build and run the suite. **Expected:** 14/14.
- [ ] **Step 2:** Harness smoke test of every sidebar entry, plus Home's "Continue Watching ›" and "Frequently Listened Artists ›". Log grep clean.
- [ ] **Step 3: Ledger.**
  - A Figma comparison per shot: `after_videos_s01_grid` against `videos_grid.png`, and `after_videos_s01_list` against `videos_list.png`, at 1600 against 1920.
  - The departures from the spec, and the rulings.
- [ ] **Step 4: Commit** `doc: finish the videos & music browsing slice`.

## Ledger

Shots (1600×900, dark, test library with `redesign-media` and `redesign-music`) in `docs/superpowers/figma/4c/`: `after_videos_root.png`, `after_videos_s01_grid.png`, `after_videos_s01_list.png`, `after_music_root.png`, `after_music_songs.png`, `after_music_songs_level.png`, `after_music_songs_list.png`. References: `videos_grid.png`, `videos_list.png` (1920×1080) and `sb_music_1..3.png`, `sb_videos_1..3.png` (the sidebar variants, 427×986). The Figma frames are 1920 wide and the shots 1600, so the number of columns differs; the cards themselves are the same size.

### Figma comparison

| Shot against reference | Figma | Built | Verdict |
|---|---|---|---|
| `after_videos_s01_grid` / `videos_grid.png`: card | 316 wide, 16:9, radius 12, title 16 px `#969696`, watched = `#6B6B6B` title and a 4 px accent line | The same card (`HomeVideoCard`, `dimmed`): E03 and E01 are dimmed, E01 has the orange line | match |
| Grid: gaps | 20 horizontal, 40 vertical | 20 / 40 | match |
| Grid: columns | 5 per row at 1920 | 4 per row at 1600 (the row fits as many as the width allows) | deviation: responsive, by design |
| Grid: header | crumbs Videos ▸ Shows ▸ The Wand ▸ S01, count, sort, view, search, "…" | crumbs carry the root folder too: Videos ▸ redesign-media ▸ Shows ▸ The Clip ▸ S01 (the spec's trail starts at the library folder); same controls | match, plus the root crumb the spec asks for |
| Grid: titles | file names with `.mp4` | the library's title (no extension) | deviation: the ML title is shown, as everywhere in 4b |
| Grid: thumbnails | cartoon stills | colour-bar test clips (the fixture) | data only |
| `after_videos_s01_list` / `videos_list.png`: rows | 4 columns of compact rows, small thumbnail, 14 px text; current input in the accent colour; watched rows dim with a short progress mark | 3 columns at 1600; compact rows (32 high, 14 px `#969696`), `playing` = accent text plus a veiled thumbnail with a play glyph; E03/E01 dimmed with no progress mark (both are finished, and finished media carry no progress, so the mark only shows on a partly watched file) | match, columns differ with the width |
| List: header | crumbs, "110 items" (sample text), sort, list toggle, search, "…" | the same controls, real count | match |
| Both: shell | window chrome, sidebar about 216 px wide at 1920 | 4a's shell, sidebar 152 px at 1600; the mini player and control bar are there because the harness auto-plays the last item | not 4c: outside this slice; the player strip is a harness artefact |
| `after_music_root` / `sb_music_1.png` | Add, Songs, Albums, Artists, Genres, count 4, no search | the same five tiles and glyphs in grid form (200 tiles, `#1E1E1E`, 20 gaps); list form is a 400-wide column of the same rows. Header has no sort, view toggle or search | match; Figma's sidebar variant draws the icons, the spec drops them |
| `after_music_songs` / `sb_music_2.png` | Music ▸ Songs, Add, then a folder row | Music ▸ Songs with one folder tile per library folder, no Add (the spec's call) | deviation: no Add on Songs, by the spec |
| `after_music_songs_level`, `_list` / `sb_music_3.png` | tracks as `title - artist` rows | list rows read `title - artist`; the grid shows 200 square cards with the artist as subtitle | match (the grid has no Figma frame) |

### Departures

Every *(my call)* in the spec, and what the build added:
1. Video groups no longer appear in Videos: the folder hierarchy replaces them.
2. A folder level that a rescan emptied stays on the page with "No results" and does not navigate back.
3. The Music root is a hand-built `PageExt` (not a model page): five tiles, the count is 4 (Add isn't counted), not searchable, no sort, no view toggle.
4. In list view the Music root is a 400-wide column (marked `ponytail:`); Figma has only the sidebar variant.
5. The Add tile appears in both views at the Videos root (grid tile, list compact row), as each view's `headerDelegate`. In the grid it sits alone on its row, because Figma has no main-view root frame.
6. While a search runs, the Add header collapses to height 0 instead of unloading, because `ExpandGridView` doesn't relayout when its header is removed.
7. `MLFolderBrowseModel` answers a `thumbnail` role (= `small_cover`) for files, so `HomeVideoCard` stays untouched.
8. `LibraryFolderPage` plays state: `Qt.resolvedUrl(model.mrl)` against `Player.url`, because `Player.url` is decoded and the ML mrl is encoded.
9. `VLCIcons.artist` and `VLCIcons.genre` are new (from the Figma exports). `artist.svg` was flattened with a one-off per-element variant of the flatten script (winding fix), not committed.
10. The Songs page is a nested `PageLoader` (`base`, `folder`), so the paths read as the spec's table.
11. `PageExt._tabs`, the tab row and every `Navigation.downItem: tabRow` are gone.
12. Removed pages and their redirects: `["video","all"]`, `["video","playlists"]`, `["music","tracks"]`, `["music","playlists"]` no longer exist. A grep of `modules/gui/qt` (QML and C++) finds nothing that pushes them. The history is in memory only and starts at `["home"]`, so nothing can restore them either. The only mentions left are test inputs (`test_navigation_history.cpp`, `tst_LibraryHelpers.qml`). So there was nothing to redirect, and no redirect code was added.

Files removed with no remaining reference: `VideoAllDisplay.qml`, `VideoAllSubDisplay.qml`, `VideoGroupDisplay.qml`, `VideoPlaylistsDisplay.qml`, `MusicTracksDisplay.qml` (also from `meson.build`, `Makefile.am` and `po/POTFILES.in`).

Kept:
- `MusicPlaylistsDisplay.qml`: `PlaylistsDisplay.qml` is built on it.
- `VideoAll.qml`: Home's `continueWatching` page uses it.
- `MusicTrackListDisplay`, `PlaylistMediaDisplay` and `PlaylistMediaList`: Home's `listenAgain` and `MusicPlaylistsDisplay` still use them.

Controller rulings made during execution:
- Task 2 also answers a `thumbnail` role (departure 7).
- Task 3 shows the Add tile in both views (departure 5).
- Header Down and Escape on a page with an Add tile land on the Add tile; opening the Videos root therefore starts with the Add tile focused, ringless. A level restored by Back or a crumb is the exception: its first focus goes to the restored item (fix wave).
- The dead `displayText` fields on the Music albums/artists/genres entries were swept (nothing read them; `BannerTabButton` is used only by the toolbar editor, with its own model).

### Known minors (not fixed)
- `folder_tree`: duplicate roots give duplicate root children; `splitRange` boundary cases are only partly pinned in tests.
- `onVlcMlEvent` returns after a reset instead of deferring to the base class (harmless: the base handles none of those events).
- `MLBaseModel::addAndPlay` would pass a folder row's synthetic id; the page opens folders in QML and never plays them.
- No C++ model test for `MLFolderBrowseModel`; its ML wiring is evidenced by the harness.
- The grid and list Components in `LibraryFolderPage` repeat about 15 lines (column maths, margins, Add header shape); inline components can't see the file's ids and a single Component breaks the view's item pool.
- `ExpandGridView.qml` `'_getItem'` / `'layout'` TypeError from a delayed layout after a grid ↔ list switch (pre-existing `callLater` pattern; once seen in Task 3, absent from the final runs).
- `_emptyButton` is assigned in `onCompleted`.
- The non-searchable Music root header is about 5 px shorter than on searchable pages, so the header jumps entering Songs (fix: a minimum row height equal to the search field's).
- The Add dialog (`DialogsProvider.addFolderToLibrary()`) was not opened in the harness; a modal file dialog on Xvfb without a window manager is awkward, and it is the same call on both roots.
- The root empty state (Add tile plus the Browse button, with an empty library) was not exercised.

### Fix wave (final review)
- Back / a crumb restores the place in a level: the views record `History.viewProp.initialIndex` on `currentIndexChanged`, `_open` records the opened folder's index (a click doesn't make the card current, and index 0 is no change), and the page aliases `initialIndex` to its `MainViewLoader`. The first focus of a restored level skips the Add tile and sets the view's `currentIndex` before the rows load, so the view focuses that cell as it creates it. `MainViewLoader` also runs `resetFocus()` when loading ends (it only ran on a count change, which can land while still loading, and then bailed out); that is what scrolls a far item into view.
- Songs sort like the tracks: the menu has the old `MusicTracksDisplay` rows (Title, Album, Artist, Duration, Track; its Disc row is dropped, as `MLAudioModel` never sorted by it) and `MLFolderBrowseModel::nameToCriteria` takes `MLAudioModel`'s map. Videos keep Alphabetic / Duration / Date added.
- The menu key opens the context menu on `HomeVideoCard`, `HomeSquareCard` and `HomeListRow` (`Keys.onMenuPressed`, as `GridItem` does), so Home gets it too.
- `MLFolderBrowseModel` resets on `VLC_ML_EVENT_FOLDER_UPDATED`.
- `folder_tree` dedupes with a `QSet` and breaks case-insensitive ties case-sensitively (`Shows` before `shows`), pinned by a test.
- `LibraryFolderPage.qml` is in `po/POTFILES.in` (Home's QML files with strings already were).
- Harness: Videos ▸ redesign-media ▸ Shows (2nd folder), Back: Shows focused, by mouse and by keyboard; Back again: redesign-media focused at the Videos root, not Add. Songs sort menu lists the five track rows. With `ml.db` edited for the check (backed up first) to give `waveform` another artist and `black bird` an album "Zebra", Artist A-Z put waveform first and Z-A last, Album A-Z put black bird last and Z-A first (the fixture's tags are all "Tester" with no album; the original `ml.db` was put back). Menu key opened MLContextMenu on a video card, an audio card, a Songs list row and a Home Listen Again card. Log grep clean.

### Verification
- Build clean; `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt`: 14/14 OK after the deletions.
- Harness smoke (1600×900, `-vv`) after the deletions: Videos, Music, Network, Playlists, Recent, Add item (opens its menu), Home, Home ▸ "Continue Watching ›" (opens the 12-item page, Back returns to Home) and Home ▸ "Frequently Listened Artists ›" (Music ▸ Artists, 2 items) all load and render.
- Log grep (TypeError, ReferenceError, non-existent property, unavailable, "unable to load"): empty.
