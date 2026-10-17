# Library Home (slice 4b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace VLC 4's Home body with Figma's five rows: Continue Watching, Listen Again, Frequently Visited Folders, Frequently Visited Playlists, Frequently Listened Artists. Each row comes in a grid view and a list view.

**Architecture:**
- **Data:** two new media-library models.
  - `MLRecentAudioModel` is the audio twin of `MLRecentVideoModel`.
  - `MLFrequentArtistModel` ranks artists by how often they appear in the audio history.
  - Folders are ranked in QML, from `MLRecentMediaModel` through `Helpers.rankByFrequency`.
- **Layout:** `HomePage.qml` becomes a Flickable holding a `NavigableCol` of `HomeSection`s.
  - Each section has a clickable "Title ›" header and one line of cards (grid) or rows (list).
  - A section's `limit` is the number of cards that fit the width.
  - The Figma cards are new, Home-local QML files. 4c will generalise them for the library grids.

**Tech Stack:** Qt 6 / QML, the C++ media-library models (`MLBaseModel`/`MLListCacheLoader`), meson. Tests: `qml_test` (`tests/tst_*.qml`) and plain C++ test executables.

**Spec:** `docs/superpowers/specs/2026-10-17-vlc-redesign-library-home-design.md`

## Global Constraints

- **Figma is the source of truth** (`dSoAm0gN9ZterHSssJU9FN`, Home `6261:15078`, list variant `1106:5633`). VLC 4's Home is not a reference.
- **Sizes:** all Figma px go through `VLCStyle.dp(<px>, VLCStyle.scale)`, as in 4a.
- **Colours:** dark values are `#969696` (titles), `#6B6B6B` (subtitles), `#8F8F8F` (list text), `#171717` (image backing), `#1E1E1E` (folder card), `#D37918` (progress). Use the `theme.palette?.isDark ? <figma> : <theme role>` pattern from `PageExt.qml` for light mode.
- **Font:** Inter is already the UI font. Titles are 20 px, cards 16 px, list rows 14 px.
- **Harness runs** are silent and isolated:
  - always `--aout=dummy` (built into `vlc-xvfb.sh`);
  - xdotool only through `docs/superpowers/scripts/vlc-xvfb.sh click|key`, or with `DISPLAY=:77` set explicitly. **Never** touch the user's `:0`.
- **Log check after every task:** run `-vv`, then grep `build/redesign-profile/run/vlc.log` for `TypeError|ReferenceError|non-existent property|unavailable`. Ignore the known, pre-existing `ExpandGridView.qml … 'layout'` line.
- **Commits:** as the global git user, with no Claude attribution. The message style is `qt: …` or `doc: …`.
- **Build:** `ninja -C build`. **Tests:** `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt`.

## Review Focus

1. **Network or stream media in the play history** (`http://…`, `dvd://`). These have no parent folder. The folder row must skip anything that isn't `file://`, never show an empty-name card, and never crash. This is pinned by the `tst_LibraryHelpers` case `test_folderEntries_skipsNonFile` (Task 2).
2. **Tracks with no artist** (`i_artist_id == 0`) and the "Unknown Artist" row. The first are skipped. The artist row must not show a blank card. This is pinned by `test_frequency_rank` (zero ids are dropped) in Task 2.
3. **A narrow window** (sidebar plus 700 px of content): `limit` must stay ≥ 1, with no card overflowing the row and no horizontal scroll. Task 3 checks this in the harness at 1000×700.
4. **History changing while Home is open:** play something new, come back, and the rows update without a restart. This works through `VLC_ML_EVENT_HISTORY_CHANGED` → `resetRequested` in both new models, and through the folder recompute on `countChanged`/`modelReset`. Task 4 checks it in the harness.
5. **A search that matches nothing:** every row is hidden and "No results" shows. It must not fall back to the empty-library label. Task 5 checks it in the harness.

---

### Task 1: `MLRecentAudioModel`, the Listen Again sub-page, and the dead sub-pages removed

