# VLC Redesign: Player side panel (slice 4e) Design

**Source of truth:** Figma "VLC Redesign (Community)", file key `dSoAm0gN9ZterHSssJU9FN`.
- **Frames:**
  - Sidebar component `848:1996`, ten variants (`Default 848:1995`, home, videos ×3, music ×3, network, playlists). 4b–4d already took the rows and hierarchy from them; this slice builds the panel itself.
  - `Player - Music 4767:23726`: a sidebar instance sits off-canvas at x −437, y 40 (between the 40 px title bar and the 54 px control bar), so the panel slides in from the left.
- **Video:** `redesign source.mp4` 11:36–11:56 shows the behaviour the frames can't:
  - The title bar's sidebar button (between "…" and the folder chip) opens and closes it.
  - The video area narrows; the title bar and the control bar keep the full width.
  - The panel's ↗ button leaves the player for the same place in the full library.
- **Reference shots** in `docs/superpowers/figma/4e/`: `sb_default.png` (848:1995), `sidebar_all.png` (all variants), `player_music.png` (4767:23726).
- **Memory `figma-is-the-spec`** applies. Standing ruling since 4b: no question round; choices not in a frame are marked *(my call)*.

## Scope

- The sidebar button in the player's title bar.
- The panel: an icon rail plus the library pages, narrow, beside the video or the music cover.
- A compact two-row page header for narrow widths, with a ↗ "open in library" button in the panel.
- The Figma's filled glyph for the active sidebar entry, in the rail and the library sidebar.
- The playing item marked in the library pages.

Out of scope:
- New page bodies. The panel shows the 4b–4d pages as they are; their grid and list already size by width.
- The mini player card that the video shows after ↗ (slice 6). ↗ uses today's mini bar.
- Context menus (slice 5).
- The roadmap's "before 4e" extraction of a shared grid page from `LibraryFolderPage` / `PlaylistsPage` / `RecentDisplay`. *(My call: skip it.)* The panel doesn't need to change those pages, so the extraction is a pure refactor with no 4e payoff. If the build finds it does have to touch all three, extract first.

## How it works

**One library, two places.** The player (`Player.qml`) and the library (`MainDisplay.qml`) are never alive together: `MainInterface`'s `viewLoader` swaps one for the other. So the panel shares the global `History` with the library rather than keeping its own:
- Opening the panel shows `History.viewPath`, which is where the user was in the library when playback started. (In the video, S01E05 was played from S01; the panel opens on S01.)
- Navigating in the panel pushes to the same `History`.
- ↗ just leaves the player. `MainDisplay` is rebuilt and loads `History.viewPath`, which is the panel's page.
- The 27 files that call `History` need no change.

**The page list** (`pageModel`: home, video, music, network, playlists, recent, discover, mlsettings) moves out of `MainDisplay` to one shared definition that both `MainDisplay` and the panel use. The panel also keeps `MainDisplay`'s other loader duties:
- the sort memory per path (`ModelSortSettingHandler` on `MainCtx.sort`);
- `History.update(["home"])` when the history is empty (VLC launched straight into a file).

## Title bar

- `Player.qml`'s `LocalTopbar` shows its existing `navigationVisibilty` button (`showNavigationToggle: true`; glyph `panel_left`, the Figma `sidebar-left`). It is checked while the panel is open.
- The panel starts closed each time the player opens *(my call)*. It isn't saved in settings.

## Panel layout

Figma 848:1995 at 1920; every size goes through `VLCStyle.dp(…, VLCStyle.scale)` like the earlier slices.

