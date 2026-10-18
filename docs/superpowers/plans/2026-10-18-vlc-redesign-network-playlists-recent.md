# Network, Playlists & Recent (slice 4d) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Network, Playlists and Recent the Figma's root rows and 4c's library look.
- **Network:** Add Network Stream / Podcasts / Radio, plus LAN shares.
- **Playlists:** Create playlist plus playlist tiles / rows with a hover "…".
- **Recent:** the play history in 4c's video card and compact row.

**Architecture:**
- **Roles:** the `thumbnail` / `isNew` / `main_artist` roles move from `MLFolderBrowseModel` into `MLMediaModel`, so every media model (Recent included) feeds 4c's cards.
- **Shared root page:** the Music root's tile page becomes a shared `LibraryRootPage.qml`, used by Music and Network.
- **Playlists and Recent:** each becomes a `MainViewLoader` page in the shape of `LibraryFolderPage.qml`, an `ExpandGridView` for grid and for list.
- **Podcasts and Radio:** they reuse `BrowseTreeDisplay` under new `network/podcasts` and `network/radio` paths.

**Tech Stack:** Qt 6 / QML, the C++ media-library models (`MLMediaModel`, `MLListCacheLoader`), `NetworkDeviceModel` / `NetworkMediaModel`, meson. Tests: `qml_test` (`tests/tst_LibraryHelpers.qml`).

**Spec:** `docs/superpowers/specs/2026-10-18-vlc-redesign-network-playlists-recent-design.md`

## Global Constraints

- **Figma is the source of truth** (`dSoAm0gN9ZterHSssJU9FN`).
  - Frames: Network `858:5294`, Playlists `858:5374`, and the playlist row `2459:9352`.
  - Shots are in `docs/superpowers/figma/4d/`. VLC 4's Network sections and playlist grid are not references.
- **Sizes:** all Figma px go through `VLCStyle.dp(<px>, VLCStyle.scale)`.
- **Colours** (dark), using the pattern `theme.palette?.isDark ? <figma> : <theme role>` from the Home cards:
  - playlist name `#969696`, or `#C6C6C6` while hovered;
  - glyphs `#8F8F8F`;
  - tile backing `#1E1E1E`;
  - the other values are 4c's (`#171717` image backing, `#6B6B6B` dimmed text, `#D37918` progress).
- **Rows:** the compact `HomeListRow`: height 32, a 24 px glyph in a 32 px slot, a 10 gap, Inter 14, 10 between rows, 20 above the first row.
- **Counts never include Add / Create rows.**
- **Back-restore:**
  - A page restored from History keeps its item through its own `initialIndex`, handed to the `MainViewLoader` once, after the first load. This is the `restoreOnce` pattern in `LibraryFolderPage.qml:157-174`.
  - Never bind a page's `initialIndex` to the loader's.
  - Do not touch `MainViewLoader.qml`.
- **Harness runs:**
  - `docs/superpowers/scripts/vlc-xvfb.sh` only (Xvfb :77, `--aout=dummy` built in, `-vv`). Never xdotool on the user's display.
  - Don't touch PID 2956754.
  - The Xvfb run sees the host's real LAN: never browse into a real share.
- **Git:** commits as the global git user (ming), with no Co-Authored-By. Work on branch `redesign/network-playlists`.
- **After each task:**
  - `ninja -C build`;
  - `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt` all OK;
  - grep `build/redesign-profile/run/vlc.log` for `TypeError|ReferenceError|non-existent property` after any harness run: none new.
- **New QML files** go in both `modules/gui/qt/meson.build` and `Makefile.am`, plus `po/POTFILES.in`. Deleted ones come out of all three.

## Review Focus

1. **A LAN share appears or vanishes while the Network root is open:** the tiles rebuild, and focus stays on a valid tile, not on nothing. Task 3, Step 6.
2. **Typing a search on Playlists or Recent after Back:** every letter stays in the field. This was 4c's regression. Tasks 4 and 5, harness step.
3. **Create playlist cancelled, or with an empty name:** nothing changes, nothing is pushed, and no warning appears. Task 4, Step 5.
4. **A Recent audio item with no cover, or a video whose file is gone:** a glyph placeholder, no TypeError. Task 5, Step 4.
5. **Podcasts / Radio offline or slow:** the busy indicator, then the empty label; Back from Podcasts lands on the Podcasts tile. Task 3, Step 6.

