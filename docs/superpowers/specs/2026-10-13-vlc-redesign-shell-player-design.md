# VLC Redesign — Shell + Player (slice 1) Design

Source of truth: Figma "VLC Redesign (Community)", file key `dSoAm0gN9ZterHSssJU9FN`, plus `redesign source.mp4` (Juxtopposed redesign video) in the repo root (untracked).

## Context

VLC 4 master already ships much of the redesign: the fullscreen player (thin seek bar with times above, white
play button with accent ring, ±10 s skip, cast/fullscreen, `⋮` + play-queue buttons top-right, media title
under the back button) and an icon sidebar with a panel toggle. This slice closes the remaining gaps in the
**window shell** and the **compact (mini) player bar**. Settings, Open-Media dialogs, the Home page sections,
onboarding and the floating mini-player card are out of scope (later slices).

## Design tokens (Figma variables, dark theme)

| Token | Value | Used for |
|---|---|---|
| Dark/Accent/Main | `#D37918` | accent: selected icons, play pill, seek handle, checks |
| Dark/BG/B1 | `#0E0E0E` | window/sidebar outer background, page background |
| Dark/BG/A4 | `#191919` | sidebar inner card, title bar (`#191919` @ 95 %) |
| Dark/BG/A5 | `#151515` | text-field background |
| mini bar bg | `#1B1B1B` | compact player bar |
| seek track | `#090909` | compact seek/volume track |
| seek elapsed | `#371F06` | compact seek elapsed fill |
| Dark/FG/2 | `#C6C6C6` | primary text, selected sidebar label |
| Dark/FG/A2 | `#8F8F8F` | secondary text, unselected sidebar label, window title |
| Dark/FG/A3 | `#6B6B6B` | tertiary text ("110 items"), paused play pill |
| Dark/Divider/Dim | `#222222` | header divider |

Typography: Inter Regular 14 (sidebar, title bar, counts), 16 (page header crumbs), 20 (section titles).

## Components

1. **Title bar** (40 px, `#191919`@0.95): left = VLC cone (24 px) + `…` menu button (28 px) [+ panel toggle];
   centre = window title, 14 px `#8F8F8F`; right = minimize, maximize, **fullscreen**, close (36×24 each).
   Back/forward move out of the title bar into the page header.
2. **Sidebar** (expanded, 217 px): outer `#0E0E0E`, padding 8; inner card `#191919`, radius 6, padding 12/16,
   item spacing 14; item = 24 px icon + 8 px gap + 14 px label, row height 32. Selected: accent icon, `#C6C6C6`
   label, no left indicator bar; unselected: `#8F8F8F`. Labels: Home, **Videos**, Music, **Network**, …
3. **Page header** (row height 34, then 1 px `#222222` divider, 17 px gap): back (←) and forward (→) 24 px icons
   with 12 px gap, page title 16 px `#8F8F8F`; right group: "N items" 14 px `#6B6B6B`, sort, grid/list, search,
   all 20 px apart.
4. **`…` main menu** (flat, icons + shortcuts): Open File(s) Ctrl+O · Open Folder Ctrl+F · Open Network Stream
   Ctrl+N · Open Disc Ctrl+D · Open Capture Device Ctrl+C · Convert Ctrl+R · Open Recent › — Customize Player ·
   Settings Ctrl+P · About VLC Shift+F1.
5. **Compact player bar** (Mini player, 54 px, `#1B1B1B`, padding 11/20, gap 20): left = previous, **play pill**
   (54×28, radius 6, accent; paused-state pill `#6B6B6B`), next; centre = current time (15 px `#8F8F8F`),
   **block seek bar** (28 px tall, `#090909`, radius 6; elapsed `#371F06` radius 4 inset 2; handle 8×24 accent
   radius 4), duration; right = volume, audio/subtitle tracks, playback settings, play queue.

## Decisions

- Keep features the Figma omits (Discover entry, Preferences footer, Tools/View/Help menus) reachable;
  the flat `…` menu gets them under a trailing separator ("More" submenus) rather than deleting them.
- Multi-level breadcrumbs ("Videos › Shows › …"), the always-visible search field, Playlists/Recent/Add item
  sidebar entries and the volume gradient meter are deferred to slice 2 (they need new views/models).
- Dark theme only for this slice; light theme keeps current values.
- New default control-bar layouts only affect new profiles; users' saved profiles are untouched.
