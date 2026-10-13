# VLC Redesign — Slice 3a: Player Panels (tracks + playback) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace VLC 4's full-width tracks menu with the Figma tracks panel: a vertical card at the bottom right, with Video/Audio/Subtitles tabs and tick lists. Make the "Extended settings" button open the Figma playback panel (reverse, audio visualizer, speed) in place of the effects dialog window.

**Architecture:**
- `PlayerPanel.qml` is one reusable popover: a T.Popup holding a 400 px card, a tab header, one page per tab and an optional footer button.
- `TrackSection.qml` is a titled tick list. It binds to any of VLC's check-role models: TrackListModel, AudioDeviceModel or VLCVarChoiceModel. All of them have roles `display`/`checked`, and selecting a row is `setData(idx, true, Qt.CheckStateRole)`.
- `TracksPanel.qml` and `PlaybackPanel.qml` are built from those two.
- `LangButton` and `ExtendedSettingsButton` load the panels with the Loader/lock/menuOpened wiring LangButton already uses.

**Tech Stack:** Qt 6 QML (QtQuick.Templates), the existing PlayerController models, and the Xvfb and Wayland harness scripts in `docs/superpowers/scripts/`.

**Spec:** Figma `dSoAm0gN9ZterHSssJU9FN`, `Controls` variants: subtitles `491:2216`, audio `496:2495`, video `498:2674`, playback `2238:9432` (panel `5187:24308`). Reference screenshots: `scratchpad/figma/pn_subs.png`, `pn_audio.png`, `pn_video.png`, `pn_playback.png`. Roadmap: `docs/superpowers/specs/2026-10-13-vlc-redesign-roadmap.md`, slice 3.

## Global Constraints

- Figma is the spec (memory `figma-is-the-spec`); VLC 4's tracks menu is not a reference.
- Panel card:
  - 400 px wide, radius 10, background `#0E0E0E` at 95 % opacity.
  - Its right edge is 20 px from the player's right edge, and its bottom is 20 px above the top of the control bar.
- Tab header:
  - 50 px tall, `#090909`.
  - Each tab is a 20 px icon, a 6 px gap and a 12 px label.
  - The selected tab's label is `#8F8F8F` with a 2 px accent (`#D37918`) underline; the others are `#6B6B6B`.
- Section title row: 60 px tall, 28 px side padding, 14 px `#6B6B6B` text, with any action icons right-aligned in the row.
- Track row:
  - 32 px tall, 12 px between rows, 20 px side padding.
  - A 32 px tick box (accent tick when checked, empty otherwise), a 10 px gap, then a 14 px `#969696` label that elides.
- Footer button: 360×32, `#090909`, radius 4, with 20 px around it.
- Use the dark hex values only when `palette.isDark`; otherwise use ColorContext colours (light theme is slice 10).
- Write sizes as `VLCStyle.dp(n, VLCStyle.scale)` and user strings in `qsTr()`.
- List every new QML file in both `modules/gui/qt/meson.build` and `modules/gui/qt/Makefile.am`, next to `player/qml/TracksMenu.qml`.
- QML inline components cannot see ids outside themselves, even in the same file. Pass colours into them as properties.
- Every visual check runs VLC with `-vv`, then `grep -E "TypeError|ReferenceError|non-existent property|unavailable|Unable to assign" build/redesign-profile/run/vlc.log`. Expected: no output.
- X11 check setup:
  - `cp /tmp/conf.bak build/redesign-profile/config/vlc/vlc-qt-interface.conf`
  - `docs/superpowers/scripts/vlc-xvfb.sh start build/redesign-media/tracks2.mkv; sleep 6`
  - Coordinates: the player bar spans y 846–900, the tracks button is at (1503, 873), and the card spans x 1180–1580.
- Branch `redesign/player-panels`, with one commit per task.

## Review Focus

