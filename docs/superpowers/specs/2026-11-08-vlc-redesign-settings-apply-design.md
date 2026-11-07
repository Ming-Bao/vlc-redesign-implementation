# VLC Redesign — Settings apply when changed (design)

Date: 2026-11-08. Follows slice 7 (Settings window, plan `docs/superpowers/plans/2026-10-25-vlc-redesign-settings.md`).

## Why

The user changed settings and saw nothing happen, so they suspected most of the Settings window was dead. Testing
(below) showed only 4 rows are truly dead. The real problem is timing: every row saves, but about half only take effect
later (on the next video or the next launch), and nothing tells you that. The user wants a change to apply the moment
it's made. Where VLC can't do that, the row must say when it will apply.

## Goals

1. Every row that VLC *can* apply to the running app does so on change: interface settings re-read live, and
   video/audio/subtitle/playlist settings reach the playing media.
2. Every row that can't apply on change carries a small tag after its name: **"Next video"** or **"After restart"**.
3. The 4 dead rows are wired up or removed.
4. The 4 untested action buttons are checked by hand.

## Non-goals

- **Reopening the current video** or **restarting VLC** to apply a setting. User: "keep those to read on startup". The
  "Next video" and "After restart" rows stay read where VLC reads them today; only the tag is new.
- Rows whose meaning is start-up behaviour (listed under "My calls") are not forced onto the running
  app. They get the tag for when they're read.
- The Figma audit and the Customize Player second-row bug (recorded under "Later" in the roadmap).

## Anti-goals

- A setting that silently does nothing. After this work, every visible row either applies on change or says when it
  applies.
- Settings changing something that the player's own controls then show wrongly. When Settings pushes a value, the
  player's controls (speed button, aspect menu, panels) show it. The reverse isn't required (see "One way only").
- Changing Dark-theme visuals beyond the new tags.

## Decided with the user

- **Tag look: option B** of the mockup (`.superpowers/brainstorm/…/apply-note.html`). It's a small chip right after
  the row name (and after its ⓘ), text `Next video` / `After restart`, about 11 px, FG/A3-ish grey on a BG/A2-ish chip,
  radius 4, padding 2×7. Rows keep their height. Rows that apply on change get no chip. The chip follows Light/Dark
  through the token table (`theme.palette.tokens`), like everything since slice 10. Exact tokens are the builder's
  pick; it must stay quiet next to the label.
- **No reopen, no restart.** Tags only, for anything VLC reads at video start or launch.
- **Apply immediately** is the rule for everything else.
- **"Default …" rows change the playing media too** (user, 2026-11-08: "1 yes"). The rule is *whatever VLC can change
  live*: Default playback speed sets the current rate, Default audio/subtitle track switch the current track, audio
  delay, subtitle delay, aspect ratio, zoom, deinterlacing, picture, equalizer and effects all reach what's playing.
- **One way only** (user: "2 one way"). Settings → player. The player's own controls (speed button, delay sliders,
  aspect ratio, zoom in the player panels) keep changing only the current media and do **not** rewrite the Settings
  defaults. So after a player tweak, Settings may show a different value from what's playing. That's accepted. When
  Settings is opened or changed again, it pushes its value again.

## My calls (not confirmed by the user)

- **Repeat / Shuffle / Stop after each item / When playback finishes** change the live play queue
  (`vlc_playlist_SetPlaybackRepeat` / `…Order` / `…MediaStoppedAction`). These are the one exception to "one way":
  the player's repeat/shuffle buttons already write the same config (`playlist_controller.cpp`), so the Settings rows
  just re-read it and show the queue's state.
- **The start-up rows that only get a tag** are the ones whose meaning is "on start": Startup volume, Start in compact
  mode, Start minimized to the tray, Start videos in fullscreen, Continue where
  you left off / Remember the playback position, Show filename when a video starts (and its duration). "Preferred …"
  rows (languages, video quality) are matching rules used when a media opens, not values, so they get "Next video".
- **Dead rows:**
  - `qt-error-dialogs`: wire it. When off, error pop-ups are not shown (they still go to the messages log). The label
    stays the Figma's. Confirmations that guard a destructive action (Reset all settings, Reset all shortcuts, delete
    from the library…) always show, whatever this row says.
  - `qt-fs-controller`: wire it. When off, the player's control bar does not appear in fullscreen (the mouse still
    shows the cursor). It applies live.
  - `qt-fs-sensitivity` and `playlist-tree`: remove the rows. The redesign shows the fullscreen bar on any mouse move
    (no edge zone) and the queue is flat, so these settings have nothing to control.
