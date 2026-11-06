# VLC Redesign: Onboarding (slice 9) Design

**Source of truth:** Figma "VLC Redesign (Community)", file key `dSoAm0gN9ZterHSssJU9FN`, plus `redesign source.mp4`.

| Page | Frames | Video |
|---|---|---|
| Welcome | `1899:3055` | 19:52–19:54 |
| Theme and colour | `1902:3670` (orange, Back + Next), then one frame per accent: `1902:4020` red, `1902:4325` yellow, `1902:4634` green, `1902:4940` cyan, `1902:5245` blue, `1902:5550` purple, `1902:6160` pink, `1902:6465` grey | 19:55 |
| Keyboard shortcuts | `1902:6770` | 19:56–19:59 |

All frames are 1090 × 759: a card `#0E0E0E`, radius 14, shadow 0 4 11.8 `#00000061`.

- **Reference shots:** `docs/superpowers/figma/9/onboarding-NN-<node>.png`.
- **Memory `figma-is-the-spec`** applies. The user skipped the question round ("skip questions"), so every choice no frame or video shows is marked *(my call)*.
- **What the video settles:**
  - The card stands alone, with no main window around it.
  - The theme page has Back and Next. Frames `1902:4020`…`6465` show Next only, but they are colour variants of `1902:3670`, so all of them get Back. *(my call)*
  - Finish closes it.

## Scope

Replace VLC's Qt-widgets `FirstRunWizard` with a three-page QML onboarding card, and make the accent colour apply live.

Out of scope:
- **The light theme** (slice 10). Light and System are stored, and the app uses VLC 4's light palette until slice 10, as Settings does today. The onboarding card itself stays dark.
- **The old wizard's privacy page and layout page.** See Departures.

## Window

- **A frameless modal window** over the main window, built on `DialogCard.qml` (slice 8). It reuses that file's placement, the 90 % screen cap, the shadow and the drag. *(my call: the video shows the card alone; a separate window is the closest match and needs no change to the main view.)*
- **No title bar and no footer bar.** `DialogCard` gains `showHeader: false`. The buttons sit inside the page, as in the frames. The card can still be dragged by its empty background. *(my call)*
- **Size:** 1090 × 759 Figma px × `VLCStyle.scale`, fixed.
- **Shown** where `MainCtx` now calls `THEDP->firstRunDialog()` (when `qt-privacy-ask` is on, queued after startup). `DialogsProvider::firstRunDialog()` emits a signal that the QML side opens, the way slice 8 routed `openNetDialog`. It holds global shortcuts like the slice 8 dialogs (`MainCtx.holdGlobalShortcuts`).
- **Escape, and closing the window from the WM**, end onboarding the way the old wizard's reject did: `qt-privacy-ask` is set to 0 and the config saved. Nothing else is changed, and no folder is added. *(my call: the frames have no close button. Without this, a keyboard user is stuck on first launch.)*
- **The old `FirstRunWizard`** (`dialogs/firstrun/*`, its `.ui`, meson and qt6.pro entries) is deleted. *(my call: nothing else opens it.)*

## Shared parts

- **Buttons:** 100 × 32, radius 6, Inter SemiBold 16.
  - Next and Finish: fill = the chosen accent, text `#161616`.
  - Back: fill `#1B1B1B`, text `#8F8F8F`.
  - Placement: Next/Finish at right 62, bottom 56. Back is 8 to its left (right 170).
- **Text field:** `#090909`, border 2 `#191919`, radius 6, height 36, padding 8/18/8/12, Inter 16 `#C6C6C6`. This is slice 8's field at 16 px.
- **Page headings:** Inter 24, `#969696`, centred. The theme page's heading is Light; the shortcuts page's is Regular.
- **Enter** activates Next or Finish. A focus ring (`VLCStyle.focus_border`, accent) marks keyboard focus on every control. *(my call)*

## Page 1: Welcome

| Part | Figma |
|---|---|
| Cone | 141 × 141, centred, top 116, filled with the accent. The frame's asset is VLC's cone; reuse the redesign's existing cone glyph or SVG if it matches, otherwise export it from the frame. |
| "Welcome to VLC!" | Inter Light 32, `#EAEAEA`, centred, top 286 |
| Body | Inter Light 16, line height 1.75, `#969696`, width 595, centred, top 362. Text as in the frame. |
| Folder block | left 248, top 500, width 595, gap 16 |
| "Choose a Media Folder to get started with" | Inter 14, `#8F8F8F` |
| Field + Browse | row, gap 10. The field fills the row. Browse is 114 wide: `#1B1B1B`, radius 6, Inter 16 `#8F8F8F`. |
| Next | as above |