---

### Task 1: Media roles move into MLMediaModel

**Files:**
- Modify: `modules/gui/qt/medialibrary/mlmediamodel.hpp` (Roles enum), `mlmediamodel.cpp` (`roleNames`, `itemRoleData`, `thumbnailUpdated`).
- Modify: `modules/gui/qt/medialibrary/mlfolderbrowsemodel.hpp` / `.cpp` (drop the moved roles).

**Interfaces:**
- **Produces:** on every `MLMediaModel`, the QML roles below. `MLRecentMediaModel` gets them for free.
  - `thumbnail`: the `small_cover` value.
  - `isNew`: `MLVideo::isNew()` for videos, otherwise undefined.
  - `main_artist`: `MLAudio::getArtist()` for audio, otherwise undefined.
- **Consumes:** nothing new.

- [ ] **Step 1: Add `MEDIA_THUMBNAIL`, `MEDIA_IS_NEW` and `MEDIA_MAIN_ARTIST` to `MLMediaModel::Roles`, before `MEDIA_ROLES_COUNT`.**
  - Map them in `roleNames()` to `"thumbnail"`, `"isNew"` and `"main_artist"`.
  - Answer them in `itemRoleData` with the `dynamic_cast<const MLVideo*>` / `<const MLAudio*>` code now in `MLFolderBrowseModel::itemRoleData`.
  - `thumbnailUpdated` emits `dataChanged` for `{MEDIA_SMALL_COVER, MEDIA_THUMBNAIL}`.
- [ ] **Step 2: In `MLFolderBrowseModel`, delete `FOLDER_IS_NEW`, `FOLDER_ARTIST` and `FOLDER_THUMBNAIL`, and their `roleNames` entries.**
  - Keep `FOLDER_IS_FOLDER` and the folder-row branch, now switching on the `MEDIA_*` names.
  - Delete the `thumbnailUpdated` override if it existed only to add `FOLDER_THUMBNAIL`. Keep it if it also corrects the row offset for folders.