- **Output device (`aout`)** is in the live group because VLC 4 can restart the audio output at run time. If the
  builder finds that switching the output *module* mid-playback isn't reliable, it gets the "Next video" tag instead.
  Record the call in the ledger.
- **Hidden rows** (11, not in this Linux build) are unchanged. If they appear on another platform, they need a class.
  The builder gives each one the class its reader implies (proxy → Next video, one-instance → After restart, etc.).

## Evidence (2026-11-08, harness `vlc-xvfb.sh`, `longsub.mkv` playing)

- **Live today:** Subtitles ▸ Text color (the on-screen subtitle turned red mid-video), Controls ▸ Short skip (set to
  30 s, one → press jumped 0:15 → 0:45).
- **Not live:** Video ▸ Hue (no colour change while playing; applied after a relaunch), Playback ▸ Default playback
  speed (2× chosen, clock kept 1×), Audio ▸ Maximum volume (the bar's volume slider unchanged; applied after a
  relaunch).
- **Buttons:** General ▸ All settings opens Advanced Preferences; Controls ▸ Edit Keyboard Shortcuts opens the
  Keyboard Shortcuts dialog. Not clicked: Open configurations folder (would open a file manager on the user's real
  desktop from Xvfb), Reset all settings, Reset all shortcuts, Privacy ▸ Clear history now.
- **Static trace:** every option's readers were found by grepping `"<option>"` in `src/ lib/ modules/` (excluding
  the settings UI and option declarations). This classified the rest. 4 options have no reader at all in VLC 4.
- **Why interface settings don't apply:** the legacy Preferences called `p_mi->reloadPrefs()` on save
  (`dialogs/preferences/preferences.cpp`); the new window only calls `config_SaveConfigFile` on close
  (`SettingsWindow.qml` → `SettingsBridge::save`). Several of these options are also read once in a constructor
  (`interface_window_handler.cpp`, `video_window_handler.cpp`, `systray.cpp`), so `reloadPrefs` alone won't cover them.

## Classes

| Class | Count | Meaning | Work |
|---|---|---|---|
| LIVE | 45 | Read at the time of use; already applies on change | none (spot-check a few) |
| PLAYER | 35 | Has a run-time control on the playing media that Settings doesn't call | push to the player on change |
| UI | 12 | Qt interface option, read at start or in `loadPrefs` only | re-read on change |
| NEXT | 45 | Read when a video, decoder, output or stream starts | `Next video` tag |
| LAUNCH | 24 | Read once when VLC (or that service) starts | `After restart` tag |
| DEAD | 4 | No reader in VLC 4 | wire 2, remove 2 |
| HIDDEN | 11 | Option not in this build; row already hidden | none |
| BUTTON | 6 | Action rows | hand-check the 4 untested |

The class is a guess from the code for any row not in the Evidence list. **The builder verifies each PLAYER, UI
and DEAD row in the running app** (change it during playback, see the effect). A row that turns out not to apply live
moves to NEXT or LAUNCH and gets its tag. That move goes in the ledger, not a silent drop.

## How (what's left to the builder, with pointers)

- **One place for "when does this apply".** Add a field to each row in `dialogs/settings/qml/SettingsData.js` (e.g.
  `applies: "next"` / `"restart"`), documented in the file's header comment like the other row fields. Each custom row
  file (`rows/*.qml`) needs it handled too where its sub-rows differ. `SettingsRowDelegate.qml` draws the chip. Search
  results show the chip too.
- **PLAYER rows:** reuse `PlayerEffects` (`player/player_effects.{hpp,cpp}`, QML singleton `Effects`). It already
  writes config *and* the live aout/vout variables (`setValue`), toggles audio filters (`setFilterEnabled`), and
  handles equalizer, crop, transform and subtitle scale. The in-player settings tabs (slice 3c,
  `player/qml/*SettingsPage.qml`) use it and apply live. Rows that are player state, not aout/vout variables (rate,
  audio/subtitle delay, track categories, repeat/order/stopped action), go through the player/playlist API. Settings
  writing config only and then pushing live is fine; the order doesn't matter as long as both happen on every change.
- **UI rows:** call `MainCtx::reloadPrefs()` (or a narrower per-option refresh) when a UI option changes.
  `SettingsBridge::changed(name)` already fires on every write. For options read in constructors (window title name,
  opacity, pause-on-minimize, autoresize, tray, notifications, icon change), add a re-read on change in the owner.
