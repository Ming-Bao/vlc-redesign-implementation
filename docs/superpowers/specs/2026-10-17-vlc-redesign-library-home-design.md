# VLC Redesign: Library Home (slice 4b) Design

**Source of truth:** Figma "VLC Redesign (Community)", file key `dSoAm0gN9ZterHSssJU9FN`.
- **Frames:**
  - Home `6261:15078` (1920×1080). Only the first three rows fit in it.
  - Sidebar Home variant `1106:5633`. It shows all five rows as a compact list. That panel itself is slice 4e. Here it gives the row order and titles, and the look of list view.
- **Reference shots** in `docs/superpowers/figma/4b/`: `home.png` (the 1920 frame) and `sidebar_home.png`.
- **Memory `figma-is-the-spec`** applies: VLC 4's Home (Open File/Open Disc banner, Favorites, New Videos, New Music) is not a reference.
- **User ruling (2026-10-17):** "use the figma, the figma is the source of truth". There was no question round. Every choice below that isn't in the frame is marked *(my call)*.

## Scope

Replace the body of `medialibrary/qml/HomePage.qml` with Figma's five rows. The page header (crumbs, count, sort, view, search, "…") is 4a's shared `PageExt` header. It stays as it is, except for the Home-specific items listed under Header.

Out of scope:
- The player side panel (4e).
- Per-item context-menu redesign (slice 5).
- Videos/Music browsing (4c).

## Rows

They come in this order, each one hidden when it is empty:

| # | Title (Figma) | Items | Card | Source |
|---|---|---|---|---|
| 1 | Continue Watching | videos in progress | video card | `MLRecentVideoModel` (existing) |
| 2 | Listen Again | recently played audio | square media card | **new `MLRecentAudioModel`**, a copy of `MLRecentVideoModel` on `vlc_ml_list_audio_history` / `vlc_ml_count_audio_history` |
| 3 | Frequently Visited Folders | folders | folder card | derived; see below |
| 4 | Frequently Visited Playlists | playlists | square media card | `MLPlaylistListModel` |
| 5 | Frequently Listened Artists | artists | square media card | derived; see below |

**"Frequently" data** *(my call)*. The media library keeps play counts and play history only per media item. Folders, playlists and artists have neither.
- **Folders:** take the last 100 entries of the global play history (`MLRecentMediaModel`, audio and video). Rank each entry's parent folder by how many of those entries it holds. Ties go to the most recently played. Each folder appears once.
- **Artists:** do the same over the audio history, with the main artist of each track.
- **Playlists:** there is no per-playlist play data, so the row shows the library's playlists in `MLPlaylistListModel`'s default order. Mark it `ponytail:`. The upgrade is ranking by the plays of each playlist's tracks.
- **Where it runs:** C++ or QML is the builder's choice. Whichever it is, it must not block the UI thread on the media library, so use the models' async loading or `MLThreadPool` like the other ML models do.

**Row length** *(my call)*: one line per row, with no wrapping and no horizontal scrolling. It holds as many cards as fit the current width at a 20 px gap. The section title (or its chevron) opens the full list.

**"Title ›" targets** *(my call; reuse what exists)*:
- **Continue Watching:** the existing `continueWatching` sub-page of `HomeDisplay`.
- **Listen Again:** a new `listenAgain` sub-page of `HomeDisplay`, built like `continueWatching` but on `MLRecentAudioModel` in the Music track view.
- **Folders:** a new `folders` sub-page that shows the full derived list as a grid of folder cards.
- **Playlists:** the sidebar Playlists page (`["playlists"]`).
- **Artists:** Music ▸ Artists.

## Figma values

Colours are dark-theme tokens. Light theme maps them through the same `theme`/`ColorContext` roles 4a used.

**Section** (`6261:15142`): a column with padding 20 at top and bottom.
- **Header row:** gap 5. The title is Inter Regular 20 in `#969696` (Dark/FG/A1), followed by a 24 px right chevron in the same colour.
  - There is no right-chevron glyph. Rotate `chevron_down` (−90°) rather than adding one *(my call)*.
- **Card row** (`6272:13818`): padding 20 at top and bottom, horizontal gap 20.