- [ ] **Step 3:** Build and run the qt suite. Expected: 14 OK.
- [ ] **Step 4: Harness check of 4c (the roles' existing consumers).**
  - Videos ▸ redesign-media ▸ Shows ▸ The Clip ▸ S01 grid: thumbnails show, and played titles are dimmed.
  - Music ▸ Songs, at a level with tracks, in list mode: rows read "title - artist".
  - The log is clean.
- [ ] **Step 5: Commit** `qt: media models answer thumbnail, isNew and main_artist`.

### Task 2: LibraryRootPage, shared by Music and Network

**Files:**
- Create: `modules/gui/qt/medialibrary/qml/LibraryRootPage.qml`, cut from `MusicDisplay.qml`'s `rootComponent` body (lines 56-180).
- Modify: `MusicDisplay.qml` (uses it), `util/qml/Helpers.qml`, `tests/tst_LibraryHelpers.qml`, meson / Makefile.am / POTFILES.

**Interfaces:**
- **Produces:**
  - `LibraryRootPage` (a `Widgets.PageExt`):
    - `property var tiles`: `[{ glyph, text, add: bool, … }]`.
    - `signal tileActivated(var tile, int index, int reason)` and `signal tileMenuRequested(var tile, int index, point globalPos)`.
    - `itemCount` bound to `Helpers.rootItemCount(tiles)`, `isSearchable: false`.
    - The grid is `HomeSquareCard` (200 base, `#1E1E1E` backing), and the list is a compact `HomeListRow`, as in today's Music root.
    - **Focus on entry:** the first tile without `add`, falling back to tile 0.
    - It keeps the focused tile's index when `tiles` is reassigned with the same length, and clamps to the last tile when the list shrinks.
  - `Helpers.rootItemCount(tiles : var) : int`: the number of tiles without `add: true`.
  - `Helpers.withShares(fixed : var, shares : var, glyph : string) : var`: `fixed`, then one `{ glyph, text: share.name, share: i }` per share, in order.

- [ ] **Step 1: Write failing tests in `tst_LibraryHelpers.qml`:**

```qml
function test_rootItemCount() {
    compare(Helpers.rootItemCount([]), 0)
    compare(Helpers.rootItemCount([{ add: true }, { text: "a" }, { text: "b" }]), 2)
    compare(Helpers.rootItemCount([{ add: true }]), 0)
}
function test_withShares() {
    const fixed = [{ add: true, text: "Add" }, { text: "Podcasts" }]
    compare(Helpers.withShares(fixed, [], "g"), fixed)
    const r = Helpers.withShares(fixed, [{ name: "truenas" }, { name: "nas2" }], "g")
    compare(r.length, 4)
    compare(r[2].text, "truenas"); compare(r[2].share, 0); compare(r[2].glyph, "g")
    compare(r[3].share, 1)
    compare(fixed.length, 2) // input untouched
}
```

- [ ] **Step 2:** Run `meson test -C build tst_LibraryHelpers`. Expected: FAIL (not a function).
- [ ] **Step 3: Implement both helpers in `Helpers.qml`, and create `LibraryRootPage.qml`.**
  - `MusicDisplay`'s root becomes `LibraryRootPage { title: qsTr("Music"); tiles: […] }`.
  - The tiles are today's `_tiles`, with `add: true` on Add.
  - `onTileActivated` keeps today's `_activate` logic.
- [ ] **Step 4:** Build and run the qt suite. Expected: all OK.
- [ ] **Step 5: Harness, Music root.**
  - It looks as it did in `docs/superpowers/figma/4c/after_music_root.png`.
  - The count is "4 items".
  - It opens with Songs focused, not Add (this fixes 4c's ledgered "opens with Add focused" defect for Music).
  - Arrow keys walk the tiles.
  - The log is clean.
- [ ] **Step 6: Commit** `qt: one root tile page for the library roots`.

### Task 3: Network root, Podcasts and Radio

**Files:**
- Create: `modules/gui/qt/network/qml/NetworkHomeDisplay.qml`.
- Modify: `network/qml/BrowseDisplay.qml` (pageModel).
- Delete: `network/qml/BrowseHomeDisplay.qml` and `network/qml/BrowseDeviceView.qml`. They have no other users; grep again before deleting. `StandardPathModel` C++ stays.
- Modify: meson / Makefile.am / POTFILES.

**Interfaces:**
- **Consumes:** `LibraryRootPage` and `Helpers.withShares` (Task 2). `NetworkHomeDisplay` imports `VLC.MediaLibrary`, which is always built.
- **Produces:** the paths `["network"]` (home), `["network","podcasts"]`, `["network","radio"]`, `["network","podcasts","browse"]` + `{ tree }`, `["network","radio","browse"]` + `{ tree }`, and `["network","browse"]` + `{ tree }` (unchanged).

- [ ] **Step 1: `NetworkHomeDisplay` is a `LibraryRootPage` titled "Network".**
  - **Tiles:** `Helpers.withShares([{ glyph: VLCIcons.add, text: qsTr("Add Network Stream"), add: true }, { glyph: VLCIcons.topbar_network, text: qsTr("Podcasts"), page: "podcasts" }, { glyph: VLCIcons.topbar_network, text: qsTr("Radio"), page: "radio" }], shares, VLCIcons.folder)`.
  - **`shares`:** rebuilt from `NetworkDeviceModel { ctx: MainCtx; sd_source: NetworkDeviceModel.CAT_LAN; source_name: "*" }` on `countChanged` / `loadingChanged`, with `getDataAt(i)` for each row.
  - **Activation:**
    - Add: `DialogsProvider.openNetDialog()`.
    - `page`: `History.push([...pagePrefix, page], reason)`.
    - `share`: read `type` from `getDataAt(share)`. For `NetworkMediaModel.TYPE_DIRECTORY`, `TYPE_NODE` or `TYPE_PLAYLIST`, push `["network","browse"]` with `{ tree: data.tree }`; otherwise `deviceModel.addAndPlay(share)`. This is the logic of `BrowseDeviceView.qml:125-150`.
  - **Menu:** `tileMenuRequested` on a share opens `NetworkDeviceContextMenu { model: deviceModel; ctx: MainCtx }` via `popup([deviceModel.index(share, 0)], globalPos)`.
- [ ] **Step 2: `BrowseDisplay` pageModel.**
  - `home` → `NetworkHomeDisplay`; remove `folders` and `device`.
  - Add `podcasts` and `radio`. Each is a nested `Widgets.PageLoader` with a default root page and a `browse` page guarded on `prop.tree`.
    - The root is `BrowseTreeDisplay` on `NetworkDeviceModel { sd_source: CAT_INTERNET; source_name: "podcast" | "radio" }`.
    - `browse` is `BrowseTreeDisplay` on `NetworkMediaModel { tree }`.
    - Copy the shape and crumbs from `ServicesHomeDisplay.qml`'s `sourceRootComponent` / `sourceBrowseComponent`.
    - **Crumbs:** `{ title: qsTr("Network"), path: ["network"] }`, then `{ title: qsTr("Podcasts") | qsTr("Radio"), path: [..., "podcasts"|"radio"] }`, then the nodes, as `ServicesHomeDisplay` builds them.
  - Each Podcasts / Radio / browse page uses the `restoreOnce` pattern for `initialIndex` (Global Constraints).
- [ ] **Step 3: "Add podcast" strip on the Podcasts root.**
  - One compact `HomeListRow` (`VLCIcons.add`, `qsTr("Add podcast")`) above the `BrowseTreeDisplay` in a `ColumnLayout`.
  - Shown while `search.pattern === ""`.
  - Activated → `DialogsProvider.podcastConfigureDialog()`.
  - **Keyboard:** header Down → the strip; strip Down → `view.setCurrentItemFocus(Qt.TabFocusReason)`; view Up from the first row → the strip.
- [ ] **Step 4: Delete `BrowseHomeDisplay.qml` and `BrowseDeviceView.qml`.**
  - First `grep -rn` for their names and for `"folders"` / `"device"` pushes under `modules/gui/qt`. Expected: no users left.
  - Remove them from meson / Makefile.am / POTFILES.
- [ ] **Step 5:** Build and run the qt suite. Expected: all OK.
- [ ] **Step 6: Harness.**
  - **Network root, grid and list:** Add Network Stream, Podcasts, Radio, then the host's shares (e.g. `truenas`). Shoot `after_network_grid.png` / `after_network_list.png`.
  - **The count** = 2 + the number of shares.
  - **Focus on entry** is Podcasts.
  - **Review Focus 1:** this needs a temporary, uncommitted test hook.
    - Add a `Timer` to `NetworkHomeDisplay` that appends a fake share `{ name: "fake" }` to `shares` at 3 s and removes it at 8 s.
    - In the harness, focus "fake" at about 5 s. After 8 s, focus must be on the new last tile and the arrow keys must still work.
    - Remove the Timer and ledger the result.
  - **Podcasts:** the Add podcast strip, then the (likely empty) list. Shoot `after_podcasts.png`. Activating Add podcast opens the configure dialog; Escape closes it.
  - **Radio:** wait up to 15 s; the station tree or the busy / empty state (offline is fine). Shoot `after_radio.png`.
  - **Review Focus 5:** Back from Podcasts → the Network root with Podcasts focused.
  - **Add Network Stream** opens the open-network dialog; Escape closes it.
  - Don't open a real share. The log is clean.
- [ ] **Step 7: Commit** `qt: Figma network root with podcasts and radio`.

### Task 4: Playlists root

**Files:**
- Create: `modules/gui/qt/medialibrary/qml/PlaylistsPage.qml`.
- Modify:
  - `PlaylistsDisplay.qml`: a `Widgets.PageLoader` with `all` (default) → `PlaylistsPage`, and `list` → today's `PlaylistMediaDisplay` page, moved here from `MusicPlaylistsDisplay.qml:100`.
  - `HomeListRow.qml`: add `showMore`.
- Delete: `MusicPlaylistsDisplay.qml` and `PlaylistMediaList.qml`, after a grep shows no users.
- Modify: meson / Makefile.am / POTFILES.

**Interfaces:**
- **Consumes:** `MLPlaylistListModel { playlistType: PLAYLIST_TYPE_ALL }` (roles `id`, `name`, `thumbnail`, `count`); `DialogsProvider.newPlaylist() : bool`.
- **Produces:**
  - `HomeListRow.showMore : bool` (default false). When true, a 24 px `VLCIcons.more` button at the right end shows while `hovered || visualFocus`. Clicking it emits the existing `menuRequested(globalPos)`.
  - The name colour becomes `#C6C6C6` while hovered, only when `showMore` is set.
  - The path `["playlists","list"]` + `{ parentId, title }`, unchanged.

- [ ] **Step 1: `HomeListRow.showMore`**, as above. The button is not a tab stop; the menu key already emits `menuRequested`.
- [ ] **Step 2: `PlaylistsPage`, in `LibraryFolderPage.qml`'s shape.**
  - A `MainViewLoader` with grid and list `ExpandGridView`s, a header delegate for the Create tile / row (shown while the search is empty), and the `restoreOnce` initialIndex.
  - **Grid:** `HomeSquareCard` with `image: model.thumbnail`, `glyph: VLCIcons.playlists` when there is no thumbnail, `title: model.name`, `subtitle: qsTr("%n tracks", "", model.count)`. The base is 200.
  - **List:** `HomeListRow { compact: true; glyph: VLCIcons.playlists; text: model.name; showMore: true }`. The list never shows the cover (Figma `2459:9352`). The base is 400 with 10 gaps, as 4c's list.
  - **Create:** `VLCIcons.add`, `qsTr("Create playlist")` → `DialogsProvider.newPlaylist()`.
  - **Click / Enter:** `History.push([...pagePrefix, "list"], { parentId: model.id, title: model.name }, reason)`.
  - **Right-click, menu key or "…":** today's playlist `MLContextMenu` for that row. Reuse whatever `PlaylistMediaList` passes it.
  - **Header:** sort (`MusicPlaylistsDisplay`'s current `sortModel`), the view toggle, search; `itemCount` = the model's count.
  - **Focus on entry:** the first playlist, not Create.
- [ ] **Step 3: Move the `list` page into `PlaylistsDisplay`.** Keep its crumbs Playlists ▸ *name*. Delete `MusicPlaylistsDisplay.qml` and `PlaylistMediaList.qml` once a grep shows no users.
- [ ] **Step 4:** Build and run the qt suite. Expected: all OK.
- [ ] **Step 5: Harness.**
  - **Playlists grid:** the Create tile, then "t1". Shoot `after_playlists_grid.png`.
  - **Create a second playlist** "Cool Songs" via Create. It appears; the count reads "2 items".
  - **List mode:** hover a row: the "…" shows and the name brightens. Shoot `after_playlists_list.png` and compare with `sb_playlists.png`.
  - **"…" opens the menu**; Escape closes it.
  - **Review Focus 3:** Create, then Cancel: no change and nothing in the log. Create with an empty name: no playlist is created.
  - **Open "t1"**, then Back: "t1" stays focused.
  - **Review Focus 2:** Back, then click search, then type "coo" one key per 1.5 s: the field reads "coo".
  - The log is clean.
- [ ] **Step 6: Commit** `qt: Figma playlists root`.

### Task 5: Recent

**Files:**
- Modify: `modules/gui/qt/medialibrary/qml/RecentDisplay.qml` (the body is replaced) and `HomeVideoCard.qml` (adds `glyph`).

**Interfaces:**
- **Consumes:** `MLRecentMediaModel` roles `thumbnail`, `isNew`, `main_artist` (Task 1), plus `isVideo`, `progress`, `title`, `mrl` and `id`.
- **Produces:** `HomeVideoCard.glyph : string`. When the thumbnail is empty, the glyph is drawn centred, 48 px, `#969696` on the backing (as `HomeSquareCard` does).

- [ ] **Step 1: `HomeVideoCard.glyph`**, as above.
- [ ] **Step 2: `RecentDisplay`, in `LibraryFolderPage.qml`'s shape** without the folders, Add or sort.
  - A `MainViewLoader` on `MLRecentMediaModel { searchPattern }`, with `sortModel: []` and the `restoreOnce` initialIndex.
  - **Grid:** `HomeVideoCard` (316 base, 20 / 40 gaps), `dimmed: model.isVideo && !model.isNew`, `glyph: model.isVideo ? VLCIcons.movie : VLCIcons.topbar_music`. Use the existing glyph names; grep `vlcicons.hpp`.
  - **List:** `HomeListRow { compact: true; image: model.thumbnail; glyph: <same>; progress: model.progress; dimmed: model.isVideo && !model.isNew }`.
    - **Text:** the title for video; `title + " - " + main_artist` for audio, or just the title when the artist is empty.
    - **`playing`:** `Qt.resolvedUrl(model.mrl) === Player.url`, as 4c.
  - **Click / Enter:** `MediaLib.addAndPlay(model.id)`. **Right-click / menu key:** `MLContextMenu { model: recentModel }`.
- [ ] **Step 3:** Build and run the qt suite. Expected: all OK.
- [ ] **Step 4: Harness.**
  - **Recent grid:** video thumbnails; audio covers or the note glyph (Review Focus 4: `sine.ogg` / `huge.mp3` have no cover). Shoot `after_recent_grid.png`.
  - **List:** audio rows read "title - artist" (e.g. "moonlight - Tester"). Shoot `after_recent_list.png`.
  - **Review Focus 2:** open an item's context menu and Escape; click search; type "tra" one key per 1.5 s: the field reads "tra".
  - The log is clean.
- [ ] **Step 5: Commit** `qt: recent in the library cards`.

### Task 6: Wrap-up

**Files:** `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md` (row 4d), this plan's `## Ledger`.

- [ ] **Step 1:** Mark roadmap row 4d done, naming this plan and the departures: LAN shares on the Network root; Add podcast; Recent in the video card; the Folders / Devices sections dropped; `LibraryRootPage` shared with Music.
- [ ] **Step 2:** Append `## Ledger` to this plan, with each `after_*` shot against the Figma frames, the deletions with their grep evidence, and the Review Focus results.
- [ ] **Step 3: Commit** `doc: finish the network, playlists & recent slice`.

## Ledger

Shots (1600×900, dark, test library with `redesign-media` and `redesign-music`) in `docs/superpowers/figma/4d/`: `after_network_grid.png`, `after_network_list.png`, `after_podcasts.png`, `after_radio.png`, `after_playlists_grid.png`, `after_playlists_list.png`, `after_recent_grid.png`, `after_recent_list.png`. `before_*.png` are the old pages. References: `sb_network.png`, `sb_playlists.png` (the sidebar variants, 427×986). Figma has no main-view frame for Recent, nor for the 4d grids (Network, Playlists, Recent); those follow the Figma video card and the 4c list.

### Figma comparison

| Shot against reference | Figma | Built | Verdict |
|---|---|---|---|
| `after_network_list` / `sb_network.png` | Add Network Stream, Podcasts, Radio as compact rows; "2 items"; sort, view, search | The same three rows and glyphs (compact `HomeListRow`, 400 wide), plus one row per LAN share (truenas, folder glyph). Count 3 = 2 + 1 share. Header has the view toggle only | rows match, plus the LAN shares; header deviates: no sort or search, by the spec's call (departure 12) |
| `after_network_grid` | none | `HomeSquareCard` tiles (200, `#1E1E1E`) as the Music root | no frame; same cards as 4c |
| `after_podcasts`, `after_radio` | none | `BrowseTreeDisplay` pages. Podcasts has an "Add podcast" strip above the view (empty: "Nothing to see here"). Radio: 240 country nodes with flags | no frame; data is the live radio list |
| `after_playlists_list` / `sb_playlists.png` | Create playlist, then one row per playlist with the playlist glyph; "2 items" | "Create playlist" row, then compact rows laid out in columns at 1600; "…" appears on the hovered row (t1) and name goes `#C6C6C6` | match; the columns follow the width |
| `after_playlists_grid` | none | Create tile, then `HomeSquareCard` (cover, name, "N tracks"). Empty playlists show the library's default cover (light tile, orange note), as Home's playlist cards | no frame; deviation from the spec's dark glyph tile, see departure 6 |
| `after_recent_grid`, `after_recent_list` | none | Grid: `HomeVideoCard` (316, 16:9); cover-less items on a `#171717` backing with a 48 px glyph: `topbar_video` for videos, the note (`topbar_music`) for audio. List: compact `HomeListRow`, audio reads "title - artist" (e.g. "moonlight - Tester") | no frame; the 4c card and rows |
| All: shell | window chrome, sidebar about 216 px at 1920 | 4a's shell, sidebar 152 px at 1600; the player strip is a harness artefact | not 4d |

### Departures

1. LAN shares (`NetworkDeviceModel` CAT_LAN) are tiles on the Network root, after Add, Podcasts and Radio. A share that is a directory, node or playlist opens `[network, browse]`; any other share plays. Right-click on a share opens `NetworkDeviceContextMenu`.
2. The Folders / Computer / Devices (`StandardPathModel`) sections are dropped; nothing pushes `network/folders` or `network/device`.
3. Podcasts has an "Add podcast" row (opens `podcastConfigureDialog`), a strip above the view that hides while a search runs. Radio has none.
4. `LibraryRootPage` is the tile page for both the Network and Music roots. The Music root now opens on Songs (not Add) and restores its tile on Back, like Network. The view toggle is Network's only (`hasGridListMode` is on `NetworkHomeDisplay`, not the shared page).
5. `BrowseTreeDisplay` restores its item on Back for every user (LAN browse, Discover ▸ Services, Podcasts, Radio). They recorded `History.viewProp.initialIndex` before but nothing read it. It also gained `setCurrentItemFocus`, so those pages focus on load.
6. The Playlists grid uses the model's default cover for empty playlists (as Home). The spec's "glyph when no thumbnail" is wired but never fires. Awaiting the user's sign-off.
7. Playlist drag-and-drop, multi-select delete and the "Processing…" indicator are dropped; Figma shows none of them. Awaiting the user's sign-off.
8. Recent uses the 16:9 `HomeVideoCard` (new `glyph`, for audio and cover-less items) and compact `HomeListRow`s. The glyphs are `VLCIcons.topbar_video` / `topbar_music` (`movie` doesn't exist).
9. `thumbnail`, `isNew` and `main_artist` are roles of `MLMediaModel`. The duplicates `VIDEO_THUMBNAIL`, `VIDEO_IS_NEW` and `AUDIO_ARTIST` are removed (the same name under two ids breaks `dataChanged` refresh), as are `MLFolderBrowseModel`'s `FOLDER_*` copies. `MLMediaModel::thumbnailUpdated` replaces the two subclass overrides.
10. `PlaylistsPage` copies `LibraryFolderPage`'s move/focus/restore plumbing and `RecentDisplay` copies it again (about 100 lines each). A shared base would have reworked 4c mid-slice.
11. `HomeListRow.showMore` (default false): a "…" button on hover or focus, used by the Playlists list.
12. The Network root has no sort and no search (Figma's sidebar variant draws them). The spec makes it a fixed tile page: `LibraryRootPage` is not searchable and has no sort menu, and only the view toggle is on.

### Deletions

- `BrowseHomeDisplay.qml`, `BrowseDeviceView.qml`: `grep -rn 'BrowseHomeDisplay\|BrowseDeviceView\|HomeDeviceView' modules/gui/qt po` found only the build lists and `BrowseDisplay.qml`. The only `"folders"` hits are Home's own page (`HomeDisplay.qml`, `HomePage.qml`).
- `MusicPlaylistsDisplay.qml`, `PlaylistMediaList.qml`: the grep showed `PlaylistMediaList.qml` used only by `MusicPlaylistsDisplay`, and that only by `PlaylistsDisplay`. (`PlaylistMediaList` in `modules/control/upnp_server` is an unrelated C++ alias.)
- All four are out of `meson.build`, `Makefile.am` and `po/POTFILES.in`; `NetworkHomeDisplay`, `LibraryRootPage` and `PlaylistsPage` are in.

### Review Focus results

1. Live `tiles` reassign keeps or clamps focus: a temporary Timer added and removed a fake share. With the grid focused, focus (and its ring) moves to the new last tile; with the header focused it isn't stolen. Fixes: `onTilesChanged` clamps `_current`; the rebuilt tile takes the old focus reason (ring kept); `_target` and `_pending` are functions (as bindings they were stale when the delegates rebuilt).
2. Search field keeps its text: click search, type one key per 1.5 s: "coo" on Playlists, "tra" on Recent. Menu Escape also checked.
3. Create playlist: `DialogsProvider::newPlaylist()` already returns on Cancel or an empty name; checked, nothing added. A named one appears and the count goes up.
4. Recent audio without a cover (`sine.ogg`, `huge.mp3`) shows the note glyph. A video whose file is gone: not exercised.
5. Back restores the tile: Network ▸ Radio, Podcasts and Music ▸ Albums, and Playlists ▸ a playlist (by index), Recent (3rd item). A share not yet discovered on Back (temporary hook) is focused when it appears. Podcasts and Radio offline or slow, and their busy indicator: not exercised (Radio loaded online, 240 countries within 15 s, and no busy state was recorded).

### Known pre-existing issues (not fixed)
- Enter/Space on a `BrowseTreeDisplay` grid item does nothing on Xvfb (`actionAtIndex` is never emitted); double-click works. The code path is untouched since upstream (`GridItem`, `NetworkGridItem`); check on master or a real desktop.
- Playlist search returns nothing for the terms tried (coo, cool, t1: "0 items"); same result with the old page stashed.

### Known minors (not fixed)
- No automated check of the role names; `MLVideoGroupsModel` and the audio models outside the folder page are harness-unchecked.
- `LibraryRootPage`: `_pending` stays true if the focused restored tile shrinks away; the Add tile records `initialIndex` 0.
- `BrowseTreeDisplay`: `restoreOnce` stays armed when the restored count never exceeds the index; Podcasts and Radio pages have no Escape → Back (as Services); the 400 dp Add row width is duplicated.
- `PlaylistsPage`: the ~80 px gap under the Create tile (as 4c); `qsTr` gets `undefined` without `?? 0`; `LibraryFolderPage` may have the same entry-focus gap after sidebar Right.
- Recent: import order.
- `LibraryRootPage`: `tileCard` and `tileRow` repeat the same Navigation/focus block; the `_current` regrow jump (Task 2 review): an index kept past the end (a pending restore) sends the focus back to it when the list regrows.
- Dialogs can't take Escape on Xvfb (no window manager); they were closed by their buttons.
- The Add dialog, Escape on the Add Network Stream dialog and real LAN shares (truenas was listed, never opened) were not exercised.

### Verification
- Build clean; `QT_QPA_PLATFORM=offscreen meson test -C build --suite qt`: 14/14 OK after each task.
- Harness (1600×900, `-vv`) per task. Final log greps, all empty: Tasks 1, 2, 3 and 5 grepped `TypeError`, `ReferenceError` and "non-existent property"; Task 4 also grepped "unable to load" and "is not defined". One `ReferenceError: DialogsProvider is not defined` showed up in Task 3's first run and was fixed (`import VLC.Dialogs`). Task 3's final grep lacked the "is not defined" pattern (and "unable to load"), but that error is a `ReferenceError`, which it did grep.

### Final review fix wave
- `LibraryRootPage` scrolls: the tiles sit in a `Flickable` (wheel, scrollbar), the focused tile is kept in view, and a grid/list switch starts at the top. The list is one column that grows down (a `TopToBottom` Flow with no height never wraps). Checked with 15 temporary fake shares (removed): the last share scrolls into view in both modes. Music still matches `4c/after_music_root.png` and opens on Songs.
- `PlaylistsPage` and `LibraryFolderPage` clamp the restored index (as `RecentDisplay`).
- `NetworkHomeDisplay` rebuilds the share tiles on `dataChanged`, `modelReset` and row inserts/removes/moves too; the model sorts by name explicitly (its default already did).
- Podcasts opens on its feeds; the Add podcast row takes the focus only when there are none (checked with no feeds; with feeds not exercised).
- Playlists: a search with no hits shows "No results", centred; an empty library entered while it loads moves the focus to Create once it has loaded.
- "Play as audio" shows for videos only (Recent's list menu and `HomeVideoCard`).
- The Network root looks the same, so `after_network_grid.png` and `after_network_list.png` were not re-shot.
- Removed from Known minors above: the playlist "No playlists found" offset, the unclamped restore index, the stale shares, and "Play as audio" on audio items.