- **Keep the save-on-close** (`SettingsBridge::save`) as it is. Live apply is in addition to it.
- **Tests:** extend the Qt suite (`modules/gui/qt/tests/`, currently 29/29) where the logic is testable without a
  running video. Examples: every row has a class (no row without `applies` unless it's on the live list), the chip text
  matches the field, and UI options trigger a reload. PLAYER behaviour is verified on the harness with a playing video
  and recorded in the plan's ledger, the way slices 8–10 did.

## Appendix: all 182 rows

Class per row as tested or traced on 2026-11-08 (see Evidence). `(File.qml)` is a custom row; `[module]` is the
module a toggle adds to its list option.

| Page | Row | Option(s) | Class |
|---|---|---|---|
| general | Theme | `(ThemeRow.qml)` | LIVE |
| general | Accent color | `(AccentRow.qml)` | LIVE |
| general | Show confirmation and error dialogs | `qt-error-dialogs` | DEAD |
| general | Check for updates automatically | `qt-updates-notif` | HIDDEN |
| general | Save a log | `file-logging` | LAUNCH |
| general | Log file | `logfile` | LAUNCH |
| general | Log details | `log-verbose` | LAUNCH |
| general | Log format | `logmode` | LAUNCH |
| general | Collect playback statistics | `stats` | NEXT |
| general | Open configurations folder | `(openConfig)` | BUTTON |
| general | Reset all settings | `(resetAll)` | BUTTON |
| general | All settings | `(legacyPrefs)` | BUTTON |
| general | Write to the system log | `syslog` | LAUNCH |
| general | Include debug messages in the system log | `syslog-debug` | LAUNCH |
| general | System log identity | `syslog-ident` | LAUNCH |
| general | System log facility | `syslog-facility` | LAUNCH |
| interface | Use a custom skin | `intf skins2-last` | LAUNCH |
| interface | Skin file | `skins2-last` | LAUNCH |
| interface | Play video inside main window | `embedded-video` | NEXT |
| interface | Resize window to fit video | `qt-video-autoresize` | UI |
| interface | Keep window above other windows | `video-on-top` | UI |
| interface | Show window decorations | `video-deco` | NEXT |
| interface | Show the file name in the title bar | `qt-name-in-title` | UI |
| interface | Open fullscreen on | `qt-fullscreen-screennumber` | LIVE |
| interface | Start in compact mode | `qt-minimal-view` | LAUNCH |
| interface | Hide after | `mouse-hide-timeout` | UI |
| interface | Show controls in fullscreen | `qt-fs-controller` | DEAD |
| interface | Show a system tray icon | `qt-system-tray` | UI |
| interface | Start minimized to the tray | `qt-start-minimized` | LAUNCH |
| interface | Show a popup when the track changes | `qt-notification` | UI |
| interface | Show the playlist as a tree | `playlist-tree` | DEAD |
| interface | Window opacity | `qt-opacity` | UI |
| interface | Pause video when window is minimized | `qt-pause-minimized` | UI |
| interface | Bring VLC to the front when playback starts | `qt-auto-raise` | LIVE |
| interface | Show cover art in the window when playing audio | `qt-bgcone` | UI |
| interface | Show the file browser inside the open dialog | `qt-embedded-open` | LIVE |
| interface | Allow the app icon to change | `qt-icon-change` | UI |
| interface | Fullscreen controls opacity | `qt-fs-opacity` | UI |
| interface | Fullscreen controls sensitivity | `qt-fs-sensitivity` | DEAD |
| privacy | Save recently played items | `save-recentplay` | LIVE |
| privacy | Remember the playback position | `restore-playback-states` | NEXT |
| privacy | Clear history now | `(clearHistory)` | BUTTON |
| privacy | Fetch titles and cover art from the internet | `metadata-network-access` | LIVE |
| privacy | Submit played tracks to last.fm | `extraintf lastfm-username [audioscrobbler]` | LAUNCH |
| privacy | Last.fm username | `lastfm-username` | LAUNCH |
| privacy | Last.fm password | `lastfm-password` | LAUNCH |
| privacy | Last.fm submission URL | `scrobbler-url` | LAUNCH |
| controls | Defaults | `(editHotkeys)` | BUTTON |
| controls | Reset all shortcuts | `(resetHotkeys)` | BUTTON |
| controls | Very short skip | `extrashort-jump-size` | LIVE |
| controls | Short skip | `short-jump-size` | LIVE |
| controls | Medium skip | `medium-jump-size` | LIVE |
| controls | Long skip | `long-jump-size` | LIVE |
| controls | Scroll wheel | `hotkeys-y-wheel-mode` | LAUNCH |
| controls | Horizontal scroll | `hotkeys-x-wheel-mode` | LAUNCH |
| controls | Web remote control | `extraintf http-password [http]` | LAUNCH |
| controls | Port | `http-port` | LAUNCH |
| controls | Password | `http-password` | LAUNCH |
| playback | Continue where you left off | `restore-playback-pos` | NEXT |
| playback | Start playing as soon as a file opens | `playlist-autostart` | LIVE |
| playback | Default playback speed | `rate` | PLAYER |
| playback | Preferred video quality | `preferred-resolution` | NEXT |
| playback | Preferred menu language | `menu-language` | NEXT |
| playback | Default audio track | `audio-track` | PLAYER |
| playback | Default subtitle track | `sub-track` | PLAYER |
| playback | Repeat | `repeat loop (RepeatRow.qml)` | PLAYER |
| playback | Shuffle | `random` | PLAYER |
| playback | Stop after each item | `play-and-stop` | PLAYER |
| playback | When playback finishes | `play-and-exit` | PLAYER |
| playback | Seek precisely | `input-fast-seek` | NEXT |
| playback | Default optical drive | `dvd` | LIVE |
| playback | Repair damaged AVI files | `avi-index` | NEXT |
| playback | Load matching .mkv files from the same folder | `mkv-preload-local-dir` | NEXT |
| playback | Time-shift buffer folder | `input-timeshift-path` | NEXT |
| playback | Time-shift buffer size | `input-timeshift-granularity` | NEXT |
| video | Enable video | `video` | PLAYER |
| video | Start videos in fullscreen | `fullscreen` | NEXT |
| video | Stop the screensaver during playback | `disable-screensaver` | NEXT |
| video | Play video as desktop wallpaper | `video-wallpaper` | PLAYER |
| video | Picture | `hue gamma (PictureRows.qml)` | PLAYER |
| video | Deinterlacing | `deinterlace` | PLAYER |
| video | Method | `deinterlace-mode` | PLAYER |
| video | Aspect ratio | `aspect-ratio` | PLAYER |
| video | Crop | `crop` | PLAYER |
| video | Scale video to the window | `autoscale` | PLAYER |
| video | Zoom | `zoom autoscale` | PLAYER |
| video | Position in the window | `align` | NEXT |
| video | Save to | `snapshot-path` | LIVE |
| video | File name prefix | `snapshot-prefix` | LIVE |
| video | Format | `snapshot-format` | LIVE |
| video | Size | `snapshot-width snapshot-height` | LIVE |
| video | Number files sequentially | `snapshot-sequential` | LIVE |
| video | Show a preview after capture | `snapshot-preview` | LIVE |
| video | Custom aspect ratios | `custom-aspect-ratios` | NEXT |
| video | Custom crop ratios | `custom-crop-ratios` | NEXT |
| video | Monitor pixel aspect ratio | `monitor-par` | NEXT |
| audio | Enable audio | `audio` | PLAYER |
| audio | Output device | `aout` | PLAYER |
| audio | Speaker setup | `stereo-mode` | PLAYER |
| audio | Maximum volume | `qt-max-volume` | UI |
| audio | Startup volume | `volume-save (StartupVolumeRow.qml)` | LAUNCH |
| audio | Volume step | `volume-step` | LIVE |
| audio | Normalize loudness | `audio-filter [normvol]` | PLAYER |
| audio | Target level | `norm-max-level` | NEXT |
| audio | Replay gain | `audio-replay-gain-mode` | PLAYER |
| audio | Replay gain preamp | `audio-replay-gain-preamp` | NEXT |
| audio | Equalizer | `audio-filter equalizer-bands (EqualizerRows.qml)` | PLAYER |
| audio | Two-pass | `equalizer-2pass` | PLAYER |
| audio | Spatial audio | `audio-filter (SpatialRows.qml)` | PLAYER |
| audio | Stereo widening | `audio-filter [stereo_widen]` | PLAYER |
| audio | Compressor | `audio-filter [compressor]` | PLAYER |
| audio | Pitch shift | `pitch-shift audio-filter [scaletempo_pitch]` | PLAYER |
| audio | Chorus/flanger | `audio-filter [chorus_flanger]` | PLAYER |
| audio | Karaoke | `audio-filter [karaoke]` | PLAYER |
| audio | Preferred audio language | `audio-language` | NEXT |
| audio | Audio delay | `audio-desync` | PLAYER |
| audio | Visualizer | `audio-visual` | PLAYER |
| audio | Pass compressed audio to the receiver | `spdif` | HIDDEN |
| audio | Detect Dolby Surround | `force-dolby-surround` | NEXT |
| audio | Resampling quality | `audio-resampler` | NEXT |
| audio | Media role | `role` | NEXT |
| audio | Visualization size | `effect-width effect-height` | NEXT |
| subtitles | Enable subtitles | `spu` | PLAYER |
| subtitles | Preferred language | `sub-language` | NEXT |
| subtitles | Text encoding | `subsdec-encoding` | NEXT |
| subtitles | Load subtitle files automatically | `sub-autodetect-file` | NEXT |
| subtitles | File name matching | `sub-autodetect-fuzzy` | NEXT |
| subtitles | Font | `freetype-font` | LIVE |
| subtitles | Font size | `sub-text-scale` | PLAYER |
| subtitles | Bold | `freetype-bold` | LIVE |
| subtitles | Text color | `freetype-color` | LIVE |
| subtitles | Text opacity | `freetype-opacity` | LIVE |
| subtitles | Outline thickness | `freetype-outline-thickness` | LIVE |
| subtitles | Outline color | `freetype-outline-color` | LIVE |
| subtitles | Shadow | `freetype-shadow-opacity` | LIVE |
| subtitles | Shadow color | `freetype-shadow-color` | LIVE |
| subtitles | Shadow distance | `freetype-shadow-distance` | LIVE |
| subtitles | Background | `freetype-background-opacity` | LIVE |
| subtitles | Background color | `freetype-background-color` | LIVE |
| subtitles | Background opacity | `freetype-background-opacity` | LIVE |
| subtitles | Vertical position | `sub-margin` | PLAYER |
| subtitles | Subtitle delay | `sub-delay` | PLAYER |
| subtitles | Show feedback for shortcuts | `osd` | LIVE |
| subtitles | Show filename when a video starts | `video-title-show` | NEXT |
| subtitles | Show filename for | `video-title-timeout video-title-show` | NEXT |
| subtitles | Load subtitles from these folders | `sub-autodetect-path` | NEXT |
| subtitles | Shadow angle | `freetype-shadow-angle` | LIVE |
| subtitles | Text direction | `freetype-text-direction` | LIVE |
| subtitles | Monospace font | `freetype-monofont` | LIVE |
| library | Only allow one VLC window | `one-instance` | HIDDEN |
| library | Apply to files opened from the file manager | `one-instance-when-started-from-file one-instance` | HIDDEN |
| library | Add to the playlist instead of replacing it | `playlist-enqueue one-instance` | HIDDEN |
| library | When opening a folder | `recursive` | LIVE |
| library | Show hidden files | `show-hiddenfiles` | LIVE |
| library | Fetch titles and artwork | `metadata-network-access` | LIVE |
| library | Use the media library | `media-library` | LAUNCH |
| network | Buffering | `file-caching live-caching (BufferingRows.qml)` | NEXT |
| network | HTTP proxy | `http-proxy` | HIDDEN |
| network | HTTP proxy password | `http-proxy-pwd` | HIDDEN |
| network | OpenSubtitles API key | `qt-opensubtitles-key` | LIVE |
| network | Verify certificates against the system trust store | `gnutls-system-trust` | LIVE |
| network | Cipher preference | `gnutls-priorities` | LIVE |
| performance | Hardware-accelerated decoding | `dec-dev` | NEXT |
| performance | Video post-processing | `postproc-q` | HIDDEN |
| performance | Skip the H.264 loop filter | `avcodec-skiploopfilter` | NEXT |
| performance | Decoding threads | `avcodec-threads` | NEXT |
| performance | Drop frames when the system can't keep up | `drop-late-frames` | NEXT |
| performance | Give VLC real-time priority | `high-priority` | HIDDEN |
| performance | Decoder | `codec` | NEXT |
| performance | Clock synchronisation | `clock-synchro` | NEXT |
| performance | Clock jitter | `clock-jitter` | NEXT |
| recording | Save recordings to | `input-record-path` | LIVE |
| recording | Record without re-encoding when possible | `input-record-native` | LIVE |
| recording | Cast quality | `sout-chromecast-conversion-quality` | NEXT |
| recording | Play locally while streaming | `sout-display` | NEXT |
| recording | Include audio | `sout-audio` | NEXT |
| recording | Include video | `sout-video` | NEXT |
| recording | Include subtitles | `sout-spu` | NEXT |
| recording | Encoding preset | `sout-x264-preset` | HIDDEN |
| recording | Tuning | `sout-x264-tune` | HIDDEN |
| extensions | Add-ons | `(ExtensionsRows.qml)` | LIVE |
| extensions | Load add-ons on startup | `qt-autoload-extensions` | LAUNCH |