**Video card** (`6272:13852`): 316 wide, column, gap 20.
- Thumbnail 16:9, radius 12, background `#171717`, image fills it (cover).
- A 20 % black veil over the image. The frame stacks an extra image on top of it; treat that as the thumbnail itself, not an asset.
- Progress bar: `#D37918` (Accent/Main), 4 px tall, at the bottom-left. Width = thumbnail width × progress.
- Title: Inter 16 `#969696`, one line, elided.
- *(My call)* hover/focus behaviour is the same as the 4a grid card: play button overlay and focus ring, using the existing `VideoGridItem` affordances if they can be restyled to these values.

**Square media card** (`6272:13898`): 200×200 image, radius 12, background `#171717`, column gap 20.
- Then a text column with gap 10:
  - title: Inter 16 `#969696`;
  - subtitle: Inter 16 `#6B6B6B` (Dark/FG/A3).
  - Both are one line and elided.
- **Listen Again:** the track cover; title = track title, subtitle = main artist.
- **Playlists** *(my call)*: the playlist cover; title = name, subtitle = "N tracks".
- **Artists** *(my call)*: the artist cover, kept square to match the card family; title = artist name, subtitle = "N tracks".

**Folder card** (`6284:13980`): 200×200, background `#1E1E1E`, radius 12.
- The 48 px `folder` glyph is centred, in `#969696` *(my call; the SVG asset is the existing redesign folder icon)*.
- A gap of 20, then the name in Inter 16 `#969696`, one line, elided.

## Behaviour

**Actions:**

| Action | Video card | Audio card | Folder card | Playlist card | Artist card |
|---|---|---|---|---|---|
| Click / Enter | play (resumes) | play the track | open the folder in the network browser, the same as the player's folder chip (`MainCtx.folderTree`) | open the playlist page | open the artist page |
| Context menu | existing `MLContextMenu` | existing `MLContextMenu` | none | existing | existing |

**Keyboard:**
- Navigation is the existing `Navigation` attached API. Left/right moves within a row; up/down moves between rows, to the same column or the nearest one.
- Up from the first row goes to the header.
- Escape in the search field drops to the first row, through 4a's `escaped()` → `defaultNavigationDown`.

**Header on Home:**
- **Item count** *(my call)*: the total number of media in the library, video and audio together (the frame shows "110 items").
- **Sort:** keeps HomePage's existing `sortModel` (Alphabetic, Duration). A chosen sort applies inside every media row. Until the user picks a sort, each row keeps its natural order (recent or frequent). The folder, playlist and artist rows are not re-sorted *(my call)*.
- **Search:** filters every row by its pattern. Rows with no match hide.
- **View toggle:** grid gives the Figma cards above. List gives `1106:5633`'s compact rows (see the table below), in the same sections, with the same items, still one line per item. Grid is the default. The choice is remembered like the other pages' view choice.
- **"…" menu:** 4a's rows, plus a **Favorites** row that opens the existing favorites page. Favorites leaves the Home body because the Figma has no Favorites row, but the feature stays reachable *(my call)*.

**List view** (`1106:5633`):

| Part | Value |
|---|---|
| Section header | Inter 16 `#969696` with the chevron pushed to the right |
| Row height | 42 |
| Thumbnail | 32 px (a 32×32 crop for video, with a 4 px tall progress mark) |
| Text | `title - subtitle` in Inter 14 `#8F8F8F` |
| Folder, playlist and artist rows | 24 px glyph instead of an image: `folder`, `playlists`, and an artist glyph *(my call: the existing artist placeholder icon)* |

**Empty states:**
- **Empty library** (all rows empty and no search): the library's standard empty label with its Browse button *(my call)*.
- **A search with no match:** "No results".

## Removed

- `HomePage.qml`: the Open File/Open Disc banner, and the Favorites, New Videos and New Music rows.
- `HomeDisplay.qml`: the `newVideo` and `newMusic` sub-pages. `favorites` stays, since the "…" menu opens it.

## Verification

- **Harness:** `docs/superpowers/scripts/vlc-xvfb.sh` at 1600×900, `-vv`, `--aout=dummy`.
  - Shots of Home in grid view and list view go to `docs/superpowers/figma/4b/after_*.png`.
  - Compare them with `home.png`; the ledger goes in the plan.
- **The test library needs history:** play at least one video part-way and one audio track before the shots, so that rows 1, 2, 3 and 5 have items.
- **Log:** grep `vlc.log` for TypeError, ReferenceError and "non-existent property" after each task.
- **Automated test:** `tests/tst_*.qml` or a C++ test for the folder/artist ranking: given a list of (folder, time) entries, it checks the order and that there are no duplicates.
- **Suite:** the qt suite passes.