**Files:**
- Create: `modules/gui/qt/medialibrary/mlrecentaudiomodel.hpp`, `.cpp`. Copy `mlrecentvideomodel.*` with `MLVideoModel`→`MLAudioModel`, `MLVideo`→`MLAudio`, and `video_history`→`audio_history`.
- Modify: `modules/gui/qt/meson.build`. Add it to the moc headers list near line 98 and to the sources near line 359.
- Modify: `modules/gui/qt/Makefile.am`. Add it next to the three `mlrecentvideomodel` lines (~233, ~477).
- Modify: `modules/gui/qt/maininterface/mainui.cpp`. Add the include and `qmlRegisterType<MLRecentAudioModel>(uri, versionMajor, versionMinor, "MLRecentAudioModel")` next to line 481.
- Modify: `modules/gui/qt/medialibrary/qml/HomeDisplay.qml`.
  - Add a `listenAgain` page: a `Widgets.PageExt` titled `qsTr("Listen Again")`. It holds `MusicTrackListDisplay` (or whatever `MusicTracksDisplay` uses for its body) with `model: MLRecentAudioModel { ml: MediaLib; sortCriteria/sortOrder/searchPattern from the page }`, and the same `needToNavigateBack` behaviour as `continueWatching`.
  - Delete the `newVideo` and `newMusic` pages.

**Interfaces:**
- Produces: the QML type `MLRecentAudioModel`, with the same roles as `MLAudioModel` (`id`, `title`, `cover`, `small_cover`, `main_artist`, `duration`, `mrl`, …) and a `limit` property.
- Produces: the `HomeDisplay` page names `continueWatching`, `listenAgain` and `favorites`, used as `History.push(["home", <name>])`.

- [ ] **Step 1:** Write the two files. Build each `MLAudio` exactly as `MLAudioModel::Loader::load` does: its constructor takes the `vlc_medialibrary_t*` as well as the media, as `mlaudio.cpp:41` shows.
- [ ] **Step 2:** `ninja -C build`. Expected: links with no warnings in the new files.
- [ ] **Step 3:** Edit `HomeDisplay.qml` as above.
- [ ] **Step 4:** Harness check: `vlc-xvfb.sh start -vv`, let Home load, then grep `vlc.log`. Expected: no QML errors. Nothing on Home links to the Listen Again page until Task 3, so Task 3 checks it.
- [ ] **Step 5:** `meson test -C build --suite qt`. Expected: 12/12 OK.
- [ ] **Step 6:** Commit: `qt: add MLRecentAudioModel and the Listen Again home page`.

### Task 2: frequency ranking (C++ and JS) and `MLFrequentArtistModel`

**Files:**
- Create: `modules/gui/qt/util/frequency_rank.hpp`. Header-only.
- Create: `modules/gui/qt/tests/test_frequency_rank.cpp`. Register it in `meson.build` like `test_qt_waveform_util` (~1478), with the name `test_qt_frequency_rank` and no extra deps.
- Create: `modules/gui/qt/medialibrary/mlfrequentartistmodel.hpp`, `.cpp`. Register it in `meson.build`, `Makefile.am` and `mainui.cpp` like Task 1, with the QML name `MLFrequentArtistModel`.
- Modify: `modules/gui/qt/util/qml/Helpers.qml`. Add two functions.
- Modify: `modules/gui/qt/tests/tst_LibraryHelpers.qml`. Add their tests.

**Interfaces:**
- Produces (C++): `template <typename T> std::vector<T> rankByFrequency(const std::vector<T>& keysMostRecentFirst, const T& skip = T{})`.
  - It returns each distinct key once, most frequent first. Ties go to the key seen earliest in the input, which is the most recent.
  - Keys equal to `skip` are dropped.
