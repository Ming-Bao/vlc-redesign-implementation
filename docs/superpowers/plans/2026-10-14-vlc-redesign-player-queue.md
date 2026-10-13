# VLC Redesign — Slice 3b: Player Queue Card (queue, bookmarks, chapters) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the player, the queue button opens the Figma queue card instead of VLC 4's side pane. The card has Queue, Bookmarks and Chapters tabs. This slice also closes the deferred slice 3a panel polish (M1, M3, M4, M6, row focus).

**Architecture:**
- The card is a `PlayerPanel`, the slice 3a popover, with two new switches: `fillHeight` and non-modal.
- It replaces the `PlaylistPane` that `Player.qml` loads into `playlistpopup`. Its visibility stays driven by `MainCtx.playqueuePanel.visible` through the existing `PlayerPlaylistVisibilityFSM`. Hotkeys, the queue button, the bar autohide lock and the detached play-queue window therefore keep working unchanged.
- Each tab is one QML page:
  - `QueuePage` lists `PlaylistListModel`.
  - `BookmarksPage` lists `MLBookmarkModel`.
  - `ChaptersPage` lists `Player.chapters`.
- All three pages use one shared 32 px row component, `PanelRow`.

**Tech Stack:**
- Qt 6.11 QML (QtQuick.Templates).
- Existing models: `PlaylistListModel`, `MainPlaylistController`, `MLBookmarkModel`, `ChapterListModel`.
- FontForge icon font pipeline: `pixmaps/makeIconFont.py` and `docs/superpowers/scripts/{clean,flatten}-figma-svg.py`.
- The Xvfb and Wayland harness.

**Spec:**
- Figma file `dSoAm0gN9ZterHSssJU9FN`, `Controls` variants:
  - queue `491:1781`, whose card is `463:831`.
  - bookmarks `6320:13763`.
  - chapters `6321:14024`.
- Panel divider: `496:2652`. Roadmap: `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md`, slice 3.
- Memory `figma-is-the-spec`: Figma is the spec, and VLC 4's play queue pane is not a reference.

## Global Constraints

- **Card:**
  - 400 px wide, radius 10, `#0E0E0E` at 95 %.
  - 20 px from the player's right edge, 20 px above the control bar, 20 px below the top bar.
  - **Full height regardless of content** (Figma 946 px at 1080p).
- **Tab bar:**
  - 50 px tall, `#090909`, then a 1 px gap.
  - Each tab is a 20 px icon, an 8 px gap and a 12 px label.
  - The selected tab is `#8F8F8F` with a 2 px `#D37918` underline; the others are `#6B6B6B`. `PlayerPanel` already draws this.
- **Header row:**
  - Queue: 68 px tall. Bookmarks: 64 px tall. Chapters has no header.
  - 28 px left padding, 20 px right padding.
  - 14 px `#6B6B6B` text, then 24 px icons, 12 px apart, right-aligned.
- **List:**
  - 20 px side padding; rows are 32 px tall with 12 px between them.
  - Labels are 14 px: title `#969696`, trailing time `#6B6B6B`, right-aligned.
  - The chapters list starts 20 px below the tab bar.
- Queue row: a 32 px drag-handle box (24 px icon), a 10 px gap, the title, the duration.
- Bookmark row: name, then time.
- Chapter row:
  - The number is 14 px Medium `#D37918` in a 34 px column.
  - The row has 4 px inner side padding.
  - Then the name, then the time.
