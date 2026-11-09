# VLC Redesign

A full redesign of the **VLC media player** interface, built on VLC 4's engine.
It implements the community Figma design *"VLC Redesign"* as a new Qt/QML
interface: a new player, library, menus, mini player, settings, dialogs,
onboarding and a light theme.

> **Beta.** This is an unofficial fork, not a VideoLAN release. Expect rough edges.
> Report problems on the [issue tracker](https://github.com/Ming-Bao/vlc-redesign-implementation/issues).

## What's new

- **Player**: a pinned video with a solid control bar, a new icon set and the Inter font;
  tracks, playback, queue, bookmarks and chapters panels; per-type video, audio and
  subtitle settings that replace the old effects dialog; a seek bar thumbnail preview.
- **Music player**: a waveform seek bar and a cover-art layout.
- **Library**: Home (Continue Watching, Listen Again, frequently visited folders, playlists
  and artists), folder-based Videos and Music, Network (streams, podcasts, radio),
  Playlists and Recent, with a side panel you can open beside the player.
- **Mini player**: a floating card over the library.
- **Menus, Settings and dialogs**: every menu, the Settings window, Open Network Stream,
  New Playlist, Add Subtitles (including OpenSubtitles with your own API key),
  Keyboard Shortcuts and Customize Player are redrawn. Most settings apply at once.
- **Onboarding**: a three-page first-run card (welcome, theme and colour, shortcuts).
- **Themes**: dark, light, or follow the system, with a choice of accent colour.

## Download

Get the latest build from [Releases](https://github.com/Ming-Bao/vlc-redesign-implementation/releases).

| Platform | File | Notes |
|---|---|---|
| Windows 10/11 (64-bit) | `vlc-redesign-*-win64.exe` | Installer. Installs next to regular VLC, as "VLC Redesign". A portable `.zip` is also provided. |
| macOS 12+ (Apple Silicon) | `vlc-redesign-*-macos-arm64.dmg` | Not signed: right-click the app and choose **Open** the first time. |
| Linux (x86-64) | `vlc-redesign-*-x86_64.AppImage` | `chmod +x` it and run. Needs a recent distribution (2025 or later). |

The builds are not code-signed, so Windows SmartScreen and macOS Gatekeeper will warn on first launch.

## Uninstall

Each package removes the app **and** its settings, media library and caches.

- **Windows**: *Settings ▸ Apps ▸ VLC Redesign ▸ Uninstall* (or `uninstall.exe` in the
  install folder). "Delete preferences and cache" is ticked by default. For the portable zip, run
  `uninstall.cmd` from the extracted folder.
- **macOS**: run `Uninstall VLC Redesign.command` from the disk image.
- **Linux**: run `uninstall.sh` (from the release) and give it the AppImage's path:
  `sh uninstall.sh ~/Applications/vlc-redesign-x86_64.AppImage`.

**Note:** this fork keeps VLC's settings folders (`%APPDATA%\vlc`, `~/Library/Preferences/org.videolan.vlc`,
`~/.config/vlc` and friends). If you also use regular VLC, uninstalling
resets its settings too.

## Building from source

The fork builds like VLC 4. It needs Qt 6 (with the Network module) and Meson 1.10 or later:

```sh
meson setup build
ninja -C build
build/bin/vlc-static
```

See [INSTALL](INSTALL) and the [VLC hacking guide](https://wiki.videolan.org/Hacker_Guide) for
dependencies. Release packaging lives in `.github/workflows/release.yml`.

Design notes, per-slice specs and plans are in [`docs/superpowers/`](docs/superpowers/);
[the roadmap](docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md) lists what each
slice changed and where it departs from the Figma.

## Credits

- Redesign implementation: Ming Bao and Galen Green (see [AUTHORS](AUTHORS)).
- Design: the community Figma file *"VLC Redesign"*.
- Engine and everything else: [VLC](https://www.videolan.org/vlc/) by VideoLAN and its
  contributors. This project is not affiliated with or endorsed by VideoLAN; VLC is a
  VideoLAN trademark.

## License

Like VLC, this is released under the GPLv2 *(or later)*; libVLC is LGPLv2 *(or later)*.
See [COPYING](COPYING) and [COPYING.LIB](COPYING.LIB).