- Produces (JS): `Helpers.rankByFrequency(keys : var) : var`. Same rule over an array of strings. Empty strings are dropped.
- Produces (JS): `Helpers.folderEntries(mrls : var) : var`.
  - It maps media MRLs, most recent first, to `[{ mrl: <folder url string>, name: <decoded last folder segment> }]`, ranked by `rankByFrequency`.
  - Only `file://` MRLs count. The folder is the MRL up to its last `/`, without the trailing slash.
  - This is pure JS, so it must not depend on `MainCtx`.
- Produces (QML type): `MLFrequentArtistModel`, a subclass of `MLArtistModel` with the same roles (`id`, `name`, `cover`, `nb_tracks`, …) and `limit`/`searchPattern`.
  - Its order: artists of the last 100 audio-history entries (`album_track.i_artist_id`), ranked by `rankByFrequency` with `skip = 0`.
  - `searchPattern` filters by case-insensitive name substring.
  - `count` and `load` must apply the same ranking and filter, then `offset`/`limit`.
  - `loadItemById` is `vlc_ml_get_artist`.
  - `onVlcMlEvent`: `VLC_ML_EVENT_HISTORY_CHANGED` → `emit resetRequested()`, then fall through to `MLArtistModel`.

- [ ] **Step 1: Write the failing C++ test** in `test_frequency_rank.cpp`. Use plain `assert`/`QCOMPARE` in the style of `test_waveform_util.cpp`:
  - `rankByFrequency<int64_t>({3,1,3,2,1,3}, 0) == {3,1,2}`
  - `rankByFrequency<int64_t>({5,0,7,0,7}, 0) == {7,5}` (zeros dropped, 7 is the more frequent)
  - `rankByFrequency<int64_t>({4,9}, 0) == {4,9}` (a tie keeps the most recent first)
  - `rankByFrequency<int64_t>({}, 0).empty()`
- [ ] **Step 2: Write the failing QML tests** in `tst_LibraryHelpers.qml`:
  - `test_rankByFrequency`: `["a","b","a","","c","b","a"]` → `["a","b","c"]`.
  - `test_folderEntries`: `["file:///m/Shows/e1.mkv","file:///m/Films/f.mkv","file:///m/Shows/e2.mkv"]` → `[{mrl:"file:///m/Shows",name:"Shows"},{mrl:"file:///m/Films",name:"Films"}]`.
  - `test_folderEntries_skipsNonFile`: `["http://x/a.mp3","dvd:///dev/sr0","file:///m/My%20Music/t.mp3"]` → `[{mrl:"file:///m/My%20Music",name:"My Music"}]`.
- [ ] **Step 3:** `ninja -C build && meson test -C build --suite qt`. Expected: `test_qt_frequency_rank` fails to compile or link, or fails its assertions, and `tst_LibraryHelpers` fails on the new cases.
- [ ] **Step 4:** Implement `frequency_rank.hpp` (count with a hash map, then a stable sort of first occurrences by count, descending), `Helpers.rankByFrequency` and `Helpers.folderEntries`.
- [ ] **Step 5:** Run the tests. Expected: all qt tests pass (13 + the new cases).
- [ ] **Step 6:** Implement `MLFrequentArtistModel`. A private helper, `std::vector<std::unique_ptr<MLArtist>> rankedArtists(vlc_medialibrary_t*, const QString& pattern)`, is shared by `count` and `load`. It uses `vlc_ml_list_audio_history` with `{ .i_nbResults = 100 }`. Build it. Expected: clean.
- [ ] **Step 7:** Commit: `qt: rank folders and artists by play history`.

### Task 3: Home cards and sections; rows 1–2 in grid view

**Files:**
- Create: `modules/gui/qt/medialibrary/qml/HomeSection.qml`.
- Create: `modules/gui/qt/medialibrary/qml/HomeVideoCard.qml`.
- Create: `modules/gui/qt/medialibrary/qml/HomeSquareCard.qml`.
- Register all three in the `VLC.MediaLibrary` QML file list in `meson.build`, next to `HomePage.qml`.
- Modify: `modules/gui/qt/medialibrary/qml/HomePage.qml`. Rewrite the Flickable body.
  - Delete: `NoMedialibHome.ConeNButtons`, the Favorites/New Videos/New Music rows, `listCover*` properties, and the four-row `setCurrentItemFocus`.
  - Keep: the Flickable scaffolding (`scrollHandler`, `contentYBehavior`, touch filtering, `positionFlickableToContainItem` on focus).

