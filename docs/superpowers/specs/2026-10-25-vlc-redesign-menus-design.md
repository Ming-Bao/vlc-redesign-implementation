# VLC Redesign: Menus (slice 5) Design

**Source of truth:** Figma "VLC Redesign (Community)", file key `dSoAm0gN9ZterHSssJU9FN`.
- **Frames:**
  - `menu 6062:13354`: the title bar's "…" menu.
  - `Profiles 6648:20666`: the same menu with its Profile submenu open (and the hover look on "Profile (Movies)").
  - `right-click menu 6065:13616`: right-click on the player.
  - `file context menu 2404:13340`, `folder context menu 2139:8935`, `playlist context menu 2459:9389`: right-click in the library.
- **Reference shots** in `docs/superpowers/figma/5/`: `main_menu.png`, `profiles.png`, `right_click.png`, `file_ctx.png`, `folder_ctx.png`, `playlist_ctx.png`.
- **Memory `figma-is-the-spec`** applies. The user skipped the question round ("go ahead and plan it"); choices not in a frame are marked *(my call)*.

## Scope

- One look for every menu VLC pops up: the Figma card, rows, two-tone icons, shortcuts, chevrons, checks and dividers.
- The "…" menu's entries and its Profile submenu.
- The player right-click menu's entries.
- The library's file, folder and playlist menus: their entries and the actions behind the new ones.

