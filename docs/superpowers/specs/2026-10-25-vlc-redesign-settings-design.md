# VLC Redesign: Settings window (slice 7) Design

**Source of truth:** Figma "VLC Redesign (Community)", file key `dSoAm0gN9ZterHSssJU9FN`.
- **19 frames named "Settings - *"** (1048 × 865), one per sidebar page, a few twice. The second copy scrolls further or opens Advanced Options:

| Page | Frames | Title-bar text |
|---|---|---|
| General | `999:5047`, `3046:9282` (Advanced Options open) | Global Settings |
| Interface | `3046:10057`, `3062:11379` (full) | Interface Settings |
| Privacy | `3062:11911` | Privacy Settings |
| Controls | `6536:14482` | Mouse, Keyboard & Remote Controls |
| Playback | `3062:12552`, `3072:13408` (full) | Playback Preferences |
| Video | `3073:14187`, `3073:15375` (full) | Video Defaults |
| Audio | `3073:15879`, `3180:17398` (Effects, EQ open) | Audio Defaults |
| Subtitles | `3180:17989`, `6536:13908` (full) | Subtitle Defaults |
| Library | `6542:15251` | Playlists, Folders & Files |
| Network | `6543:15649` | Network Connections & Security |
| Performance | `6571:15958` | Performance Settings |
| Recording | `6571:16429` | Recording, Casting & Streaming Out |
| Extensions | `6575:17137` | Add-ons & Scripts |

- **Reference shots** in `docs/superpowers/figma/7/`, one PNG per frame (`<page>-<node>.png`). The frames clip at 865 px, so the "full" frames list rows that the shots cut off. The row lists below come from the frames' layers, not the shots.
- **Memory `figma-is-the-spec`** applies. The user skipped the question round ("go look at the figma and start planning"). Every choice that no frame shows is marked *(my call)*.

## Scope