**Interfaces:**
- **`HomeSection`** (FocusScope):
  - `property string title`, `property var model` (an ML model or a JS array), `property Component cardDelegate`, `property Component listDelegate` (Task 5), `property real cardWidth`, `readonly property int fit`.
  - **`fit`** is the number of cards that fit: `Math.max(1, Math.floor((width + dp(20)) / (cardWidth + dp(20))))`.
  - **`signal titleClicked(int reason)`.**
  - **`function setCurrentItemFocus(reason)`.**
  - **Visible** only when the shown count is > 0.
  - **Layout:**
    - top/bottom padding 20;
    - header row (gap 5): the title as a focusable button in Inter 20 `#969696`, then a 24 px `VLCIcons.chevron_down` rotated −90 in the same colour;
    - then the card row: a `Widgets.NavigableRow`, top/bottom padding 20, spacing 20, `delegate: cardDelegate`;
    - `Navigation` goes down from the title to the row and up from the row to the title.
- **`HomeVideoCard`:**
  - `required property var model` (roles `id`, `title`, `thumbnail`, `progress`), `property var contextModel`, `property int index`.
  - **Size and layout:** 316 wide, a 16:9 thumbnail with radius 12, on `#171717`.
    - The image is a cover-filled `Widgets.ImageExt` with `radius`.
    - A 20 % black veil sits over it.
    - The bottom-left `#D37918` bar is 4 px tall, `width: thumb.width * model.progress`, visible when progress > 0.
    - A 20 px gap, then the title in Inter 16 `#969696`, elided.
  - **Click / Enter:** `MediaLib.addAndPlay(model.id)`. **Right-click:** `MLContextMenu` on `contextModel`.
  - **Focus:** a focus ring like 4a's grid card.
- **`HomeSquareCard`:**
  - `property url image`, `property string glyph` (used when `image` is empty, as a 48 px `VLCIcons` glyph), `property color backing` (default `#171717`; folders use `#1E1E1E`), `property string title`, `property string subtitle`.
  - **`signal activated()`** on click or Enter, and **`signal menuRequested(point globalPos)`**.
  - **Layout:** a 200×200 image with radius 12, a 20 px gap, then title (Inter 16 `#969696`), a 10 px gap, and subtitle (Inter 16 `#6B6B6B`, hidden if empty).
- **`HomePage`, after this task:** `NavigableCol { id: sections }`. Its sections are:
  - `continueWatching`: `MLRecentVideoModel { limit: continueWatching.fit; sort/search from root }`, `cardWidth: dp(316)`;
  - `listenAgain`: `MLRecentAudioModel { limit: listenAgain.fit; … }`, `cardWidth: dp(200)`, cards with `image: model.cover`, `title: model.title`, `subtitle: model.main_artist`.
  - `titleClicked` → `root.seeAllButtonClicked(<"continueWatching"|"listenAgain">, reason)`.
  - Page margins: content left/right = 20 (from the Figma: `p-[20px]` on the content column), sections full width.

- [ ] **Step 1:** Write the three components to the values above.
- [ ] **Step 2:** Rewrite the `HomePage` body with the two sections. `setCurrentItemFocus` focuses the first visible section.
- [ ] **Step 3:** Build, then check in the harness.
  - Play a video for about 10 s and stop it. Play an audio track. Go Home.
  - Take a shot (`vlc-xvfb.sh shot …/home_t3.png`). Both rows should show Figma-sized cards and a progress bar on the video.
  - Click "Listen Again ›": the Listen Again page lists the track. Back.
  - Resize to 1000×700 with `xdotool windowsize` on `DISPLAY=:77`: the rows hold fewer cards, with no overflow (Review Focus 3).