**Behaviour:**
- **The field starts with the XDG Videos folder** (`config_GetUserDir(VLC_VIDEOS_DIR)`). It is shown with `~` for the home folder, as in the frame. If there is no Videos folder, the field starts empty with the placeholder `e.g., ~/Videos` in `#404040`. *(my call)*
- **Browse** opens the system folder picker, starting at the field's folder. Picking a folder fills the field.
- **The field is editable.** `~` is expanded. Next is disabled (50 % opacity, like slice 8's Save) while the field holds text that is not an existing folder. An empty field is allowed and means no folder. *(my call)*
- **The folder is not added until Finish**, so Back loses nothing.
- **With no media library** (`vlc_ml_instance_get` is null), the folder block is hidden.

## Page 2: Theme and colour

| Part | Figma (frame `1902:3670`) |
|---|---|
| Preview | A player window drawn small (the `Player` instance at 0.55): a title bar with the cone (accent) and min, max, fullscreen and close; an empty `#090909` video area; and the control bar (`Controls`, 29.7 high, `#191919` at 95 %). The control bar has: prev, play (accent pill), next; time `00:02:10`; seek bar with accent fill and a dim accent track; `00:25:40`; volume; and the bar's right icons. Centred, 1056 wide, from the top of the card to 594 down. |
| Heading | "Select your preferred theme and color.", over the preview, top 173 |
| Theme tiles | three, 116 × 157, at x 331 / 487 / 643, top 286, gap 22 to the label. Each is a 116 × 116 frame (radius 19, padding 8) around a 100 × 100 swatch (radius 12). Selected: a 4 px accent ring outside the frame. Label Inter Light 16, `#8F8F8F`, centred. |
| Light | swatch `#AFAFAF` |
| Dark | swatch `#222222` |
| System | swatch `#222222` with an `#AFAFAF` diagonal over the right part (the frame's gradient) |
| Accent swatches | nine 64 × 64 cells at x 41 + 80·i, top 655. Each is a 40 × 40 dot centred in the cell. Unselected: 50 % opacity. Selected: full opacity and a 4 px ring of the accent at 30 %, inside the cell (radius 32). |
| Colours | `#D37918`, `#E15032`, `#C49E23`, `#19A234`, `#18AAD3`, `#185DD3`, `#8E42FF`, `#F052B3`, `#AFAFAF`. These are slice 7's `AccentRow` swatches; one list is shared. |
| Back, Next | as above |

**Behaviour:**
- **Picking a swatch recolours the whole card at once:** the preview's accents, the theme ring, the Next and Finish buttons, the welcome cone, and the focus rings. This is what the eight colour frames show.
- **A theme tile only moves the ring.** The preview stays dark until slice 10. *(my call)*
- **Dark is always preselected.** The card only appears on a first run, so the frame's Dark wins over VLC's System default. The accent preselects the current `qt-accent-color`, so a command-line `--qt-accent-color` shows. *(my call)*
- **Nothing is written until Finish.**

## Page 3: Keyboard shortcuts

| Part | Figma |
|---|---|
| Heading | "Learn the basic keyboard shortcuts.", top 60 |
| Grid | two columns from left 62, top 154, 150 apart. Each column has a 220-wide label column (Inter Light 16, `#969696`, rows 54 apart) and a 153-wide key column (rows 40 apart), gap 20. |
| Key cap | `#1B1B1B`, border 3 `#373737`, radius 12, shadow 0 6 0 `#5C5C5C40`, padding 4/20 (one letter or word) or 4/12 (an arrow or a symbol), Inter Light 16 `#EAEAEA`. Pairs are joined by a `/` in `#969696` with gap 10. Chords (SHIFT + S) use gap 4. |
| Footer note | "Find the full list in the menu.", Inter 16, `#6B6B6B`, left 62, on the buttons' line |
| Back, Finish | as above |

**Rows and keys.** The labels are Figma's. The keys are the user's real bindings, read from the `key-*` options. Only the first binding of a tab-separated list is shown; modifiers are split into caps and written in upper case (`SHIFT`, `CTRL`); arrows are shown as ← → ↑ ↓. *(my call: slice 5's menus already show VLC's real keys. The Figma's keys differ from VLC's defaults: Figma has ← → for seeking, VLC has Shift+← →; Figma has < >, VLC has p n; and so on. Showing keys that don't work would teach the wrong thing.)*

| Left column | option(s) | Right column | option(s) |
|---|---|---|---|
| Play / Pause | `key-play-pause` | Toggle Fullscreen | `key-toggle-fullscreen` |
| Seek Backward / Forward | `key-jump-extrashort` / `key-jump+extrashort` | Increase / Decrease Volume | `key-vol-up` / `key-vol-down` |
| Previous / Next Item | `key-prev` / `key-next` | Show / Hide Queue | the queue toggle, `Ctrl+L` (`GlobalShortcuts.qml`) |
| Previous / Next Frame | `key-frame-previous` / `key-frame-next` | Show / Hide File Browser | a new shortcut, see below |
| Cycle Subtitle Track | `key-subtitle-track` | Take a Snapshot | `key-snapshot` |
| Cycle Audio Track | `key-audio-track` | Record | `key-record` |

- **Show / Hide File Browser** has no shortcut today. Add `Ctrl+Shift+L` in `GlobalShortcuts.qml`. It toggles the player's library side panel (4e, `PlayerControlbarControls.libraryPanelOpen`) while `MainCtx.playerView` is true, and does nothing elsewhere. *(my call: Figma's `L` is VLC's loop key and Ctrl+B is bookmarks. Ctrl+Shift+L pairs with the queue's Ctrl+L. The builder confirms it is free.)*
- **A row whose binding is empty** shows a single cap with "—". *(my call)*
- **The cap split is a small pure JS function** (`OnboardingKeys.js`). Slice 8's `HotkeyModel::displayKeys` joins whole bindings with `, ` and cannot split a chord into caps, but the spelling of `Esc` follows it (`esc`).

## Finish

In order:
1. **Theme:** `MainCtx.colorScheme.setScheme(...)` with the chosen scheme.
2. **Accent:** `qt-accent-color` is set to `default` for the orange, or to the hex for the others, as `AccentRow` does. Then it is applied live (below).
3. **Folders:** the field's folder, if any, is added to the media library as an entry point. The XDG Music folder is added too, if it exists and isn't the same folder or inside it. *(my call: the old wizard added Videos and Music. Slice 4c's Music page is empty without a music folder, and the harness's `seed` relies on it.)*
4. **Done:** `qt-privacy-ask` = 0, the media library is reloaded, and the config is saved (`config_SaveConfigFile`), as the old wizard's `finish()` did.

**Not touched:** `metadata-network-access`, `qt-menubar`, `qt-titlebar`, `qt-pin-controls` and the control-bar profile all keep their defaults. *(my call. See Departures.)*

## Live accent

Today `SystemPalette` reads `qt-accent-color` once, in `componentComplete`. The accent therefore only changes on the next launch (a slice 7 call).

- **Move that read into `SystemPalette::updatePalette()`.** The theme providers (`systempalettethemeprovider`, `gtkthemeprovider`) already re-read the option on every palette update.
- **Add a signal:** `MainCtx::accentColorChanged()`. Every `SystemPalette` reruns `updatePalette()` when it fires. Finish emits it after writing the option.
- **Settings' `AccentRow` emits it too.** Settings' accent then applies at once, and the slice 7 "next launch" departure is removed from the roadmap. *(my call: same signal, and it removes a known wart.)*
- **Baked-orange SVGs stay orange.** That was already the case in slice 7.

## Departures (summary for the roadmap row)

- No privacy page. `metadata-network-access` keeps its default, off, and stays reachable in Settings ▸ Network. The old wizard asked for consent; the Figma has no such page. Leaving the option off is the privacy-safe reading.
- No layout page (modern or classic). The redesign has one layout.
- Keys are the real bindings, not the Figma's.
- A new `Ctrl+Shift+L` toggles the file browser.
- Escape skips onboarding.
- The Music folder is added alongside the chosen folder.
- Dark is preselected on a first run.
- The preview stays dark for Light and System until slice 10.
- The accent becomes live everywhere.

## Testing

- **C++ (`tests/`):** a folder rule test. It covers: `~` expansion; empty → no folder; a missing path → invalid; and Music skipped when it is the same folder as the chosen one or inside it. The rule lives in a small free function so it can be tested without the ML.
- **QML (`tst_*.qml`):** the key-cap split. Cases: `Shift+s` → `SHIFT`, `S`; `Left` → `←`; a tab list → its first entry; empty → `—`.
- **Harness:**
  - Rewrite `vlc-xvfb.sh seed` for the new pages: Next, Next, Finish. The point of `seed` is unchanged: index `build/redesign-{media,music}` from XDG Videos and Music.
  - Take a shot of each page: Welcome; theme with orange; theme with green; shortcuts. Compare them with the frames.
  - After Finish with green, the main window's accent is green with no restart.
  - Escape on page 1 leaves `qt-privacy-ask=0` and adds no folder.
  - The usual `-vv` log grep for QML errors.
