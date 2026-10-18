# VLC Redesign: Videos & Music browsing (slice 4c) Design

**Source of truth:** Figma "VLC Redesign (Community)", file key `dSoAm0gN9ZterHSssJU9FN`.
- **Frames:**
  - Videos grid `970:4028`: Videos ▸ Shows ▸ The Wand ▸ S01, 15 episode cards. The card values are below.
  - Videos list `970:3792`: the same folder as 4-column compact rows.
  - Sidebar panel variants. They give the hierarchy and the root rows; the panel itself is 4e.
    - Videos: `848:1997` (Videos: Add, Shows, Films, Anime), `4778:25847` (Videos ▸ Shows: The Wand) and `4778:25957` (… ▸ Shows ▸ The Wand: S01, S02).
    - Music: `858:5001` (Music: Add, Songs, Albums, Artists, Genres), `4767:23606` (Music ▸ Songs: My Songs) and `4778:24990` (… ▸ Songs ▸ My Songs: tracks "title - artist" with covers).
- **Reference shots** in `docs/superpowers/figma/4c/`: `videos_grid.png`, `videos_list.png`, `sb_videos_{1,2,3}.png` and `sb_music_{1,2,3}.png`.
- **Memory `figma-is-the-spec`** applies. VLC 4's Videos page (All/Playlists, video groups) and Music page (Artists/Albums/Tracks/Genres/Playlists tabs) are not references.
- **User ruling (standing since 4b):** "use the figma, the figma is the source of truth". There was no question round. Every choice below that isn't in a frame is marked *(my call)*.

## Scope

- **Videos and Music are folder browsers.**
  - **Videos:** the library folders that hold videos (Shows, Films, Anime), then their subfolders, then the video files.
  - **Music:** a root with Songs, Albums, Artists and Genres.
    - **Songs** is the same folder browser over audio: library folders, then subfolders, then tracks.
    - **Albums, Artists and Genres** are the existing pages, reached from the root.
- **The breadcrumbs grow** with each folder level.
- **4a's temporary tabs go:** `PageExt._tabs` and the tab row under the header.

Out of scope:
- The player side panel (4e). It reuses this hierarchy later.
- Restyling the Albums, Artists and Genres pages. There is no Figma main-view frame for them, so they keep 4a's header and their current bodies.
- Per-item context-menu redesign (slice 5).
- Network, Playlists and Recent (4d).

## Data: the folder tree *(my call)*

The media library has no "subfolders that contain videos" query. `VLC_ML_LIST_SUBFOLDERS` lists every subfolder, including ones with no media of the type. So the tree is derived from two flat lists:

1. **Roots:** the library's entry points, through the existing `MLFolderModel` (`MLFoldersModel`). These are the folders the user added (Shows, Films, Anime).
2. **Media folders:** the folders that hold media of the type, through `vlc_ml_list_folders_by_type(VIDEO | AUDIO)`.
   - `MLVideoFoldersModel` already lists the video ones.
   - It gains an MRL role and a media-type choice, so it can list audio folders too. This can be a rename or a property; that's the builder's call.

Two pure helpers in `Helpers.qml` turn these into a level and its crumbs. They are unit-tested in `tests/tst_LibraryHelpers.qml`.