- [ ] **Step 4:** Check the log, then `meson test`. Expected: clean, all pass.
- [ ] **Step 5:** Commit: `qt: home Continue Watching and Listen Again rows with the Figma cards`.

### Task 4: rows 3–5 (Folders, Playlists, Artists) and the Folders page

**Files:**
- Modify: `modules/gui/qt/medialibrary/qml/HomePage.qml`.
- Modify: `modules/gui/qt/medialibrary/qml/HomeDisplay.qml`. Add a `folders` page: a `Widgets.PageExt` titled `qsTr("Frequently Visited Folders")`, with a wrapping `Flow`/`GridView` of `HomeSquareCard`s over `Helpers.folderEntries(...)` (the full list, not truncated).

**Interfaces:**
- Consumes: `Helpers.folderEntries`, `MLFrequentArtistModel`, `HomeSection`, `HomeSquareCard` (Task 2/3).
- **`HomePage` folder data:**
  - Add `MLRecentMediaModel { id: historyModel; ml: MediaLib; limit: 100 }` and a `property var folderEntries: []`.
  - Recompute on `historyModel.countChanged` and `modelReset`: `historyModel.getDataFlat([0..count-1], items => folderEntries = Helpers.folderEntries(items.filter(i => i).map(i => i.mrl.toString())))`.
  - The section's model is `folderEntries` filtered by `root.search.pattern` (case-insensitive name match), then `.slice(0, fit)`.
- **Folder card:** `glyph: VLCIcons.folder`, `backing: "#1E1E1E"`, `title: name`. When activated:
  ```js
  const tree = MainCtx.folderTree(mrl)
  if (tree) History.push(["network", "browse"], { tree: tree }, reason)
  ```
  This mirrors `Player.qml`'s `onFolderClicked`.
- **Playlists:** `MLPlaylistListModel { ml: MediaLib; playlistType: MLPlaylistListModel.PLAYLIST_TYPE_ALL; limit: fit; searchPattern }`. Mark it `// ponytail: library order; rank by the plays of a playlist's tracks if that ever matters`.
  - The card: `image: model.thumbnail`, `title: model.name`, `subtitle: qsTr("%1 track", "%1 tracks", model.count).arg(model.count)`.
  - Activate → `History.push(["playlists", "list"], { parentId: model.id, title: model.name }, reason)`.
  - Title → `History.push(["playlists"], reason)`.
- **Artists:** `MLFrequentArtistModel { ml: MediaLib; limit: fit; searchPattern }`.
  - The card: `image: model.cover`, `title: model.name`, `subtitle` = "%n tracks" over `nb_tracks`.
  - Activate → `History.push(["music", "artists", "albums"], { artistId: model.id }, reason)`.
  - Title → `History.push(["music", "artists"], reason)`.
- **Folder section title** → `root.seeAllButtonClicked("folders", reason)`.
- **Context menus:** playlists and artists use `MLContextMenu`; folders have none.

- [ ] **Step 1:** Add the three sections and the folder data.
- [ ] **Step 2:** Add the `folders` page to `HomeDisplay`.
- [ ] **Step 3:** Harness check (Review Focus 4).
  - Home shows the folder row (the `redesign-media` / `redesign-music` folders), the Playlists row (create one through Add item ▸ New playlist if the profile has none), and the Artists row with "Tester".
  - Click each card and each title, and confirm where each lands.
  - Play a track from another artist, return Home: the Artists row updates without a restart.
- [ ] **Step 4:** Check the log, run `meson test`, then commit: `qt: home folder, playlist and artist rows`.

### Task 5: list view, header count, Favorites in "…", empty states

**Files:**
- Create: `modules/gui/qt/medialibrary/qml/HomeListRow.qml`. Register it in `meson.build`.
- Modify: `HomeSection.qml` and `HomePage.qml`.