| Part | Figma |
|---|---|
| Whole panel | 427 wide, from the title bar's bottom to the control bar's top |
| Rail | 50 wide; icon wrappers 30×32 at x 10, first at y 8, 46 apart |
| Rail entries | Home, Videos, Music, Network, Playlists, Recent, + (Add item) |
| Page area | 377 wide, 20 padding left/right/top |
| Header row 1 (24 high) | back, forward (36 apart), crumbs from x 70, then "…" and ↗ (36 apart) at the right |
| Header row 2 (24 high, 20 below row 1) | "15 items" at the left; sort, view, search icons (36 apart) at the right |
| Divider | 17 below row 2, full width |
| Rows | 32 high, 10 apart, first 20 below the divider (4c's compact `HomeListRow`) |

- **Colours:** read from 848:1995's design context at build time. The rail is a slightly lighter grey than the page area in the render.
- **Opening:** the panel slides in from the left. The video area's left edge (the music cover's centring area in the audio player) follows the panel's right edge, so the video shrinks rather than being covered. The title bar and the control bar keep the full width.
  - If resizing the video surface every frame stutters, the slide may be dropped. In that case the panel appears at once *(builder's call)*.
- **Auto-hide:** while the panel is open, the player's controls don't auto-hide (`lockUnlockAutoHide(true)`). This is the same rule as the queue card.
- **Both players:** the panel works the same in the video player and the music player (the Figma instance is in Player - Music).

## Rail

- `SideNavigationPane` in its existing collapsed state (`delegateShowText: false`) *(my call)*.
  - It already has the six entries and the active-page logic (`History.match(History.viewPath, uri)`).
  - Clicking an entry pushes its root, the same as in the library.
  - The click handling (`onItemClicked`: push, or scroll to the top when the page is already loaded) and the Add item `FigmaMenu` currently live in `MainDisplay` around the pane, at about lines 596–660. They move into the shared piece with `pageModel`, so they aren't copied. The collapsed state's expandable-item popup (`NavigationBarContextMenu`) isn't needed: no entry expands.
- **Active entry: the Figma's filled glyph** (user call 2026-10-19: "use the figma"). See "Active sidebar entry" below. The same rule applies to the full library sidebar.

## Active sidebar entry (rail and library sidebar)

The Figma draws the active entry the same way in both places (rail variants of 848:1996; library sidebar in Home 6261:15078 and Videos grid 970:4028):

| Where the user is | Glyph | Label (library sidebar only) |
|---|---|---|
| The section's root page (Home, Videos, Music…) | **filled**, accent `#D37918` | primary (white) |
| Deeper in the section (Videos ▸ Shows …) | **filled**, the inactive grey | as inactive |
| Another section | outline, inactive grey (as now) | as now |

- **Six new filled glyphs:** home, videos, music, network, playlists and recent. Export them from the Figma (the active rail instances in the variants: home 1106:5633, videos 848:1997, music 858:5001, network 858:5294, playlists 858:5374; Recent has no active variant, so take its filled glyph from the icon set 42:356, or use the outline glyph if there is none, and note it). Append them to `VLCIcons` with the 4a pipeline.
- **Replaces 4a's rule** in `SideNavigationDelegate` (accent-coloured outline glyph when `highlighted || checked`).
- **"Root" means** `History.viewPath` equals the entry's own uri (`History.exactMatch`). "Deeper" means `History.match` but not an exact match.
- **Glyph check:** the Figma's Music entry is a folder with a note. The library sidebar's current Music glyph was a single note in the 4d shots. Use the Figma's outline and filled pair.
- **Add item** is never active.

## Compact header

`PageExt`'s header switches to the Figma two-row layout when the page is narrow *(my call: by width, below about `dp(600)`, not by a flag from the panel)*:
- Nothing has to be passed down through the nested loaders (`VideoDisplay` → `LibraryFolderPage` …).
- A narrow library window gets the same header.

What changes:
- **Row 1:** back, forward, crumbs (the existing "…" collapsing of leading crumbs), then "…" and ↗.
- **Row 2:** the count, then sort and view as now, then **search as an icon**. Clicking the icon swaps the count for the search field. Escape, or emptying the field and leaving it, swaps back *(my call)*.
- **↗ "Open in library"** shows only while the page is in the panel (`MainCtx.playerView`). Its action is the title bar's `leavePlayer()`: stop embedded video when there is no picture-in-picture, then `MainCtx.playerView = false`.
  - **The glyph** is new. Export it from the Figma icon set (appended to `VLCIcons`, using the 4a pipeline: `flatten-figma-svg.py`, then `makeIconFont.py`).

## Playing item

User call 2026-10-19, from the video at 11:48: the panel shows what's playing.
- **What it looks like:** the row or card of the media that's playing has an accent `#D37918` title and a play glyph over its thumbnail. The glyph is the queue card's current-item `play` glyph in accent, centred on a darkened thumbnail.
- **Where it applies:** the media rows and cards on Videos / Songs folder levels (`LibraryFolderPage`), Recent, and Home's Continue Watching / Listen Again.
  - It shows in the full library too, since these are the same pages *(my call: there's no reason to hide it there)*.
  - Folders, playlists and artists are not marked.
- **How to tell it's playing:** the item's MRL equals `Player.url`. The pages' models already expose `mrl` / `url`, so there's no new C++.
- **Figma check:** the `media` row component (instances 6784:16226…) may have a playing variant. If it does, its values win over the video's.

## Behaviour

- **Activating an item** plays it as it does in the library (the pages' own handlers), and the player stays.
- **Keyboard:**
  - The title bar button is reachable as now. Down from the title bar goes into the panel when it is open.
  - Right from the panel's content goes to the video / controls.
  - Escape in the panel goes back (`History.previous()`, as the pages already do). At the history root it moves focus to the title bar button.
- **Fullscreen:** the button and the panel work the same.

## Known, not fixed (pre-existing)

- Escape on the player itself calls `History.previous()` (`Player.qml` `_onNavigationCancel`), so it silently moves the library's history. With the panel open this now shows up as a panel page change. Leave it unless it gets in the way in testing.

## Left to the builder

- The colours and fonts from 848:1995's design context.
- Where the shared `pageModel` lives (a singleton, or a component both files instantiate).
- The slide animation's duration (use `VLCStyle` durations) and whether it survives the video-resize check.
- The exact narrow threshold for the compact header.

## Verification

In the Xvfb harness (`vlc-xvfb.sh`, `DISPLAY=:77`, silent):
- Play S01E05 from Videos ▸ Shows ▸ The Clip ▸ S01 (the fixture for the Figma's The Wand), open the panel, and compare with `sb_default.png`.
- Use every rail entry; go back and forward; search; switch the view.
- ↗ lands on the same page in the library.
- The music player with the panel open, compared with `player_music.png`.
- No QML errors in the log; the Qt tests pass.