- Divider between track-panel sections: 1 px `#222222`.
- Use the dark hex values only when `palette.isDark`; otherwise use ColorContext colours (light theme is slice 10).
- Write sizes as `VLCStyle.dp(n, VLCStyle.scale)` and user strings in `qsTr()`.
- **Icon font:** the 97 existing keys keep their order, because charcodes are assigned by index. New keys are only appended.
- **New QML files:** list each in `modules/gui/qt/meson.build` (module `VLC.Player`, after `'player/qml/PlaybackPanel.qml'`) and `modules/gui/qt/Makefile.am` (after `player/qml/PlaybackPanel.qml \`).
- **Harness:**
  - `H=docs/superpowers/scripts/vlc-xvfb.sh; L=build/redesign-profile/run/vlc.log`.
  - Before each start: `cp /tmp/conf.bak build/redesign-profile/config/vlc/vlc-qt-interface.conf`. If `/tmp/conf.bak` is gone, run `$H seed` once and copy that conf to `/tmp/conf.bak`.
  - Start with `$H start -vv build/redesign-media/plain.mp4 build/redesign-media/tracks2.mkv build/redesign-media/chapters.mkv; sleep 6`. The driver already passes `--aout=dummy`; any hand-rolled run must add it too (memory `redesign-harness`).
- **Coordinates at 1600×900:**
  - The queue button is at (1568, 873), the bar spans y 846–900, and the card spans x 1180–1580, y 60–826.
  - Tab centres sit at y 85: Queue x 1250, Bookmarks x 1380, Chapters x 1510.
  - These are computed from Figma. If a click misses, read the real position from a shot and note it in the ledger.
- **Log check:** every visual check ends with `grep -E "TypeError|ReferenceError|non-existent property|unavailable|Unable to assign|is not a type|Could not convert" $L`. Expected: no output.
- **Saved state:** per-file state persists in `build/redesign-profile/data/vlc/ml/` across runs. Do not move it aside in this slice, because bookmarks need the indexed media.
- **Branch:** `redesign/player-queue`, one commit per task.

## Review Focus

1. **Escape and hotkeys keep the play-queue state in step.**
   - Escape on the card closes it, and the queue button shows unchecked.
   - The next click on the button opens it again (not a no-op double toggle).
   - Ctrl+L (VLC's play-queue hotkey) toggles the card.
   - Pinned in Task 2, Step 6.
2. **Removing the playing item.** Playback moves to the next item, the card stays open, and no QML error appears. Pinned in Task 2, Step 7.
3. **A long queue (300 items)** opens at once and scrolls with the wheel; the list is virtualised, not 300 delegates. Pinned in Task 2, Step 8.
4. **Media the library has not indexed:** the Bookmarks "+" is disabled and the tab shows "0 Bookmarks" with no error. Pinned in Task 4, Step 6.
5. **A modal panel over the queue card.**
   - The tracks panel opens on top of the card.
   - A click outside closes only the tracks panel; the queue card stays.
   - Pinned in Task 2, Step 9.

---

### Task 0: Branch and roadmap

**Files:** Modify `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md`

- [ ] **Step 1:** `git switch -c redesign/player-queue master`
- [ ] **Step 2:** In the roadmap table, replace the slice 3 row with these four rows:
```markdown
| 3a Player panels (done) | Controls subtitles 491:2216, audio 496:2495, video 498:2674, playback 2238:9432 | Tracks panel + playback panel (`PlayerPanel`). |
| 3b Queue card | Controls queue 491:1781, bookmarks 6320:13763, chapters 6321:14024 | Replaces the player's side play queue; plan 2026-10-14-vlc-redesign-player-queue. |
| 3c Settings tabs + effects | Controls video settings 498:2937, audio settings 536:1059, subtitle settings 763:1958; effect accordions 536:1855, 543:990, 614:1430, 6114:13610, 536:1513, 536:1703, 612:1223 | Gear panel gains Video/Audio/Subtitles *settings* tabs (defaults, sync, filters, preset) — not track lists; replaces the effects dialog. |
| 3d Music player | Player-Music 4767:23726, Controls waveform 2139:8124, music 4778:26181 | Waveform seek bar needs decoded peaks — own design pass. |
```
- [ ] **Step 3:** Commit `doc: split the player panels slice in the redesign roadmap`.

### Task 1: Icons for the queue card

**Files:**
- Create: `modules/gui/qt/pixmaps/redesign/queue-tab.svg`, `chapters.svg`, `drag-handle.svg`
- Modify: `modules/gui/qt/pixmaps/redesign/mapping.json`, `modules/gui/qt/pixmaps/VLCIcons.json`
- Regenerate: `modules/gui/qt/pixmaps/VLCIcons.ttf`, `modules/gui/qt/style/vlcicons.hpp`, `vlcicons.cpp`

**Interfaces — produces:**
- `VLCIcons.playqueue`: the Figma queue tab icon (stacked lines).
- `VLCIcons.chapters`: the chapters tab icon.
- `VLCIcons.drag_handle`: the "=" handle on queue rows.

- [ ] **Step 1: Failing check.**
  - Add to `mapping.json`: `"queue-tab.svg": ["playqueue"], "chapters.svg": ["chapters"], "drag-handle.svg": ["drag_handle"]`.
  - Run `python3 -I docs/superpowers/scripts/check-icon-font.py modules/gui/qt/pixmaps`.
  - Expected: FAIL, because FontForge cannot open the SVGs yet.
- [ ] **Step 2: Export the SVGs from Figma.**
  - Load the `figma:figma-use` skill, then run `use_figma` on file `dSoAm0gN9ZterHSssJU9FN`:
```js
const ids = { 'queue-tab': 'I2127:7555;2461:9715', 'chapters': 'I2127:7575;2127:7532', 'drag-handle': 'I463:849;463:418' };
const out = {};
for (const [name, id] of Object.entries(ids)) {
  const n = await figma.getNodeByIdAsync(id);
  out[name] = n ? await n.exportAsync({ format: 'SVG_STRING' }) : null;
}
return out;
```
  - Write each string to `modules/gui/qt/pixmaps/redesign/<name>.svg`.
  - If any id is null, fall back: run `get_design_context` on node `463:831` and download its `imgFrame1` (queue tab), `imgFrame3` (chapters) and `imgFrame8` (drag handle) assets with curl.
  - The drag handle is mirror-symmetric, so the instance's flip does not matter.
- [ ] **Step 3: Clean and flatten.** `python3 -I docs/superpowers/scripts/clean-figma-svg.py modules/gui/qt/pixmaps/redesign/{queue-tab,chapters,drag-handle}.svg && python3 -I docs/superpowers/scripts/flatten-figma-svg.py modules/gui/qt/pixmaps/redesign/{queue-tab,chapters,drag-handle}.svg`
- [ ] **Step 4: Append the keys.**
  - Append to the end of `VLCIcons.json`'s `glyphs`, after `folder`: `{"key": "playqueue", "path": "./redesign/queue-tab.svg"}, {"key": "chapters", "path": "./redesign/chapters.svg"}, {"key": "drag_handle", "path": "./redesign/drag-handle.svg"}`.
  - Then, from `modules/gui/qt/pixmaps`, run `python3 makeIconFont.py VLCIcons.json`.
- [ ] **Step 5: Check.**
  - `check-icon-font.py` must print `icon font OK`.
  - `git diff modules/gui/qt/style/vlcicons.hpp` must show only three added keys, with no existing key renumbered.
  - Render the three glyphs next to the Figma tabs by eye: `python3 -I -c "import fontforge;f=fontforge.open('modules/gui/qt/pixmaps/VLCIcons.ttf');[f[0xE000+i].export(f'/tmp/g{i}.png',64) for i in (97,98,99)]"`.
- [ ] **Step 6:** `ninja -C build`, then commit `qt: add the queue, chapters and drag handle icons from the redesign`.

### Task 2: Queue card with the Queue tab

**Files:**
- Modify: `modules/gui/qt/player/qml/PlayerPanel.qml`, `player/qml/Player.qml` (the `Loader { id: playlistpopup … }` block and its four references), `player/qml/controlbarcontrols/PlaylistButton.qml`
- Create: `player/qml/PanelRow.qml`, `player/qml/QueuePage.qml`, `player/qml/QueuePanel.qml`, `docs/superpowers/scripts/count-px.sh`
- Register the three QML files in `meson.build` and `Makefile.am`.

**Interfaces:**
- Consumes:
  - `VLCIcons.playqueue` and `VLCIcons.drag_handle` from Task 1.
  - `PlayerPanel` (`tabs`, `currentTab`, `maximumHeight`, `colorContext`, `_dark`).
- Produces:
```qml
// PlayerPanel.qml (new)
property bool fillHeight: false   // card takes maximumHeight; each page fills it and scrolls itself
// PanelRow.qml
T.ItemDelegate {
    property alias leading: leadingHolder.data   // optional leading item
    property string trailingText
    property bool current: false    // playing item / current chapter: accent label
    property bool selected: false   // list cursor: tinted background
}
// QueuePanel.qml: PlayerPanel { fillHeight: true; modal: false } holding QueuePage
// QueuePage.qml: ColumnLayout; its ListView `list` has function focusRow() (PlayerPanel.onOpened calls it)
// count-px.sh IMG X Y W H HEX [FUZZ%]: prints how many pixels of the box match HEX
```

Ledger these rulings when executing:
- **The card stays non-modal**, like the pane it replaces. It is toggled by the queue button, its hotkey and Escape, and it does not close on outside clicks. The other panels are pick-and-go; the queue is kept open while watching. Cost if wrong: one extra click to dismiss.
- **The playing item's title is accent-coloured.** Figma's queue frame shows no playing item; the accent matches the chapter numbers.
- **Header text is `"%1 items - %2"`**, with VLC's `formatLong()` duration ("2 h 3 min", not Figma's "2h 3m"), so durations stay translated in one place.
- **Click selects; double-click or Enter plays.** "–" and Delete remove the selected row. This keeps VLC's queue semantics, since Figma doesn't define the interaction.
- **Dropped:** the right-click context menu, search, multi-selection, and dropping files onto the player's top-bar queue button while the card is docked. Cost if wrong: those stay available only in the library's queue pane and the detached queue window.

- [ ] **Step 1: The pixel helper and the failing check.**
  - Create `docs/superpowers/scripts/count-px.sh` (`chmod +x`):
```sh
#!/bin/sh
# usage: count-px.sh IMG X Y W H HEX [FUZZ%] — print how many pixels in the box match HEX within FUZZ (default 12%)
img=$1 x=$2 y=$3 w=$4 h=$5 hex=$6 fuzz=${7:-12}
magick "$img" -crop "${w}x${h}+${x}+${y}" +repage -fuzz "${fuzz}%" -fill white -opaque "$hex" \
    -fuzz 0 -fill black +opaque white -format "%[fx:round(mean*w*h)]" info:
```
  - Then start the harness (Global Constraints) and run:
    ```
    $H click 1568 873; sleep 1; $H shot /tmp/q1.png
    docs/superpowers/scripts/px.sh /tmp/q1.png 1400 760 '#0E0E0E' 14   # card fills down to the bar
    docs/superpowers/scripts/px.sh /tmp/q1.png 1400 70 '#090909' 6     # tab bar at the card top
    docs/superpowers/scripts/count-px.sh /tmp/q1.png 1242 186 300 20 '#969696'   # first row title ink
    ```
  - Expected today: the first two FAIL, because the side pane is a different colour and starts under the top bar.
- [ ] **Step 2: `PlayerPanel.qml`: `fillHeight` and the non-modal mode.**
  - Add after `property real maximumHeight…`:
```qml
    // the card takes maximumHeight and each page fills it (for pages that scroll themselves, like the queue)
    property bool fillHeight: false
```
  - Replace `implicitHeight: Math.min(contentHeight + topPadding + bottomPadding, maximumHeight)` with:
```qml
    implicitHeight: fillHeight ? maximumHeight
                               : Math.min(contentHeight + topPadding + bottomPadding, maximumHeight)
```
  - Show the tab bar whenever there is a tab, as Figma does even for a single tab. This also fixes 3a minor M5, the playback panel's missing "Playback" header. In the tab-bar `Rectangle`, change `visible: root.tabs.length > 1` to `visible: root.tabs.length > 0`.
  - In the `Connections` on the overlay, change the target so non-modal cards ignore outside clicks:
```qml
        target: root.visible && root.modal ? root.T.Overlay.overlay : null
```
  - In `pageFlick`, replace `Layout.preferredHeight: pageHolder.implicitHeight` with `Layout.preferredHeight: root.fillHeight ? -1 : pageHolder.implicitHeight`.
  - In `pageHolder`:
    - Replace `implicitHeight: children[root.currentTab]?.implicitHeight ?? 0` with `implicitHeight: root.fillHeight ? pageFlick.height : (children[root.currentTab]?.implicitHeight ?? 0)`.
    - In `_sync()`, after the width binding, add:
```qml
                        if (root.fillHeight) {
                            const page = children[i]
                            page.height = Qt.binding(() => pageHolder.height)
                        }
```
- [ ] **Step 3: `PanelRow.qml`**
```qml
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.Style
import VLC.Widgets as Widgets

// one 32 px row of the player card lists (Figma queue, bookmarks, chapters): leading item, label, trailing text
T.ItemDelegate {
    id: row

    property alias leading: leadingHolder.data
    property string trailingText
    property bool current: false
    property bool selected: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Item
    }
    readonly property bool _dark: theme.palette.isDark

    implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
    // the list keeps keyboard focus and moves its cursor; rows only take clicks
    focusPolicy: Qt.NoFocus

    background: Rectangle {
        radius: VLCStyle.dp(4, VLCStyle.scale)
        color: row.selected ? Qt.rgba(1, 1, 1, 0.08)
                            : (row.hovered ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
    }

    contentItem: RowLayout {
        spacing: VLCStyle.dp(10, VLCStyle.scale)

        Item {
            id: leadingHolder
            visible: children.length > 0
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }

        Widgets.LabelExt {
            Layout.fillWidth: true
            text: row.text
            elide: Text.ElideRight
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: row.current ? theme.accent : (row._dark ? "#969696" : theme.fg.primary)
        }

        Widgets.LabelExt {
            visible: text.length > 0
            text: row.trailingText
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: row._dark ? "#6B6B6B" : theme.fg.secondary
        }
    }
}
```
- [ ] **Step 4: `QueuePage.qml` and `QueuePanel.qml`**
```qml
// QueuePage.qml
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.PlayerControls
import VLC.Menus
import VLC.Dialogs

// Figma queue tab: count and length with sort/repeat/shuffle/remove/add, then the queue
ColumnLayout {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }
    readonly property bool _dark: theme.palette.isDark

    spacing: 0

    PlaylistListModel {
        id: queueModel
        playlist: MainPlaylistController.playlist
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(68, VLCStyle.scale)
        Layout.leftMargin: VLCStyle.dp(28, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        spacing: VLCStyle.dp(12, VLCStyle.scale)

        Widgets.LabelExt {
            Layout.fillWidth: true
            text: qsTr("%1 items - %2").arg(queueModel.count).arg(queueModel.duration.formatLong())
            elide: Text.ElideRight
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root._dark ? "#6B6B6B" : theme.fg.secondary
        }

        Widgets.SortControl {
            font.pixelSize: VLCStyle.icon_normal
            description: qsTr("Sort")
            enabled: MainPlaylistController.count > 1
            checked: MainPlaylistController.sortKey !== PlaylistController.SORT_KEY_NONE
            popupAbove: false
            model: MainPlaylistController.sortKeyTitleList
            sortKey: MainPlaylistController.sortKey
            sortOrder: (MainPlaylistController.sortOrder === PlaylistController.SORT_ORDER_DESC)
                       ? Qt.DescendingOrder : Qt.AscendingOrder
            onSortSelected: key => { MainPlaylistController.sortKey = key }
            onSortOrderSelected: type => {
                MainPlaylistController.sortOrder = (type === Qt.DescendingOrder)
                        ? PlaylistController.SORT_ORDER_DESC : PlaylistController.SORT_ORDER_ASC
                MainPlaylistController.sort()
            }
        }

        LoopButton { font.pixelSize: VLCStyle.icon_normal }

        RandomButton { font.pixelSize: VLCStyle.icon_normal }

        Widgets.IconToolButton {
            text: VLCIcons.remove
            font.pixelSize: VLCStyle.icon_normal
            description: qsTr("Remove from the queue")
            enabled: list.currentIndex >= 0
            onClicked: list.removeCurrent()
        }

        Widgets.IconToolButton {
            text: VLCIcons.add
            font.pixelSize: VLCStyle.icon_normal
            description: qsTr("Add to the queue")
            onClicked: addMenu.popup(mapToGlobal(0, height), [qsTr("Add File..."), qsTr("Add Folder...")])

            StringListMenu {
                id: addMenu
                ctx: MainCtx
                onSelected: (index) => {
                    if (index === 0)
                        DialogsProvider.simpleOpenDialog(false)
                    else
                        DialogsProvider.PLAppendDir()
                }
            }
        }
    }

    ListView {
        id: list

        // PlayerPanel.onOpened focuses this: the cursor starts on the playing item
        function focusRow() {
            if (currentIndex < 0)
                currentIndex = Math.max(0, MainPlaylistController.currentIndex)
            positionViewAtIndex(currentIndex, ListView.Contain)
            return list
        }

        function removeCurrent() {
            if (currentIndex >= 0)
                queueModel.removeItems([currentIndex])
        }

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)

        model: queueModel
        currentIndex: -1
        spacing: VLCStyle.dp(12, VLCStyle.scale)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        T.ScrollBar.vertical: Widgets.ScrollBarExt { }

        Keys.onReturnPressed: MainPlaylistController.goTo(currentIndex, true)
        Keys.onEnterPressed: MainPlaylistController.goTo(currentIndex, true)
        Keys.onDeletePressed: removeCurrent()

        delegate: PanelRow {
            id: queueRow

            required property int index
            required property var model

            width: ListView.view.width
            text: model.title
            trailingText: model.duration.formatShort()
            current: model.isCurrent
            selected: ListView.isCurrentItem

            leading: Widgets.IconLabel {
                width: VLCStyle.dp(32, VLCStyle.scale)
                height: VLCStyle.dp(32, VLCStyle.scale)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: VLCIcons.drag_handle
                font.pixelSize: VLCStyle.icon_normal
                color: queueRow._dark ? "#8F8F8F" : queueRow.colorContext.fg.secondary
            }

            onClicked: list.currentIndex = index
            onDoubleClicked: MainPlaylistController.goTo(index, true)
        }
    }
}
```
```qml
// QueuePanel.qml
import QtQuick

