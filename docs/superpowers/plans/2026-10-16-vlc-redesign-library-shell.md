# VLC Redesign: Slice 4a, Library Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The library window gets the Figma shell:
- a sidebar of exactly seven entries (Home, Videos, Music, Network, Playlists, Recent, Add item);
- a page header with breadcrumbs, the item count, Figma sort and view menus, an always-visible search field and a "…" menu;
- temporary text tabs for the old Videos/Music sub-items;
- one shared Figma menu component behind every menu.

**Architecture:**
- **Pure helpers** in the existing `Helpers` singleton (`VLC.Util`): `sortRowLabel()` (the sort-menu wording table) and `breadcrumbs()` (crumbs from a page path). A QML unit test covers both.
- **`widgets/qml/FigmaMenu.qml`**: a `T.Menu` filled from a plain `rows` array through an `Instantiator`. The sort, view, "…" and Add item menus all use it.
- **Header:** `PageExt.qml`'s `DefaultPageHeader` gains a crumb row and a tab row. `GridSortFilterControls.qml` becomes the Figma right group (sort, view, search, "…").
- **Sidebar:** `NavigationModel` (C++) becomes a flat seven-row list. `MainDisplay.qml` gains the `playlists` and `recent` pages and the Add item menu. The "…" title-bar menu gets Discover under More.
- **Library actions with dialogs** (add a folder to the library, create a playlist) become two `DialogsProvider` slots. The QML callers (`VLC.Widgets`, `MainDisplay`) cannot import `VLC.MediaLibrary`, which is registered only when the media library exists.

**Tech Stack:**
- Qt 6 QML (QtQuick, Templates, QtQml.Models `Instantiator`), QtTest QML (`qml_test`).
- C++17: `NavigationModel`, `DialogsProvider`, `VLCMenuBar`/`QmlGlobalMenu`, QTest.
- The icon-font pipeline (`pixmaps/makeIconFont.py`), the Figma MCP for two glyphs.
- The Xvfb and Wayland harness.

**Spec:** `docs/superpowers/specs/2026-10-16-vlc-redesign-library-shell-design.md`. Read it first.
- **Figma file:** `dSoAm0gN9ZterHSssJU9FN` (Galen's `d9xvroRclV6SaObbcqRmBr` cannot be read here).
- **Frames:** Videos grid `970:4028` (sidebar `970:4043`, header row `1040:2669`, crumbs `6153:13642`, search `1040:2876`), Home `6261:15078`, Sorting Options `856:2215`, View Options `858:3290`.
- **Reference shots** in `docs/superpowers/figma/4a/`: `grid.png`, `home.png`, `list.png`, `sort_menu.png`, `view_menu.png`, and today's `before_home.png`, `before_videos.png`.

### Where this plan departs from the spec, and why

1. **Helpers instead of `SortLabels.js`.** The QML module build (`meson.build` `qml_modules`) lists only `.qml` sources and singletons; it has no `.js` path. `Helpers.qml` is already a `VLC.Util` singleton, and `qml_test` already links `VLC.Util` (`tst_FSM`). So the table lives in `Helpers.sortRowLabel()`, and the test is `tests/tst_LibraryHelpers.qml`.
2. **`album_title` is always "Album A-Z / Z-A".** Every page that offers `album_title` sorts tracks by their album (`MusicTracksDisplay`, `MusicArtistsAlbums` list mode). No page sorts albums by their own title through that key, so the per-page label override isn't needed.
3. **Two `DialogsProvider` slots** replace "`getExistingDirectoryUrl()` + `MLFolderModel.add(url)`" and "`getTextDialog` + `MLPlaylistListModel.create`":
   - `addFolderToLibrary()` and `newPlaylist()`.
   - The callers live in `VLC.Widgets` and `MainDisplay`, which can't import `VLC.MediaLibrary` (it isn't registered without a media library).
   - The slots make the same `vlc_ml_add_folder` / `vlc_ml_playlist_create` calls those models make.
4. **Two crumb depths wait for 4c:**
   - *Music ▸ Albums ▸ album* doesn't exist yet: an album opens as an inline expand panel in the Albums grid, not as a page.
   - *Music ▸ Artists ▸ artist* doesn't either: that page (`MusicArtistsAlbums.qml`) sets `header: null` and draws its own artist banner.
   - 4c replaces both views. Every other depth in the spec gets its crumbs here.
5. **Video grouping moves into the sort menu.** The old Videos sort menu (`SortMenuVideo`) also offered "Do not group videos / Group by name / Group by folder". The Figma menu keeps them as three rows after the sort rows, so grouping isn't lost before 4c.
6. **The network folder page joins the shared header.**
   - `BrowseTreeHeader.qml` and `NetworkAddressbar.qml` are replaced by the shared header, with crumbs from the browse model's path.
   - Their "Add to / Remove from media library" button becomes a row of that page's "…" menu.
7. **Two new glyphs.** Figma's sidebar Playlists icon (lines with a play triangle) differs from the existing `playlist` glyph, and Figma's thin menu check differs from the old `check`. Both are appended as `playlists` and `checkmark`.
8. **View Options is 265 wide.** That's the Figma node's width (`858:3290`). The spec's 295 is the Sorting Options width.

## Global Constraints

- **Branch:** `redesign/library-shell` (it already holds the spec). One commit per task, authored as the repo's global git user (`ming <mingbao2891@gmail.com>`), with no AI attribution or co-author trailer.
- **Palette:** Figma's dark hex values apply only when `theme.palette.isDark`. Otherwise use ColorContext colours (light theme is slice 10).
- **Sizes and strings:** sizes are `VLCStyle.dp(n, VLCStyle.scale)` (24 px icons may use `VLCStyle.icon_normal`, which is `dp(24)`). User strings go in `qsTr()` (QML) or `qtr()` (C++).
- **New QML files** are added to both build systems:
  - `modules/gui/qt/meson.build`: in the module's `'sources': files(...)` list.
  - `modules/gui/qt/Makefile.am`: in the matching `*_QML` list, next to a sibling.
  - Removed QML files leave both lists the same way.
- **Icon font keys are append-only** (charcodes go by index).
- **Silence:** every run uses `--aout=dummy` (the harness adds it). Any hand-rolled run must add it too.
- **Harness:**
  - `H=docs/superpowers/scripts/vlc-xvfb.sh; L=build/redesign-profile/run/vlc.log`; `S` is the session scratchpad directory.
  - Before each start: `cp /tmp/conf.bak build/redesign-profile/config/vlc/vlc-qt-interface.conf`. If `/tmp/conf.bak` is gone, run `$H seed` once and copy the seeded conf to `/tmp/conf.bak`.
  - Start in the library: `$H start -vv; sleep 6`. The window is 1600×900.
  - Shots: `$H shot $S/<name>.png`. Clicks: `$H click X Y`, with coordinates read off the previous shot. Keys: `$H key Escape`. Stop: `$H stop`.
  - Shots go in the scratchpad, never the repo, except the final ones in Task 7.
- **Log check:** every visual check ends with `grep -E "TypeError|ReferenceError|non-existent property|unavailable|Unable to assign|is not a type|Could not convert|Cannot assign|Cannot read property|unable to load view|component is not ready" $L`. Expected: no output.
- **Process check:** after `$H stop`, `pgrep -x vlc-static` prints nothing.
- **Build and test:**
  - `ninja -C build` must be clean.
  - `meson test -C build --suite qt` must pass every test: 11 before this slice, 12 after Task 1.
- **Dialogs in the harness:** cancel every native dialog the checks open (`$H key Escape`). Never add folders outside `build/` to the test library.

## Review Focus

