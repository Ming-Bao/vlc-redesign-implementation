# VLC Redesign: Dialogs (slice 8) Design

**Source of truth:** Figma "VLC Redesign (Community)", file key `dSoAm0gN9ZterHSssJU9FN`, plus `redesign source.mp4`.

| Dialog | Frames | Size | Video |
|---|---|---|---|
| Open Network Stream | `6216:13614` | 1048 × 631 | 12:24–13:24 |
| New Playlist | `6259:14954` | 713 × 589 | 13:24 |
| Add Subtitles | `1911:7545` (folder, Save off), `3336:11929` (folder, Save on), `1919:8707` (file), `1919:9278` (file, OpenSubtitles) | 1048 × 800 | 5:54–6:27 |
| Keyboard Shortcuts | `2437:14832` | 1048 × 800 | 15:54–16:00 |
| Customize Player | `2107:5604`, `2160:6137`, `2160:6564`, `2160:7005`, `2160:7437`, `2160:7869`, `6587:19923`, `2160:8301`, `2160:8732` | card 1048 × 655 over the player | 19:12–19:30 |

Components: `target` `1959:5325`, `origin` `1963:5465`, `subtitle multiple` `1915:8397`, `subtitle one` `1919:9121`.

- **Reference shots:** `docs/superpowers/figma/8/<dialog>-<node>.png`.
- **Memory `figma-is-the-spec`** applies. The user skipped the question round again ("plan the next slice"), so every choice no frame or video shows is marked *(my call)*.
- **What the video settles:**
  - Add Subtitles has the three targets and works with To This Folder + From OpenSubtitles, which no frame shows.
  - Hovering a paired subtitle shows a swap glyph.
  - A saved stream opens straight away as a browsable page, "Network ▸ Index", with its channels listed.

## Scope

Build the five dialogs and route every existing entry point to them.

Out of scope:
- **The legacy Open Media dialog** stays for its File, Disc and Capture tabs and for Stream and Convert. Only `openNetDialog` moves.
- **The legacy add-to-playlist dialog** (`PlaylistsDialog`) stays. It has no frame.
- **The light theme** (slice 10) and **the first-run wizard** (slice 9).

## Shared window