import VLC.Style

// Figma queue card: stays open while watching (non-modal), fills the height beside the video
PlayerPanel {
    id: root

    tabs: [
        { text: qsTr("Queue"), icon: VLCIcons.playqueue }
    ]

    fillHeight: true
    modal: false
    dim: false

    QueuePage { }
}
```
- [ ] **Step 5: Wire the card in `Player.qml` and fix `PlaylistButton`.**
  - Delete the whole `Loader { id: playlistpopup … }` block, from `Loader {` through its closing brace just before `Dialogs {`. Put this in its place:
```qml
    QueuePanel {
        id: playlistpopup

        // the play queue state (button, hotkey, FSM) decides; the card follows it
        readonly property bool shown: playlistVisibility.isPlaylistVisible && MainCtx.playqueuePanel.docked

        parent: rootPlayer
        x: rootPlayer.width - width - VLCStyle.dp(20, VLCStyle.scale)
        y: rootPlayer.positionSliderY - height - VLCStyle.dp(20, VLCStyle.scale)
        maximumHeight: rootPlayer.positionSliderY - VLCStyle.dp(80, VLCStyle.scale)
        z: 1

        colorContext.palette: windowTheme.palette

        onShownChanged: shown ? open() : close()
        Component.onCompleted: if (shown) open()
        // Escape closes the card itself: keep the play queue state in step
        onClosed: if (playlistVisibility.isPlaylistVisible) playlistVisibility.togglePlaylistVisibility()
    }
```
  - In the TopBar's `plListView:` binding, replace the `if (playlistpopup.active) return playlistpopup.item else ` branch so it reads:
```qml
        plListView: (playlistWindowLoader?.status === Loader.Ready) ? playlistWindowLoader.item.playlistView : null
```
  - A Popup is not an Item. Replace each of the three `return playlistpopup` lines and the `? playlistpopup :` in the toggle button's `Navigation.upItem` with `playlistpopup.contentItem`.
  - In `PlaylistButton.qml`, `playlistWidget` does not exist in the player (the upstream ReferenceError). Guard it:
```qml
        if (MainCtx.playqueuePanel.visible && MainCtx.playqueuePanel.docked
                && typeof playlistWidget !== "undefined") {
```
  - Register `'player/qml/PanelRow.qml'`, `'player/qml/QueuePage.qml'` and `'player/qml/QueuePanel.qml'` in both build files, then run `ninja -C build`.
- [ ] **Step 6: Step 1's checks pass, plus Review Focus 1.**
  - Re-run Step 1. Expected:
    - Both `px.sh` lines print `ok`.
    - `count-px.sh` prints more than 20.
    - The log grep is empty.
    - `/tmp/q1.png` matches `pn_queue.png` by eye (card, header, three rows with handles and durations).
  - Escape: `$H key Escape; sleep 0.5; $H shot /tmp/q2.png`. Expected: `px.sh /tmp/q2.png 1400 760 '#0E0E0E' 14` FAILS (closed).
    - Then `$H click 1568 873; sleep 1; $H shot /tmp/q3.png`. Expected: the same check passes (one click reopens).
  - Hotkey: `$H key ctrl+l; sleep 0.5`, then shoot. Expected: closed. Press it again: open.
- [ ] **Step 7: Selection, play and Review Focus 2.**
  - Double-click the second row: `DISPLAY=:77 xdotool mousemove 1350 240 click --repeat 2 --delay 80 1; sleep 2`. Expected: `grep -c "tracks2.mkv" $L` grows, and the second title turns accent: `count-px.sh <shot> 1242 230 300 20 '#D37918'` prints more than 20.
  - Click the second (now playing) row, then "–", which is about (1512, 145); read the exact spot from `/tmp/q1.png`. Expected:
    - `chapters.mkv` starts playing (`grep chapters.mkv $L`).
    - The card stays open, with two rows.
    - The log grep is empty.
- [ ] **Step 8: Review Focus 3.**
  - `$H start -vv $(for i in $(seq 300); do printf 'build/redesign-media/plain.mp4 '; done); sleep 8`, open the card and shoot.
  - Expected: the header reads "300 items - …", and the card is open within a second of the click.
  - `DISPLAY=:77 xdotool mousemove 1350 500 click --repeat 15 5`, then shoot again. Expected: different rows show.
  - Also `grep -c "PanelRow" $L` is 0 (no per-delegate warnings).
- [ ] **Step 9: Review Focus 5.**
  - With the card open, click the tracks button (1503, 873). Expected: the tracks card draws over the queue card. In the shot, (1400, 700) is inside both cards; check the tracks rows are visible there.
  - Click the video at (600, 400). Expected:
    - The tracks card closes and the queue card stays: `px.sh … 1400 200 '#0E0E0E' 14` is ok.
    - The video did not pause: the log has no `pause` state change after the click.
- [ ] **Step 10:** Commit `qml: show the player's play queue as the Figma queue card`.

### Task 3: Drag a queue row to reorder

**Files:** Modify `modules/gui/qt/player/qml/QueuePage.qml`

**Interfaces — consumes:** `QueuePage`'s `list`, `queueModel` and the delegate's `leading` handle from Task 2. **Produces:** nothing new.

Ledger this ruling when executing: during a drag, the target row shows the selection tint, and on release the row lands there. There is no floating ghost row. Cost if wrong: a less tactile drag.

- [ ] **Step 1: Failing check.**
  - Start the 3-item harness, open the card, and drag row 1's handle onto row 3: `DISPLAY=:77 xdotool mousemove 1216 196 mousedown 1 mousemove 1216 220 mousemove 1216 284 mouseup 1; sleep 1`.
  - Then double-click row 1. Expected after the change: `tracks2.mkv` opens. Today, `plain.mp4` (unchanged order) opens.
- [ ] **Step 2: Add the DragHandler to the handle in the delegate.** Replace the `leading: Widgets.IconLabel { … }` block with:
```qml
            leading: Widgets.IconLabel {
                id: handle

                width: VLCStyle.dp(32, VLCStyle.scale)
                height: VLCStyle.dp(32, VLCStyle.scale)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: VLCIcons.drag_handle
                font.pixelSize: VLCStyle.icon_normal
                color: queueRow._dark ? "#8F8F8F" : queueRow.colorContext.fg.secondary

                // the row lands where the pointer is on release; the cursor tint shows the spot meanwhile
                DragHandler {
                    id: dragHandler

                    target: null
                    xAxis.enabled: false

                    function targetIndex() {
                        const p = list.mapFromItem(null, dragHandler.centroid.scenePosition)
                        const i = list.indexAt(VLCStyle.dp(10, VLCStyle.scale), p.y + list.contentY)
                        if (i >= 0)
                            return i
                        return p.y < 0 ? 0 : list.count - 1
                    }

                    onCentroidChanged: if (active) list.currentIndex = targetIndex()
                    onActiveChanged: {
                        if (active)
                            return
                        const to = targetIndex()
                        if (to !== queueRow.index)
                            queueModel.moveItemsPre([queueRow.index], to > queueRow.index ? to + 1 : to)
                        list.currentIndex = to
                    }
                }
            }
```
- [ ] **Step 3:** Run Step 1 again. Expected: `tracks2.mkv` opens. Also drag row 3 up to row 1, then double-click row 1. Expected: the item that was third plays. The log grep is empty.
- [ ] **Step 4:** Commit `qml: drag queue rows by their handle to reorder`.

### Task 4: Bookmarks tab

**Files:**
- Modify: `modules/gui/qt/medialibrary/mlbookmarkmodel.hpp`, `mlbookmarkmodel.cpp`, `player/qml/QueuePanel.qml`
- Create: `player/qml/BookmarksPage.qml` (register it in both build files)

**Interfaces:**
- Consumes: `PanelRow`, `PlayerPanel`, and the `QueuePanel` tab list from Task 2.
- Produces:
```cpp
// MLBookmarkModel (QML):
Q_PROPERTY(bool canAdd READ canAdd NOTIFY canAddChanged FINAL)   // current media is in the media library
Q_INVOKABLE void add();
Q_INVOKABLE void remove(const QModelIndexList& indexes);
```

Ledger these rulings when executing:
- **Bookmark times use VLC's `formatHMS()`** ("00:42"), not Figma's "00:00:42:023". Cost if wrong: no milliseconds shown.
- **Click selects; double-click or Enter seeks** (`select()`), as in the queue.
- **Without a media library**, the tab is still listed and the page holds only the "0 Bookmarks" header with "+" disabled. That keeps the tabs and pages aligned by index.

- [ ] **Step 1: Failing check.**
  - Start the harness, open the card and shoot `/tmp/b1.png`. Expected today: the "Bookmarks" tab label is missing, so `count-px.sh /tmp/b1.png 1340 78 90 14 '#6B6B6B'` prints 0.
  - Today the Queue tab is alone and centred, at x ≈ 1380, so measure on the shot that this box is clear of it.
- [ ] **Step 2: C++.**
  - In `mlbookmarkmodel.hpp`:
    - Add `Q_PROPERTY(bool canAdd READ canAdd NOTIFY canAddChanged FINAL)` under the `ml` property.
    - Prefix `void add();` and `void remove( const QModelIndexList& indexes );` with `Q_INVOKABLE`.
    - Add `bool canAdd() const { return m_currentMediaId != 0; }` in the public section.
    - Add before `private:`:
```cpp
signals:
    void canAddChanged();
```
  - In `mlbookmarkmodel.cpp`, emit after every write of the id. List the writes with `grep -n "m_currentMediaId = " medialibrary/mlbookmarkmodel.cpp`; today there is one, at line 424. After each, add:
```cpp
            emit canAddChanged();
```
  - `ninja -C build`. Expected: it builds.
- [ ] **Step 3: `BookmarksPage.qml`**
```qml
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player

// Figma bookmarks tab: count with remove/add, then the current media's bookmarks
ColumnLayout {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }
    readonly property bool _dark: theme.palette.isDark
    readonly property var _model: modelLoader.item

    spacing: 0

    // MLBookmarkModel needs the media library; without one the page keeps only its header
    Loader {
        id: modelLoader
        active: MainCtx.mediaLibraryAvailable
        sourceComponent: MLBookmarkModel {
            player: Player
            ml: MediaLib
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(64, VLCStyle.scale)
        Layout.leftMargin: VLCStyle.dp(28, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        spacing: VLCStyle.dp(12, VLCStyle.scale)

        Widgets.LabelExt {
            Layout.fillWidth: true
            text: qsTr("%1 Bookmarks").arg(list.count)
            elide: Text.ElideRight
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root._dark ? "#6B6B6B" : theme.fg.secondary
        }

        Widgets.IconToolButton {
            text: VLCIcons.remove
            font.pixelSize: VLCStyle.icon_normal
            description: qsTr("Remove bookmark")
            enabled: list.currentIndex >= 0
            onClicked: list.removeCurrent()
        }

        Widgets.IconToolButton {
            text: VLCIcons.add
            font.pixelSize: VLCStyle.icon_normal
            description: qsTr("Add bookmark")
            enabled: root._model?.canAdd ?? false
            onClicked: root._model.add()
        }
    }

    ListView {
        id: list

        function focusRow() {
            if (currentIndex < 0 && count > 0)
                currentIndex = 0
            return list
        }

        function removeCurrent() {
            if (currentIndex >= 0)
                root._model.remove([root._model.index(currentIndex, 0)])
        }

        function seekCurrent() {
            if (currentIndex >= 0)
                root._model.select(root._model.index(currentIndex, 0))
        }

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)

        model: root._model
        currentIndex: -1
        spacing: VLCStyle.dp(12, VLCStyle.scale)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        T.ScrollBar.vertical: Widgets.ScrollBarExt { }

        Keys.onReturnPressed: seekCurrent()
        Keys.onEnterPressed: seekCurrent()
        Keys.onDeletePressed: removeCurrent()

        delegate: PanelRow {
            required property int index
            required property var model

            width: ListView.view.width
            text: model.name
            trailingText: model.time
            selected: ListView.isCurrentItem

            onClicked: list.currentIndex = index
            onDoubleClicked: { list.currentIndex = index; list.seekCurrent() }
        }
    }
}
```
  - In `QueuePanel.qml`, append `{ text: qsTr("Bookmarks"), icon: VLCIcons.bookmark }` to `tabs`, and add `BookmarksPage { }` after `QueuePage { }`.
  - Register the page and run `ninja -C build`.
- [ ] **Step 4: Run the checks.**
  - Re-run Step 1. Expected: more than 0.
  - Click the Bookmarks tab (1380, 85), then "+" at about (1548, 143). Expected: the header reads "1 Bookmarks", and `count-px.sh <shot> 1200 182 280 20 '#969696'` prints more than 20 (the row "Bookmark at 00:0x").
  - Watch the log grep for `Could not convert`. If the `remove([index])` call shows it, add `Q_INVOKABLE void removeAt(int row) { remove({ index(row, 0) }); }` to the header and call `root._model.removeAt(currentIndex)`.
- [ ] **Step 5: Seek and remove.**
  - Let the media play for 3 s, double-click the bookmark row, then shoot. Expected: the time label in the bar shows the bookmark's time again, give or take 1 s.
  - Click the row, then "–". Expected: "0 Bookmarks".
- [ ] **Step 6: Review Focus 4.**
  - `mkdir -p /tmp/unindexed && cp build/redesign-media/plain.mp4 /tmp/unindexed/x.mp4`, then start the harness with `/tmp/unindexed/x.mp4` and open the Bookmarks tab.
  - Expected: "0 Bookmarks", the "+" is drawn in the disabled colour and clicking it adds nothing, and the log grep is empty.
- [ ] **Step 7:** Commit `qml: bookmarks tab in the player queue card`.

### Task 5: Chapters tab

**Files:**
- Create: `modules/gui/qt/player/qml/ChaptersPage.qml` (register it in both build files)
- Modify: `player/qml/QueuePanel.qml`

**Interfaces — consumes:** `PanelRow` (the `leading` slot and `current`) and `QueuePanel` from Tasks 2 and 4. `Player.chapters` (`ChapterListModel`) provides roles `display`, `checked` (current chapter) and `time` (`VLCTime`), plus `selectChapter(int)`.

Ledger this ruling when executing: a single click jumps to the chapter, because there is nothing to remove, so no selection step is needed. Media without chapters shows a centred "No chapters" caption.

- [ ] **Step 1: Failing check.** Start the harness with `build/redesign-media/chapters.mkv` (chapters "One" at 0 s and "Two" at 30 s) and open the card. Expected: no third tab; `count-px.sh <shot> 1470 78 90 14 '#6B6B6B'` prints 0.
- [ ] **Step 2: `ChaptersPage.qml`**
```qml
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player

// Figma chapters tab: number, name and start time of each chapter; a click jumps there
Item {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }
    readonly property bool _dark: theme.palette.isDark

    Widgets.LabelExt {
        anchors.centerIn: parent
        visible: list.count === 0
        text: qsTr("No chapters")
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        color: root._dark ? "#6B6B6B" : theme.fg.secondary
    }

    ListView {
        id: list

        function focusRow() {
            currentIndex = Math.max(0, currentIndex)
            return list
        }

        anchors.fill: parent
        anchors.topMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)

        model: Player.chapters
        spacing: VLCStyle.dp(12, VLCStyle.scale)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        T.ScrollBar.vertical: Widgets.ScrollBarExt { }

        Keys.onReturnPressed: Player.chapters.selectChapter(currentIndex)
        Keys.onEnterPressed: Player.chapters.selectChapter(currentIndex)

        delegate: PanelRow {
            id: chapterRow

            required property int index
            required property var model

            width: ListView.view.width
            leftPadding: VLCStyle.dp(4, VLCStyle.scale)
            rightPadding: VLCStyle.dp(4, VLCStyle.scale)
            text: model.display
            trailingText: model.time.formatHMS()
            current: model.checked
            selected: ListView.isCurrentItem && list.activeFocus

            leading: Widgets.LabelExt {
                width: VLCStyle.dp(34, VLCStyle.scale)
                text: chapterRow.index + 1
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                font.weight: Font.Medium
                color: chapterRow.colorContext.accent
            }

            onClicked: Player.chapters.selectChapter(index)
        }
    }
}
```
  - In `QueuePanel.qml`, append `{ text: qsTr("Chapters"), icon: VLCIcons.chapters }` to `tabs`, and add `ChaptersPage { }` last.
  - Register the page and run `ninja -C build`.
- [ ] **Step 3: Run the checks.**
  - Re-run Step 1. Expected: more than 0.
  - Click the Chapters tab (1510, 85) and shoot. Expected:
    - Two rows, "1 One" and "2 Two", with accent numbers: `count-px.sh <shot> 1204 137 30 20 '#D37918'` is more than 5.
    - Row 1's name is accent, because it is the current chapter.
  - Click row 2 at (1350, 191), wait 1 s and shoot. Expected:
    - The bar time reads 00:30 or later.
    - Row 2's name is accent: `count-px.sh <shot> 1250 181 200 20 '#D37918'` is more than 10.
- [ ] **Step 4: No chapters.** Play `plain.mp4` and open Chapters. Expected: "No chapters" is centred, and the log grep is empty.
- [ ] **Step 5:** Commit `qml: chapters tab in the player queue card`.

### Task 6: Panel polish deferred from slice 3a

**Files:** Modify `modules/gui/qt/player/qml/PlayerPanel.qml`, `TrackSection.qml`, `TracksPanel.qml`, `PlaybackPanel.qml`

**Interfaces:**
- Consumes: `PlayerPanel.onOpened`'s page-focus logic.
- Produces: `PlayerPanel.focusPage()`, the same logic, callable. Also `TrackSection.divider: bool`.

This task covers the 3a ledger minors M1, M3, M4 and M6, plus the faint row focus. M5 is fixed in Task 2, Step 2. M2 (focus reason after Escape), M7 (pre-start playlist lock) and M8 (windowed cursor) stay deferred.

- [ ] **Step 1: Failing checks**, one per item, with the tracks panel (1503, 873) open on `tracks2.mkv`:
  - **M1:** With focus on the Subtitles page's first row, press Up. Expected after the fix: focus is on the Subtitles tab (the current one), not Video. Check it by pressing Down, then Return: today nothing happens from the header.
  - **M6:** On the Subtitles tab, shoot `/tmp/p6.png`. A 1 px `#222222` divider runs the card's width between "Embedded Tracks" and "External Tracks". Check with `count-px.sh /tmp/p6.png 1180 100 400 700 '#222222' 2`: expected more than 350 after the fix (one full line), and about 0 today.
  - **M3:** Open the playback panel (1536, 873). Press Right on the speed slider 3 times from 1×. Expected after the fix: the speed label reads "1.15x". Today it may read "1.1500000000000001x" or odd rates.
  - **M4:** Click Reverse on `plain.mp4`, where most inputs refuse a negative rate. Shoot 100 ms and 600 ms later. Expected after the fix: both shots show OFF. Today the first shows ON (the flicker).
- [ ] **Step 2: M1, in `PlayerPanel.qml`.**
  - Move `onOpened`'s body into `function focusPage()` on the root and make `onOpened: focusPage()`.
  - In the tab delegate, add:
```qml
                        // only the current tab is in the focus chain: Up from the first row lands on it
                        focusPolicy: checked ? Qt.StrongFocus : Qt.ClickFocus
                        Keys.onDownPressed: root.focusPage()
```
- [ ] **Step 3: M6 and row focus, in `TrackSection.qml`.**
  - Add `property bool divider: false` and, as the first child:
```qml
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        visible: root.divider
        color: root._dark ? "#222222" : theme.border
    }
```
  - Add bottom padding after the `Repeater` (the Figma rows frame is 18 px taller than its rows):
```qml
    Item { implicitHeight: VLCStyle.dp(18, VLCStyle.scale) - root.spacing }
```
  - In `TrackRow`:
    - Add `readonly property ColorContext colorContext: ColorContext { id: rowTheme; colorSet: ColorContext.Item; focused: row.visualFocus }`.
    - Make the background `color: row.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"; border.width: row.visualFocus ? VLCStyle.focus_border : 0; border.color: rowTheme.visualFocus`.
  - In `TracksPanel.qml`, set `divider: true` on the "Output Device" and "External Tracks" sections.
- [ ] **Step 4: M3 and M4, in `PlaybackPanel.qml`.**
  - Speed slider: add `snapMode: T.Slider.SnapAlways`, and make `onMoved: Player.rate = (Player.rate < 0 ? -1 : 1) * Math.round(value * 100) / 100`.
  - Reverse switch: set `checkable: false` so a click never flips it by itself. Replace its click handler body with just `Player.reverse()`. `checked: Player.rate < 0` then never loses its binding, so delete the `checked = Qt.binding(...)` restore line.
- [ ] **Step 5:** Re-run every Step 1 check. Expected: all pass, and the log grep is empty. Re-run `fixchecks.sh` (memory `redesign-harness`; its audio row is at y ≈ 690) and `dismiss.sh` if they are in the session scratchpad. Otherwise repeat their C1/I1/I3 steps by hand from the slice 3a plan.
- [ ] **Step 6:** Commit `qml: player panel polish (tab focus, section dividers, speed steps, reverse switch)`.

### Task 7: Wayland pass and suites

- [ ] **Step 1:** `dbus-run-session -- docs/superpowers/scripts/wl-drive.py /tmp/s3bwl <steps>`: open the queue card, switch through all three tabs, and shoot each. Expected: the card sits at the bottom right at full height, and the log grep is empty.
- [ ] **Step 2:** `meson test -C build --suite qt` → 9/9. Player tests: 22 OK. `test_modules_misc_medialibrary` segfaults in the system libmedialibrary's exit handlers; this is known and pre-existing.
- [ ] **Step 3:** Silence check: `grep -c "aout=dummy" docs/superpowers/scripts/vlc-xvfb.sh docs/superpowers/scripts/wl-drive.py`. Expected: 1 in each.
