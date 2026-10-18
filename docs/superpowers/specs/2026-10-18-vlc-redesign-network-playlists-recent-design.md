# VLC Redesign: Network, Playlists & Recent (slice 4d) Design

**Source of truth:** Figma "VLC Redesign (Community)", file key `dSoAm0gN9ZterHSssJU9FN`.
- **Frames:**
  - Network sidebar variant `858:5294`: Network, "2 items", then the rows Add Network Stream, Podcasts and Radio.
  - Playlists sidebar variant `858:5374`: Playlists, "2 items", then Create playlist and the playlist rows "Cool Songs" and "Anime to Watch".
  - Playlist row component `2459:9352`, with two variants: `unwatched` and `hover-unwatched`.
- **Recent has no frame.** The file has only the sidebar label "Recent" and the `recent` icon (searched by name across the whole page).
- **Reference shots** are in `docs/superpowers/figma/4d/`:
  - Figma: `sb_network.png`, `sb_playlists.png`.
  - Current app: `before_network.png`, `before_playlists.png`, `before_recent.png`.
- **Memory `figma-is-the-spec`** applies. VLC 4's Network page (Folders / Devices / Network sections) and its playlist grid are not references.
- **User ruling (standing since 4b):** "use the figma, the figma is the source of truth". There was no question round. Every choice below that isn't in a frame is marked *(my call)*.

## Scope

- **Network root:** the Figma rows (Add Network Stream, Podcasts, Radio), followed by the shares discovered on the local network.
- **Podcasts and Radio:** each opens its services-discovery tree under Network.
- **Playlists root:** Create playlist, then the library's playlists, as Figma tiles / rows.
- **Recent:** the play history, drawn with 4c's video card and compact row.
- **Removed:** the network page's Folders / Computer / Devices sections and their "see all" sub-pages.

Out of scope:
- The player side panel (4e). It reuses these pages later.
- The Open network stream and New playlist dialogs (slice 8). The existing dialogs are used.
- The playlist context menu redesign (slice 5). The existing `MLContextMenu` is used.
- Restyling the pages below the roots: a share's folders, a podcast feed, a radio directory, a playlist's tracks. None has a Figma main-view frame, so they keep their current bodies (`BrowseTreeDisplay`, `PlaylistMediaDisplay`) under 4a's header, as 4c did for Albums / Artists / Genres.

## Network

**Root rows, in order:**

| Row | Glyph | Action |
|---|---|---|
| Add Network Stream | `add` | `DialogsProvider.openNetDialog()` (the 4a "Add item" entry) |
| Podcasts | `topbar_network` (the Figma `streaming` glyph) | opens Podcasts |
| Radio | `topbar_network` | opens Radio |
| *each discovered LAN share* *(my call)* | `folder` | as now (`BrowseDeviceView`): a directory / node / playlist opens in `["network", "browse"]`, anything else plays; right-click / the menu key opens `NetworkDeviceContextMenu` |