1. **"None" in Subtitles** unselects the current subtitle. The log shows `unselected` for `spu/…` and no new spu selection, and the None row is ticked. Pinned in Task 1, Step 6.
2. **Media with no track of a kind** (for example, the Video tab for an audio-only file) shows only "None", ticked, with no gap and no QML error. Pinned in Task 3, Step 3.
3. **Fullscreen**: while a panel is open, the bars stay shown. The bars' forced hide (`forceUnlock`) closes the panel. Pinned in Task 3, Step 4.
4. **Long track names** elide inside the card and never widen it past 400 px. Pinned in Task 1, Step 7.
5. **Keyboard**: Up/Down walk the rows, Left/Right switch tabs from the header, and Enter or Space selects. Escape closes the panel and returns focus to the button. Pinned in Task 3, Steps 1 and 5.

---

### Task 0: Branch

- [ ] `git switch -c redesign/player-panels`

### Task 1: `PlayerPanel` + `TrackSection` + `TracksPanel`, opened by LangButton

**Files:**
- Create: `modules/gui/qt/player/qml/PlayerPanel.qml`, `modules/gui/qt/player/qml/TrackSection.qml`, `modules/gui/qt/player/qml/TracksPanel.qml`
- Modify: `modules/gui/qt/player/qml/controlbarcontrols/LangButton.qml` (the Loader's `sourceComponent`)
- Modify: `modules/gui/qt/meson.build`, `modules/gui/qt/Makefile.am`

**Interfaces — produces:**
```qml
// PlayerPanel.qml
T.Popup {
    property var tabs: []           // [{text, icon}]; header hidden when < 2
    property int currentTab: 0
    property string footerText: ""  // footer hidden when empty
    signal footerClicked()
    default property alias pages: pageHolder.data   // one Item per tab, in tab order
    readonly property ColorContext colorContext
    readonly property bool _dark
}
// TrackSection.qml
ColumnLayout {
    property string title
    property var model           // check-role model, or null for a title-only section
    property bool showNone: true // prepend a "None" row that unselects all
    property alias actions: actionRow.data
    readonly property Item firstRow   // Task 3 focuses it on open
}
// TracksPanel.qml
PlayerPanel { }   // tabs Video, Audio, Subtitles; opens on Subtitles
```

- [ ] **Step 1: Failing check.** With the harness running, run `vlc-xvfb.sh click 1503 873; sleep 1; vlc-xvfb.sh shot /tmp/s3-1.png`, then:
  ```
  px.sh /tmp/s3-1.png 1400 640 '#0E0E0E' 14   # inside the Figma card
  px.sh /tmp/s3-1.png 1170 640 '#0E0E0E' 14   # 10 px left of the card: must not be panel
  ```
  - Expected today: the first check FAILS. The old menu is a full-width three-column popup at the slider, and (1400, 640) is above it, on video.
  - After the change: the first check passes and the second fails.

- [ ] **Step 2: `PlayerPanel.qml`**
```qml
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.Style
import VLC.Widgets as Widgets

T.Popup {
    id: root

    property var tabs: []
    property int currentTab: 0
    property string footerText: ""
    default property alias pages: pageHolder.data

    signal footerClicked()

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    readonly property bool _dark: theme.palette.isDark

    width: VLCStyle.dp(400, VLCStyle.scale)
    padding: 0
    focus: true
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutsideParent

    background: Rectangle {
        radius: VLCStyle.dp(10, VLCStyle.scale)
        color: root._dark ? Qt.rgba(0x0E / 255, 0x0E / 255, 0x0E / 255, 0.95) : theme.bg.primary
    }

    contentItem: ColumnLayout {
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: VLCStyle.dp(50, VLCStyle.scale)
            visible: root.tabs.length > 1
            topLeftRadius: VLCStyle.dp(10, VLCStyle.scale)
            topRightRadius: VLCStyle.dp(10, VLCStyle.scale)
            color: root._dark ? "#090909" : theme.bg.secondary

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: root.tabs

                    delegate: T.TabButton {
                        id: tab

                        required property int index
                        required property var modelData

                        readonly property color _fg: checked ? (root._dark ? "#8F8F8F" : theme.fg.primary)
                                                             : (root._dark ? "#6B6B6B" : theme.fg.secondary)

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        checked: root.currentTab === index
                        text: modelData.text
                        onClicked: root.currentTab = index

                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: VLCStyle.dp(6, VLCStyle.scale)

                                Widgets.IconLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.icon
                                    font.pixelSize: VLCStyle.dp(20, VLCStyle.scale)
                                    color: tab._fg
                                }

                                Widgets.ListLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.text
                                    font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
                                    color: tab._fg
                                }
                            }
                        }

                        background: Item {
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - VLCStyle.dp(16, VLCStyle.scale)
                                height: VLCStyle.dp(2, VLCStyle.scale)
                                color: theme.accent
                                visible: tab.checked
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: pageHolder

            Layout.fillWidth: true
            implicitHeight: children[root.currentTab]?.implicitHeight ?? 0

            function _sync() {
                for (let i = 0; i < children.length; ++i) {
                    children[i].visible = (i === root.currentTab)
                    children[i].width = Qt.binding(() => pageHolder.width)
                }
            }

            onChildrenChanged: _sync()

            Connections {
                target: root
                function onCurrentTabChanged() { pageHolder._sync() }
            }
        }

        T.Button {
            id: footer

            Layout.fillWidth: true
            Layout.margins: VLCStyle.dp(20, VLCStyle.scale)
            implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
            visible: root.footerText.length > 0
            text: root.footerText
            onClicked: root.footerClicked()

            background: Rectangle {
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: root._dark ? "#090909" : theme.bg.secondary
                border.width: footer.visualFocus ? VLCStyle.focus_border : 0
                border.color: theme.visualFocus
            }

            contentItem: Widgets.ListLabel {
                text: footer.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._dark ? "#8F8F8F" : theme.fg.primary
            }
        }
    }
}
```

- [ ] **Step 3: `TrackSection.qml`**
```qml
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.Style
import VLC.Widgets as Widgets

ColumnLayout {
    id: root

    property string title
    property var model: null
    property bool showNone: true
    property alias actions: actionRow.data
    readonly property Item firstRow: noneRow.visible ? noneRow : (rows.count > 0 ? rows.itemAt(0) : null)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }
    readonly property bool _dark: theme.palette.isDark
    readonly property color _labelColor: _dark ? "#969696" : theme.fg.primary

    // bumped on every model change so _anyChecked re-evaluates (the models have no notifier for it)
    property int _rev: 0
    readonly property bool _anyChecked: {
        void(_rev)
        if (!model)
            return false
        for (let i = 0; i < model.rowCount(); ++i)
            if (model.data(model.index(i, 0), Qt.CheckStateRole))
                return true
        return false
    }

    // uncheck every checked row except `except`
    function _uncheckAll(except) {
        for (let i = 0; i < model.rowCount(); ++i) {
            const idx = model.index(i, 0)
            if (i !== except && model.data(idx, Qt.CheckStateRole))
                model.setData(idx, false, Qt.CheckStateRole)
        }
    }

    Connections {
        target: root.model
        ignoreUnknownSignals: true
        function onDataChanged() { root._rev++ }
        function onRowsInserted() { root._rev++ }
        function onRowsRemoved() { root._rev++ }
        function onModelReset() { root._rev++ }
    }

    spacing: VLCStyle.dp(12, VLCStyle.scale)

    component TrackRow : T.ItemDelegate {
        id: row

        property bool ticked: false
        property color tickColor
        property color labelColor

        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
        focusPolicy: Qt.StrongFocus

        Accessible.role: Accessible.RadioButton
        Accessible.checked: ticked

        background: Rectangle {
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: (row.visualFocus || row.hovered) ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        }

        contentItem: RowLayout {
            spacing: VLCStyle.dp(10, VLCStyle.scale)

            Widgets.IconLabel {
                Layout.preferredWidth: VLCStyle.dp(32, VLCStyle.scale)
                horizontalAlignment: Text.AlignHCenter
                text: row.ticked ? VLCIcons.check : ""
                color: row.tickColor
                font.pixelSize: VLCStyle.icon_normal
            }

            Widgets.ListLabel {
                Layout.fillWidth: true
                text: row.text
                elide: Text.ElideRight
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: row.labelColor
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(60, VLCStyle.scale) - root.spacing
        Layout.leftMargin: VLCStyle.dp(28, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(28, VLCStyle.scale)

        Widgets.ListLabel {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root._dark ? "#6B6B6B" : theme.fg.secondary
        }

        Row {
            id: actionRow
            spacing: VLCStyle.dp(12, VLCStyle.scale)
        }
    }

    TrackRow {
        id: noneRow

        visible: root.showNone && !!root.model
        text: qsTr("None")
        ticked: !root._anyChecked
        tickColor: theme.accent
        labelColor: root._labelColor
        onClicked: root._uncheckAll(-1)
    }

    Repeater {
        id: rows

        model: root.model

        delegate: TrackRow {
            required property var model
            required property int index

            text: model.display
            ticked: model.checked
            tickColor: theme.accent
            labelColor: root._labelColor
            onClicked: {
                if (model.checked)
                    return
                model.checked = true
                // the video track model selects simultaneously; the Figma list is single-choice
                root._uncheckAll(index)
            }
        }
    }
}
```

- [ ] **Step 4: `TracksPanel.qml`**
```qml
import QtQuick
import QtQuick.Layouts

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs

PlayerPanel {
    id: root

    tabs: [
        { text: qsTr("Video"), icon: VLCIcons.topbar_video },
        { text: qsTr("Audio"), icon: VLCIcons.topbar_music },
        { text: qsTr("Subtitles"), icon: VLCIcons.audiosub }
    ]
    currentTab: 2

    footerText: qsTr("Show Preferences")
    onFooterClicked: {
        root.close()
        DialogsProvider.prefsDialog()
    }

    ColumnLayout {
        spacing: 0

        TrackSection { Layout.fillWidth: true; title: qsTr("Embedded Tracks"); model: Player.videoTracks }
    }

    ColumnLayout {
        spacing: 0

        TrackSection { Layout.fillWidth: true; title: qsTr("Embedded Tracks"); model: Player.audioTracks }
        TrackSection { Layout.fillWidth: true; title: qsTr("Output Device"); model: Player.audioDevices; showNone: false }
    }

    ColumnLayout {
        spacing: 0

        TrackSection { Layout.fillWidth: true; title: qsTr("Embedded Tracks"); model: Player.subtitleTracks }

        TrackSection {
            Layout.fillWidth: true
            title: qsTr("External Tracks")

            actions: Widgets.IconToolButton {
                text: VLCIcons.add
                description: qsTr("Add subtitle file")
                onClicked: {
                    root.close()
                    DialogsProvider.loadSubtitlesFile()
                }
            }
        }
    }
}
```
Ledger these rulings when executing:
- VLC's track model has no embedded/external flag, so every subtitle track is listed under "Embedded Tracks", and "External Tracks" carries only the add action. Cost if wrong: loaded subtitle files show under Embedded.
- The Figma "edit" action (subtitle sync) is not on the panel. It is still reachable through Effects and Filters › Synchronization.
- Audio "Output Device" has no refresh icon, because VLC refreshes devices by itself.

- [ ] **Step 5: LangButton and registration.**
  - In `LangButton.qml`, replace the Loader's `sourceComponent: TracksMenu {` header and its `x`/`y`/`focus` lines as shown below. Keep `id: menu`, `parent`, `z`, `colorContext.palette`, `onOpened` and `onClosed` exactly as they are.
    ```qml
            sourceComponent: TracksPanel {
                id: menu

                parent: root._parentItem

                x: parent.width - width - VLCStyle.dp(20, VLCStyle.scale)
                y: parent.positionSliderY - height - VLCStyle.dp(20, VLCStyle.scale)
                z: 1
    ```
  - Add `'player/qml/PlayerPanel.qml'`, `'player/qml/TrackSection.qml'` and `'player/qml/TracksPanel.qml'` after `'player/qml/TracksMenu.qml'` in `meson.build`.
  - Add the same paths, each followed by ` \`, after `player/qml/TracksMenu.qml \` in `Makefile.am`.
  - Run `ninja -C build`. Expected: it builds.
- [ ] **Step 6: Run the Step 1 checks again.** Expected: the first passes, the second fails, and the log grep is empty. Compare `/tmp/s3-1.png` with `pn_subs.png` by eye.
  - **Review Focus 1:**
    - Click the "Dialogue" row. Expected: `grep "ES track" vlc.log` shows `selected` for `spu/`.
    - Click "None". Expected: the log shows `unselected` for that `spu/` with no new spu `selected` line, and the shot shows the tick on None.
  - Switch the Audio tab to "Track 2". Expected: the log shows `selected` for `audio/`.
- [ ] **Step 7: Review Focus 4.**
  - Make a long-title copy: `ffmpeg -y -i build/redesign-media/tracks2.mkv -c copy -metadata:s:s:0 title="Presented By EMBER — Dialogue [English] (forced) with a very long name" build/redesign-media/longsub.mkv`
  - Start it with the harness, open the panel, and shoot `/tmp/s3-long.png`.
  - Expected: `px.sh /tmp/s3-long.png 1170 640 '#0E0E0E' 14` FAILS (the card did not widen), and the row label visibly ends in "…".
- [ ] **Step 8: Commit** `qml: redesign the tracks menu as the Figma side panel`.

### Task 2: Playback panel on the "Extended settings" button

**Files:**
- Create: `modules/gui/qt/player/qml/PlaybackPanel.qml` (register it in meson.build and Makefile.am, like Task 1)
- Modify: `modules/gui/qt/player/qml/controlbarcontrols/ExtendedSettingsButton.qml`

**Interfaces — consumes:** `PlayerPanel` (`tabs`, `footerText`, `footerClicked`, `colorContext`, `_dark`) from Task 1. **Produces:** `PlaybackPanel`, a PlayerPanel with one "Playback" tab, so its header is hidden.

Ledger these rulings when executing:
- The Figma playback panel also has Video/Audio/Subtitles tabs. Those duplicate TracksPanel, which is one click away, so this panel gets a single tab.
- "Show Subtitle Timeline on Seekbar", "Show Statistics" and "Sleep Timer" have no VLC feature behind them. Their rows are omitted rather than shown inert.
- Speed reuses `PlaybackSpeed.qml` unchanged (0.25–4 log scale, shift-snapping). The 16 px Figma bar with 0.25–2 ticks is later polish. Cost if wrong: the slider looks like VLC's until restyled.
- The footer, "Effects and Filters", keeps `DialogsProvider.extendedDialog()` reachable.

- [ ] **Step 1: Failing check.**
  - Run `vlc-xvfb.sh click 1463 873; sleep 2; DISPLAY=:77 xdotool search --name "Adjustments and Effects"`. EXTENDED sits left of LANG, so it is about 40 px left of 1503. If the click misses, read the button's x from a shot.
  - Expected today: a window id is printed.
  - After the change: nothing is printed, and `px.sh 1400 700 '#0E0E0E' 14` passes.
- [ ] **Step 2: `PlaybackPanel.qml`**
```qml
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs

PlayerPanel {
    id: root

    readonly property color _labelColor: _dark ? "#6B6B6B" : colorContext.fg.secondary
    readonly property color _fieldColor: _dark ? "#090909" : colorContext.bg.secondary
    readonly property color _valueColor: _dark ? "#8F8F8F" : colorContext.fg.primary

    tabs: [ { text: qsTr("Playback"), icon: VLCIcons.effect_filter } ]

    footerText: qsTr("Effects and Filters")
    onFooterClicked: {
        root.close()
        DialogsProvider.extendedDialog()
    }

    component SettingRow : RowLayout {
        property alias label: lbl.text
        property color labelColor

        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(52, VLCStyle.scale)
        Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        spacing: VLCStyle.dp(12, VLCStyle.scale)

        Widgets.ListLabel {
            id: lbl
            Layout.fillWidth: true
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: parent.labelColor
        }
    }

    ColumnLayout {
        spacing: 0

        Item { Layout.preferredHeight: VLCStyle.dp(8, VLCStyle.scale) }

        SettingRow {
            label: qsTr("Reverse")
            labelColor: root._labelColor

            T.Switch {
                id: reverseSwitch

                implicitWidth: VLCStyle.dp(68, VLCStyle.scale)
                implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
                checked: Player.rate < 0
                onToggled: Player.reverse()
                Accessible.name: qsTr("Reverse")

                indicator: Rectangle {
                    anchors.fill: parent
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: root._fieldColor
                    border.width: reverseSwitch.visualFocus ? VLCStyle.focus_border : 0
                    border.color: root.colorContext.visualFocus

                    Rectangle {
                        x: reverseSwitch.checked ? parent.width - width - VLCStyle.dp(4, VLCStyle.scale)
                                                 : VLCStyle.dp(4, VLCStyle.scale)
                        y: VLCStyle.dp(4, VLCStyle.scale)
                        width: parent.width / 2 - VLCStyle.dp(4, VLCStyle.scale)
                        height: parent.height - VLCStyle.dp(8, VLCStyle.scale)
                        radius: VLCStyle.dp(4, VLCStyle.scale)
                        color: reverseSwitch.checked ? root.colorContext.accent : "#191919"

                        Widgets.ListLabel {
                            anchors.centerIn: parent
                            text: reverseSwitch.checked ? qsTr("ON") : qsTr("OFF")
                            font.pixelSize: VLCStyle.dp(10, VLCStyle.scale)
                            color: root._valueColor
                        }
                    }
                }
            }
        }

        SettingRow {
            label: qsTr("Audio Visualizer")
            labelColor: root._labelColor

            Widgets.ComboBoxExt {
                id: visCombo

                Layout.preferredWidth: VLCStyle.dp(220, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(48, VLCStyle.scale)
                model: Player.audioVisualization
                textRole: "display"
                bgColor: root._fieldColor
                color: root._valueColor

                // re-read whenever the panel opens; the model has no "current index" property
                currentIndex: {
                    void(root.opened)
                    for (let i = 0; i < model.rowCount(); ++i)
                        if (model.data(model.index(i, 0), Qt.CheckStateRole))
                            return i
                    return 0
                }
                onActivated: (i) => model.setData(model.index(i, 0), true, Qt.CheckStateRole)
            }
        }

        SettingRow {
            label: qsTr("Speed")
            labelColor: root._labelColor

            Widgets.ListLabel {
                Layout.preferredWidth: VLCStyle.dp(140, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: qsTr("%1x").arg(+Player.rate.toFixed(2))
                color: root._valueColor
                background: Rectangle { color: root._fieldColor; radius: VLCStyle.dp(4, VLCStyle.scale) }
            }
        }

        PlaybackSpeed {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        }
    }
}
```

- [ ] **Step 3: ExtendedSettingsButton.**
  - Add `import VLC.Player`.
  - Replace `onClicked: DialogsProvider.extendedDialog()` with the code below.
  - It works the same way in the mini-player bar, where `rootPlayer` is undefined and `g_mainDisplay` hosts the panel, as for LangButton.
```qml
    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)

    readonly property var _parentItem: ((typeof rootPlayer !== 'undefined') && (rootPlayer !== null)) ? rootPlayer
                                                                                                       : g_mainDisplay

    enabled: panelLoader.status === Loader.Ready

    onClicked: panelLoader.item.open()

    Loader {
        id: panelLoader

        sourceComponent: PlaybackPanel {
            id: panel

            parent: extdSettingsBtn._parentItem

            x: parent.width - width - VLCStyle.dp(20, VLCStyle.scale)
            y: parent.positionSliderY - height - VLCStyle.dp(20, VLCStyle.scale)
            z: 1

            colorContext.palette: extdSettingsBtn.colorContext.palette

            onOpened: {
                extdSettingsBtn.requestLockUnlockAutoHide(true)
                extdSettingsBtn.menuOpened(panel)
            }

            onClosed: {
                extdSettingsBtn.requestLockUnlockAutoHide(false)
                extdSettingsBtn.forceActiveFocus()
                extdSettingsBtn.menuOpened(null)
            }
        }
    }

    function forceUnlock() {
        if (panelLoader.item)
            panelLoader.item.close()
    }
```
- [ ] **Step 4: Verify.** Run `ninja -C build`, then rerun Step 1. Expected: no dialog window, the panel pixel check passes, and the log grep is empty.
  - Pick "Spectrometer" in the visualizer. Expected: `grep -i "visual\|spectrometer" vlc.log` shows the module loading.
  - Drag the speed slider. Expected: the "1x" field changes and the log shows `rate` changes.
  - Compare the shot with `pn_playback.png` by eye.
- [ ] **Step 5: Commit** `qml: open the playback settings panel from the player bar`.

### Task 3: Panel keyboard, empty-model and fullscreen behaviour

**Files:** Modify `modules/gui/qt/player/qml/PlayerPanel.qml` and `modules/gui/qt/player/qml/TrackSection.qml`.

**Interfaces — consumes:** `TrackSection.firstRow`, plus `PlayerPanel.pageHolder` and the TabButton delegate (Task 1).

- [ ] **Step 1: Failing check (keyboard).**
  - Open the tracks panel by clicking (1503, 873), then `vlc-xvfb.sh key Down; vlc-xvfb.sh key Return; sleep 1`.
  - Expected today: no new `ES track selected` line after the open, because no row has focus on open.
- [ ] **Step 2: Implement focus.**
  - TrackRow additions in `TrackSection.qml`. T.ItemDelegate already turns Space into `clicked`; this adds Return and arrow walking:
```qml
        Keys.onUpPressed: nextItemInFocusChain(false)?.forceActiveFocus(Qt.BacktabFocusReason)
        Keys.onDownPressed: nextItemInFocusChain(true)?.forceActiveFocus(Qt.TabFocusReason)
        Keys.onReturnPressed: clicked()
```
  - PlayerPanel additions in `PlayerPanel.qml`:
```qml
    onOpened: {
        const page = pageHolder.children[currentTab]
        for (const c of (page?.children ?? [])) {
            if (c.firstRow) {
                c.firstRow.forceActiveFocus(Qt.TabFocusReason)
                return
            }
        }
    }
```
  - Inside the TabButton delegate:
```qml
                        Keys.onLeftPressed: root.currentTab = Math.max(0, root.currentTab - 1)
                        Keys.onRightPressed: root.currentTab = Math.min(root.tabs.length - 1, root.currentTab + 1)
```
  - Run `ninja -C build`. Expected: it builds.
- [ ] **Step 3: Review Focus 2.**
  - Run `ffmpeg -y -f lavfi -i sine=f=440:d=60 build/redesign-media/sine.ogg`, then start the harness with that file.
  - Open the panel and shoot it. Read the card's top y and click the Video tab at x ≈ 1247 (1180 + 400/6), y = top + 25.
  - Expected: a single "None" row, ticked, and the log grep is empty.
- [ ] **Step 4: Review Focus 3.**
  - `vlc-xvfb.sh key F11; sleep 1`, open the tracks panel, `sleep 5`, then shoot.
  - Expected: `px.sh 1503 873` is the bar colour (`#191919`, tolerance 14) and the card is still there.
  - `vlc-xvfb.sh key Escape; sleep 5`, then shoot. Expected: the bars are hidden.
  - If the bars don't hide, check that `requestLockUnlockAutoHide(false)` fires on close.
- [ ] **Step 5: Review Focus 5.** Rerun Step 1.
  - Expected: a new `ES track selected` line appears (Down moves from None to the first track, and Return selects it).
  - Press `Escape`. Expected: the card is gone, and the shot shows the focus ring on the tracks button.
- [ ] **Step 6: Commit** `qml: keyboard navigation for the player panels`.

### Task 4: Wayland pass and suite

- [ ] **Step 1:** Run:
  ```
  dbus-run-session -- docs/superpowers/scripts/wl-drive.py /tmp/s3wl "vlc:build/redesign-media/tracks2.mkv,-vv" sleep:6 move:1503,873 click:1503,873 sleep:1 shot:tracks key:Escape click:1463,873 sleep:1 shot:playback
  ```
  Expected: both shots show the card at the bottom right, and the log grep is empty.
- [ ] **Step 2:** Run `meson test -C build --suite qt`. Expected: 9/9 OK. Commit only if this pass needed a fix; give each fix its own commit, naming the failing shot in the message.
