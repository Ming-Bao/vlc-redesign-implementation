# VLC Redesign: Library Shell (slice 4a) Design

**Source of truth:** Figma "VLC Redesign (Community)", file key `dSoAm0gN9ZterHSssJU9FN`.
- This account can read that key; Galen's `d9xvroRclV6SaObbcqRmBr` cannot be read here.
- **Frames:**
  - Videos grid `970:4028` (sidebar, header and breadcrumbs).
  - Home `6261:15078`.
  - List `970:3792`.
  - Sorting Options `856:2215`.
  - View Options `858:3290`.
- **Reference shots** in `docs/superpowers/figma/4a/`:
  - `grid.png`, `home.png`, `list.png`: the 1920 frames rendered at 1600.
  - `sort_menu.png`, `view_menu.png`.
  - `before_home.png`, `before_videos.png`: today's build.
- **Memory `figma-is-the-spec`** applies: VLC 4's own library design is not a reference.

## Where this sits

Slice 4 (Library) is split into five parts, each with its own spec → plan → build cycle:

| Part | Scope |
|---|---|
| **4a Library shell** (this spec) | Sidebar entries, page header (breadcrumbs, item count, sort menu, view menu, search field, "…" menu), the shared Figma menu style |
| 4b Home | Continue Watching, Listen Again, Frequently Visited Folders/Playlists/Artists |
| 4c Videos & Music browsing | Folder-based Videos; Music root rows (Songs, Albums, Artists, Genres); the Figma grid card and list row; "Add" rows. Replaces 4a's temporary sub-page tabs. |
| 4d Network, Playlists, Recent | The Figma pages behind those sidebar entries |
| 4e Player side panel | Sidebar component `848:1996`: an icon rail plus a browse panel beside the player |

Slice 1 had deferred the multi-level breadcrumbs, the always-visible search field and the Playlists/Recent/Add item sidebar entries. They land here.

## Decisions taken with the user (2026-10-16)

| Question | Ruling |
|---|---|
| Split slice 4? | Yes, into 4a–4e as above, with 4a first. |
| Sidebar contents | **Exactly Figma's seven entries.** Discover moves into the "…" main menu. The Preferences footer goes, since Settings is already in "…". The sidebar's Videos/Music sub-items become a temporary row of tabs in the page, until 4c. |
| "Add item" | **A small add menu:** Add folder to library, Open network stream, New playlist. Each runs VLC's existing action. |
| Header "…" menu | Add File, Add Folder, Rescan library. Figma's per-item entries (Edit Subtitle/Audio Tracks, Info) act on a selection, so they go to slice 5's context menus. |

## Figma values