- **The LAN shares** are `NetworkDeviceModel { sd_source: CAT_LAN; source_name: "*" }`, today's "Network" section.
  - *(My call)* The Figma shows only the three rows. Dropping share browsing would remove a core VLC feature with nothing in its place. The shares are rows of the same kind, so they follow Radio. With no shares (the Figma's case) the page matches the frame exactly.
  - Cost if wrong: one repeater to delete.
- **Dropped:** "Folders" (local standard paths, which the Videos / Music folders and the open dialogs cover), "Computer" and "Devices" (capture cards, audio inputs, drives, which the Open capture device dialog covers). Their "see all" sub-pages (`network/folders`, `network/device`) go too *(my call)*.
- **Count:** Podcasts + Radio + shares. The Figma shows "2 items" with no shares; Add isn't counted.
- **Header:**
  - **Not searchable, no sort** *(my call, like 4c's Music root)*. The rows are fixed and the share list is short.
  - The view toggle stays.
- **Grid / list:**
  - **Grid:** 4c's Music-root tile, a 200 px `HomeSquareCard` with a glyph.
  - **List:** 4c's compact `HomeListRow` with a glyph: a 24 px glyph in the 32 px slot, text Inter 14.
- **Colours:**
  - Text `#6B6B6B` (Dark/FG/A3) in the frame for all three rows; Add's and the rows' glyphs are `#8F8F8F` (Dark/FG/A2).
  - *(My call)* Use the colours the 4c Music-root tiles already use, so Network, Music and Playlists match each other. The Figma's A3 is close to the dimmed tone.
- **Spacing** in the frame: row height 32, gap 10 between rows, glyph-to-text gap 10, 20 px above the first row. This is 4c's compact row.

**Podcasts and Radio pages:**
- **Model:** today's service source page. `BrowseTreeDisplay` on `NetworkDeviceModel { sd_source: CAT_INTERNET; source_name: "podcast" | "radio" }` (the SD probe names in `podcast.c` / `radio.c`), then `NetworkMediaModel` trees below.
- **Paths:**
  - `["network", "podcasts"]` and `["network", "radio"]`.
  - A node below them: `["network", "podcasts", "browse"]` / `["network", "radio", "browse"]` + `{ tree }`.
- **Crumbs:** Network ▸ Podcasts ▸ *feed* ▸ …, and Network ▸ Radio ▸ *directory* ▸ … . Each crumb pushes what `onBrowse` pushed for its node, like `ServicesHomeDisplay`'s source crumbs.
- **Podcasts gets an "Add podcast" row** *(my call)*. It opens `DialogsProvider.podcastConfigureDialog()`, today reachable only from Discover ▸ Services. Without it a fresh Podcasts page is empty with no way to subscribe.
  - **Where:** `BrowseTreeDisplay` can't put a row in front of its model. So the Add row is one compact `HomeListRow` (`add` glyph, "Add podcast") in a strip above the view, inside the Podcasts page, in both grid and list modes.
  - **Keyboard:** Down from the header reaches it, and Down from it enters the view.
  - It is shown only while the search is empty.
- **Empty pages:** the existing `BrowseTreeDisplay` empty label and busy indicator, unchanged. Radio needs the internet.
- **Crumbs:** `BrowseTreeDisplay` takes a `breadcrumbs` property; `ServicesHomeDisplay` already overrides it. Podcasts and Radio set their own, so the hard-coded "Network" crumb isn't a problem.
- **`source_name`** is fixed by the path ("podcast" / "radio"), not carried in the History props. Discover ▸ Services keeps its own `source_root` pages and crumbs, unchanged.

**Discover ▸ Services stays** as it is (the "…" ▸ More entry from 4a). It is the only place listing the other internet services (Jamendo, Icecast …).

## Playlists

**Root items, in order:**
1. **Create playlist:** glyph `add`. It runs the 4a "New playlist" flow, `DialogsProvider.newPlaylist()`, then the new playlist appears in this list. It is shown only while the search is empty.
2. **The library's playlists:** `MLPlaylistListModel { playlistType: PLAYLIST_TYPE_ALL }`, as today.

**Count:** playlists only (the frame shows "2 items" with two playlists).

**Header:** the existing playlist sort menu, the view toggle and search.

**List row** (`2459:9352`):
- A 337-wide row at the sidebar's width; in the main view it stretches like 4c's compact list.
- Gap 10, a 32 px slot holding the 24 px `playlists` glyph, the name Inter 14.
- **Name colour:** `#969696` (Dark/FG/A1), or `#C6C6C6` (Dark/FG/2) while hovered.
- **Hover:** a 24 px `more` ("…") glyph button at the right end. This is new: add an optional trailing "more" button to `HomeListRow` (property `showMore`, signal `menuRequested` as now). It shows while hovered or focused.
- *(Old name check)* "today's `componentList`" is `PlaylistMediaDisplay` on the `["playlists", "list"]` path; it stays. It opens `MLContextMenu` for that playlist, the same menu as a right-click.
  - *(My call)* The button also shows while the row has keyboard focus, so it isn't mouse-only. The menu key opens the same menu.
- *(My call)* The Figma row shows the glyph, never the cover. Keep the glyph in the list. The grid uses the cover.

**Grid** *(my call; no frame)*: 4b's playlist card on Home, a `HomeSquareCard` with the playlist cover, title = name, subtitle = "N tracks". The Create tile is the Music root's Add tile (`add` glyph, "Create playlist").

**Click / Enter** on a playlist opens the existing playlist page, `["playlists", "list"]` (today's `componentList`). Crumbs: Playlists ▸ *name*.

**Removed:** `MusicPlaylistsDisplay`'s grid / list delegates for the `all` page, but only if nothing else uses them. Run a grep, and record what was kept and why in the ledger.

## Recent *(my call throughout; no frame)*

The Recent page keeps `MLRecentMediaModel`, last played first. It changes only how the items are drawn.

**Roles:** `MLRecentMediaModel` lacks the `thumbnail`, `isNew` and `main_artist` roles that 4c's cards read. `MLFolderBrowseModel` computes all three generically from `MLVideo` / `MLAudio`.
- Hoist those three roles into `MLMediaModel`, so every media model (folder browse, recent and the rest) answers them.
- Drop the copies from `MLFolderBrowseModel`. It keeps `isFolder`, and its folder-row special cases.
- This is a C++ change and needs a rebuild.

**Placeholder:** `HomeVideoCard` gains a `glyph` property, drawn centred on the backing when there is no thumbnail, as `HomeSquareCard` does.

**Items:**
- **Grid:** 4c's video card, `HomeVideoCard` (316 at 1920, 16:9, radius 12, progress bar, title). The page holds video and audio together, so every item uses the 16:9 card.
  - Audio items show their cover, cropped.
  - With no cover, they show the music glyph centred on the `#171717` backing, as the Listen Again placeholder does.
- **List:** 4c's compact row with the 32 px thumbnail, the title, and the progress mark. Video titles are played-dimmed (`isNew` false) like 4c. Audio rows read "title - artist" like 4c's Songs.
- **Click / Enter:** plays the item. Right-click / the menu key: `MLContextMenu`.
- **Header:**
  - Count, the view toggle, and search.
  - No sort: the history keeps its order, as today.

## Navigation and history

| Path | Page | Crumbs |
|---|---|---|
| `["network"]` | Network root | Network |
| `["network", "podcasts"]`, `["network", "radio"]` | the SD source's root | Network ▸ Podcasts |
| `["network", "podcasts", "browse"]` + `{ tree }` (and radio) | a node below it | Network ▸ Podcasts ▸ … |
| `["network", "browse"]` + `{ tree }` | a LAN share or a folder in it (as now) | Network ▸ *share* ▸ … (as now) |
| `["playlists"]` | Playlists root | Playlists |
| `["playlists", "list"]` + playlist props (as now) | a playlist's tracks | Playlists ▸ *name* |
| `["recent"]` | Recent | Recent |

**Pushes to removed paths:** only `BrowseHomeDisplay` pushes `network/folders` and `network/device`, and it goes. History is in memory and starts at Home, so no stale entry can name them, and no redirect is needed. Grep for `History.push` users to confirm.

**Back:** a page restored from History keeps its item through `initialIndex`.
- 4c's lesson: restore it once, in the page, after the first load. Never bind it to `MainViewLoader.initialIndex`, which re-applies it on every count change and steals focus from the search field.

## Behaviour shared by the three roots

**Keyboard:**
- The tiles / rows form one navigable grid / list, as on the Music root.
- Up from the first row goes to the header.
- Escape in the search field drops to the first item.

**Focus on entry:** the first item that isn't Add / Create *(my call; 4c logged "Videos root opens with Add focused" as a defect)*.

**Empty library** (no media library): nothing to build. The sidebar model (`NavigationModel.hasMedialib`) already gates the library entries, and each view keeps its own empty label. Network doesn't depend on the library.

## Removed

- `BrowseHomeDisplay.qml` (the three sections) and the `folders` / `device` pages in `BrowseDisplay.qml`.
- `StandardPathModel`'s QML use. The C++ class stays: it is registered in `mainui.cpp` and mirrored in `mainctx.cpp`.
- `BrowseDeviceView.qml` stays if the share rows reuse its click logic; otherwise it goes once a grep shows no users.
- `MusicPlaylistsDisplay`'s `all` page body (`PlaylistMediaList` is used nowhere else). Ledger what was deleted.
- `RecentDisplay.qml`'s `MediaView` body. The file stays; its body is replaced.

## Verification

- **Harness:** `docs/superpowers/scripts/vlc-xvfb.sh` at 1600×900, `-vv`, `--aout=dummy`. Never on the user's display.
  - **Library:** the existing test library. It has a playlist "t1"; add a second playlist through the Create flow during the run.
  - **The Xvfb run sees the host's real LAN** (a `truenas` SMB share shows today). A shot with shares is fine. Note it in the ledger, and don't browse into a real share.
  - **Radio needs the internet.** Shoot whatever loads within 15 s, and accept the busy / "No results" state offline.
- **Shots** go to `docs/superpowers/figma/4d/after_*.png`:
  - Network root (grid and list);
  - Podcasts (with the Add podcast row);
  - Radio;
  - Playlists (grid, and list with one row hovered);
  - Recent (grid and list).

  Compare them with `sb_network.png` / `sb_playlists.png`. The ledger goes in the plan.
- **Log:** grep `vlc.log` for TypeError, ReferenceError and "non-existent property" after each task.
- **Automated tests:** the root's item list is a pure function, the static rows plus the share names. Pin that function and the `count` rule (Add / Create not counted) in a `qml_test` next to `tst_LibraryHelpers.qml`.
- **Suite:** the qt suite passes.