- **`folderLevel(roots, mediaFolders, parent)`** returns `{ folders: [{ name, mrl }], folderId }`.
  - **`parent === ""` (the root):** returns each root that is an ancestor of, or equal to, at least one media folder. Roots holding no media of the type are hidden.
  - **Otherwise:** returns the distinct next path segment under `parent` of every media folder below it.
  - **`folderId`:** the id of the media folder whose MRL equals `parent`, or 0 when there is none. With 0, the level has only folders and no files.
  - **Names:** the decoded last path segment, sorted A→Z, case-insensitively and locale-aware.
  - **MRL handling:** compares MRLs with one trailing slash normalised away, and matches at path-segment boundaries, so `…/Shows` is not a parent of `…/Shows2`. It must not throw on a malformed `%` escape (4b's `folderEntries` already handles this).
- **`folderCrumbs(roots, mrl)`** returns `[{ name, mrl }]`, from the root that contains `mrl` down to `mrl` itself.

**Files at a level:** an `MLVideoModel` / `MLAudioModel` with `parentId = { folderId, VLC_ML_PARENT_FOLDER }`. `vlc_ml_list_video_of` and `vlc_ml_list_media_of` already route `VLC_ML_PARENT_FOLDER` to `VLC_ML_LIST_FOLDER_MEDIA`. When `folderId` is 0, no media model is bound, because an unset `parentId` would list the whole library.

**Updates:** the levels refresh when folders or media are added or removed. The base models already reset on media-library events, so the derived level is recomputed when either model changes.

## Navigation and history

| Path | Page | Crumbs |
|---|---|---|
| `["video"]` | Videos root (folder level `""`) | Videos |
| `["video", "folder"]` + `{ mrl }` | Videos folder level | Videos ▸ *root name* ▸ … ▸ *folder* |
| `["music"]` | Music root: Songs, Albums, Artists, Genres | Music |
| `["music", "songs"]` | Songs root (audio folder level `""`) | Music ▸ Songs |
| `["music", "songs", "folder"]` + `{ mrl }` | Songs folder level | Music ▸ Songs ▸ *root name* ▸ … ▸ *folder* |
| `["music", "albums"]`, `["music", "artists"]`, `["music", "genres"]` | the existing pages | Music ▸ Albums, and so on |

- **Each folder crumb** goes back to its level, carrying `{ mrl }` as the History props, like `BrowseTreeDisplay`'s crumbs. 4a's crumb row already collapses deep paths into "…".
- **Removed sub-pages:**
  - `video/all`, `video/playlists`, `music/tracks` and `music/playlists`.
  - Video groups no longer appear in Videos, because the folder hierarchy replaces them *(my call)*.
  - Every `History.push` to a removed path is redirected: video playlists and music playlists go to the sidebar Playlists page (`["playlists"]`), and tracks go to `["music", "songs"]`.
  - The sidebar's Videos and Music entries open the roots.

## Figma values

Colours are dark-theme tokens. Light theme maps them through the same `theme`/`ColorContext` roles 4a and 4b used.

**Content area** (`970:4079`): padding 20 at top and bottom, under the header divider.

**Video grid** (`6270:13766`): horizontal gap 20, vertical gap 40.
- **Card** (`6270:13767`): 316 wide, a column with gap 20.
  - **Thumbnail:** 16:9, radius 12, background `#171717`, image fills it (cover), then a 20 % black veil.
  - **Progress:** a `#D37918` (Accent/Main) bar 4 px tall at the bottom-left, width = thumbnail width × progress. It shows when progress > 0.
  - **Title:** Inter Regular 16, one line, elided.
    - `#969696` (Dark/FG/A1) for an unplayed video.
    - `#6B6B6B` (Dark/FG/A3) once played (`isNew` false) *(my call for the rule; the frame shows the watched episodes dimmed with a bar)*.
  - **No subtitle:** 4a's duration line under the title goes.
- **Width:** at 1920 the frame fits exactly 5 × 316. *(My call)* Columns = as many 316-wide cards as fit with 20 gaps, and the cards stretch to fill the width, as `ExpandGridView` already does.
- **Hover/focus** *(my call)*: as 4a's grid card, with the play-button overlay and the focus ring.

**Video list** (`6841:16096`): a wrapped grid of compact rows. Gap 10 in both directions, padding 20 at top and bottom.
- **Row** (`6841:16097`): 406 wide at 1920 (4 columns), a row with gap 10, height 32.
  - **Thumbnail:** 32×32, radius 2, background `#303030`, image cover.
  - **Text:** Inter 14, one line, elided.
    - `#969696` for an unplayed video, `#6B6B6B` once played.
  - **Progress:** when progress > 0, a 3 px `#D37918` bar along the bottom of the thumbnail, from the left, ending 4 px before the right edge.
  - **Playing item:** title in `#D37918`, and the thumbnail darkened 70 % with the accent play glyph centred.
- **Columns:** *(my call)* as many 400-wide rows as fit with 10 gaps, stretched to fill.

**Folder tiles** *(my call; there is no main-view frame for a folder level)*:
- **Grid, video levels:** the video card's footprint. A 16:9 box, `#1E1E1E`, radius 12, with a 48 px `folder` glyph centred in `#969696`, and the name below it like a card title.
- **Grid, audio levels and the Music root:** 4b's folder card (200×200 `#1E1E1E`, radius 12, 48 px glyph, name Inter 16 `#969696`).
- **List:** a compact row with a 24 px glyph centred in the 32 px thumbnail slot, then the name. This matches the sidebar variants' folder rows.

**Audio files** (Songs levels):
- **Grid:** 4b's square media card. 200 cover, title = track title, subtitle = main artist.
- **List:** a compact row with a 32 px cover and the text `title - artist`. This matches `4778:24990`.

**Music root tiles:**
- **Songs, Albums, Artists, Genres:** a folder card / compact row each, with the sidebar variant's glyph: a music note, an album, an artist and a speaker. Use the existing redesign SVGs where they exist, otherwise download the Figma ones from `858:5001`.

**"Add" tile** *(my call on placement and action)*:
- **Where:** first, on the Videos root and the Music root, like the sidebar variants.
  - Not on deeper levels: the main-view frames at S01 show none.
  - Not on the Songs root: the Music root's Add already adds a folder.
- **Look:** a `+` glyph and the label "Add", styled as a folder tile / row.
- **Action:** opens the folder picker and adds the chosen folder to the media library, the same action as the sidebar's "Add item ▸" folder entry from 4a.

## Behaviour

**Items:**
- **A folder tile:** click / Enter opens that level.
- **A video or track:**
  - Same as today's grid: click selects; double-click / Enter plays; the hover play button plays.
  - Ctrl/Shift multi-selection and drag stay. The context menu (`MLContextMenu`) acts on the selection.
- **Folder tiles** have no context menu *(my call)*.

**Order within a level:** folders come first, then files.
- **Folders:** always A→Z.
- **Files:** follow the header sort, using the existing video sort model on Videos and the tracks' sort model on Songs.

**Keyboard:** the folders and files form one navigable grid / list. Arrow keys move across the boundary between them, and up from the first row goes to the header. Escape in the search field drops to the first item, as on Home.

**Header:**
- **Count:** folders + files at this level (`970:4028` shows "15 items").
- **Sort:** the existing sort menus. The order never changes the folders.
- **View toggle:** grid ⇄ list, remembered per page like 4a.
- **Search** *(my call)*: a non-empty pattern searches the whole library of that type, not just the current folder. The ML folder query only lists a folder's direct media, so a subtree search would be partial.
  - Results are a flat list of matching files, plus the folders at this level whose names match.
  - With no match: "No results".
- **The Music root** isn't searchable. It has no sort and no view toggle, and its count is 4.

**Empty states:**
- **A root with no media folders:** the Add tile plus the library's existing empty label with its Browse button.
- **A folder level that a rescan emptied:** "No results". *(My call)* Stay on the page rather than auto-navigating back.

## Removed

- `PageExt._tabs` and the tab row; `VideoDisplay`'s and `MusicDisplay`'s old page models (`all`, `playlists`, `tracks`).
- **QML files** only those pages used, once nothing references them. Run a grep, delete only what has no other user, and list what was kept and why in the ledger.

## Verification

- **Harness:** `docs/superpowers/scripts/vlc-xvfb.sh` at 1600×900, `-vv`, `--aout=dummy`.
  - **The test library** needs nested folders: a root with two levels of subfolders holding videos, and one holding audio. Build it under `build/redesign-profile` from the existing test clips: copies or symlinks, never the user's real media folders.
  - **Shots** go to `docs/superpowers/figma/4c/after_*.png`: Videos root, a folder level in grid and list, the Music root, and a Songs level. Compare them with the Figma frames; the ledger goes in the plan.
- **Log:** grep `vlc.log` for TypeError, ReferenceError and "non-existent property" after each task.
- **Automated tests:** `tst_LibraryHelpers.qml` cases for `folderLevel` and `folderCrumbs`:
  - nesting and the root filter;
  - trailing slashes;
  - the `Shows`/`Shows2` boundary;
  - percent-encoded names;
  - a root that is itself a media folder;
  - an MRL outside every root, which gives an empty level and empty crumbs.
- **Suite:** the qt suite passes.