Out of scope:
- The QML `FigmaMenu` (4a's sort, view, header "…", Add item and Home folder menus). It already draws this look; it only gets the icon column if a task needs it.
- The light theme (slice 10). The native menu style is dark only. *(my call, with a `ponytail:` note: read the palette's lightness when slice 10 lands.)*
- The dialogs the menus open (Keyboard Shortcuts, Customize Player, Add subtitles and so on are slice 7/8). Entries open today's dialogs.
- The menus with no Figma frame (network browse, queue, bookmarks, programs, renderers, sort). They take the new look and keep their entries.

## How it works

**Two kinds of menus exist today.**
- *Native:* `QMenu`s built in C++ (`menus/menus.cpp`, `menus/qml_menu_wrapper.cpp`, `menus/custom_menus.cpp`). The QML ML menus are native too: `MLContextMenu` → `NativeMenu` → `StringListMenu` turns a list of strings into a `QMenu`.
- *QML:* `widgets/qml/FigmaMenu.qml` (slice 4a).

**Restyle, don't port.** One `QProxyStyle` subclass draws every `QMenu` the Figma way. It is installed on the `QApplication` at start, wrapping whatever style is chosen, including the user's saved `MainWindow/QtStyle` and the simple-preferences style switch. *(my call)*
- **Why not port to QML:** the right-click menu's Playback/Video/Audio/Subtitle submenus are built at popup time from VLC variables (tracks, aspect ratio, deinterlace, chapters…), with radio groups and dynamic refresh. Porting them to QML is a large rewrite for no visual gain.
- **What a native menu gives that a QML popup doesn't:** it can extend past the window edge and over fullscreen video.
- **Coverage:** one style covers every menu, including the ones in dialogs.

**The style** (`style/menustyle.{hpp,cpp}`; the name is the builder's):

| Part | Figma (all in logical px, × the interface scale factor) |
|---|---|
| Card | `rgba(25,25,25,0.95)`, radius 10, padding 4 |
| Shadow | 0 8 15 `rgba(0,0,0,0.46)` (as `FigmaMenu`), drawn inside a transparent margin |
| Row | 48 high, 14 left/right padding, 2 top/bottom, 10 between icon, label and right column; radius 6 |
| Hover / keyboard highlight | `#1F1F1F` (as `FigmaMenu`; the Profiles frame shows it on "Profile (Movies)") |
| Label | Inter 14, `#8F8F8F`; disabled 40 % opacity (as `FigmaMenu`) |
| Shortcut | Inter 14, `#6B6B6B`, right-aligned, written "Ctrl + O" (spaces around `+`) |
| Submenu chevron | 24 px chevron-right at the row's right |
| Check (checkable and radio items) | the accent `#D37918` checkmark in the icon slot at the left, label after it (Profiles frame: "✓ Movies") |
| Divider | 1 px `#222222`, full card width less the padding, no extra vertical space |
| Icon | 24 px at the left, before the label; a row without an icon keeps no gap *(my call)* in menus where no row has one, and keeps the 24 px slot when any row has one so labels line up |
| Width | at least 265; grows with content (the "…" menu is 375 in Figma, the right-click menu 292) |
| Mnemonics | never underlined (Figma labels have none); `&` keys still work |

- **Translucency:** the card's rounded corners and shadow need a translucent window. The style's `polish(QWidget*)` sets `Qt::WA_TranslucentBackground` and `Qt::FramelessWindowHint | Qt::NoDropShadowWindowHint` on each `QMenu`.
- **Shadow margin:** popup positions are shifted by the shadow margin so the *card*, not the window, lands at the requested point.
- **Xvfb can't check this:** it has no compositor, so translucent corners show black there. Visual checks run on the Wayland driver (`wl-drive.py`).

**Icons.** The Figma menu icons are two-tone: strokes in `#AB6314` (accent, dim) and `#8F8F8F`. A one-colour glyph from `VLCIcons.ttf` can't draw that.
- Each icon is downloaded from the frames' design context as an SVG, unchanged, into `pixmaps/redesign/menu/` and listed in `assets.qrc`, `Makefile.am` and `meson.build`.
- Actions take `QIcon(":/redesign/menu/<name>.svg")`; Qt's SVG icon engine keeps both colours.
- They replace the old `:/menu/*.svg` / `ColorizedSvgIcon` icons on the entries listed below. Entries the Figma doesn't show get no icon.
- On hover the icon stays as is (no frame shows a hovered icon).

## The "…" menu (`VLCMenuBar::MainMenu`, frames 6062:13354 / 6648:20666)

In this order, with the Figma's shortcuts:

1. Open File(s) `Ctrl + O`
2. Open Folder `Ctrl + F`
3. Open Network Stream `Ctrl + N`
4. Open Disc `Ctrl + D`
5. Open Capture Device `Ctrl + C`
6. Convert `Ctrl + R`
7. Open Recent ▸ (today's `RecentMenu`)
8. divider
9. Profile (*name*) ▸
10. Keyboard Shortcuts ›
11. Customize Player ›
12. Settings `Ctrl + P`
13. About VLC `Shift + F1`

Changes from today:
- **Labels:** the "…" endings go, to match the Figma.
- **New entries:**
  - **Profile ▸** (below).
  - **Keyboard Shortcuts:** opens Preferences on the hotkeys section. *(my call: the Figma dialog is slice 8.)* If the preferences dialog can't open on a section, it opens Preferences.
- **Chevrons:** Keyboard Shortcuts and Customize Player have a chevron in the Figma but open dialogs. *(my call: draw it anyway, as a plain glyph on the action, so the row matches the frame.)*
- **Quit is removed.** The Figma has none; Ctrl+Q, the window's close button and the right-click menu still quit. *(my call)*
- **More ▸ stays as the last entry, below a divider.** It isn't in the Figma, but it is the only way to reach Discover (4a) and the Media/Playback/Audio/Video/Subtitle/Tools/View/Help menus from the library. This keeps the standing rule that features with no Figma place stay reachable. *(my call)*

**Profile submenu (6648:20666).** VLC's "profiles" are the control-bar layouts in Customize Player (`ControlbarProfileModel`: Default, Minimalist, One-liner, Simplest, Classic, plus the user's). *(my call: the Figma's Movies/Shows/Music/Work are placeholder names for these.)*
- The parent row's label is "Profile (*selected profile's name*)".
- The submenu lists every profile with the checkmark on the selected one, and picking one sets `selectedProfile`.
- Then a divider and "+ New", which opens Customize Player, where profiles are created. *(my call: no inline naming prompt.)*

## Player right-click menu (`VLCMenuBar::PopupMenu`, frame 6065:13616)

This one builder serves right-click on the video, the audio player's context menu (`QmlAudioContextMenu`) and the `intf-popupmenu` hotkey.

1. Play / Pause `Space` (Pause while playing, as today)
2. Stop `S`
3. Previous Item `P`
4. Next Item `N`
5. Record `R`
6. divider
7. Hide UI `Ctrl + H`: VLC's Minimal View toggle, checkable *(my call: the Figma writes Ctrl + \, but the label shows the real binding)*
8. divider
9. Playback ▸ (`NavigMenu`, with the speed and jump entries from `PopupMenuControlEntries` folded in)
10. Video ▸ (`VideoMenu`, plus the Fullscreen toggle that used to sit at the top level)
11. Audio ▸ (`AudioMenu`)
12. Subtitle ▸ (`SubtitleMenu`)
13. divider
14. More Settings ▸ (`ToolsMenu` then `ViewMenu`, divided)
15. Playlist ▸: Show/hide the queue, Shuffle, Repeat, Save play queue to file, Clear the queue *(my call; whatever of these the playlist controller already exposes)*
16. Open Media ▸ (today's `PopupMenuStaticEntries` open list)
17. Quit VLC `Ctrl + Q`

- **Shortcut labels show the binding VLC actually has.** Where VLC's default hotkey differs from the Figma's letter, VLC's wins: the shortcut column must not lie. The plan lists each one it changes.
- **The dialog-provider build** (`b_isDialogProvider`, the skins interface) keeps today's extra Interface and Help entries.

## Library menus

**Native menus get icons and dividers.** `StringListMenu::popup` accepts, alongside plain strings, maps `{ text, icon, separator, checked, enabled, shortcut }`. `NativeMenu` passes them through from its `actions` entries (new optional keys `icon`, `separator`, `checked`, `enabled`). Plain strings still work for existing callers.

**File menu (frame 2404:13340): `MLContextMenu` on media items** (Home rows and cards, Videos/Music folder pages, Recent, artist/album/genre track lists):

| Figma entry | Action |
|---|---|
| Play | `addAndPlay` (as today) |
| Mark as Watched | `setItemPlayed(true)`; reads "Mark as Unwatched" when already watched *(my call)* |
| Favorite | add to favourites; reads "Remove from Favorites" when it is one *(my call)* |
| Stream | `DialogsProvider.streamingDialog([mrl], true)` (new: a QML-invokable taking the media's URL) |
| Convert | `streamingDialog([mrl], false)` |
| Add to Queue | `addToPlaylist` (today's "Enqueue") |
| Add to Playlist | `playlistsDialog` (as today) |
| Show in File Explorer | open containing folder (as today), local files only |
| Go to Source | the item's folder in the library: the 4c `LibraryFolderPage` level that holds it, or for a file outside the library folders, the file browser on its folder *(my call)* |
| Add Subtitle Tracks | file dialog (subtitle filters) → `vlc_ml_media_add_external_mrl(…, VLC_ML_FILE_TYPE_SUBTITLE)` |
| Add Audio Tracks | file dialog (audio filters) → `…VLC_ML_FILE_TYPE_SOUNDTRACK` |
| Properties & Metadata | `mediaInfoDialog` (today's "Media Information") |

- **Attached tracks must play.** Today the Qt library's playback never adds a media's external files to the input item, so "Add Subtitle Tracks" would do nothing visible. The media library module's input-item path (where an ML media becomes an `input_item_t`) adds each `VLC_ML_FILE_TYPE_SUBTITLE` / `…SOUNDTRACK` file of the media as an input slave. Fixing it at the module serves every interface.
- **Entries without a Figma place stay, below a divider** *(my call)*: Play as audio, Play as album, Enqueue as album, Add to an audio-/video-only playlist, Information (the expand panel), Delete (streams), Delete File From System. Their `visible` rules are unchanged.
- **Multiple selection:** entries that only make sense for one item hide when several are selected, as today's `visible` rules do. New single-item entries follow suit: Stream, Convert, Show in File Explorer, Go to Source, Add Subtitle/Audio Tracks, Properties.

**Folder menu (frame 2139:8935)**: library folders, i.e. Home's Frequently Visited Folders (today a `FigmaMenu`) and the folder tiles and rows of `LibraryFolderPage`.

| Figma entry | Action |
|---|---|
| Add File | file dialog opening in this folder; the picked files join the queue *(my call: VLC 3's playlist "Add File…")* |
| Add Folder | folder dialog opening in this folder; the folder joins the queue *(my call)* |
| Edit Subtitle Tracks, Edit Audio Tracks | **not shown**: VLC has no per-folder track settings *(my call; ledger)* |
| Resync | `vlc_ml_reload_folder(mrl)`: rescan this folder *(my call: "resync" = re-index)* |
| Info | **not shown**: no folder information dialog exists *(my call; ledger)* |

- 4d's "Play all videos" and "Add all videos to the queue" (the user's call, 2026-10-19) stay at the top, above Add File.
- Home's folder menu moves from `FigmaMenu` to this native menu, so all folder menus are the same menu *(my call)*.

**Playlist menu (frame 2459:9389): `PlaylistListContextMenu`** (Playlists page, Home's Frequently Visited Playlists):

| Figma entry | Action |
|---|---|
| Play | `addAndPlay` (today's "Add and play") |
| Favorite | `VLC_ML_PLAYLIST_SET_FAVORITE` toggle; "Remove from Favorites" when set *(my call)* |
| Shuffle | play the playlist, then shuffle the queue |
| Export Playlist | save dialog (`.m3u8`) → write `#EXTM3U` and the playlist's media MRLs in order *(my call: one format; VLC's own export only works on the play queue)* |
| Add to Queue | `addToPlaylist` (today's "Enqueue") |
| Add Subtitle Tracks, Add Audio Tracks | **not shown**: no meaning for a whole playlist *(my call; ledger)* |
| Properties & Metadata | **not shown**: no playlist information dialog exists *(my call; ledger)* |

- Rename and Delete (VLC's, not in the Figma) stay below a divider.

**`PlaylistMediaContextMenu`** (a playlist's own tracks) takes the file menu's entries where they apply and keeps its playlist-specific ones (remove from playlist, move). *(my call)*

## Verification

- Wayland driver shots (`wl-drive.py`, Alt-free; right-click needs a `rclick:X,Y` step, added if missing) of each Figma frame's menu next to its reference shot in `docs/superpowers/figma/5/`.
- The `-vv` log grep for QML errors, as in every slice.
- New logic gets a test:
  - the shortcut text formatter ("Ctrl+Shift+O" → "Ctrl + Shift + O", "Ctrl++" survives);
  - the M3U8 writer;
  - `StringListMenu`'s mixed string/map input.
- Manual checks:
  - a subtitle attached through "Add Subtitle Tracks" shows in the Subtitle track list the next time the media plays;
  - Resync starts a scan (the ML's discovery events in the log).

## Ledger

The plan file keeps a `## Ledger` of every departure from the frames. It starts with each *(my call)* above.
