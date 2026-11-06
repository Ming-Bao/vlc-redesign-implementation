# VLC Redesign: Light theme (slice 10) Design

**Source of truth:** Figma "VLC Redesign (Community)", file key `dSoAm0gN9ZterHSssJU9FN`.

| What | Where |
|---|---|
| The one light frame | `Player - Light 2425:13624` (1920 × 1080): the player with the library side panel open. Shot: `docs/superpowers/figma/10/player-light-2425-13624.png` |
| The light colours | the file's local paint styles `Light/*` (25 styles, below). They pair one-to-one with the `Dark/*` styles every earlier slice used. |
| The video | `redesign source.mp4` never shows the light theme. In the onboarding the user stays on Dark. |

- **Memory `figma-is-the-spec`** applies.
- The user skipped the question round ("skip questions"). Every choice that no frame shows is marked *(my call)*.
- Only one screen has a light frame, so the rest of the app is derived from it by one rule: the **token swap** (below).

## Scope

Make **Light** (Settings ▸ Theme, onboarding) look like the Figma's light theme everywhere the redesign draws, and make **System** follow the desktop's light or dark preference with the same two palettes.

**In scope:**
- the `SystemPalette` light palette;
- every QML surface built in slices 1–9: shell, library, player, panels, mini player, settings, dialogs, Customize Player, onboarding preview;
- the Figma menus (`style/menustyle.cpp`);
- the redesign SVGs with baked colours.

**Out of scope:**
- Skins, the Windows theme provider and VLC's legacy Qt-widgets dialogs. Those follow Qt's own palette, which `MainCtx` already switches with the scheme.
- The onboarding card. It stays dark (see Onboarding).

## The tokens

Figma's local paint styles. "=" means the light value is the same as the dark one.

| Token | Dark | Light (Figma) | Light used *(when not the Figma's)* |
|---|---|---|---|
| FG/1 | `#EAEAEA` | `#EAEAEA` (=) | **`#161616`** *(my call)* |
| FG/2 | `#C6C6C6` | `#C6C6C6` (=) | **`#2E2E2E`** *(my call)* |
| FG/A1 | `#969696` | `#3C3C3C` | |
| FG/A2 | `#8F8F8F` | `#2E2E2E` | |
| FG/A3 | `#6B6B6B` | `#6B6B6B` (=) | |
| FG/A4 | `#404040` | `#3B3B3B` | **`#9B9B9B`** *(my call)* |
| FG/B1 | `#161616` | `#161616` (=) | |
| BG/A1 | `#222222` | `#EDEDED` | |
| BG/A2 | `#1F1F1F` | `#DDDDDD` | |
| BG/A3 | `#1B1B1B` | `#D5D5D5` | |
| BG/A4 | `#191919` | `#B3B3B3` | **`#D5D5D5`** (= Light BG/A3) *(my call)* |
| BG/A5 | `#151515` | `#888888` | **`#DEDEDE`** (= Light BG/B2) *(my call)* |
| BG/B1 | `#0E0E0E` | `#E7E7E7` | |
| BG/B2 | `#090909` | `#DEDEDE` | |
| BG/A3 Transparent | `#191919` 95 % | `#D5D5D5` 75 % | |
| BG/B1 Transparent | `#0E0E0E` 95 % | `#E7E7E7` 80 % | |
| BG/B2 Transparent | `#000000` 80 % | (none) | **`#000000` 80 %** (it dims behind dialogs) *(my call)* |
| Divider/Dim | `#222222` | `#ACACAC` | |
| Divider/Bright | `#373737` | `#9B9B9B` | |
| Accent/Main | `#D37918` | `#E8851A` | |
| Accent/Bright | `#FC9729` | `#FFA13B` | |
| Accent/Dim | `#AB6314` | `#965916` | |
| Accent/Logo | `#D37918` | `#C2711A` | |
| BG/Accent Bright | `#371F06` | `#D8BA9A` | |
| BG/Accent Dark | `#1A1611` | `#C6AB89` | |

**Why the four overrides.** The Figma's light FG/1, FG/2 and FG/A4 and BG/A4, BG/A5 break the ramp they belong to:
- **FG/1 and FG/2** are copies of the dark values. Applied as-is, light grey text sits on a light grey page and can't be read. In dark they are the strongest text, so in light they get the darkest values: FG/B1 for FG/1 and FG/A2 for FG/2.
- **FG/A4** is the dimmest text in dark: placeholders, the off knob. The Figma's light FG/A4, `#3B3B3B`, is darker than FG/A3, so placeholders would outrank real text. It takes Divider/Bright's `#9B9B9B` instead.
- **BG/A4 and BG/A5** are surfaces in dark: the settings face, the sidebar card, text fields, the search box. They are nearly the same as BG/A3 and BG/B2. The Figma's light `#B3B3B3` and `#888888` are mid greys. The frame uses `#888888` only for the volume track (see the player). So in general use A4 takes light A3 and A5 takes light B2.

## The token swap (the rule)

Every colour the redesign takes from a `Dark/*` token takes the same token's light value (the table's last column) when the palette is light.