- **`DialogCard.qml`** in `dialogs/dialogs/qml/`, used by the four form dialogs. It has the title bar, the footer and the shadow. It extracts the window code from `SettingsWindow.qml` (frameless `Window`, `transientParent: MainCtx.intfMainWindow`, shadow margin, placement capped to 90 % of the screen, `startSystemMove` on the title bar), which then uses it too.
- **The four form dialogs are separate modal windows** (`Qt.ApplicationModal`), like Settings. *(my call: the frames are bigger than VLC's default 600 × 420 window. The video shows them inside a maximized window, which a separate window looks the same as.)*
- **Customize Player is not a window.** It must share a drag surface with the player's bars, so it is an overlay item in the main window.
- **Values (Figma px × `VLCStyle.scale`):**
  - card `#191919` at 95 %, radius 14, shadow 0 8 15 `#00000075` (Add Subtitles and Customize Player: `#0E0E0E` at 95 %);
  - title bar 50 high, `#090909`, padding 9, title left-padded 10, Inter 14 `#8F8F8F`, × in a 32 square;
  - footer 72 high, padding 20, buttons 100 × 32, radius 6;
  - Cancel `#1B1B1B`, Inter SemiBold 14 `#8F8F8F`;
  - Save `#371F06`, text `#D37918`, at 50 % opacity when off.
  - Save reads the accent through `theme.accent`, like slice 7.
- **Text fields:** `#090909`, radius 6, border 2 `#191919`, padding 8/18/8/12, Inter 14, placeholder `#404040`.
- **Section heads:** Inter 16 `#C6C6C6`, help Inter 14 `#6B6B6B`, gap 5. Dividers 1 `#222222`.
- **Escape and × act as Cancel.** Enter activates Save when it is on, except in a multi-line field.

## Open Network Stream

Opened by `DialogsProvider::openNetDialog()`, which now emits a signal for the QML dialog. All its callers keep working: Ctrl+N, both menus, Network's Add Network Stream.

| Part | Figma |
|---|---|
| Body | padding 22/20, gap 20 |
| "Network URL" / "You can enter multiple links to load." | section head |
| URL box | 194 high, multi-line, placeholder `e.g., https://www.example.com/stream.avi` |
| "Playlist Name" + "(optional)" in `#6B6B6B` / "The playlist will be saved and displayed with this title." | section head |
| Name field | 37 high, placeholder `e.g., Favorite TV Channels` |

**Behaviour:**
- One URL per line. Blank lines are ignored. A line without `://` gets `http://` in front. *(my call)*
- Save is on when at least one line is non-blank.
- **With a name:** the links are saved, the dialog closes, and the Network page opens on the saved entry, as the video does at 13:18. *(video)*
- **Without a name:** nothing is saved. The links are queued and the first plays, as Ctrl+N does today. The button reads **Open** instead of Save. *(my call: the field says "optional" and a Save that saves nothing would lie. **Flagged for review.**)*
- **Storage:** `<userdata>/network-playlists/<name>.m3u8`, a plain `#EXTM3U` file with `#PLAYLIST:<name>` and one line per URL. The name is sanitised for the file system. A name that exists overwrites after a confirmation. *(my call: no media library needed, so it works in builds without one, and VLC's own browse tree can open it.)*
- **On the Network page:** `NetworkHomeDisplay` adds one tile per saved file, after Radio, titled by name. Activating it opens `folderTree` on the single URL only when the file has one link and its path ends in `.m3u`, `.pls` or `.xspf`, so its channels are the page; otherwise on the saved file, which lists each link as a row that plays. A plain media URL, or an HLS `.m3u8`, has no rows to browse and would open an empty page, so a playlist saved under `.m3u8` also opens as one row. The tile's menu has Delete. *(my call, changed after the final review)*

## New Playlist

Opened by `DialogsProvider::newPlaylist()`, which keeps its name and all callers but stops using `QInputDialog`. The `bool` return goes: `LibraryAddMenu` reacts to a new `playlistCreated()` signal instead.

| Part | Figma |
|---|---|
| "Playlist Details" / "The playlist will be saved and displayed with this title and thumbnail." | section head |
| Name field | 541 × 37, placeholder `e.g., Favorite Videos` |
| Cover well | 112 square, `#090909`, radius 6, border 2 `#191919`; a 30 square `#161616` radius 5 button with a plus |
| "Select Files" / "These files will be added to the playlist." | section head |
| Drop box | 673 × 186, `#090909`, radius 6, dashed border 2 `#2D2D2D`; "Drag files into the box or click here to select files." `#404040`; 84 × 30 `#161616` radius 5 plus button |

**Behaviour:**
- Save is on when the name is non-blank. Files are optional. *(my call: the Playlists page already allows an empty playlist.)*
- The cover well opens an image picker and shows the picked image, cropped to fill. *(video 13:24)*
- The drop box takes dropped files and the picker's choice. Once it holds files it lists them in rows, each with a remove ×, and keeps the + button. *(my call: no frame shows this state.)* Dropped folders add their media files, not recursively. *(my call)*
- Save creates the playlist through `MLPlaylistListModel::create`, resolving each file with `vlc_ml_get_media_by_mrl`, or `vlc_ml_new_external_media` when it is not in the library.
- **Custom cover:** the media library has no playlist thumbnail, so the image is copied to `<userdata>/playlist-covers/<id>.<ext>`. `MLPlaylistListModel::getCover` prefers that file. Deleting the playlist deletes it. *(my call)*

## Keyboard Shortcuts

Opened by a new `DialogsProvider.showHotkeysDialog()`, from the "…" menu and the Settings Controls page's Edit Keyboard Shortcuts. This retires both `prefsDialog(SPrefsHotkeys)` paths. The legacy panel stays reachable through All settings.

| Part | Figma |
|---|---|
| Top | 96 high: title row, then search box 820 × 34 `#151515` radius 6 (placeholder `Search Keyboard Shortcuts...`) and field dropdown 200 × 34 |
| Field dropdown | All Fields, Actions, Hotkeys, Global Hotkeys (the legacy search's four) |
| Header | Action, Hotkey, Global Hotkey; Inter 14 `#6B6B6B`; divider below |
| Section head | Inter 16 `#969696` |
| Row | 33 high, 14 apart; label Inter 14 `#C6C6C6` |
| Key cell | 270 × 33, `#090909`, radius 6; key text **DM Mono** 14 `#C6C6C6`, centred; pencil at the right |

**Rows:**
- Listed from `HotkeysData.js`: sections → `{ option, label? }`. The Figma's two sections and nine labels are verbatim; the frame clips the rest. Every other `key-*` option goes into a section *(my call, table below)* and uses VLC's own text.
- `check-settings-options.py` also checks this file: every `key-*` option appears exactly once.

| Section | Options |
|---|---|
| Basic | toggle-fullscreen "Toggle fullscreen", leave-fullscreen "Exit fullscreen / close dialog", position "Show playback position and time", intf-show "Show interface controls in fullscreen", quit, intf-boss, intf-popup-menu, snapshot, record, clear-playlist |
| Playback | play-pause "Play / pause", stop "Stop playback", next "Next track", prev "Previous track", program-sid-next "Next program / Service ID", program-sid-prev, pause, play, faster, slower, rate-*, frame-*, random, loop |
| Seeking | jump±extrashort/short/medium/long, chapter-*, title-*, disc-menu, nav-* |
| Audio | vol-*, audio-track, audiodevice-cycle, audiodelay-* |
| Subtitles | subtitle-*, subdelay-*, subsync-*, subpos-* |
| Video | aspect-ratio, crop*, uncrop-*, toggle-autoscale, incr/decr-scalefactor, deinterlace*, zoom*, unzoom, wallpaper, projection-toggle, viewpoint-* |
| Bookmarks | set-bookmark*, play-bookmark* |

**Behaviour:**
- Clicking a cell or its pencil captures: the cell shows "Press a key…" and the next key combination fills it. *(my call: no frame)* Every key can be bound, including Escape, as the frame's `esc` row needs. Clicking elsewhere cancels capture.
- The Delete key clears a focused cell when it is not capturing. The pencil's tooltip says so. *(my call, as the legacy dialog)*
- Capture replaces the option's whole value, so a row with two default keys ends up with one. *(my call: no frame shows two keys.)* Existing multi-key values display joined by `, `.
- **A key another action already has** asks through `DialogCard.ask`: "%1 is already used by %2. Reassign it?" Yes removes it from the other row.
- Global cells work the same on `global-key-*`. On Wayland global hotkeys don't fire; that is VLC's existing behaviour.
- Save is on once something changed and writes every changed option with `config_PutPsz`, then `config_SaveConfigFile`. Cancel discards.
- **Changes apply on the next launch**, because `libvlc_InternalActionsInit` builds the key map once. A line left of Save says "Changes apply the next time VLC starts." *(my call: a core reload is out of scope.)*
- Key text uses `vlc_keycode2str` / `VLCKeyToString`, and capture uses `qtEventToVLCKey`, as the legacy dialog does.
- **Copy:** the frame shows `F`, `esc`, `Space`. VLC's names are used as they come, except `Esc` → `esc`. *(my call)*
- **DM Mono** is bundled in `assets.qrc` (OFL), Regular only.

## Add Subtitles

Opened by a new `DialogsProvider.showAddSubtitles(QVariantMap context)`:

| Entry point | Opens on |
|---|---|
| File menu ▸ Add Subtitle Tracks (`MLContextMenu`; replaces `pickFile`) | To This File, that media |
| Folder menu ▸ Edit Subtitle Tracks (Figma `2139:8935`; slice 5 omitted it) | To This Folder, that folder |
| Playlist menu ▸ Add Subtitle Tracks (Figma `2459:9389`; slice 5 omitted it) | To This Playlist, that playlist |
| Player's Tracks panel Add (`TracksListPage`, `TracksPanel`; both call `loadSubtitlesFile`) | To This File, the playing media |

The media-menu `Subtitle ▸ Add Subtitle File…` in `menus.cpp` also moves. Add Audio Tracks keeps `pickFile`: no frame replaces it.

**Top row** (under the title; all 34 high, radius 6, `#151515`, gap 10): target dropdown 200, origin dropdown 200, then:
- **From Computer:** the location, full width: folder glyph + `Videos / Shows / The Wand / S01`. Clicking it picks another folder. *(my call)*
- **From OpenSubtitles:** search field + language dropdown 200.
- **From Link ...:** a URL field with a placeholder. To This File only: choosing a Folder or Playlist target falls back to From Computer. *(my call)*

Dropdown lists are 209 wide, `#191919`, radius 6, options 48 high with a tick on the current one (FigmaMenu look).

**Rows:**
- **To This File** (`subtitle one`): 36 high, radius 6, padding 8, gap 16; document glyph, name Inter 14 `#969696`. Clicking toggles selection: `#090909` and an accent tick. Multi-select. A file matching the media is ticked to start with. *(my call)*
- **To This Folder / Playlist:** media glyph + name on the left, a dashed line, then the paired subtitle (`subtitle multiple`). Hovering the subtitle shows `#090909` and the swap glyph. Clicking opens a menu of all candidate files plus **None**. *(video for the glyph; the menu is my call.)*
- A media with no match shows **None** in `#404040`. *(my call)*

**Matching** is one pure function, `matchSubtitles(mediaNames, subtitleNames) -> QVector<int>`:
1. normalise both stems: lower-case, keep letters and digits (`thewand_s01e01.srt` matches `The_Wand_S01E01.mp4`, as in the video);
2. equal stems win;
3. then a subtitle stem that starts with the media stem (`The_Wand_S01E01_English`);
4. then the same `SxxEyy` token (`s1e1` included);
5. each subtitle is used once; otherwise `-1`.

**Save** is on when at least one pairing is set, and it attaches each with `MediaLib::addExternalTrack`. Media not in the library (a playing stream or unindexed file) goes through `PlayerController::AddAssociatedMedia`. When the target includes the playing media, it is also added to the running player, so it appears in the Tracks panel at once, as the video does at 6:27. *(video)*

**Media lists:** folder = the library's media directly in that folder (`vlc_ml_list_folder_media`), sorted by name. Playlist = the playlist's media. Candidate subtitle files come from one directory scan with VLC's subtitle extensions, in the folder of the first media or the one chosen. *(my call)*

### From OpenSubtitles

**This part needs the user's decision before it is built; see Open Decisions.** It is the slice's last task, so the rest is unaffected.

- `api.opensubtitles.com/api/v1`: `GET /subtitles?query&languages`, `POST /download`, header `Api-Key`. Verify these against the official docs when building: only third-party pages could be read while writing this.
- The legacy XML-RPC API, which VLSub 0.11.1 uses, is reported shut down since January 2026 by one third-party source. Don't reuse it, and check VLSub separately.
- `Qt6Network` is a new dependency, and the key is a new string option `qt-opensubtitles-key`, on a new Settings ▸ Network row. An empty key shows "Add an OpenSubtitles API key in Settings ▸ Network" with a button that opens it, instead of results.
- To This Folder runs one search, then pairs results with `matchSubtitles`.
- Save downloads each chosen file beside its media (`<stem>.<lang>.srt`), or to `<userdata>/subtitles/` when the folder isn't writable, then attaches it.
- A failed search shows its error in the row area. A failed download skips that file and reports the count. Nothing partial is attached.

## Customize Player

The frames are a storyboard of one editing session, not separate states:
1. `2107:5604` opens with every bar item dashed, seekbar inline, Save off.
2. `2160:6137` the seekbar goes to its own row, Save on.
3. `2160:6564` prev/play/next go to the centre.
4. `2160:7005` the title goes from the title bar to the bottom left.
5. `2160:7437` "…", sidebar and folder go down too.
6. `2160:7869` fullscreen goes down.
7. `6587:19923` Favorite comes from the palette, which reflows without it.
8. `2160:8301`, `2160:8732` after Save, with and without the sidebar open.

**Opening:** `showToolbarEditorDialog()` (same callers) sets `MainCtx.customizingPlayer`. The player page shows, navigated to if needed and restored on close. With no media it edits with placeholder text, "Title" and `00:00`. *(my call)* Bars stay shown (auto-hide off). Everything but the overlay and the bars ignores input.

**The zones** (dashed `#6B6B6B` 1, dash 4/4, on every item and every zone):

| Zone | Model | Starts with |
|---|---|---|
| Title bar left, centre, right | new `PlayerControlbarModel::Topbar` left/center/right | "…", library sidebar, folder ▸ title ▸ minimize, maximize, fullscreen, close |
| Seek row | new `PlayerControlbarModel::SeekRow` | empty |
| Bottom left, centre, right | `Videoplayer` (or `Audioplayer`, whichever the player shows) | prev, play, next ▸ *(seekbar inline)* ▸ volume, visualizer, subtitles, settings, queue |

- The cone logo is fixed. *(frames: not dashed)*
- **The seekbar** (time, slider, duration) is one mandatory item, in the Seek row or inline in the bottom centre. Dragging it to the palette or elsewhere bounces back. *(my call: it isn't in the palette.)* Dropping it inline moves any centre items to the end of the left zone. `ControlBar._textPosition` follows `SeekRow`: non-empty → above, else `Inline`. Old saved profiles therefore need no migration.
- **Only the player's title bar** is model-driven. The library's `LocalTopbar` stays fixed. *(my call: it's "Customize Player".)*

**The palette** (card `#0E0E0E` at 95 %, 1048 × 655; title bar + hint row 94 high; hint `Drag items around and out of the box below to re-order them. Drag items into the box to remove them from the player.` `#6B6B6B`; body padding 34, 9 columns of 86, column gap 24, row gap 16–20; 30 × 32 glyph dashed + label):

Items in Figma order, showing only what isn't placed. Spacer and Divider always show, and may be placed many times. An item dragged to the box leaves the bar and reappears in order.

| Label | Control | | Label | Control |
|---|---|---|---|---|
| Spacer | `WIDGET_SPACER` | | Right Sidebar | new: toggles the player panel |
| Divider | new, 1 × 24 `#222222` | | Quit VLC | `QUIT_BUTTON` |
| Playback Speed | `PLAYBACK_SPEED_BUTTON` | | VLC Settings | new: `prefsDialog()` |
| Forward 10s, Backward 10s | new: `jumpBySeconds(±10)` | | Go Home | new: `History.push(["mc","home"])` |
| Forward 15s, Backward 15s | `SKIP_FW_BUTTON`, `SKIP_BACK_BUTTON` | | Thumbnail | new: media artwork |
| Stop | `STOP_BUTTON` | | File, Artist, Folder, Playlist Name | new: one text widget each |
| Repeat | `LOOP_BUTTON` | | Properties | `INFO_BUTTON` |
| Shuffle | `RANDOM_BUTTON` | | Replay | new: seek to 0, play |
| Record | `RECORD_BUTTON` | | Chapters | new: panel's Chapters page |
| Snapshot | `SNAPSHOT_BUTTON` | | Favorite | new: toggles library favorite |
| Picture in Picture | `PLAYER_SWITCH_BUTTON` | | Bookmark | `BOOKMARK_BUTTON` |
| Zoom | new: `Player.zoom` menu | | Bookmarks | new: panel's Bookmarks page |
| HDR | **not built** | | Playlists | new: Playlists page |

- **HDR** is dropped: VLC has no HDR control (slice 3c departed the same way).
- **Picture in Picture** leaves the player for the mini card, where the video keeps playing. *(my call)*
- **New control ids** take `ControlListModel`'s `RESERVED_0X2B…` slots and the free values after them, so saved ints stay valid.
- **Title-bar-only widgets** are new controls too: `MORE_MENU`, `LIBRARY_PANEL`, `FOLDER_CHIP`, `MEDIA_TITLE`, `WINDOW_MINIMIZE`, `WINDOW_MAXIMIZE`, `WINDOW_CLOSE`. They can go in any zone, as the storyboard shows, and removed ones appear in the palette after the Figma's items. *(my call: the frames only show them placed.)*
- **Dragging:** reuse `EditorDNDView` and `EditorDNDDelegate`.

**Saving:** Save is on when `ControlbarProfile.dirty`. Save → `controlbarProfileModel.save()`. Cancel, ×, Escape → `reload()`, as `ToolbarEditorDialog` does. Editing applies to the selected profile. Live previews are the bars themselves.

**Profiles:** Profile ▸ New asks for a name (`getTextDialog`), clones the current profile, selects it and opens Customize Player. *(my call: the Figma's Movies, Shows and so on are not built; slice 5 kept VLC's profile names.)*

**Small windows:** the card caps to the window minus the bars, and the palette scrolls.

**Removed:** `ToolbarEditorDialog.qml`, `ToolbarEditor.qml`, `ToolbarEditorButtonList.qml`, `EditorTabButton.qml`, `EditorDummyButton.qml`, and the `Miniplayer` tab with them (slice 6's card has no controls to edit). `g_mainDisplay.positionSliderY` fallbacks go, as the handoff asks.

## Open Decisions

For the user. Each default below is what the plan builds if they don't answer.

1. **From OpenSubtitles.** It needs a registered API key, which an open-source build can't embed secretly, and a new `Qt6Network` dependency. The default is to **build it last, with users pasting their own key in Settings**. The alternative is to hide the entry and leave it to VLSub.
2. **Open Network Stream without a name.** The default is that the button reads **Open** and plays without saving.

## Testing

- **C++ (`tests/`):** `matchSubtitles` table test; `HotkeyModel` (load, reassign, clear, dirty); saved stream file round trip; `ControlListModel` id stability (existing ints unchanged).
- **QML (`tst_*.qml`):** `HotkeysData.js` (every section has rows; search by field); palette filtering.
- **Script:** `check-settings-options.py` covers `HotkeysData.js`.
- **Harness:** a `drag:X1,Y1,X2,Y2` step in `wl-drive.py`. The same step lets slice 7's unverified window drag finally be checked. Shots are compared with the Figma frames for each dialog.