**Interfaces:**
- **`HomeListRow`:** `property url image`, `property string glyph`, `property real progress: -1`, `property string text`, plus `signal activated()` and `signal menuRequested(point globalPos)`.
  - Height 42.
  - A 32 px image with radius 4: square crop with `fillMode: PreserveAspectCrop`. When `image` is empty, a 24 px glyph in `#8F8F8F`.
  - When `progress ≥ 0`, a 4 px `#D37918` mark sits under the image, 32 × progress wide.
  - Then a 10 px gap and `text` in Inter 14 `#8F8F8F`, elided.
- **`HomeSection` in list mode** (`!MainCtx.gridView`):
  - the header is the title in Inter 16, with the chevron at the far right;
  - the body is a `Widgets.NavigableCol` of `listDelegate` instances over the same model, with `fit` fixed at `5` *(the list variant shows 3 in a narrow panel; 5 matches today's Home list limit)*.
- **Row text:**

  | Row | Text |
  |---|---|
  | video | `title` |
  | audio | `title + " - " + main_artist` |
  | folder | `name` |
  | playlist | `name` |
  | artist | `name` |

- **Row glyphs:** folder `VLCIcons.folder`, playlist `VLCIcons.playlists`. For artists use `cover`, falling back to `VLCStyle.noArtArtistSmall`.
- **Header count:** the Flickable gets `readonly property int count: libraryCount.count`, with `MLMediaModel { id: libraryCount; ml: MediaLib }`. `PageExt.itemCount` reads `_firstChild.count`, so check that the Flickable is `_firstChild`; if it isn't, expose the count on whatever is.
- **"…":** `headerMenuRows: [{ text: qsTr("Favorites"), run: () => root.seeAllButtonClicked("favorites", Qt.OtherFocusReason) }]`. Use the row shape from 4a's `FigmaMenu`, `{text, icon, checked, run}`, with `icon` and `checked` omitted.
- **Empty states**, a centred item in place of the sections:
  - **No visible sections and `search.pattern === ""`:** `Widgets.EmptyLabelButton` with the text `qsTr("No media found\nPlease try adding sources")`, the cover `VLCStyle.noArtVideoCover`, and the button `qsTr("Browse")` → `History.push(["network"])`.
  - **No visible sections and a non-empty pattern:** `Widgets.EmptyLabel` with `qsTr("No results")`.
  - Wait until the ML models finish loading (`!model.loading`), as the old `_hasMedias` binding did, so the label doesn't flash at startup.

- [ ] **Step 1:** Write `HomeListRow` and the list mode in `HomeSection`, then wire `listDelegate` for all five rows.
- [ ] **Step 2:** Add the header count, the "…" Favorites row and the empty states.
- [ ] **Step 3:** Harness check (Review Focus 5).
  - Toggle the view: list rows match `sidebar_home.png`'s rows (32 px art, "title - artist").
  - Search "zzzz": "No results", with no rows.
  - Clear the search: the rows come back.
  - "…" ▸ Favorites opens the Favorites page.
  - The header reads "N items" with the library total.
- [ ] **Step 4:** Check the log, run `meson test`, then commit: `qt: home list view, item count, favorites menu row and empty states`.

### Task 6: shots, ledger, roadmap

**Files:**
- Create: `docs/superpowers/figma/4b/after_home_grid.png`, `after_home_list.png`, `after_home_empty_search.png`.
- Modify: this plan (append `## Ledger`) and `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md` (mark the 4b row done and record the departures).

- [ ] **Step 1:** Take the three shots at 1600×900 with history present.
- [ ] **Step 2:** Write `## Ledger`.
  - A table with one line per Figma value (section padding, title size and colour, card sizes, gaps, progress bar, folder card colour): the Figma value, what's built, and match or deviation.
  - A "Departures" list with every *(my call)* from the spec.
- [ ] **Step 3:** Update the roadmap row 4b to "(done)" with the plan name and one line of departures.
- [ ] **Step 4:** Commit: `doc: finish the library home slice`.