- **Accent tokens follow the user's accent.** With the default accent, Light uses `#E8851A`. With a picked accent, both themes use the picked hex. The accent-derived tokens are computed from it, as dark already does:
  - **Dark:** BG/Accent Bright = accent × 0.26 (gives `#371F06`); Accent/Dim = `darker(accent, 1.24)`.
  - **Light:** BG/Accent Bright = 30 % accent over `#D1D1D1` (gives `#D8BA9A` from `#E8851A`). Accent/Dim = `darker(accent, 1.55)` (gives about `#965916`). Accent/Bright and BG/Accent Dark are derived the same way if anything uses them. *(my call: these formulas reproduce the Figma's values for the default orange.)*
  - **Logo:** the default is Light Accent/Logo `#C2711A`. A picked accent colours the cone as it does in dark.
- **Literals that aren't a dark token** (for example `#1E1E1E` hover, `#171717`, `#2A2A2A`, `#303030`, `#3A3A3A`, `#202020`): take the light partner of the nearest dark token by lightness. Each one goes in the plan's Ledger with the value it got. *(my call)*
- **Colours with meaning stay:** the record red, the volume gradient, the accent swatches, cover art, `#303030` thumbnail placeholders, and the black dimming behind dialogs.
- **No more "light falls back to VLC 4".** Today about 45 QML bindings read `isDark ? "<Figma dark>" : theme.<VLC 4 colour>`, and about 156 hex literals sit in QML/JS. After this slice no redesign surface uses VLC 4's light colours.

## Where the tokens live

- **One table, in C++,** with both themes. It is the only place a token's hex appears. *(my call: `SystemPalette` and `menustyle.cpp` both need it, and C++ can hand it to QML; a QML table would need a C++ copy.)*
- **`SystemPalette` exposes the active theme's tokens to QML** as one typed property per token (for example `theme.palette.tokens.fgA2`), so a misspelled name fails loudly instead of drawing black. It also carries the accent-derived tokens. Every palette instance answers for its own scheme, so a context that forces `VLCStyle.darkPalette` still gets dark tokens.
- **`makeLightPalette()` is rewritten from the token table,** set by set, mirroring how slice 1 rewrote `makeDarkPalette()`. The `ColorContext` sets (View, Window, Item, Button…) get the light partner of whatever dark gave them. QML that uses `theme.fg.primary` and the like then gets light Figma colours with no further change.
- **QML bindings become one expression,** `theme.palette.tokens.<name>`, with no `isDark` branch where the branch only picked a colour. `SettingsStyle.qml` keeps its role names but reads tokens.
- **The menu style** (`style/menustyle.cpp`, its "dark values only; slice 10" ponytail) reads the tokens of the main theme palette when it paints. Menus open after a theme switch draw in the new theme.
- **Live switching:** changing Theme in Settings recolours every open surface without a restart. This already works for the palette (`paletteChanged`). It must keep working for the tokens and the menus.

## System

- **System picks between the two Figma palettes** by the desktop's dark/light preference: the theme provider's `isThemeDark()` (the GTK provider reads the desktop portal's `color-scheme`, which GTK 3's theme colours ignore), else Qt's colour-scheme hint when no provider answers. It no longer takes the GTK/Qt provider's own colours. *(my call: the redesign has one look per lightness. Adwaita's colours mixed with Figma literals is today's half state.)*
- The provider is kept so a desktop switch still fires `paletteChanged`, and for its CSD metrics and images if the title bar uses them.
- If no provider loads, System takes Qt's colour-scheme hint, else Light.

## The player (frame `2425:13624`)

The frame is the token swap applied to the slice 2/4e player, with these exact values:

| Part | Light |
|---|---|
| Title bar | BG/A3 Transparent (`#D5D5D5` 75 %), 40 high; folder name and centred title `#2E2E2E`; icons `#2E2E2E`; cone Accent/Logo |
| Control bar | BG/A3 Transparent, a 1 px top border in Divider/Dim `#ACACAC`, 54 high; times `#2E2E2E`; icons `#2E2E2E` |
| Seek bar | track BG/B2 `#DEDEDE`, elapsed BG/Accent Bright `#D8BA9A`, handle Accent/Main |
| Play pill | Accent/Main. The frame's pill is `#D37918`, a dark literal left in place; the handle beside it is `#E8851A`. One accent per theme. *(my call)* |
| Volume meter (compact) | track BG/A5 as the Figma has it, `#888888` (not the general A5 override); the same gradient and white 20 % wash as dark. Light shows the meter too. Today `_meter` is dark-only. |
| Rail | BG/A3 Transparent; icons `#2E2E2E`; the active entry in the accent |
| Side panel | BG/B1 Transparent (`#E7E7E7` 80 %); crumbs: current `#2E2E2E`, others `#8F8F8F` and separators `#404040` as the frame has them; "15 items" FG/A3; the forward arrow at 30 % |
| Side panel rows | unwatched names FG/A1 → `#3C3C3C`, watched FG/A3 `#6B6B6B`, the progress line the accent. The frame paints unwatched names `#969696`: an unconverted dark literal that reads lighter than the watched ones and nearly vanishes on `#E7E7E7`. *(my call: the swap keeps watched dimmer, as dark does)* |
| Video area | unchanged (the video). |

- **The player no longer forces night while a video plays.** Today `Player.qml` and `MinimalView.qml` switch to `VLCStyle.darkPalette` when there is embedded video and the controls aren't pinned. The frame shows a light player with a video playing. *(my call: drop the force in both. `ArtistTopBanner` keeps its dark palette, because it sits on artwork.)*
- **No background blur.** The frame's bars have a 25 px backdrop blur, but in a window nothing scrolls under them, and the dark bars have none. *(my call)*
- **Fullscreen overlay bars** use BG/A3 Transparent at 95 % alpha in light, as dark does, so the video under them doesn't wash out the controls. *(my call)*

## Baked SVG colours

Some redesign SVGs are drawn as images with their colours inside:
- `pixmaps/redesign/menu/*`: 42 two-tone menu icons, `#8F8F8F` plus `#AB6314`;
- `mini/*`: 11 files, `#EAEAEA`, `#8F8F8F`, `#D37918`;
- `dialogs/*`: 4 files, `#8F8F8F`, `#6B6B6B`;
- `onboarding/cone.svg`: the accent key `#FF8800`.

- **In light, their greys are swapped at load** for the light partner (`#8F8F8F` → `#2E2E2E`, `#EAEAEA` → `#161616`, `#6B6B6B` stays). QML uses the existing `SVGColorImage` colorizer. `menus.cpp` and `menustyle.cpp` use `colorizeSvg()` (`util/color_svg_image_provider.cpp`). *(my call: no second copy of each icon.)*
- **Baked accent colours stay as they are,** as in slices 7–9. That is the departure already on the roadmap.
- **The icon font** (`VLCIcons.ttf`) is coloured at run time and needs nothing.

## Onboarding

- **The card stays dark** in every theme. All eleven onboarding frames are dark, and the card shows before a theme is chosen. *(my call)*
- **The preview follows the theme tile.** Light draws the small player with the light tokens; Dark draws it dark; System draws whichever the desktop prefers. This removes slice 9's departure ("the preview stays dark for Light and System until slice 10").
- The preview's colours come from the same token table, through a palette for the picked scheme, not from literals.

## Departures (summary for the roadmap row)

- Light FG/1, FG/2, FG/A4, BG/A4 and BG/A5 are not the Figma's values (see the token table).
- The light play pill is the light accent; the frame has the dark `#D37918`.
- The side panel's unwatched names are FG/A1 `#3C3C3C`; the frame has `#969696`.
- No backdrop blur; fullscreen bars are 95 % opaque.
- The player no longer forces dark while a video plays.
- System uses the Figma palettes, chosen by the desktop's dark/light preference, not the desktop's own colours.
- The onboarding card stays dark; its preview follows the tile.
- Baked accent colours in SVGs stay orange (carried over).
- Every surface without a light frame is the token swap of its dark frame.

## Testing

- **C++ (`tests/`):** a token table test. It covers:
  - every dark token has a light partner;
  - the overrides hold;
  - the light accent formulas give `#D8BA9A` and about `#965916` from `#E8851A`;
  - dark still gives `#371F06` from `#D37918`.
- **Grep checks** (scripts in the plan): no `"#xxxxxx"` literal of a dark token is left in QML/JS outside the allow-list ("colours with meaning"); no `isDark ?` branch picks only a colour.
- **Harness, Light, at 1600 × 900:**
  - The player with the side panel open, next to the frame. Compare the title bar, the bars, the seek bar, the volume meter, the rail, the panel and the rows.
  - Shots of every slice-1–9 screen in Light: Home, Videos grid and list, Music, Network, Playlists, Recent; the player panels (tracks, playback, queue, settings tabs); the mini player; the Settings window; each dialog; Customize Player; a menu; the onboarding preview with the Light tile. Each is checked for text that can't be read and for any leftover dark surface.
- **Live switch:** Dark → Light → System in Settings with a menu, the mini player and Settings open. Everything recolours with no restart.
- **System:** with the desktop preference dark and light (`gsettings set org.gnome.desktop.interface color-scheme prefer-dark` / `default` on the Wayland driver, or the provider's test hook), System follows it.
- **Dark unchanged:** before and after shots of the same screens in Dark match pixel for pixel, apart from the listed departures.
- The usual `-vv` log grep for QML errors.
