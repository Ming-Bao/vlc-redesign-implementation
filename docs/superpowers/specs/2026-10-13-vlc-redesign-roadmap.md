# VLC Redesign — Roadmap (Figma = spec)

Target: faithful implementation of Figma "VLC Redesign (Community)" and
`redesign source.mp4` (same design, different context). VLC 4's existing design is NOT a reference.
Figma file keys: `dSoAm0gN9ZterHSssJU9FN` (the original; readable from ming's Figma account, use this one) and Galen's duplicate
`d9xvroRclV6SaObbcqRmBr` (not readable from ming's account). Node IDs are identical in both.
Reference renders of each slice's frames are committed under `docs/superpowers/figma/<slice>/` (1920 frames rendered at 1600 wide,
so fixed-size elements look ~1.2× larger in 1600 px VLC shots than in these renders).
Slice 4 is split into 4a–4e (2026-10-16); each part gets its own spec → plan → build cycle, in order.
Slice 1 (done, merged): dark tokens, sidebar card, title bar, page header, flat "…" menu, compact mini bar.

| Slice | Scope (Figma nodes) | Notes |
|---|---|---|
| 2 Player + global look | Player frames 247:445, 187:328, hide-UI 3328:11554; Controls default variant (491:1780); Inter font; icon set 42:356 → VLCIcons.ttf | Player keeps window title bar (folder + centred title), video not overlaid (pinned), solid compact bar, new default Videoplayer/Audioplayer layouts. Icons: export SVG via `exportAsync({format:'SVG_STRING'})` (stroke-based, 24px, #8F8F8F; strokes must be expanded to fills before `pixmaps/makeIconFont.py`, needs python3-fontforge). Inter: `rsms-inter-fonts` (Fedora) or bundle OFL. |
| 3a Player panels (done) | Controls subtitles 491:2216, audio 496:2495, video 498:2674, playback 2238:9432 | Tracks panel + playback panel (`PlayerPanel`). |
| 3b Queue card | Controls queue 491:1781, bookmarks 6320:13763, chapters 6321:14024 | Replaces the player's side play queue; plan 2026-10-14-vlc-redesign-player-queue. |
| 3c Settings tabs + effects (done) | Controls video settings 498:2937, audio settings 536:1059, subtitle settings 763:1958; effect accordions 536:1855, 543:990, 614:1430, 6114:13610, 536:1513, 536:1703, 612:1223 | Gear panel gains Video/Audio/Subtitles *settings* tabs (defaults, sync, filters, preset) — not track lists; replaces the effects dialog. Plan 2026-10-14-vlc-redesign-player-settings; HDR, Geometry/Overlay/Advanced, stereo Test, embedded sub format and size units omitted (no VLC feature / no design). |
| 3d Music player (done) | Player-Music 4767:23726, Controls waveform 2139:8124, music 4778:26181 | Plan 2026-10-16-vlc-redesign-music-player; waveform via hidden-player decode (transcode→smem), music only; lyrics/visualisation row dropped (pure Figma). |
| 4a Library shell (spec written, plan next) | Videos grid 970:4028 (sidebar 970:4043, header row 1040:2669, breadcrumbs 6153:13642, search 1040:2876), Sorting Options 856:2215, View Options 858:3290 | Spec 2026-10-16-vlc-redesign-library-shell-design (branch `redesign/library-shell`). Sidebar = exactly Home, Videos, Music, Network, Playlists, Recent, Add item; Discover → "…" menu > More; Preferences footer dropped (Settings is in "…"); Videos/Music sub-items become temporary in-page tabs until 4c. Header: breadcrumbs, item count, Figma sort + view menus, always-visible search, "…" (Add File / Add Folder / Rescan). Add item = menu (Add folder to library / Open network stream / New playlist). Playlists/Recent open VLC's existing views until 4d. |
| 4b Library Home | Home 6261:15078; sidebar variant home 1106:5633 (section list) | Continue Watching, Listen Again, Frequently Visited Folders / Playlists / Artists, "Title ›" headers; drop VLC 4's Open File/Open Disc banner and New Videos/New Music rows. |
| 4c Videos & Music browsing | grid 970:4028, list 970:3792; sidebar variants videos 848:1997 / 4778:25847 / 4778:25957, music 858:5001 / 4767:23606 / 4778:24990 | Folder-based: Videos root = library folders (Shows/Films/Anime) → subfolders → files; Music root = Add, Songs, Albums, Artists, Genres → folders → tracks; breadcrumbs extend with folders. Figma grid card (316 wide at 1920, 16:9, radius 12, 20 % dark overlay, title 16 px #969696; watched = #6B6B6B title + 4 px accent progress line) and 4-column compact list rows. "Add" rows. Removes 4a's temporary tabs. |
| 4d Network, Playlists, Recent | sidebar variants network 858:5294, playlists 858:5374 | Network: Add Network Stream, Podcasts, Radio. Playlists: Create playlist + list. Recent page layout. |
| 4e Player side panel | sidebar component 848:1996 (variant Default 848:1995; an instance sits off-canvas in Player - Music 4767:23726) | Compact icon rail + browse panel (same 4b–4d content, narrow) that slides in beside the player. |
| 5 Menus | menu 6062:13354 + Profiles 6648:20666, right-click 6065:13616, file/folder/playlist context menus 2404:13340, 2139:8935, 2459:9389 | QML-styled menus with Figma icons. |
| 6 Mini player card | Miniplayer 970:3091 (5 variants incl. queue) | Floating card over library. |
| 7 Settings window | 17 "Settings - *" frames (999:5047 …) | Replaces Preferences dialog. |
| 8 Dialogs | Open network stream 6216:13614, New playlist 6259:14954, Add subtitles 1911:7545…, Keyboard shortcuts 2437:14832, Customize player 2107:5604… | |
| 9 Onboarding | 11 "Onboarding" frames (1899:3055 …) | Replaces first-run wizard. |
| 10 Light theme | Player - Light 2425:13624 | |

Each slice: writing-plans → user review → executing-plans; verify against Figma frames with
`docs/superpowers/scripts/vlc-xvfb.sh` (X11) and `wl-drive.py` (Wayland).