**Sidebar** (`970:4043`; slice 1's card is unchanged):
- Outer `#0E0E0E`, padding 8. Inner card `#191919`, radius 6, padding 12/16, 14 px between items.
- Item: a 30×32 icon wrapper with padding 4 and a 24 px icon, an 8 px gap, then the label in Inter 14 `#8F8F8F`.
- Order: Home, Videos, Music, Network, Playlists, Recent, Add item.
- Selected (slice 1): accent icon and `#C6C6C6` label.

**Header row** (`1040:2669`): full width, gap 20. Then the divider (1 px `#222222`), with 17 px between the row and the divider.
- **Back/forward:** 24 px arrows with a 12 px gap. Disabled is shown at 30 % opacity. Then a 10 px gap to the crumbs.
- **Breadcrumbs** (`6153:13642`): gap 6.
  - Crumbs are Inter Regular 16 `#8F8F8F`.
  - The separator is the character "▶" at 8 px in `#404040`, 8 px wide.
  - The last crumb is Inter Semi Bold 16 `#969696`.
- **Right group**, gap 20:
  - "15 items": Inter 14 `#6B6B6B`.
  - Sort icon, 24 px.
  - View icon, 24 px: the four-square grid, or the list glyph in list mode.
  - Search field (`1040:2876`): 325 wide, `#151515`, radius 6, padding 5/8, gap 10. A 24 px search icon, then "Search" in 14 px `#404040`.
  - The "…" icon, 24 px.

**Menus** (View Options `858:3290`; Sorting Options `856:2215` uses the same rows without icons):
- Card: `rgba(25,25,25,0.95)` with a 50 px background blur, radius 10, padding 4, shadow `0 8 15 rgba(0,0,0,0.46)`.
- Row: 48 tall, padding 14/2, gap 10.
  - Optional 24 px icon in `#8F8F8F`.
  - Label: Inter 14 `#8F8F8F`, filling the width.
  - A 24 px accent check (`#D37918`) on the current choice.
- Hovered or keyboard-current row: `#1F1F1F`, radius 6.
- Sorting Options: 295 wide, 16 rows. View Options: 295 wide, 2 rows (Grid View, List View).

## Design

### 1. Sidebar (`maininterface/qml/SideNavigationPane.qml`, `MainDisplay.qml` page model)

**Entries:**

| Entry | Opens |
|---|---|
| Home | `home` (unchanged) |
| Videos | `video` |
| Music | `music` |
| Network | `network` |
| Playlists | new page `playlists`: VLC's existing playlist list view on an `MLPlaylistListModel` with `playlistType: PLAYLIST_TYPE_ALL` |
| Recent | new page `recent`: a list of `MLRecentMediaModel` items using the existing list delegates (title, thumbnail, double-click plays) |
| Add item | opens the add menu (section 4), not a page |

- Icons: the Figma glyphs. Reuse slice 1 icon keys where they exist. New glyphs (playlists, recent, add) are appended to the icon font (append-only).
- **Removed from the sidebar:** Discover, the Preferences footer and every indented sub-item.
- **Discover** stays reachable through a "Discover" entry in the "…" main menu's "More" submenu (`menus/menus.cpp` `MainMenu`). It asks the QML side to show the `discover` page. `MainCtx` already routes requests like that; if it doesn't, a small signal that `MainDisplay` handles with `History.push(["discover"])` does it.
- **Media-library folder settings** (`mlsettings`) stay reachable from Settings, as today.

### 2. Sub-page tabs (temporary, until 4c)

- Videos (All, Playlists) and Music (Artists, Albums, Tracks, Genres, Playlists) show a row of text tabs directly under the header divider, in place of the old sidebar sub-items.
- **Style:**
  - Inter 14, 16 px tab padding, row height 40.
  - Selected: `#C6C6C6` with a 2 px `#D37918` underline.
  - Others: `#8F8F8F`.
- Keyboard: Left/Right between tabs, Down into the content, Up to the header.
- Tabs drive the same `History` paths the sub-items used, so the existing views and their saved state keep working.

### 3. Page header (`widgets/qml/PageExt.qml` `DefaultPageHeader`, `widgets/qml/GridSortFilterControls.qml`)

- **Breadcrumbs replace the single title label.**
  - `PageExt` gains `property var breadcrumbs`: a list of `{ title, path }`, where `path` is a `History` path array. It defaults to `[{ title: <page title>, path: <current path> }]`.
  - Pages with depth set it: Music ▸ Albums ▸ *album*; Music ▸ Artists ▸ *artist*; Videos ▸ Playlists ▸ *playlist*; Network ▸ *source* ▸ *folder…* (from the browse model's path).
  - Clicking a crumb other than the last calls `History.push(crumb.path)`.
  - Crumbs elide from the left when the row is too narrow: the first crumbs collapse into "…".
- **Item count:** unchanged logic; style per Figma.
- **Sort:** the icon opens the Figma sort menu.
  - Each entry of the page's `sortModel` gives two rows, ascending then descending, labelled through a table:

    | `criteria` key | Ascending row | Descending row |
    |---|---|---|
    | `title`, `name`, `album_title` (album pages) | "Title A-Z" | "Title Z-A" |
    | `release_year` | "Oldest First" | "Newest First" |
    | `duration` | "Shortest First" | "Longest First" |
    | `last_played_date` | "Unwatched First" | "Watched First" |
    | `main_artist` | "Artist A-Z" | "Artist Z-A" |
    | `album_title` (track pages) | "Album A-Z" | "Album Z-A" |
    | `track_number` | "Track Number Ascending" | "Track Number Descending" |
    | `disc_number` | "Disc Number Ascending" | "Disc Number Descending" |
    | `mrl`, `url` | "URI Ascending" | "URI Descending" |
    | `nb_tracks`, `nb_videos` | "Fewest Items First" | "Most Items First" |
    | anything else | "<sortModel text> Ascending" | "<sortModel text> Descending" |

    The `album_title` row depends on the page: on album pages it is the item's own title, on track pages it is the album. The page passes its own label for that key.

  - Choosing a row sets both `sort.criteria` and `sort.order`; the check marks the current pair.
- **View:** the icon shows the current mode and opens the View Options menu (Grid View / List View, each with its icon and a check). It sets `MainCtx.gridView`. It is hidden on pages without `hasGridListMode`, as today.
- **Search:** an always-visible 325 px field bound to the page's `SearchCtx` pattern.
  - It filters as you type. Escape clears it and returns focus to the content.
  - It is hidden on pages without `isSearchable`.
- **"…" header menu:**

  | Row | Action |
  |---|---|
  | Add File | `DialogsProvider.openFileDialog()` |
  | Add Folder | pick a folder (see Add folder to library) and add it as a media-library folder |
  | Rescan library | `MediaLib.reload()` |

- **Keyboard order:** back, forward, crumbs, sort, view, search, "…". Down goes into the tabs or the content.

### 4. Add item menu

Opened from the sidebar's Add item entry, anchored to its right.

| Row | Action |
|---|---|
| Add folder to library | A folder picker, then `MLFolderModel.add(url)`. Needs a new `Q_INVOKABLE QUrl DialogsProvider::getExistingDirectoryUrl()` wrapping the existing `getDirectoryDialog` code path. |
| Open network stream | `DialogsProvider.openNetDialog()` |
| New playlist | `DialogsProvider.getTextDialog` for the name, then `MLPlaylistListModel.create(name, [])`, then show the Playlists page |

### 5. Shared menu style

- One new QML component, `widgets/qml/FigmaMenu.qml`: a `T.Menu` with the Figma card, and rows with an optional icon, a label and a check (`checked` flag).
- The sort menu, the view menu, the header "…" menu and the Add item menu all use it.
- Opening a menu doesn't steal player hotkeys (as 3b's panels).
- Dark hex values apply only when `palette.isDark`; otherwise ColorContext colours (light theme is slice 10).

### 6. Testing

**Harness (Xvfb and Wayland):** shots of Home, Videos, Music ▸ Albums ▸ an album, and Network ▸ a folder, compared with `grid.png`/`home.png`. Checks:
- every sidebar entry opens its page;
- the Add item menu opens and each row starts its action (cancel the dialogs);
- each sort row re-sorts and moves the check;
- the view menu toggles grid/list;
- search filters, and Escape clears it;
- a crumb click goes up;
- the keyboard path works through the sidebar, header, tabs and content.

**Log check** (TypeError, ReferenceError, …) stays clean.

**QML unit test:** the sort-label table is a pure JS function `sortRowLabel(criteria, text, order)` in `widgets/qml/SortLabels.js`, covered by a new `tests/tst_SortLabels.qml` registered in `meson.build`'s `qml_tests` like `tst_FSM`. It checks every key in the table and the fallback for an unknown key.

## Out of scope

- The Home sections (4b).
- Folder-based Videos/Music, the Figma grid card and list row, "Add" rows (4c).
- The Figma Network/Playlists/Recent page layouts (4d).
- The player side panel (4e).
- Per-item context menus, including Edit Subtitle/Audio Tracks and Info (slice 5).
- The mini player card (slice 6).
- The light theme (slice 10).