- A new Settings window that replaces the simple Preferences dialog as what "Settings" opens (Ctrl+P, the "…" menu entry, the Tracks and Playback panels' "Show Preferences" links).
- Its 13 pages, search, Advanced Options sections, and the row controls they use.

Out of scope:
- **The legacy Preferences dialog** (`dialogs/preferences/`) stays in the tree, unchanged. It is still opened by:
  - the hotkeys path (`DialogsProvider::prefsDialog(int)`: the "…" menu's Keyboard Shortcuts and the Controls page's Edit Keyboard Shortcuts), until slice 8 builds the Figma shortcuts dialog;
  - a new **All settings** row (see General). *(my call: VLC has about 1,600 options and the Figma shows about 150, so the expert tree must stay reachable.)*
- **The light theme** (slice 10). Dark values only, read through the existing `SettingsStyle` tokens, which already fall back to the theme in light mode.
- **The first-run wizard** (slice 9).

## Where it lives

- **A separate top-level QML `Window`**, loaded the way `ToolbarEditorDialog` is: a `Loader` in `dialogs/dialogs/qml/Dialogs.qml`, opened on a new `DialogsProvider` signal.
  - `DialogsProvider::prefsDialog()` (no argument) emits that signal instead of building `PrefsDialog`. `prefsDialog(int)` is unchanged.
  - The window is non-modal and single-instance. Opening it again raises it.
  - It opens on General the first time, then on the last page shown in this session. *(my call)*
- **Frameless**, drawn as the Figma card: `#0E0E0E` at 95 % opacity, radius 14, shadow 0 8 15 `#00000075`.
  - The top bar drags the window (`startSystemMove()`), and the edges resize it (`startSystemResize()`).
  - The default size is 1048 × 865 × `VLCStyle.scale`, capped to 90 % of the screen. The minimum is about 760 × 480. *(my call)*
  - Where the platform has no compositor, the window is square-cornered. That is acceptable.
  - Escape and × close it.
- **Changes apply immediately.** The Figma has no OK/Cancel. Each control writes its VLC config option on change. The config file is saved when the window closes (`config_SaveConfigFile`), and libvlc saves again at exit.
  - Options VLC reads only at start take effect on the next launch, as in the legacy dialog. No restart banner. *(my call)*

## Layout (Figma px × `VLCStyle.scale`)

| Part | Figma |
|---|---|
| Top bar | 50 high, `#090909`, padding 8 left, 14 right |
| Search box | 200 wide, `#151515`, radius 6, padding 5/8, gap 10; search glyph 24; placeholder "Search" Inter 14 `#404040` |
| Page title | left padding 32 from the search box, Inter 16 `#969696` |
| × | 32 square button, 24 glyph |
| Sidebar column | 216 wide, padding 8; card 200 wide, `rgba(25,25,25,0.95)`, radius 6, padding 6, gap 8 |
| Group headers (App, Media, System) | padding 8/10, Inter 14 `#6B6B6B` |
| Category item | 188 wide, padding 4, gap 8, radius 2; icon box 32 (24 glyph); label Inter 14 `#8F8F8F`; selected: background `#222222`, label `#EAEAEA`, accent-filled glyph |
| Content | scrolls; padding 20 top, 24 sides, 100 bottom; 20 between sections |
| Section header | padding 10/0, Inter Medium 16 `#C6C6C6` |
| Row | 784 wide in the frame, fills the content width; padding 5/0; label Inter 14 `#8F8F8F`; info glyph 18 at a gap of 10 after the label; control column 320 wide, right-aligned |
| Toggle | 68 × 32 `#090909` radius 6. On: knob `#AB6314` at the right, "ON" `#D37918` 12 px on `#371F06`. Off: knob `#404040` at the left, "OFF" `#6B6B6B` on `#191919` |
| Dropdown | 320 wide, `#090909` frame padding 2, radius 6; face `#191919` 32 high radius 4, padding 14, value Inter 14 `#8F8F8F`, chevron-down 24 |
| Segments (Theme, Size values, Startup volume) | 320 × 36 `#090909` padding 2, gap 2; segment radius 4; selected `#371F06` with `#D37918` text, others `#191919` with `#6B6B6B` |
| Accent swatches | as Segments with gap 4, nine cells, each a swatch with padding 6 and radius 1; unselected swatches at 70 % opacity |
| Text field | 36 high, `#090909`, 2 px `#191919` border, radius 6, padding 12 |
| Browse field | field 210 + gap 10 + button 100 × 32 `#191919` radius 6, Inter SemiBold 14 `#8F8F8F` |
| Button row (Reset, Clear, Open, Edit Keyboard Shortcuts) | as the Browse button. 100 wide, or 320 wide in Controls |
| Slider with ticks | track `#090909`, fill `#371F06`, handle accent; tick labels under it (frames `3062:12552`, `3073:15879`, `6536:13908`) |
| Advanced Options bar | full width, 38 high, `rgba(25,25,25,0.95)`, radius 2, Inter 14 `#8F8F8F` centred with a chevron. Right chevron when closed, down when open |

- **Reuse slice 3c's controls** in `player/qml/settings/` (`SettingToggle`, `SettingCombo`, `SettingField`, `SettingSegments`, `SettingSlider`, `ColorField`, `SettingRow`, `SettingSection`, `EffectAccordion`) and their `SettingsStyle` tokens. Add a property where the window's look differs from the player panel's, for example the row label `#8F8F8F` against the panel's `#6B6B6B`. Don't fork them.
- **The sidebar icons** come from the Figma instances in `999:5047`'s category items (General `1803:2966`, Interface `999:4961`/active `1088:4045`, Privacy `3046:10387`, Controls `1089:4451`, Playback `999:4803`, Video `999:4811`, Audio `44:408`, Subtitles `42:399`, Library `51:809`, Network `70:834`, Performance `1803:2958`, Recording `2115:7483`, Extensions `2516:9370`; info `2139:8986`; search `856:2148`).
  - Export them the way slice 5 did: SVGs under `pixmaps/redesign/settings/`, with a grey and an accent ("active") variant.
  - The active variant is drawn in the accent colour, filled where the Figma active instance is filled.

## How rows work

- **One data file describes every page:** page → sections → rows. Each row has a label, an optional VLC option name, a control kind and its parameters, and an Advanced flag. One row delegate draws any row.
  - Search and the Advanced Options split both come from this data. Pages are not hand-laid QML. *(my call)*
  - Special rows (the EQ, the add-ons list, the buffering group, startup volume, accent swatches) are their own small components, used from the data by kind.
- **A small C++ QML singleton bridges VLC config.** It does what `PlayerEffects::configValue`/`setConfigValue` do today (reuse that code; move it if that's cleaner), plus:
  - `exists(name)`: the option is registered in this build and isn't obsolete;
  - `choices(name)`: VLC's value and label lists (`config_GetIntChoices` / `config_GetPszChoices`);
  - `help(name)`: the option's long text, falling back to its text;
  - `reset(name)`: back to the default;
  - adding and removing a module in a `:`-separated list option (`audio-filter`, `video-filter`, `extraintf`, `control`);
  - `save()`.
- **A row whose option doesn't exist in this build is hidden**: platform-only options, plugins not built (skins2, x264, gnutls). A section with no visible rows hides too.
  - A `-vv` debug line lists the hidden rows, and a test checks the data file's option names against the build (below).
- **The info glyph** shows VLC's help text for the option as a tooltip on hover and keyboard focus. Rows without an option have no glyph, even where the Figma draws one. *(my call)*
- **Dropdown items** are VLC's own choice lists, with VLC's labels (translated). Where the Figma's shown value differs in wording, VLC's label wins. Where an option has no choice list, the row gives its own list (noted in the tables below).
- **Advanced Options:** each page's rows flagged Advanced sit under the bar, collapsed. The bar toggles them, and the state is kept per page for the session. *(my call)*
- **Search** (the top-bar box) filters across all pages while it has text.
  - Matching is on the row label and section title, case-insensitive. Advanced rows are included.
  - Results show in the content area, grouped under each page's title-bar text, with the sidebar selection cleared.
  - Clearing the box, or picking a sidebar page, returns to that page.
  - "No results" when nothing matches. *(my call; the Figma shows no search state.)*
- **Keyboard:** Tab moves through the sidebar, the search box and the rows' controls. Up and Down move in the sidebar.

## Pages: rows and what they write

Rows are listed in Figma order. **Adv** = under Advanced Options. "—" = not built; the reason is in the Notes column. Typos in the Figma labels are fixed: "changew" → "changes", "include subtitles" → "Include subtitles", and the second "Last.fm username" → "Last.fm password".

### General ("Global Settings")

| Row | Control | Writes | Notes |
|---|---|---|---|
| Interface language | dropdown | — | VLC on Linux/macOS follows the system locale. The Windows-only language setting lives in the legacy dialog. Not built. *(my call)* |
| Theme | segments Dark/Light/System | `MainCtx.colorScheme` | Light is VLC 4's light palette until slice 10 |
| Accent color | 9 swatches | `qt-accent-color` | Swatches `#D37918` (writes `default`), `#E15032`, `#C49E23`, `#19A234`, `#18AAD3`, `#185DD3`, `#8E42FF`, `#F052B3`, `#AFAFAF`. See Accent colour below |
| Show confirmation and error dialogs | toggle | `qt-error-dialogs` | |
| Check for updates automatically | toggle | `qt-updates-notif` | Only in builds with the updater, so hidden on Linux |
| Developer mode | toggle | — | No VLC equivalent. Not built |
| Save a log | toggle | `file-logging` | |
| Log file | browse (save file) | `logfile` | |
| Log details | dropdown | `log-verbose` | |
| Show minor warnings (Adv) | — | — | No VLC equivalent. Not built |
| Additional command line options (Adv) | — | — | Not built |
| Log format (Adv) | dropdown | `logmode` | |
| Collect playback statistics (Adv) | toggle | `stats` | |
| Open configurations folder (Adv) | button Open | opens `config_GetUserDir(VLC_CONFIG_DIR)` via `QDesktopServices` | |
| Reset all settings (Adv) | button Reset | the legacy dialog's reset (`config_ResetAll` + save), after a confirmation | |
| **All settings** (Adv) | button Open | legacy `PrefsDialog` in its All view | Not in the Figma *(my call)* |
| Developer Options (Adv section): Write to the system log, Include debug messages…, System log identity, System log facility | toggle, toggle, field, dropdown | `syslog`, `syslog-debug`, `syslog-ident`, `syslog-facility` | |

### Interface ("Interface Settings")

| Row | Control | Writes | Notes |
|---|---|---|---|
| Use a custom skin | toggle | `intf` = `skins2` / `qt` | Hidden when skins2 isn't built. Next launch |
| Skin file | browse | `skins2-last` | |
| Play video inside main window | toggle | `embedded-video` | |
| Resize window to fit video | dropdown Never/Always | `qt-video-autoresize` | A bool shown as two choices |
| Remember window size and position | — | — | VLC always does. Not built |
| Keep window above other windows | toggle | `video-on-top` | |
| Show window decorations | toggle | `video-deco` | |
| Show the file name in the title bar | toggle | `qt-name-in-title` | |
| Open fullscreen on | dropdown | `qt-fullscreen-screennumber` | "Current screen" (-1) plus one entry per screen |
| Start in compact mode | toggle | `qt-minimal-view` | |
| Auto-hide the controls | — | — | No VLC equivalent. Not built |
| Hide after | slider 0–10 s, ticks | `mouse-hide-timeout` (ms) | |
| Show controls in fullscreen | toggle | `qt-fs-controller` | |
| Show a system tray icon | toggle | `qt-system-tray` | |
| Start minimized to the tray | toggle | `qt-start-minimized` | |
| Show a popup when the track changes | dropdown | `qt-notification` | |
| Popup duration | — | — | No VLC equivalent. Not built |
| Show the playlist as a tree | toggle | `playlist-tree` | Hidden if obsolete |
| Window opacity (Adv) | slider 10–100 % | `qt-opacity` | |
| Pause video when window is minimized (Adv) | toggle | `qt-pause-minimized` | |
| Bring VLC to the front when playback starts (Adv) | dropdown | `qt-auto-raise` | |
| Show cover art in the window when playing audio (Adv) | toggle | `qt-bgcone` | |
| Show the file browser inside the open dialog (Adv) | toggle | `qt-embedded-open` | |
| Allow the app icon to change (Adv) | toggle | `qt-icon-change` | |
| Fullscreen controls opacity (Adv) | slider 10–100 % | `qt-fs-opacity` | |
| Fullscreen controls sensitivity (Adv) | slider Low/Medium/High | `qt-fs-sensitivity` | Three stops: 30 / 90 / 300 px *(my call)* |

### Privacy ("Privacy Settings")

| Row | Control | Writes | Notes |
|---|---|---|---|
| Save recently played items | toggle | `save-recentplay` | |
| Remember the playback position | toggle | `restore-playback-states` | *(my call: the Playback page's "Continue where you left off" owns `restore-playback-pos`)* |
| Never remember items matching | field | `qt-recentplay-filter` | |
| Clear history now | button Clear | `MLRecentMediaModel::clearHistory()` (the media library's history) | Disabled without a media library |
| Fetch titles and cover art from the internet | toggle | `metadata-network-access` | Also on Library; same option |
| Submit played tracks to last.fm | toggle | `audioscrobbler` in `extraintf` | |
| Last.fm username / password / submission URL | field, password field, field | `lastfm-username`, `lastfm-password`, `scrobbler-url` | |

### Controls ("Mouse, Keyboard & Remote Controls")

| Row | Control | Writes | Notes |
|---|---|---|---|
| Defaults | wide button Edit Keyboard Shortcuts | `DialogsProvider::prefsDialog(<hotkeys panel>)` | Slice 8 replaces it with the Figma dialog |
| Reset all shortcuts | wide button Reset | resets every `key-*` and `global-key-*` option, after a confirmation | |
| Very short / Short / Medium / Long skip | field with " s" suffix | `extrashort-jump-size`, `short-jump-size`, `medium-jump-size`, `long-jump-size` | |
| Single click on the video, Double click on the video | — | — | No VLC option. Not built *(my call)* |
| Scroll wheel | dropdown | `hotkeys-y-wheel-mode` | |
| Horizontal scroll | dropdown | `hotkeys-x-wheel-mode` | |
| Reverse scroll direction | — | — | No VLC option. Not built |
| Web remote control | toggle | `http` in `extraintf` | |
| Port | field | `http-port` | |
| **Password** | password field | `http-password` | Not in the Figma, but VLC's web interface refuses to start without one *(my call)* |
| (the Remotes section's repeated Scroll wheel / Horizontal scroll / Reverse rows) | — | — | A Figma copy-paste. Not built |

### Playback ("Playback Preferences")

| Row | Control | Writes | Notes |
|---|---|---|---|
| Continue where you left off | dropdown | `restore-playback-pos` | |
| Start playing as soon as a file opens | toggle | `playlist-autostart` | |
| Default playback speed | slider 0.25–2, ticks at the labels | `rate` | |
| Pause when another app uses audio | — | — | No VLC option. Not built |
| Preferred video quality | dropdown | `preferred-resolution` | |
| Preferred menu language | dropdown of languages | `menu-language` | The language list is a shared helper (also used for audio and subtitles) |
| Default audio track / Default subtitle track | field | `audio-track`, `sub-track` | |
| Repeat | dropdown Off/One/All | `repeat` and `loop` | Own list |
| Shuffle | toggle | `random` | |
| Stop after each item | toggle | `play-and-stop` | |
| When playback finishes | dropdown Stop/Quit | `play-and-exit` | Own list |
| Seek precisely | toggle | `input-fast-seek` (inverted) | |
| Show thumbnail while scrubbing | — | — | No VLC option. Not built |
| Default optical drive | editable dropdown | `dvd` | Lists the optical drives found (`/dev/sr*`, or drive letters) |
| Repair damaged AVI files | dropdown | `avi-index` | |
| Load matching .mkv files from the same folder | toggle | `mkv-preload-local-dir` | |
| Time-shift buffer folder (Adv) | browse (folder) | `input-timeshift-path` | |
| Time-shift buffer size (Adv) | dropdown Small/Medium/Large | `input-timeshift-granularity` | Own list *(my call: 10 / 50 / 200 MB)* |

### Video ("Video Defaults")

| Row | Control | Writes | Notes |
|---|---|---|---|
| Enable video | toggle | `video` | |
| Start videos in fullscreen | toggle | `fullscreen` | |
| Stop the screensaver during playback | toggle | `disable-screensaver` | |
| Play video as desktop wallpaper | toggle | `video-wallpaper` | |
| Hue, Brightness, Contrast, Saturation, Gamma | sliders | `hue`, `brightness`, `contrast`, `saturation`, `gamma`; turning any away from its default adds `adjust` to `video-filter` | Ranges are the options' own |
| Reset picture | button Reset | resets those five and removes `adjust` | |
| Deinterlacing | dropdown | `deinterlace` | |
| Method | dropdown | `deinterlace-mode` | |
| Aspect ratio | dropdown | `aspect-ratio` | "Automatic" plus `custom-aspect-ratios` |
| Crop | dropdown | `crop` | "None" plus `custom-crop-ratios` |
| Scale video to the window | toggle | `autoscale` | |
| Zoom | dropdown | `zoom` | Own list: Fit (1, with autoscale) / ¼ / ½ / 1:1 / 2:1 *(my call)* |
| Position in the window | dropdown | `align` | |
| Save to | browse (folder) | `snapshot-path` | |
| File name prefix | field | `snapshot-prefix` | |
| Format | dropdown | `snapshot-format` | |
| Size | dropdown | `snapshot-width` / `snapshot-height` | Own list: Same as video (-1) / 1920 / 1280 / 640 wide |
| Number files sequentially | toggle | `snapshot-sequential` | |
| Show a preview after capture | toggle | `snapshot-preview` | |
| Custom aspect ratios (Adv) | field | `custom-aspect-ratios` | |
| Custom crop ratios (Adv) | field | `custom-crop-ratios` | |
| Monitor pixel aspect ratio (Adv) | field | `monitor-par` | |
| Time-shift buffer size (Adv) | — | — | A Figma copy-paste from Playback. Not built |

### Audio ("Audio Defaults")

| Row | Control | Writes | Notes |
|---|---|---|---|
| Enable audio | toggle | `audio` | |
| Output device | dropdown | `aout` | The output module, as in the legacy dialog. "System default" = `any` |
| Speaker setup | dropdown | `stereo-mode` | |
| Maximum volume | slider 100–300 %, ticks | `qt-max-volume` | |
| Startup volume | segments: Remember last volume / Always starts at [field] | `volume-save` on/off | The % field has no VLC option. It shows 100 % and is read-only *(my call)* |
| Volume step | field | `volume-step` | |
| Normalize loudness | toggle | `normvol` in `audio-filter` | |
| Target level | field | `norm-max-level` | |
| Night mode | — | — | No separate VLC filter (Compressor below covers it). Not built |
| Replay gain | dropdown | `audio-replay-gain-mode` | |
| Replay gain preamp | field | `audio-replay-gain-preamp` | |
| Equalizer | toggle | `equalizer` in `audio-filter` | |
| Equalizer preset | dropdown | `equalizer-preset` | |
| (EQ panel, "Close Equalizer") | 3c's equalizer block | `equalizer-preamp`, `equalizer-bands` | Shown while the toggle is on; the bar folds it |
| Two-pass | toggle | `equalizer-2pass` | |
| Spatial audio | toggle | the mode's filter in `audio-filter` | |
| Spatial audio mode | dropdown Headphone virtualization / Room | `headphone` / `spatializer` | Own list *(my call)* |
| Stereo widening | toggle | `stereo_widen` in `audio-filter` | |
| Compressor | toggle | `compressor` in `audio-filter` | |
| Pitch shift | field | `pitch-shift` (+ `scaletempo_pitch` in `audio-filter` when ≠ 0) | |
| Chorus/flanger | toggle | `chorus_flanger` in `audio-filter` | |
| Karaoke | toggle | `karaoke` in `audio-filter` | |
| Preferred audio language | language dropdown | `audio-language` | |
| Audio delay | field (s) | `audio-desync` (ms) | |
| Visualizer | dropdown | `audio-visual` | |
| Pass compressed audio to the receiver (Adv) | toggle | `spdif` | |
| Detect Dolby Surround (Adv) | dropdown | `force-dolby-surround` | |
| Resampling quality (Adv) | dropdown | `audio-resampler` | |
| Media role (Adv) | dropdown | `role` | |
| Visualization size (Adv) | dropdown | `effect-width` / `effect-height` | Own list: Match window is not possible; list 400×300 / 800×600 / 1280×720 *(my call)* |

### Subtitles ("Subtitle Defaults")

| Row | Control | Writes | Notes |
|---|---|---|---|
| Enable subtitles | toggle | `spu` | |
| Preferred language | language dropdown | `sub-language` | |
| Text encoding | dropdown | `subsdec-encoding` | |
| Load subtitle files automatically | toggle | `sub-autodetect-file` | |
| File name matching | dropdown | `sub-autodetect-fuzzy` | |
| Font | font-family dropdown | `freetype-font` | System families (`QFontDatabase`) |
| Size values | segments Relative/Pixels | which of the next row's two options is used | Pixels when `freetype-fontsize` ≠ 0 |
| Font size | dropdown (Relative) / field (Pixels) | `freetype-rel-fontsize` / `freetype-fontsize` | Switching to Relative writes `freetype-fontsize` = 0 |
| Bold | toggle | `freetype-bold` | |
| Text color | colour field | `freetype-color` | 3c's `ColorField` |
| Text opacity | slider 0–100 % | `freetype-opacity` (0–255) | |
| Outline thickness | dropdown | `freetype-outline-thickness` | |
| Outline color | colour field | `freetype-outline-color` | |
| Shadow | toggle | `freetype-shadow-opacity` 0 / 128 | |
| Shadow color | colour field | `freetype-shadow-color` | |
| Shadow distance | dropdown Small/Medium/Large | `freetype-shadow-distance` 0.03 / 0.06 / 0.1 | Own list *(my call)* |
| Background | dropdown None/Box | `freetype-background-opacity` 0 / 128 | Own list |
| Background color | colour field | `freetype-background-color` | |
| Background opacity | slider 0–100 % | `freetype-background-opacity` | |
| Vertical position | dropdown Bottom/Raised/High | `sub-margin` 0 / 50 / 150 px | Own list *(my call)* |
| Subtitle delay | slider -5…+5 s | `sub-delay` (tenths of a second) | |
| Show feedback for shortcuts | toggle | `osd` | |
| Show feedback for | — | — | No VLC option. Not built |
| Show filename when a video starts | toggle | `video-title-show` | |
| Show filename for | slider 1–10 s | `video-title-timeout` (ms) | |
| Load subtitles from these folders (Adv) | field | `sub-autodetect-path` | |
| Ignore styling in ASS and SSA subtitles (Adv) | — | — | No VLC option. Not built |
| Shadow angle (Adv) | field | `freetype-shadow-angle` | |
| Text direction (Adv) | dropdown | `freetype-text-direction` | |
| Monospace font (Adv) | font-family dropdown | `freetype-monofont` | |
| Visualization size (Adv) | — | — | A Figma copy-paste from Audio. Not built |

### Library ("Playlists, Folders & Files")

| Row | Control | Writes | Notes |
|---|---|---|---|
| Only allow one VLC window | toggle | `one-instance` | |
| Apply to files opened from the file manager | toggle | `one-instance-when-started-from-file` | |
| Add to the playlist instead of replacing it | toggle | `playlist-enqueue` | |
| When opening a folder | dropdown | `recursive` | |
| Show hidden files | toggle | `show-hiddenfiles` | |
| Fetch titles and artwork | dropdown From the file only / Also from the internet | `metadata-network-access` | Own list |
| Use the media library | toggle | `media-library` | Next launch |

### Network ("Network Connections & Security")

| Row | Control | Writes | Notes |
|---|---|---|---|
| Buffering | dropdown Low/Normal/High/Custom | the four fields below | Normal = the options' defaults, Low = ½, High = ×2. The shown value is whichever preset matches all four, else Custom *(my call)* |
| Local files / Discs / Network streams / Live capture | fields (ms) | `file-caching`, `disc-caching`, `network-caching`, `live-caching` | Disabled (greyed, as in the Figma) unless Custom |
| HTTP proxy | field | `http-proxy` | Placeholder "System proxy" |
| HTTP proxy password | password field | `http-proxy-pwd` | |
| Verify certificates against the system trust store | toggle | `gnutls-system-trust` | |
| Cipher preference | dropdown | `gnutls-priorities` | |

### Performance ("Performance Settings")

| Row | Control | Writes | Notes |
|---|---|---|---|
| Hardware-accelerated decoding | dropdown | `avcodec-hw` | |
| Video post-processing | dropdown Off/1…6 | `postproc-q` | |
| Skip the H.264 loop filter | dropdown | `avcodec-skiploopfilter` | |
| Decoding threads | field | `avcodec-threads` | |
| Drop frames when the system can't keep up | toggle | `drop-late-frames` | |
| Give VLC real-time priority | toggle | `high-priority` | |
| Process priority | — | — | No VLC option. Not built |
| Rescan plugins | — | — | VLC can't rescan at run time. Not built |
| Encoder (Adv, Developer) | dropdown | `encoder` | |
| Decoder (Adv, Developer) | dropdown | `codec` | |
| Clock synchronisation (Adv) | dropdown | `clock-synchro` | |
| Clock jitter (Adv) | field (ms) | `clock-jitter` | |
| Clock reference averaging (Adv) | — | — | No VLC 4 option. Not built |

### Recording ("Recording, Casting & Streaming Out")

| Row | Control | Writes | Notes |
|---|---|---|---|
| Save recordings to | browse (folder), shows the path | `input-record-path` | |
| Record without re-encoding when possible | toggle | `input-record-native` | |
| Discover cast devices | — | — | Discovery runs from the renderer menu, not an option. Not built |
| Cast quality | dropdown | `sout-chromecast-conversion-quality` | |
| Play locally while streaming | toggle | `sout-display` | |
| Include audio / video / subtitles | toggles | `sout-audio`, `sout-video`, `sout-spu` | |
| Encoding preset | dropdown | `sout-x264-preset` | |
| Tuning | dropdown | `sout-x264-tune` | |

### Extensions ("Add-ons & Scripts")

- **A list box** (Figma `6575:17137`: `#090909`, radius 6, full width, about 190 high) of the installed Lua extensions, from the existing extensions manager model: name, version, and the description on hover. Click selects.
- **Search field** (210 wide) filters the list.
- **Find more extensions** opens VLC's existing add-ons manager.
- **Add** opens a file dialog for a `.lua` file, copies it into the user's extensions folder, and reloads the extensions.
- **Remove** is enabled only for an extension in the user's folder. It deletes the file (after a confirmation) and reloads.
- **Load add-ons on startup**: toggle `qt-autoload-extensions`.

## Accent colour

- The swatch row writes `qt-accent-color`. The theme's accent (`SystemPaletteThemeProvider`) already reads that option.
- The redesign's dark default is `#D37918`, while the provider's dark default is `#FF8800`. Change the provider's `default` dark value to `#D37918` and its pressed value to match, so the first swatch is the default.
- The redesign's QML hardcodes the accent in about eight files (`SettingsStyle`, `FigmaMenu`, `HomeListRow`, `HomeVideoCard`, `HomeSquareCard`, `PlayerPanel`, `VolumeWidget`, `menustyle.cpp`).
  - Route those through the theme's accent, with `accentBg` and `accentDim` derived from it. *(my call)*
  - The SVG icons with orange baked in (active sidebar glyphs, menu icons) stay orange. That goes in the Ledger.
- If the palette doesn't refresh live, the accent applies on the next launch. That is acceptable. *(my call)*

## Tests and verification

- **A Qt test** loads the settings data file and asserts that every option name it uses is registered in this build, or is on an explicit platform list (Windows/macOS-only options, plugins not built here). It catches typos.
- **A Qt test for the bridge:** a round trip for each value type, choices for one int and one string option, and list-option add and remove.
- **Visual:** for each page, compare against its `docs/superpowers/figma/7/` shot at the same window size, with the harness (`vlc-xvfb.sh start -vv`, then grep the log for QML errors).
  - Save the after-shots next to the Figma ones as `after-<page>.png`.
- **Behaviour:**
  - a toggle and a dropdown change persist across a restart;
  - search finds an Advanced row;
  - Ctrl+P opens and raises the window;
  - the "…" menu's Keyboard Shortcuts still opens the legacy hotkeys panel;
  - All settings opens the legacy dialog.