1. **Escape while a menu is open.**
   - Open the sort menu, then press Escape.
   - Expected: only the menu closes. The page stays put (`MainDisplay`'s `Navigation.cancelAction` must not run `History.previous`), and focus is back on the sort button: Right then reaches the view button.
   - Pinned in Task 3, Step 6.
2. **A deep path in a narrow window.**
   - At 1000×700, open Videos ▸ Playlists ▸ a playlist, or a Network folder 3+ levels deep.
   - Expected: the first crumbs fold into one "…" crumb, and the right group (count, sort, view, search, "…") is never pushed off or overlapped. Clicking "…" goes one level above the first visible crumb.
   - Pinned in Task 4, Step 6.
3. **No media library** (`--no-media-library`).
   - Expected:
     - the sidebar shows Home, Network and Add item;
     - the Add item menu offers only "Open network stream";
     - the header "…" offers only "Add File";
     - no QML errors.
   - Pinned in Task 5, Step 6 and Task 6, Step 5.
4. **Search across pages.**
   - Type in the field on Videos, then switch to Music and come back.
   - Expected: each page starts with an empty field and an unfiltered list. Escape clears the field and moves focus to the content. Ctrl+F focuses the field.
   - Pinned in Task 3, Step 6.
5. **Cancelled dialogs.**
   - Cancel the folder picker; cancel the playlist-name dialog; confirm it with an empty or whitespace name.
   - Expected: nothing is added or created, and the page doesn't change.
   - Pinned in Task 6, Step 5.

---

### Task 1: Sort-row labels and breadcrumbs helpers, with a QML test

**Files:**
- Modify: `modules/gui/qt/util/qml/Helpers.qml` (two functions at the end of the `QtObject`)
- Create: `modules/gui/qt/tests/tst_LibraryHelpers.qml`
- Modify: `modules/gui/qt/meson.build` (`qml_tests`), `modules/gui/qt/Makefile.am` (the `if HAVE_QT_QUICK_TEST` block)

**Interfaces:** produces, on the `Helpers` singleton (`import VLC.Util`):
- `sortRowLabel(criteria: string, text: string, order: int) : string`. `order` is `Qt.AscendingOrder` or `Qt.DescendingOrder`; `text` is the page's own sortModel label, used only for unknown keys.
- `breadcrumbs(prefix: var, title: string, labels: var) : var` returns `[{ title, path }]`.
  - There is one crumb per prefix level whose joined path (`"music/albums"`) is a key of `labels`.
  - Then comes `title` (with `path` = the whole prefix), unless the last crumb already reads `title`.

- [ ] **Step 1: Write the failing test** `modules/gui/qt/tests/tst_LibraryHelpers.qml`. Give it the GPL header of `tests/tst_FSM.qml`, year 2026.

```qml
import QtQuick
import QtTest
import VLC.Util

TestCase {
    name: "LibraryHelpers"

    function test_sortRowLabel_data() {
        return [
            { tag: "title", criteria: "title", asc: "Title A-Z", desc: "Title Z-A" },
            { tag: "name", criteria: "name", asc: "Title A-Z", desc: "Title Z-A" },
            { tag: "album_title", criteria: "album_title", asc: "Album A-Z", desc: "Album Z-A" },
            { tag: "release_year", criteria: "release_year", asc: "Oldest First", desc: "Newest First" },
            { tag: "duration", criteria: "duration", asc: "Shortest First", desc: "Longest First" },
            { tag: "last_played_date", criteria: "last_played_date", asc: "Unwatched First", desc: "Watched First" },
            { tag: "main_artist", criteria: "main_artist", asc: "Artist A-Z", desc: "Artist Z-A" },
            { tag: "track_number", criteria: "track_number", asc: "Track Number Ascending", desc: "Track Number Descending" },
            { tag: "disc_number", criteria: "disc_number", asc: "Disc Number Ascending", desc: "Disc Number Descending" },
            { tag: "mrl", criteria: "mrl", asc: "URI Ascending", desc: "URI Descending" },
            { tag: "url", criteria: "url", asc: "URI Ascending", desc: "URI Descending" },
            { tag: "nb_tracks", criteria: "nb_tracks", asc: "Fewest Items First", desc: "Most Items First" },
            { tag: "nb_videos", criteria: "nb_videos", asc: "Fewest Items First", desc: "Most Items First" },
        ]
    }

    function test_sortRowLabel(data) {
        compare(Helpers.sortRowLabel(data.criteria, "ignored", Qt.AscendingOrder), data.asc)
        compare(Helpers.sortRowLabel(data.criteria, "ignored", Qt.DescendingOrder), data.desc)
    }

    function test_sortRowLabelFallback() {
        compare(Helpers.sortRowLabel("fileSizeRaw64", "File size", Qt.AscendingOrder), "File size Ascending")
        compare(Helpers.sortRowLabel("fileSizeRaw64", "File size", Qt.DescendingOrder), "File size Descending")
        compare(Helpers.sortRowLabel("", "", Qt.AscendingOrder), " Ascending")
    }

    readonly property var labels: ({ "video": "Videos", "video/playlists": "Playlists",
                                     "music": "Music", "music/albums": "Albums" })

    function test_breadcrumbs_titleOnLastLevel() {
        // Videos ▸ All ▸ base, titled "Videos": "all"/"base" have no label, the title repeats the last crumb
        compare(Helpers.breadcrumbs(["video", "all", "base"], "Videos", labels),
                [{ title: "Videos", path: ["video"] }])
    }

    function test_breadcrumbs_titleAppended() {
        compare(Helpers.breadcrumbs(["video", "playlists", "list"], "Road trip", labels),
                [{ title: "Videos", path: ["video"] },
                 { title: "Playlists", path: ["video", "playlists"] },
                 { title: "Road trip", path: ["video", "playlists", "list"] }])
    }

    function test_breadcrumbs_unknownPage() {
        compare(Helpers.breadcrumbs(["discover", "services"], "Services", labels),
                [{ title: "Services", path: ["discover", "services"] }])
    }

    function test_breadcrumbs_emptyTitle() {
        compare(Helpers.breadcrumbs(["music", "albums"], "", labels),
                [{ title: "Music", path: ["music"] }, { title: "Albums", path: ["music", "albums"] }])
        compare(Helpers.breadcrumbs([], "", labels), [])
    }
}
```

  - Register it:
    - **meson.build:** `qml_tests = { 'tst_FSM': files('tests/tst_FSM.qml'), 'tst_LibraryHelpers': files('tests/tst_LibraryHelpers.qml'), }`, one entry per line as the file already does.
    - **Makefile.am:** after `TESTS += tests/tst_FSM.qml`, add `EXTRA_DIST += tests/tst_LibraryHelpers.qml` and `TESTS += tests/tst_LibraryHelpers.qml`.
- [ ] **Step 2: Run it and watch it fail.** `meson test -C build tst_LibraryHelpers --print-errorlogs`. Expected: FAIL with `TypeError: Property 'sortRowLabel' of object … is not a function`.
- [ ] **Step 3: Implement.** Append to `Helpers.qml`, inside the `QtObject`, after the last function:

```qml
    // Label of one row of the redesign's sort menu (Figma "Sorting Options" 856:2215).
    // `text` is the page's own sortModel label, used for criteria the table does not know.
    function sortRowLabel(criteria : string, text : string, order : int) : string {
        const asc = (order === Qt.AscendingOrder)
        switch (criteria) {
        case "title":
        case "name":
            return asc ? qsTr("Title A-Z") : qsTr("Title Z-A")
        case "album_title":
            return asc ? qsTr("Album A-Z") : qsTr("Album Z-A")
        case "release_year":
            return asc ? qsTr("Oldest First") : qsTr("Newest First")
        case "duration":
            return asc ? qsTr("Shortest First") : qsTr("Longest First")
        case "last_played_date":
            return asc ? qsTr("Unwatched First") : qsTr("Watched First")
        case "main_artist":
            return asc ? qsTr("Artist A-Z") : qsTr("Artist Z-A")
        case "track_number":
            return asc ? qsTr("Track Number Ascending") : qsTr("Track Number Descending")
        case "disc_number":
            return asc ? qsTr("Disc Number Ascending") : qsTr("Disc Number Descending")
        case "mrl":
        case "url":
            return asc ? qsTr("URI Ascending") : qsTr("URI Descending")
        case "nb_tracks":
        case "nb_videos":
            return asc ? qsTr("Fewest Items First") : qsTr("Most Items First")
        default:
            return (asc ? qsTr("%1 Ascending") : qsTr("%1 Descending")).arg(text)
        }
    }

    // Page-header crumbs for the page at `prefix` titled `title`: one crumb per prefix level
    // that `labels` names (keyed by the joined path, e.g. "music/albums"), then the title
    // unless the last crumb already reads it. Each crumb is { title, path }.
    function breadcrumbs(prefix : var, title : string, labels : var) : var {
        const crumbs = []
        for (let i = 1; i <= prefix.length; ++i) {
            const path = prefix.slice(0, i)
            const label = labels[path.join("/")]
            if (label)
                crumbs.push({ title: label, path: path })
        }
        if (title && (crumbs.length === 0 || crumbs[crumbs.length - 1].title !== title))
            crumbs.push({ title: title, path: prefix.slice(0) })
        return crumbs
    }
```

- [ ] **Step 4: Run it and watch it pass.** `ninja -C build && meson test -C build tst_LibraryHelpers --print-errorlogs`: PASS. Then `meson test -C build --suite qt`: 12/12.
- [ ] **Step 5: Commit** `qt: add the library sort-label and breadcrumb helpers`.

---

### Task 2: Playlists and check glyphs

**Files:**
- Create: `modules/gui/qt/pixmaps/redesign/playlists.svg`, `modules/gui/qt/pixmaps/redesign/checkmark.svg`
- Modify: `modules/gui/qt/pixmaps/redesign/mapping.json`, `modules/gui/qt/pixmaps/VLCIcons.json`
- Regenerate: `modules/gui/qt/pixmaps/VLCIcons.ttf`, `modules/gui/qt/style/vlcicons.hpp` (and `vlcicons.cpp` if the generator touches it)

**Interfaces:** produces `VLCIcons.playlists` (QML) / `VLCIcons::playlists` (C++), Figma's sidebar Playlists glyph, and `VLCIcons.checkmark`, Figma's menu check. Both keys are appended after `audio_tracks`, the current last.

- [ ] **Step 1: Failing check.**
  - Add `"playlists.svg": ["playlists"]` and `"checkmark.svg": ["checkmark"]` to `mapping.json`.
  - Run `python3 -I docs/superpowers/scripts/check-icon-font.py modules/gui/qt/pixmaps`. Expected: FAIL (SVGs missing).
- [ ] **Step 2: Export from Figma.** Load the `figma:figma-use` skill, then run `use_figma` on file `dSoAm0gN9ZterHSssJU9FN`:

```js
const ids = {
  'playlists': 'I970:4062;177:88',        // sidebar "Playlists" icon (970:4043)
  'checkmark': 'I2107:5993;2107:5944',    // View Options "List View" check (858:3290)
};
const out = {};
for (const [name, id] of Object.entries(ids)) {
  const n = await figma.getNodeByIdAsync(id);
  out[name] = n ? await n.exportAsync({ format: 'SVG_STRING', svgOutlineText: true }) : null;
}
return out;
```

  - Write each string to `modules/gui/qt/pixmaps/redesign/<name>.svg`.
  - If an id is null, run `get_metadata` on `970:4062` / `2107:5993` and export the child `Icon` instance it lists.
- [ ] **Step 3: Clean and flatten:**

```sh
python3 -I docs/superpowers/scripts/clean-figma-svg.py modules/gui/qt/pixmaps/redesign/{playlists,checkmark}.svg
python3 -I docs/superpowers/scripts/flatten-figma-svg.py modules/gui/qt/pixmaps/redesign/{playlists,checkmark}.svg
```

- [ ] **Step 4: Append and regenerate.**
  - In `VLCIcons.json`, append `{"key":"playlists", "path": "./redesign/playlists.svg"}` and `{"key":"checkmark", "path": "./redesign/checkmark.svg"}` after the `audio_tracks` entry.
  - From `modules/gui/qt/pixmaps`, run `python3 makeIconFont.py VLCIcons.json`.
- [ ] **Step 5: Check.**
  - `check-icon-font.py` prints `icon font OK`.
  - `git diff modules/gui/qt/style/vlcicons.hpp` shows exactly two added keys and no renumbered key.
  - Render both: `python3 -I -c "import fontforge,json;m=json.load(open('modules/gui/qt/pixmaps/VLCIcons.json'));o=[g['key'] for g in m['glyphs']];f=fontforge.open('modules/gui/qt/pixmaps/VLCIcons.ttf');[f[0xE000+o.index(k)].export(f'$S/g_{k}.png',64) for k in ('playlists','checkmark')]"`.
  - Compare by eye: the Playlists icon in `docs/superpowers/figma/4a/grid.png` (lines with a play triangle), and the check in `view_menu.png`.
- [ ] **Step 6:** `ninja -C build`, then commit `qt: add the redesign's playlists and menu check icons`.

---

### Task 3: FigmaMenu and the header's right group

**Files:**
- Create: `modules/gui/qt/widgets/qml/FigmaMenu.qml` (register in `VLC.Widgets`: `meson.build` after `'widgets/qml/PageExt.qml',`; `Makefile.am` after `widgets/qml/PageExt.qml \`)
- Rewrite: `modules/gui/qt/widgets/qml/GridSortFilterControls.qml`
- Modify: `modules/gui/qt/widgets/qml/PageExt.qml` (drop `sortMenu`; add `sortExtraRows` and `headerMenuRows`; restyle the item count)
- Modify: `modules/gui/qt/medialibrary/qml/VideoAllSubDisplay.qml`, `VideoGroupDisplay.qml` (`sortMenu: SortMenuVideo {…}` becomes `sortExtraRows`)
- Modify: `modules/gui/qt/dialogs/dialogs_provider.hpp` / `.cpp` (new `addFolderToLibrary()`)

**Interfaces:**
- Consumes: `Helpers.sortRowLabel` (Task 1), `VLCIcons.checkmark` (Task 2).
- Produces:
  - `FigmaMenu`, a `T.Menu` with `property var rows`. Each row is `{ text: string, icon?: string (glyph), checked?: bool, run?: function }`. `run` is called with `Qt.callLater` after the menu closes. Default width 295; open it with `menu.popup(anchorItem, x, y)`.
  - `PageExt.sortExtraRows: var` (rows appended to the sort menu) and `PageExt.headerMenuRows: var` (rows appended to the header "…" menu).
  - `GridSortFilterControls` properties `sortExtraRows` and `menuExtraRows`.
  - `DialogsProvider.addFolderToLibrary()`, a `Q_INVOKABLE void`: a folder picker, then the folder is added to the media library; a no-op without a media library or when cancelled.

- [ ] **Step 1: Failing check.**
  - `$H start -vv; sleep 6; $H shot $S/t3_before.png`, then click Videos in the sidebar and shoot `$S/t3_before_videos.png`.
  - The header's right group shows the list/grid toggle, the sort icon and a search *icon*. There is no field and no "…", as in `docs/superpowers/figma/4a/before_videos.png`. Clicking sort opens the native Qt menu. `$H stop`.
- [ ] **Step 2: `DialogsProvider::addFolderToLibrary()`.**
  - In `dialogs_provider.hpp`, under `public:` after the `getTextDialog` declaration:

```cpp
    /* redesign library actions, called from QML */
    Q_INVOKABLE void addFolderToLibrary();
```

  - In `dialogs_provider.cpp`, add `#include "medialibrary/medialib.hpp"` after `#include "maininterface/mainctx.hpp"`, and `#include <vlc_media_library.h>` after `#include <vlc_url.h>`. Then, after `DialogsProvider::getDirectoryDialog`:

```cpp
void DialogsProvider::addFolderToLibrary()
{
    MediaLib* ml = p_intf->p_mi->getMediaLibrary();
    if( !ml )
        return;

    const QUrl url = QFileDialog::getExistingDirectoryUrl( nullptr,
            qtr( "Choose a folder to add to the Media Library" ),
            p_intf->p_mi->getDialogFilePath(), QFileDialog::ShowDirsOnly,
            { QStringLiteral( "file" ) } );
    if( url.isEmpty() )
        return;
    p_intf->p_mi->setDialogFilePath( url );

    // same call as MLFoldersModel::add
    ml->runOnMLThread( this, [url]( vlc_medialibrary_t* p_ml ) {
        vlc_ml_add_folder( p_ml, qtu( url.toString( QUrl::FullyEncoded ) ) );
    } );
}
```

- [ ] **Step 3: `widgets/qml/FigmaMenu.qml`.** Give it the GPL header of `widgets/qml/PageExt.qml`, year 2026.

```qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import QtQml.Models

import VLC.MainInterface
import VLC.Style

// The redesign's popup menu (Figma "View Options" 858:3290, "Sorting Options" 856:2215).
// rows: [{ text, icon (glyph, optional), checked (optional), run (function, optional) }]
T.Menu {
    id: root

    property var rows: []

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }
    readonly property bool _dark: theme.palette.isDark

    width: VLCStyle.dp(295, VLCStyle.scale)
    implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
    padding: VLCStyle.dp(4, VLCStyle.scale)
    margins: VLCStyle.margin_xsmall

    contentItem: ListView {
        implicitHeight: contentHeight
        model: root.contentModel
        interactive: Window.window ? contentHeight + root.topPadding + root.bottomPadding > Window.window.height
                                   : false
        clip: true
        currentIndex: root.currentIndex
        boundsBehavior: Flickable.StopAtBounds
    }

    background: Rectangle {
        radius: VLCStyle.dp(10, VLCStyle.scale)
        // ponytail: no 50 px backdrop blur; at 95 % opacity it does not show. Add a FrostedGlassEffect if the card gets lighter.
        color: root._dark ? Qt.rgba(25 / 255, 25 / 255, 25 / 255, 0.95) : theme.bg.primary

        // Figma: 0 8 15 rgba(0,0,0,0.46)
        RoundedRectangleShadow {
            color: Qt.rgba(0, 0, 0, 0.46)
            blurRadius: VLCStyle.dp(15, VLCStyle.scale)
            yOffset: VLCStyle.dp(8, VLCStyle.scale)
            implicitWidth: parent.width + blurRadius * compensationFactor * 2
            implicitHeight: parent.height + blurRadius * compensationFactor * 2
        }
    }

    Instantiator {
        model: root.rows

        delegate: T.MenuItem {
            id: item

            required property var modelData
            required property int index

            text: modelData.text

            implicitHeight: VLCStyle.dp(48, VLCStyle.scale)
            leftPadding: VLCStyle.dp(14, VLCStyle.scale)
            rightPadding: VLCStyle.dp(14, VLCStyle.scale)
            topPadding: VLCStyle.dp(2, VLCStyle.scale)
            bottomPadding: VLCStyle.dp(2, VLCStyle.scale)

            contentItem: RowLayout {
                spacing: VLCStyle.dp(10, VLCStyle.scale)

                IconLabel {
                    visible: !!item.modelData.icon
                    text: item.modelData.icon ?? ""
                    font.pixelSize: VLCStyle.icon_normal
                    color: label.color
                }

                T.Label {
                    id: label
                    Layout.fillWidth: true
                    text: item.text
                    elide: Text.ElideRight
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: root._dark ? "#8F8F8F" : theme.fg.primary
                }

                IconLabel {
                    visible: !!item.modelData.checked
                    text: VLCIcons.checkmark
                    font.pixelSize: VLCStyle.icon_normal
                    color: root._dark ? "#D37918" : theme.accent
                }
            }

            background: Rectangle {
                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: item.highlighted ? (root._dark ? "#1F1F1F" : theme.bg.secondary) : "transparent"
            }

            // later: run once the menu has closed, so a modal dialog does not nest inside the menu's event handling
            onTriggered: if (modelData.run) Qt.callLater(modelData.run)
        }

        onObjectAdded: (index, object) => root.insertItem(index, object)
        onObjectRemoved: (index, object) => root.removeItem(object)
    }
}
```

  - If `IconLabel`/`RoundedRectangleShadow` don't resolve unqualified inside `VLC.Widgets`, add `import VLC.Widgets as Widgets` and qualify them, as `BannerTabButton.qml` does.
- [ ] **Step 4: Rewrite `GridSortFilterControls.qml`.** Keep the GPL header; the body becomes:

```qml
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Util
import VLC.Dialogs

// The page header's right group (Figma 1040:2677 + "…" 2139:8916): sort, view, search, more
NavigableRow {
    id: root

    spacing: VLCStyle.dp(20, VLCStyle.scale)

    required property SortCtx sort
    required property SearchCtx search

    // FigmaMenu rows appended to the sort menu and to the "…" menu
    property var sortExtraRows: []
    property var menuExtraRows: []

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }
    readonly property bool _dark: theme.palette.isDark

    // two rows per sortModel entry (ascending, descending), then the page's extras
    function _sortRows() : var {
        const rows = []
        const model = root.sort.model ?? []
        for (let i = 0; i < model.length; ++i) {
            const entry = model[i]
            for (const order of [Qt.AscendingOrder, Qt.DescendingOrder]) {
                rows.push({
                    text: Helpers.sortRowLabel(entry.criteria, entry.text, order),
                    checked: root.sort.criteria === entry.criteria && root.sort.order === order,
                    run: () => { root.sort.criteria = entry.criteria; root.sort.order = order }
                })
            }
        }
        return rows.concat(root.sortExtraRows)
    }

    function _popup(menu : FigmaMenu, button : Item) {
        menu.popup(button, button.width - menu.width, button.height + VLCStyle.margin_xxsmall)
    }

    IconToolButton {
        id: sortBtn

        visible: root.sort.available
        enabled: visible
        width: VLCStyle.icon_normal
        height: VLCStyle.icon_normal
        font.pixelSize: VLCStyle.icon_normal
        text: VLCIcons.topbar_sort
        description: qsTr("Sort")
        checked: sortMenu.visible

        onClicked: {
            sortMenu.rows = root._sortRows()
            root._popup(sortMenu, sortBtn)
        }

        FigmaMenu { id: sortMenu }
    }

    IconToolButton {
        id: viewBtn

        visible: MainCtx.hasGridListMode
        enabled: visible
        width: VLCStyle.icon_normal
        height: VLCStyle.icon_normal
        font.pixelSize: VLCStyle.icon_normal
        text: MainCtx.gridView ? VLCIcons.grid : VLCIcons.list
        description: qsTr("View")
        checked: viewMenu.visible

        onClicked: root._popup(viewMenu, viewBtn)

        FigmaMenu {
            id: viewMenu

            width: VLCStyle.dp(265, VLCStyle.scale)
            rows: [
                { text: qsTr("Grid View"), icon: VLCIcons.grid, checked: MainCtx.gridView,
                  run: () => { MainCtx.gridView = true } },
                { text: qsTr("List View"), icon: VLCIcons.list, checked: !MainCtx.gridView,
                  run: () => { MainCtx.gridView = false } }
            ]
        }
    }

    // Figma 1040:2876: always visible, filters as you type
    T.TextField {
        id: searchField

        visible: root.search.available
        enabled: visible
        width: VLCStyle.dp(325, VLCStyle.scale)
        height: VLCStyle.dp(34, VLCStyle.scale)
        leftPadding: VLCStyle.dp(8 + 24 + 10, VLCStyle.scale)
        rightPadding: VLCStyle.dp(8, VLCStyle.scale)
        verticalAlignment: TextInput.AlignVCenter
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        color: theme.fg.primary
        selectionColor: theme.bg.highlight
        selectedTextColor: theme.fg.highlight
        placeholderText: qsTr("Search")
        placeholderTextColor: root._dark ? "#404040" : theme.fg.secondary
        selectByMouse: true

        Accessible.name: qsTr("Search")

        background: Rectangle {
            color: root._dark ? "#151515" : theme.bg.secondary
            radius: VLCStyle.dp(6, VLCStyle.scale)
            border.width: searchField.activeFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
            border.color: theme.visualFocus

            IconLabel {
                x: VLCStyle.dp(8, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                text: VLCIcons.search
                font.pixelSize: VLCStyle.icon_normal
                color: root._dark ? "#8F8F8F" : theme.fg.secondary
            }
        }

        Binding {
            target: root.search
            property: "pattern"
            value: searchField.text
        }

        Connections {
            target: MainCtx.search
            function onAskShow() {
                if (searchField.visible)
                    searchField.forceActiveFocus(Qt.ShortcutFocusReason)
            }
        }

        Navigation.parentItem: root

        Keys.onEscapePressed: (event) => {
            searchField.clear()
            root.Navigation.defaultNavigationDown()
            event.accepted = true
        }
        Keys.priority: Keys.AfterItem
        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)
    }

    IconToolButton {
        id: moreBtn

        width: VLCStyle.icon_normal
        height: VLCStyle.icon_normal
        font.pixelSize: VLCStyle.icon_normal
        text: VLCIcons.ellipsis
        description: qsTr("More")
        checked: moreMenu.visible

        onClicked: root._popup(moreMenu, moreBtn)

        FigmaMenu {
            id: moreMenu

            rows: [{ text: qsTr("Add File"), run: () => DialogsProvider.openFileDialog() }]
                  .concat(MainCtx.mediaLibraryAvailable ? [
                      { text: qsTr("Add Folder"), run: () => DialogsProvider.addFolderToLibrary() },
                      { text: qsTr("Rescan library"), run: () => MainCtx.mediaLibrary.reload() }
                  ] : [])
                  .concat(root.menuExtraRows)
        }
    }
}
```

- [ ] **Step 5: Wire it in `PageExt.qml`.**
  - Delete `property SortMenu sortMenu: null` and its comment. In `DefaultPageHeader`, delete `sortMenu: root.sortMenu` and `property alias sortMenu: gridSortFilter.sortMenu`. Drop the `import VLC.Menus` line if nothing else in the file uses it.
  - After `property var sortModel: …`, add:

```qml
    // FigmaMenu rows the page adds to its sort menu and to its header "…" menu
    property var sortExtraRows: []
    property var headerMenuRows: []
```

  - In `header: DefaultPageHeader { … }`, add `sortExtraRows: root.sortExtraRows` and `headerMenuRows: root.headerMenuRows`. In the component, add `property alias sortExtraRows: gridSortFilter.sortExtraRows` and `property alias headerMenuRows: gridSortFilter.menuExtraRows`.
  - Delete `Navigation.navigable: gridSortFilter.enabled`: the "…" button is always there.
  - Item count label: `color: theme.palette.isDark ? "#6B6B6B" : theme.fg.secondary.alpha(0.75)`.
  - In `VideoAllSubDisplay.qml` and `VideoGroupDisplay.qml`, replace each `sortMenu: SortMenuVideo { … }` block (keep its NOTE comment, reworded) with:

```qml
    // NOTE: the grouping choices of the old video sort menu, kept after the sort rows
    sortExtraRows: [
        { text: qsTr("Do not group videos"), checked: MainCtx.grouping === MainCtx.GROUPING_NONE,
          run: () => { MainCtx.grouping = MainCtx.GROUPING_NONE } },
        { text: qsTr("Group by name"), checked: MainCtx.grouping === MainCtx.GROUPING_NAME,
          run: () => { MainCtx.grouping = MainCtx.GROUPING_NAME } },
        { text: qsTr("Group by folder"), checked: MainCtx.grouping === MainCtx.GROUPING_FOLDER,
          run: () => { MainCtx.grouping = MainCtx.GROUPING_FOLDER } }
    ]
```

  - Drop `import VLC.Menus` from those two files if nothing else there uses it.
- [ ] **Step 6: Verify (Review Focus 1 and 4).** `ninja -C build`, then start the harness, open Videos, and check each item:
  - **Right group:** shoot `$S/t3_videos.png`. It reads "N items", sort, view (grid glyph in grid mode), a 325 px dark field with a search icon and "Search", then "…", with 20 px gaps (compare `grid.png`).
  - **Sort menu:** click sort and shoot. The rows read "Title A-Z, Title Z-A, …", then the three grouping rows; one row carries the orange check (compare `sort_menu.png`). Click "Title Z-A": the grid re-sorts, and reopening shows the check on "Title Z-A".
  - **Escape:** open the sort menu and press Escape. The menu closes, the page is still Videos (not Home), and the sort button keeps focus: `$H key Right` then `Return` opens the view menu.
  - **View menu:** Grid View / List View with their icons and a check on the current one (compare `view_menu.png`). "List View" switches to the list, and the view icon becomes the list glyph.
  - **Search:**
    - click the field, `$H key t r a c k s`: the grid filters;
    - `Escape`: the field empties, the grid is unfiltered, and focus is on the content (Down/Right move the grid's current item);
    - type again, open Music, come back to Videos: the field is empty;
    - press `ctrl+f`: the field gets focus.
  - **"…":** Add File / Add Folder / Rescan library.
    - "Add File" opens VLC's Open dialog: Escape it.
    - "Add Folder" opens a folder picker: Escape it, and nothing is added (`build/redesign-profile/data` unchanged: `find build/redesign-profile -newer $L -name '*.db'` empty).
    - "Rescan library": no error in `$L`.
  - Then run the log check and the process check.
- [ ] **Step 7: Commit** `qt: add the redesign menu, sort and view menus, search field and header "…" menu`.

---

### Task 4: Breadcrumbs, back/forward and the temporary tabs

**Files:**
- Modify: `modules/gui/qt/widgets/qml/PageExt.qml` (`breadcrumbs`, `_crumbLabels`, `_tabs`; the `DefaultPageHeader` left side and tab row)
- Modify: `modules/gui/qt/network/qml/BrowseHomeDisplay.qml` (title "Network"), `modules/gui/qt/medialibrary/qml/MusicGenresDisplay.qml` (genre page title = genre name)
- Modify: `modules/gui/qt/network/qml/BrowseTreeDisplay.qml`, `modules/gui/qt/network/qml/BrowseDisplay.qml`
- Delete: `modules/gui/qt/network/qml/BrowseTreeHeader.qml`, `modules/gui/qt/network/qml/NetworkAddressbar.qml` (and their `meson.build` / `Makefile.am` lines)

**Interfaces:**
- Consumes: `Helpers.breadcrumbs` (Task 1), `PageExt.headerMenuRows` (Task 3).
- Produces: `PageExt.breadcrumbs: var`, a list of `{ title: string, path: [string], props?: object }`. Clicking a crumb other than the last calls `History.push(path, props)`, or `History.push(path)` when it has no props. Pages may override it.

- [ ] **Step 1: Failing check.** Start the harness, open Videos ▸ the "Shows" group (double-click it), and shoot `$S/t4_before.png`. The header shows the single label "Shows" (or "Videos"), with no crumbs and no tab row. `$H stop`.
- [ ] **Step 2: `PageExt` data.** After `property var headerMenuRows: []`, add:

```qml
    // crumbs of the header: [{ title, path, props (optional History properties) }]
    property var breadcrumbs: Helpers.breadcrumbs(pagePrefix, title, _crumbLabels)

    readonly property var _crumbLabels: ({
        "home": qsTr("Home"),
        "video": qsTr("Videos"),
        "video/playlists": qsTr("Playlists"),
        "music": qsTr("Music"),
        "music/artists": qsTr("Artists"),
        "music/albums": qsTr("Albums"),
        "music/tracks": qsTr("Tracks"),
        "music/genres": qsTr("Genres"),
        "music/playlists": qsTr("Playlists"),
        "network": qsTr("Network"),
        "playlists": qsTr("Playlists"),
        "recent": qsTr("Recent")
    })

    // ponytail: the old sidebar sub-items, shown as tabs under the header until 4c replaces Videos/Music browsing
    readonly property var _tabs: ({
        "video": [{ name: "all", text: qsTr("All") }, { name: "playlists", text: qsTr("Playlists") }],
        "music": [{ name: "artists", text: qsTr("Artists") }, { name: "albums", text: qsTr("Albums") },
                  { name: "tracks", text: qsTr("Tracks") }, { name: "genres", text: qsTr("Genres") },
                  { name: "playlists", text: qsTr("Playlists") }]
    })[pagePrefix[0]] ?? []
```

  - In `header: DefaultPageHeader { … }`, replace `text: root.title` with:

```qml
        breadcrumbs: root.breadcrumbs
        tabs: root._tabs
        tabRoot: root.pagePrefix[0] ?? ""
        currentTab: root.pagePrefix[1] ?? ""
```

- [ ] **Step 3: `DefaultPageHeader` layout.**
  - Replace `property alias text: label.text` with:

```qml
        property var breadcrumbs: []
        property var tabs: []
        property string tabRoot: ""
        property string currentTab: ""

        readonly property bool _dark: theme.palette.isDark

        // leading crumbs folded into one "…" crumb so the rest fits
        readonly property int _hiddenCrumbs: {
            const list = breadcrumbs
            if (list.length < 2)
                return 0
            const sep = VLCStyle.dp(8 + 2 * 6, VLCStyle.scale)      // "▶" plus its two gaps
            const fold = crumbFont.advanceWidth("…") + sep
            let used = lastCrumbFont.advanceWidth(list[list.length - 1].title)
            let n = list.length - 1
            while (n > 0) {
                const next = crumbFont.advanceWidth(list[n - 1].title) + sep
                if (used + next + (n > 1 ? fold : 0) > crumbRow.width)
                    break
                used += next
                --n
            }
            return n
        }

        readonly property var _shownCrumbs: {
            const n = _hiddenCrumbs
            if (n === 0)
                return breadcrumbs
            const up = breadcrumbs[n - 1]
            return [{ title: "…", path: up.path, props: up.props }].concat(breadcrumbs.slice(n))
        }

        FontMetrics { id: crumbFont; font.pixelSize: VLCStyle.dp(16, VLCStyle.scale) }
        FontMetrics { id: lastCrumbFont; font.pixelSize: VLCStyle.dp(16, VLCStyle.scale); font.weight: Font.DemiBold }
```

  - In the header `RowLayout { id: row … }` (spacing stays 20), replace the back/forward `Row { … }` and the `T.Label { id: label … }` with one left group:

```qml
                RowLayout {
                    Layout.fillWidth: true
                    spacing: VLCStyle.dp(10, VLCStyle.scale)

                    Row {
                        spacing: VLCStyle.dp(12, VLCStyle.scale)

                        IconToolButton {
                            id: backBtn

                            width: VLCStyle.icon_normal
                            height: VLCStyle.icon_normal
                            text: VLCIcons.back
                            description: qsTr("Previous")
                            font.pixelSize: VLCStyle.icon_normal
                            enabled: !History.previousEmpty
                            opacity: enabled ? 1.0 : 0.3

                            Navigation.parentItem: defaultPageHeader
                            Navigation.rightItem: forwardBtn
                            Navigation.downItem: tabRow.visible ? tabRow : null

                            onClicked: History.previous()
                        }

                        IconToolButton {
                            id: forwardBtn

                            width: VLCStyle.icon_normal
                            height: VLCStyle.icon_normal
                            text: VLCIcons.back
                            rotation: 180
                            description: qsTr("Next")
                            font.pixelSize: VLCStyle.icon_normal
                            enabled: !History.nextEmpty
                            opacity: enabled ? 1.0 : 0.3

                            Navigation.parentItem: defaultPageHeader
                            Navigation.leftItem: backBtn
                            Navigation.rightItem: crumbRow
                            Navigation.downItem: tabRow.visible ? tabRow : null

                            onClicked: History.next()
                        }
                    }

                    // Figma 6153:13642
                    NavigableRow {
                        id: crumbRow

                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        clip: true
                        spacing: VLCStyle.dp(6, VLCStyle.scale)

                        Navigation.parentItem: defaultPageHeader
                        Navigation.leftItem: forwardBtn
                        Navigation.rightItem: gridSortFilter
                        Navigation.downItem: tabRow.visible ? tabRow : null

                        Repeater {
                            id: crumbRepeater

                            model: defaultPageHeader._shownCrumbs

                            delegate: T.AbstractButton {
                                id: crumb

                                required property var modelData
                                required property int index
                                readonly property bool isLast: index === crumbRepeater.count - 1

                                enabled: !isLast
                                focusPolicy: Qt.StrongFocus
                                text: modelData.title

                                implicitWidth: implicitContentWidth
                                implicitHeight: implicitContentHeight

                                contentItem: Row {
                                    spacing: VLCStyle.dp(6, VLCStyle.scale)

                                    T.Label {
                                        visible: crumb.index > 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: VLCStyle.dp(8, VLCStyle.scale)
                                        text: "▶"
                                        font.pixelSize: VLCStyle.dp(8, VLCStyle.scale)
                                        color: defaultPageHeader._dark ? "#404040" : theme.fg.secondary
                                    }

                                    T.Label {
                                        text: crumb.text
                                        font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                                        font.weight: crumb.isLast ? Font.DemiBold : Font.Normal
                                        font.underline: crumb.hovered && !crumb.isLast
                                        color: defaultPageHeader._dark ? (crumb.isLast ? "#969696" : "#8F8F8F")
                                                                       : (crumb.isLast ? theme.fg.primary : theme.fg.secondary)
                                    }
                                }

                                background: Rectangle {
                                    color: "transparent"
                                    radius: VLCStyle.dp(4, VLCStyle.scale)
                                    border.color: crumb.visualFocus ? theme.visualFocus : "transparent"
                                }

                                Keys.priority: Keys.AfterItem
                                Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

                                onClicked: {
                                    if (crumb.modelData.props)
                                        History.push(crumb.modelData.path, crumb.modelData.props)
                                    else
                                        History.push(crumb.modelData.path)
                                }
                            }
                        }
                    }
                }
```

  - Keep the item-count label and `GridSortFilterControls` after this group. On `gridSortFilter`, set `Navigation.leftItem: crumbRow` and `Navigation.downItem: tabRow.visible ? tabRow : null`.
  - After the divider `Rectangle`, add the tab row:

```qml
            // ponytail: temporary (until 4c) tabs for the old Videos/Music sidebar sub-items
            NavigableRow {
                id: tabRow

                visible: defaultPageHeader.tabs.length > 0
                Layout.preferredHeight: VLCStyle.dp(40, VLCStyle.scale)

                Navigation.parentItem: defaultPageHeader
                Navigation.upItem: gridSortFilter

                Repeater {
                    model: defaultPageHeader.tabs

                    delegate: T.TabButton {
                        id: tab

                        required property var modelData
                        readonly property bool selected: modelData.name === defaultPageHeader.currentTab

                        text: modelData.text
                        height: VLCStyle.dp(40, VLCStyle.scale)
                        leftPadding: VLCStyle.dp(16, VLCStyle.scale)
                        rightPadding: VLCStyle.dp(16, VLCStyle.scale)
                        implicitWidth: implicitContentWidth + leftPadding + rightPadding
                        focusPolicy: Qt.StrongFocus

                        contentItem: T.Label {
                            text: tab.text
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                            color: defaultPageHeader._dark ? (tab.selected ? "#C6C6C6" : "#8F8F8F")
                                                           : (tab.selected ? theme.fg.primary : theme.fg.secondary)
                        }

                        background: Rectangle {
                            color: "transparent"
                            border.color: tab.visualFocus ? theme.visualFocus : "transparent"

                            Rectangle {
                                visible: tab.selected
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: VLCStyle.dp(2, VLCStyle.scale)
                                color: defaultPageHeader._dark ? "#D37918" : theme.accent
                            }
                        }

                        Keys.priority: Keys.AfterItem
                        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

                        onClicked: History.push([defaultPageHeader.tabRoot, modelData.name])
                    }
                }
            }
```

  - Down from the tab row reaches the header's own `Navigation.downAction`, which `PageExt` already points at the content. Up from the content reaches `root.header` (set in `on_FirstChildChanged`).
  - If the `Repeater`'s items don't join the `NavigableRow` (Left/Right does nothing on them), replace both `NavigableRow`s with a plain `Row`. Then chain the delegates by hand: `Navigation.leftItem: index > 0 ? repeater.itemAt(index - 1) : <the left neighbour>`, and the same for right.
- [ ] **Step 4: Titles and the network folder page.**
  - `BrowseHomeDisplay.qml`: `title: qsTr("Browse")` becomes `title: qsTr("Network")`.
  - `MusicGenresDisplay.qml`: the genre page's `title: qsTr("Genres - %1").arg(genreName)` becomes `title: genreName`.
  - `BrowseTreeDisplay.qml`:
    - delete the whole `header: BrowseTreeHeader { … }` block and `signal homeButtonClicked(int reason)`;
    - keep `property var headerPath`;
    - add:

```qml
    // Network ▸ source ▸ folder…, each crumb browses back to its node
    breadcrumbs: [{ title: qsTr("Network"), path: ["network"] }].concat(
        headerPath.map((node) => ({ title: node.display, path: root.pagePrefix, props: { tree: node.tree } })))

    // the old header's "Add to / Remove from media library" button
    headerMenuRows: (root.model?.canBeIndexed ?? false) ? [{
        text: root.model.indexed ? qsTr("Remove from media library") : qsTr("Add to media library"),
        run: () => { root.model.indexed = !root.model.indexed }
    }] : []
```

  - `BrowseDisplay.qml`: delete `onHomeButtonClicked: reason => root._showHome(reason)` and the then-unused `function _showHome(reason)`.
  - Delete `network/qml/BrowseTreeHeader.qml` and `network/qml/NetworkAddressbar.qml`, and their lines in `meson.build` and `Makefile.am`. First check `grep -rn "BrowseTreeHeader\|NetworkAddressbar" modules/gui/qt`: only those build lines may be left.
- [ ] **Step 5: Verify the crumbs.** `ninja -C build`, then start the harness:
  - **Home:** shoot `$S/t4_home.png`. The header reads "Home" (semibold #969696), with no tabs.
  - **Videos:** the crumb reads "Videos" and the tab row "All | Playlists" sits under the divider, "All" selected with an orange underline. Double-click "Shows": the crumbs read "Videos ▶ Shows"; shoot `$S/t4_group.png` and compare with `grid.png`'s row. Click "Videos": back to the Videos grid.
  - **Tabs:** click "Playlists": the crumbs read "Videos ▶ Playlists", and the tab moves.
  - **Music:** Music ▸ Albums shows "Music ▶ Albums" and five tabs. Genres ▸ a genre shows "Music ▶ Genres ▶ <genre>".
  - **Network:** the page reads "Network". Open a folder source and 2–3 folders deep: the crumbs read "Network ▶ <source> ▶ … ▶ <folder>". Click a middle crumb: that folder opens.
  - **"…" on a network folder:** the menu shows "Add to media library" (or "Remove from media library"). Leave it untouched.
  - **Keyboard:** from the sidebar press Right to reach the content, then Up for the header, then Left/Right. The order is back, forward, crumbs (the non-last ones), sort, view, search, "…". Down from the header reaches the tabs, Left/Right moves between tabs, Return opens one, and Down reaches the content.
  - Then run the log check and the process check.
- [ ] **Step 6: Verify the narrow window (Review Focus 2).**
  - Restart the harness, run `xdotool search --name "VLC" windowsize 1000 700` (with `DISPLAY=:77`), and open a network folder 3+ levels deep.
  - Shoot `$S/t4_narrow.png`. The first crumbs show as "…", and the search field and "…" button are fully visible and not overlapped.
  - Click "…": the page goes one level above the first visible crumb.
- [ ] **Step 7: Commit** `qt: add breadcrumbs and the temporary library tabs to the page header`.

---

### Task 5: Sidebar entries and the Playlists and Recent pages

**Files:**
- Modify: `modules/gui/qt/maininterface/navigationmodel.cpp` (`initilializeModel`)
- Modify: `modules/gui/qt/tests/test_navigation_model.cpp`
- Modify: `modules/gui/qt/maininterface/qml/SideNavigationPane.qml` (remove the Preferences footer)
- Modify: `modules/gui/qt/maininterface/qml/MainDisplay.qml` (`pageModel`)
- Modify: `modules/gui/qt/medialibrary/qml/PlaylistMediaList.qml`, `MusicPlaylistsDisplay.qml` (a `playlistType` property)
- Create: `modules/gui/qt/medialibrary/qml/PlaylistsDisplay.qml`, `modules/gui/qt/medialibrary/qml/RecentDisplay.qml`, registered in `VLC.MediaLibrary`: `meson.build` after `'medialibrary/qml/MusicPlaylistsDisplay.qml',`, and `Makefile.am` after `medialibrary/qml/MusicPlaylistsDisplay.qml \`

**Interfaces:**
- Consumes: `VLCIcons::playlists` (Task 2), `PageExt.breadcrumbs` (Task 4, for the "Playlists"/"Recent" crumbs).
- Produces:
  - Sidebar URIs `["home"]`, `["video"]`, `["music"]`, `["network"]`, `["playlists"]`, `["recent"]` and `["additem"]`. `additem` is not a page; Task 6 opens its menu.
  - Pages `playlists` and `recent` in `MainDisplay.pageModel`.

- [ ] **Step 1: Write the failing test.**
  - In `tests/test_navigation_model.cpp`, replace everything from `void testInitialValues() {` through the closing brace of `testExpandVideoExpandHome()` (just before `private:`) with:

```cpp
    void testInitialValues() {
        initWithMedialib(true);
        QCOMPARE(m_model->rowCount(), 7);
        int i = 0;
        COMPARE_ROW(i++, "Home", Leaf);
        COMPARE_ROW(i++, "Videos", Leaf);
        COMPARE_ROW(i++, "Music", Leaf);
        COMPARE_ROW(i++, "Network", Leaf);
        COMPARE_ROW(i++, "Playlists", Leaf);
        COMPARE_ROW(i++, "Recent", Leaf);
        COMPARE_ROW(i++, "Add item", Leaf);
    }

    void testInitialValuesNoML() {
        initWithMedialib(false);
        QCOMPARE(m_model->rowCount(), 3);
        int i = 0;
        COMPARE_ROW(i++, "Home", Leaf);
        COMPARE_ROW(i++, "Network", Leaf);
        COMPARE_ROW(i++, "Add item", Leaf);
    }

    void testURI() {
        initWithMedialib(true);
        const QList<QStringList> uris = {
            {"home"}, {"video"}, {"music"}, {"network"}, {"playlists"}, {"recent"}, {"additem"}
        };
        for (int row = 0; row < uris.size(); ++row)
            QCOMPARE(m_model->data(m_model->index(row), NavigationModel::URI).toStringList(), uris[row]);
    }

    void testExpandLeaf() {
        initWithMedialib(true);
        QVERIFY(m_model->setData(m_model->index(1), true, NavigationModel::EXPANDED));
        QCOMPARE(m_model->rowCount(), 7);
        VERIFY_NOT_INSERTED;
        VERIFY_NOT_REMOVED;
        COMPARE_ROW(1, "Videos", Leaf);
    }

    void testExpandOOB() {
        initWithMedialib(true);
        QVERIFY(!m_model->setData(m_model->index(7), true, NavigationModel::EXPANDED));
        QVERIFY(!m_model->setData(m_model->index(7), false, NavigationModel::EXPANDED));
    }
```

  - Run `ninja -C build && meson test -C build test_qt_navigation_model --print-errorlogs`. Expected: FAIL (`rowCount` 5, not 7).
- [ ] **Step 2: Flatten the model.** In `navigationmodel.cpp`, the body of `initilializeModel()` becomes:

```cpp
        m_model.children.emplace_back(qtr("Home"), "home", VLCIcons::home, QStringLiteral(":/icons/ic_fluent_home.svg"));

        if (m_hasMedialib)
        {
            m_model.children.emplace_back(qtr("Videos"), "video", VLCIcons::topbar_video, QStringLiteral(":/icons/ic_fluent_filmstrip.svg"));
            m_model.children.emplace_back(qtr("Music"), "music", VLCIcons::topbar_music, QStringLiteral(":/icons/ic_fluent_music_note_2.svg"));
        }

        m_model.children.emplace_back(qtr("Network"), "network", VLCIcons::topbar_network, QStringLiteral(":/icons/ic_fluent_wifi_1.svg"));

        if (m_hasMedialib)
        {
            m_model.children.emplace_back(qtr("Playlists"), "playlists", VLCIcons::playlists);
            m_model.children.emplace_back(qtr("Recent"), "recent", VLCIcons::history);
        }

        // not a page: the sidebar opens the add menu for this uri (MainDisplay)
        m_model.children.emplace_back(qtr("Add item"), "additem", VLCIcons::add);

        m_model.visibleChildren = m_model.children.size();
```

  - Run the test again: PASS. Then `meson test -C build --suite qt`: 12/12.
- [ ] **Step 3: Sidebar footer.** In `SideNavigationPane.qml`, delete the whole `SideNavigationDelegate { id: preferenceButton … }` block and the list's `Navigation.downItem: preferenceButton` line. Drop the `import VLC.Dialogs` line if nothing else in the file uses it.
- [ ] **Step 4: The two pages.**
  - `PlaylistMediaList.qml`: after `property bool isMusic: false`, add `property int playlistType: isMusic ? MLPlaylistListModel.PLAYLIST_TYPE_AUDIO : MLPlaylistListModel.PLAYLIST_TYPE_VIDEO`. In its `MLPlaylistListModel { … }`, replace the `playlistType: isMusic ? … : …` binding with `playlistType: root.playlistType`.
  - `MusicPlaylistsDisplay.qml`: add `property int playlistType: MLPlaylistListModel.PLAYLIST_TYPE_AUDIO` after the `enableEndFade` property, and `playlistType: root.playlistType` in its `PlaylistMediaList { … }`.
  - `medialibrary/qml/PlaylistsDisplay.qml` (GPL header, 2026):

```qml
import QtQuick

import VLC.MediaLibrary

// The library's Playlists page (sidebar): every playlist, whatever its media
MusicPlaylistsDisplay {
    playlistType: MLPlaylistListModel.PLAYLIST_TYPE_ALL
}
```

  - `medialibrary/qml/RecentDisplay.qml` (GPL header, 2026):

```qml
import QtQuick

import VLC.MediaLibrary
import VLC.Widgets as Widgets

// The library's Recent page (sidebar): the playback history, last played first
Widgets.PageExt {
    id: root

    title: qsTr("Recent")

    MediaView {
        anchors.fill: parent

        focus: true

        // the history keeps its own order
        sortModel: []

        model: MLRecentMediaModel {
            ml: MediaLib
            searchPattern: root.search.pattern
        }

        displayMarginBeginning: root.displayMarginBeginning
        displayMarginEnd: root.displayMarginEnd

        enableBeginningFade: root.enableBeginningFade
        enableEndFade: root.enableEndFade
    }
}
```

  - In `MainDisplay.qml` `pageModel`, after the `network` entry, add:

```js
        }, {
            name: "playlists",
            url: "qrc:///qt/qml/VLC/MediaLibrary/PlaylistsDisplay.qml"
        }, {
            name: "recent",
            url: "qrc:///qt/qml/VLC/MediaLibrary/RecentDisplay.qml"
```

- [ ] **Step 5: Verify.** `ninja -C build`, then start the harness and check each item:
  - **Sidebar:** shoot `$S/t5_home.png`. The card reads Home, Videos, Music, Network, Playlists, Recent, Add item with Figma's icons (compare `grid.png`'s sidebar). There is no Discover, no Preferences footer and no indented sub-items.
  - **Pages:** click each of the first six entries. Each opens its page and highlights only its own entry. Playlists shows every playlist (an empty list is fine; then create one in Task 6). Recent lists the files the earlier checks played (or is empty), and a double-click plays one.
  - **Crumbs:** they read "Playlists" and "Recent". Neither page has tabs.
  - **Add item:** clicking it now does nothing (Task 6), and the log may show no error for it.
  - Then run the log check and the process check.
- [ ] **Step 6: Verify without a media library (Review Focus 3, sidebar half).**
  - `$H start -vv --no-media-library; sleep 6; $H shot $S/t5_noml.png`.
  - The sidebar shows Home, Network and Add item, and Home shows `NoMedialibHome`.
  - Run the log check and the process check.
- [ ] **Step 7: Commit** `qt: give the sidebar the redesign's seven entries and add the Playlists and Recent pages`.

---

### Task 6: Add item menu, new playlist, and Discover in "…" ▸ More

**Files:**
- Modify: `modules/gui/qt/dialogs/dialogs_provider.hpp` / `.cpp` (new `newPlaylist()`)
- Modify: `modules/gui/qt/maininterface/qml/MainDisplay.qml` (`onItemClicked`, the add menu)
- Modify: `modules/gui/qt/menus/menus.hpp` / `.cpp` (`MainMenu` takes an optional Discover callback)
- Modify: `modules/gui/qt/menus/qml_menu_wrapper.hpp` / `.cpp` (`QmlGlobalMenu::discoverRequested`)
- Modify: `modules/gui/qt/maininterface/qml/LocalTopbar.qml` (handle it)

**Interfaces:**
- Consumes:
  - `FigmaMenu` (Task 3), `DialogsProvider.addFolderToLibrary()` (Task 3);
  - the `additem` sidebar URI and the `playlists` page (Task 5).
- Produces:
  - `DialogsProvider.newPlaylist()`, a `Q_INVOKABLE bool`. It asks for a name and creates an empty media-library playlist. It returns `false` when there is no media library, the dialog was cancelled, or the name is blank.
  - The signal `QmlGlobalMenu::discoverRequested()`.

- [ ] **Step 1: Failing check.** Start the harness and click "Add item": nothing opens. Open the title bar's "…" ▸ More: there is no Discover entry. Shoot `$S/t6_before.png`, then `$H key Escape; $H stop`.
- [ ] **Step 2: `DialogsProvider::newPlaylist()`.** In the `.hpp`, after `Q_INVOKABLE void addFolderToLibrary();`, add `Q_INVOKABLE bool newPlaylist();`. In the `.cpp`, after `addFolderToLibrary()`:

```cpp
bool DialogsProvider::newPlaylist()
{
    MediaLib* ml = p_intf->p_mi->getMediaLibrary();
    if( !ml )
        return false;

    bool ok = false;
    const QString name = QInputDialog::getText( nullptr, qtr( "New Playlist" ),
            qtr( "Playlist name:" ), QLineEdit::Normal, {}, &ok ).trimmed();
    if( !ok || name.isEmpty() )
        return false;

    // same call as MLPlaylistListModel::create
    ml->runOnMLThread( this, [name]( vlc_medialibrary_t* p_ml ) {
        vlc_ml_playlist_t* playlist = vlc_ml_playlist_create( p_ml, qtu( name ) );
        if( playlist )
            vlc_ml_playlist_release( playlist );
    } );
    return true;
}
```

- [ ] **Step 3: The Add item menu.**
  - In `MainDisplay.qml`'s `SideNavigationPane { … onItemClicked: … }`, add at the top of the handler, after the two `console.assert` lines:

```js
                if (modelUri[0] === "additem") {
                    addItemMenu.popup(item, item.width, 0)
                    return
                }
```

  - Inside `SideNavigationPane { id: sidebar … }`, next to `NavigationBarContextMenu`, add:

```qml
            // Figma sidebar "Add item": VLC's own add actions
            Widgets.FigmaMenu {
                id: addItemMenu

                rows: (MainCtx.mediaLibraryAvailable ? [
                          { text: qsTr("Add folder to library"), run: () => DialogsProvider.addFolderToLibrary() }
                      ] : [])
                      .concat([{ text: qsTr("Open network stream"), run: () => DialogsProvider.openNetDialog() }])
                      .concat(MainCtx.mediaLibraryAvailable ? [
                          { text: qsTr("New playlist"), run: () => {
                              if (DialogsProvider.newPlaylist())
                                  History.push(["playlists"])
                          } }
                      ] : [])
            }
```

  - If `DialogsProvider` isn't visible in `MainDisplay.qml`, add `import VLC.Dialogs`.
- [ ] **Step 4: Discover under "…" ▸ More.**
  - `menus.hpp`: add `#include <functional>` and change the declaration to `static void MainMenu( qt_intf_t *, QMenu *, std::function<void()> onDiscover = {} );`.
  - `menus.cpp` `VLCMenuBar::MainMenu`: change the signature to match (no default in the definition). Right after `QMenu* more = menu->addMenu( qtr( "&More" ) );`, add:

```cpp
    /* Discover left the redesign's sidebar; the QML side shows the page */
    if( onDiscover )
    {
        more->addAction( qtr( "&Discover" ), onDiscover );
        more->addSeparator();
    }
```

  - `qml_menu_wrapper.hpp` `QmlGlobalMenu`: add `void discoverRequested();` to `signals:`.
  - `qml_menu_wrapper.cpp` `QmlGlobalMenu::popup`, flat branch: `MainMenu( p_intf, m_menu.get() );` becomes `MainMenu( p_intf, m_menu.get(), [this]() { emit discoverRequested(); } );`.
  - `LocalTopbar.qml`, the `Menus.QmlGlobalMenu { id: contextMenu … flat: true … }`: add `onDiscoverRequested: History.push(["discover"])`.
- [ ] **Step 5: Verify (Review Focus 3 menu half, and 5).** `ninja -C build`, then start the harness and check each item:
  - **Add item menu:** click "Add item". A Figma menu opens to the right of the entry with "Add folder to library", "Open network stream" and "New playlist". Shoot `$S/t6_add.png`.
  - **Add folder to library:** the folder picker opens; Escape it. Nothing changes.
  - **Open network stream:** VLC's network tab opens; Escape it.
  - **New playlist, blank:** the name dialog opens. `$H key Escape`: the page is unchanged. Open it again, type two spaces and press Return: the page is unchanged and no playlist exists.
  - **New playlist, named:** open it a third time, `$H key T e s t space l i s t Return`. The Playlists page opens and lists "Test list" (it may take a moment).
  - **Discover:** the title bar "…" ▸ More ▸ Discover opens the Discover page, with no sidebar entry highlighted. Back returns to the previous page.
  - **No media library:** restart with `--no-media-library`. Add item offers only "Open network stream". The header "…" (Network page) offers only "Add File".
  - Then run the log check and the process check.
  - Clean up: delete "Test list" with its context menu on the Playlists page, so the test library stays as it was.
- [ ] **Step 6: Commit** `qt: add the sidebar add menu, new playlist, and Discover under the main menu`.

---

### Task 7: Final verification, ledger and roadmap

**Files:**
- Create: `docs/superpowers/figma/4a/after_home.png`, `after_videos.png`, `after_music.png`, `after_network.png`
- Modify: this plan (append `## Ledger`), `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md` (row 4a)

- [ ] **Step 1: Build and tests.** Run `ninja -C build` (clean) and `meson test -C build --suite qt` (12/12).
- [ ] **Step 2: Xvfb shots.** Start the harness and take four shots:
  - Home → `docs/superpowers/figma/4a/after_home.png`;
  - Videos ▸ Shows → `after_videos.png`;
  - Music ▸ Albums with an album expanded → `after_music.png`;
  - Network ▸ a folder 2 levels deep → `after_network.png`.
  - Then run the log check and the process check.
- [ ] **Step 3: Ledger.** Compare the shots with `grid.png` and `home.png`. Append a `## Ledger` section to this plan: every visible difference, recorded as fixed or as accepted with the reason.
  - **Scale note:** the Figma references are 1920 frames rendered at 1600 (×0.833), so fixed-size elements look ~1.2× larger in ours. Read size differences with that in mind, as the 3d ledger does.
  - Expected accepted items:
    - the grid cards and their titles (4c);
    - the Home sections (4b);
    - the Albums inline expand and the artist page, which have no crumb depth yet (4c, plan departure 4);
    - the title-bar differences (slice 2).
- [ ] **Step 4: Wayland pass.** `dbus-run-session -- docs/superpowers/scripts/wl-drive.py $S/wl vlc:--aout=dummy max sleep:6 shot:home`. `$S/wl/home.png` shows the seven-entry sidebar and the new header. `grep -E "TypeError|ReferenceError" $S/wl/vlc.log` is empty.
- [ ] **Step 5: Roadmap.** In row 4a, change the first cell to `4a Library shell (done)`. Change its Notes cell to:
  - `Plan 2026-10-16-vlc-redesign-library-shell. Sidebar = Home, Videos, Music, Network, Playlists, Recent, Add item (menu); Discover in "…" ▸ More; Preferences footer dropped. Header: crumbs (Helpers.breadcrumbs), Figma sort/view/"…" menus (FigmaMenu), always-visible search; temporary Videos/Music tabs until 4c. Album/artist crumb depths and the network page layout wait for 4c/4d.`
- [ ] **Step 6:** Commit `doc: finish the library shell slice` (the shots, the ledger, the roadmap).
- [ ] **Step 7:** Write the session handoff with the `handoff-doc:handoff` skill. Merging `redesign/library-shell` into `master` is the user's call.

## Ledger

Compared the four Xvfb shots (`docs/superpowers/figma/4a/after_home.png`, `after_videos.png` (Videos ▸ the "The_Clip_S01E0" group, grouped by name), `after_music.png` (Music ▸ Albums, first album expanded), `after_network.png` (Network ▸ Videos ▸ Shows)) with `grid.png` and `home.png`. The Wayland shot (headless, `wl-drive.py`) shows the same Home view.

**Scale note:** every Figma reference is a 1920-wide frame rendered at 1600 wide (x0.833), while our window is 1600x900 at VLCStyle scale 1. Fixed-size elements (icons, text, fields, bars) therefore look about 1.2x larger in our shots than in the references even when their values equal the Figma node; layout-proportional elements do not. Size differences below are read with this in mind.

- **Header row:** back/forward (24 px, forward at 30 % when disabled), crumbs, count, sort, view, 325 px search field and "…" appear in Figma's order. The search field is 325 px against 270 px in `grid.png`, which is 325 x 0.833: matches. The row gap, the 1 px divider and the 17 px (x1.2 = ~19 px) distance from the divider to the grid also match. Fixed in this slice.
- **Crumbs:** Regular #8F8F8F with a small "▸" separator, and the last crumb Semi Bold #969696: matches. "Videos ▸ The_Clip_S01E0" and "Network ▸ Videos ▸ Shows" read the same as `grid.png`'s "Videos ▸ Shows ▸ The Wand ▸ S01". Fixed in this slice.
- **Crumb depth (Albums, artists):** Music ▸ Albums does not extend to the album, and Music ▸ Artists does not extend to the artist: the album opens as the inline expand panel (visible in `after_music.png`), and the artist page draws its own banner. Accepted (4c, plan departure 4).
- **Crumb depth (Videos):** Videos groups follow VLC's grouping setting ("Videos ▸ The_Clip_S01E0") instead of Figma's folder tree "Videos ▸ Shows ▸ The Wand ▸ S01". Accepted (4c makes Videos folder-based).
- **Item count and sort on Home:** `home.png` shows "110 items" and a sort button; our Home shows only the view toggle, search and "…", with a disabled back/forward on first open. Home has no flat list to count or sort. Accepted (4b).
- **Item count on the Network root:** the root page (Folders, Devices, Network sections) shows no count, since it is a set of sections, not one list. Accepted (4d).
- **Margins:** our content starts 48 px right of the sidebar and ends 40 px from the window edge (Figma: ~29 and ~19 px at 1920). They come from VLC's existing `dynamicAppMargins` plus the layout margins that every page shares. Accepted (not part of this slice; 4c's grid pass revisits the page padding).
- **Grid cards and titles:** ours show VLC's card (bold white 12 px title, grey duration, thumbnails with the white progress line); Figma's card is 316 wide at 1920 with a 16 px #969696 title, a 20 % overlay, and the 4 px accent progress line. Accepted (4c).
- **Home sections:** ours are VLC's (Open File / Open Disc buttons, Continue Watching, New Videos, New Music); Figma's are Continue Watching, Listen Again and Frequently Visited Folders with "Title ›" headers. Accepted (4b).
- **Tab row:** the temporary tabs (All, Playlists / Artists, Albums, Tracks, Genres, Playlists) have no counterpart in Figma. They sit 17 px below the divider, with the grid starting under them; the grid is clipped just under the tab row when scrolled. Accepted (temporary, 4c removes them).
- **Sidebar order and labels:** Home, Videos, Music, Network, Playlists, Recent, Add item, with the same labels as Figma, and no Discover and no Preferences footer: matches. Fixed in this slice.
- **Sidebar width and icons:** our card is 144 px wide against ~168 px in `grid.png` (x0.833 of 201), and Home / Videos / Music use outlined glyphs (the selected one is orange) where Figma uses filled ones, with a boxed note for Music; ours also keeps a #1F1F1F row highlight under the selected entry. Slice 1's card and icons, which the spec leaves unchanged. Accepted.
- **Sort menu** (opened in a scratch shot on Videos): it uses Figma's row height, text and orange check, with Title A-Z / Z-A, Shortest / Longest First and then the three grouping rows. Figma lists 16 sort rows, ours only the keys the Videos page supports, and with the page's default order active no row shows the check. Accepted (4c; Figma's other keys need model support).
- **Title bar:** shows "VLC media player" centred with the sidebar, queue and fullscreen buttons; Figma has just the logo, "…" and window buttons and a Title-Case "VLC Media Player". Slice 2's title bar, out of scope. Accepted.
- **Ctrl+F vs Ctrl+K:** Figma has no shortcut. The search field is focused by Ctrl+K, because Ctrl+F is VLC's "Open Folder". Accepted.
- **Expanded album panel:** it spans from the sidebar edge to the window edge (160 to 1600) with a black background, where Figma has no such panel; its tracks show "0" for the track number and "Tester -  - 5 tracks" (the test files have no track number or album artist tags). Pre-existing VLC panel and test data. Accepted (4c replaces it).
- **Network root content:** the red "Screen capture" toast comes from the host's real device discovery, and the Folders / Devices cards are VLC's. Accepted (4d).
