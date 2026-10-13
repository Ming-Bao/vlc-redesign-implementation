# VLC Redesign — Roadmap (Figma = spec)

Target: faithful implementation of Figma "VLC Redesign (Community)" (`dSoAm0gN9ZterHSssJU9FN`) and
`redesign source.mp4` (same design, different context). VLC 4's existing design is NOT a reference.
Slice 1 (done, merged): dark tokens, sidebar card, title bar, page header, flat "…" menu, compact mini bar.

| Slice | Scope (Figma nodes) | Notes |
|---|---|---|
| 2 Player + global look | Player frames 247:445, 187:328, hide-UI 3328:11554; Controls default variant (491:1780); Inter font; icon set 42:356 → VLCIcons.ttf | Player keeps window title bar (folder + centred title), video not overlaid (pinned), solid compact bar, new default Videoplayer/Audioplayer layouts. Icons: export SVG via `exportAsync({format:'SVG_STRING'})` (stroke-based, 24px, #8F8F8F; strokes must be expanded to fills before `pixmaps/makeIconFont.py`, needs python3-fontforge). Inter: `rsms-inter-fonts` (Fedora) or bundle OFL. |
| 3 Player panels | Controls variants: queue, bookmarks, chapters, subtitles, playback, sub timeline, audio, video, *settings; effect panels 536:1855, 543:990, 614:1430, 6114:13610, 536:1513, 536:1703, 612:1223; Player-Music 4767:23726 (waveform seek) | Replaces TracksMenu/extended dialog in-player. |
| 4 Library | Home 6261:15078 (Continue Watching / Listen Again / Frequently Visited), grid/list 970:4028/970:3792, sidebar component 848:1996 (Home, Videos, Music, Network, Playlists, Recent, Add item), breadcrumbs, Sorting Options 856:2215, View Options 858:3290, search field | |
| 5 Menus | menu 6062:13354 + Profiles 6648:20666, right-click 6065:13616, file/folder/playlist context menus 2404:13340, 2139:8935, 2459:9389 | QML-styled menus with Figma icons. |
| 6 Mini player card | Miniplayer 970:3091 (5 variants incl. queue) | Floating card over library. |
| 7 Settings window | 17 "Settings - *" frames (999:5047 …) | Replaces Preferences dialog. |
| 8 Dialogs | Open network stream 6216:13614, New playlist 6259:14954, Add subtitles 1911:7545…, Keyboard shortcuts 2437:14832, Customize player 2107:5604… | |
| 9 Onboarding | 11 "Onboarding" frames (1899:3055 …) | Replaces first-run wizard. |
| 10 Light theme | Player - Light 2425:13624 | |

Each slice: writing-plans → user review → executing-plans; verify against Figma frames with
`docs/superpowers/scripts/vlc-xvfb.sh` (X11) and `wl-drive.py` (Wayland).
