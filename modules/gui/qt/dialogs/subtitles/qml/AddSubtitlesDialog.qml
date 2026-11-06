/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import QtQuick.Shapes
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets
import VLC.Dialogs

// Add Subtitles (Figma 1919:8707, 3336:11929): subtitle files from a folder or a link, attached to the file, the
// folder's media or the playlist's. Single instance, opened by MainInterface.qml with a context (see openWith).
DialogCard {
    id: root

    readonly property AddSubtitlesController controller: AddSubtitlesController
    // what the opener gave: it says which targets this dialog can switch to
    property var context: ({})
    // asks MainInterface.qml to open Settings on its Network page
    signal openNetworkSettings()
    // set once a save left some subtitles unattached: the dialog stays open to say so
    property int failedCount: 0

    readonly property bool _pairs: controller.target !== AddSubtitlesController.File
    readonly property real _margin: VLCStyle.dp(20, VLCStyle.scale)
    readonly property real _rowHeight: VLCStyle.dp(36, VLCStyle.scale)

    title: qsTr("Add Subtitles")
    figmaWidth: 1048
    figmaHeight: 800
    cardColor: _s.windowBg
    modal: true
    saveEnabled: controller.canSave && !controller.busy && failedCount === 0
    footerNote: failedCount > 0 ? qsTr("%n subtitle(s) could not be added.", "", failedCount) : ""

    function openWith(ctx) {
        context = controller.completeContext(ctx)
        failedCount = 0
        controller.setContext(context)
        list.positionViewAtBeginning()
        open()
    }

    onCancelled: close()
    // however it closed (Cancel, Escape, the x, the window manager): nothing goes on behind it
    onVisibleChanged: {
        if (!visible) {
            searchDelay.stop()
            controller.cancel()
        }
    }
    onSaved: {
        if (saveEnabled)
            controller.save()
    }

    Connections {
        target: root.controller
        function onFinished(attached, failed) {
            if (failed === 0)
                root.close()
            else
                root.failedCount = failed
        }
    }

    // the targets the opener's context can fill, in the order of the dropdown
    readonly property var _targets: [
        { text: qsTr("To This File"), value: AddSubtitlesController.File, ok: !!context.mrl },
        { text: qsTr("To This Folder"), value: AddSubtitlesController.Folder, ok: !!context.folder },
        { text: qsTr("To This Playlist"), value: AddSubtitlesController.Playlist, ok: context.playlistId !== undefined }
    ]
    readonly property var _origins: [
        { text: qsTr("From Computer"), value: AddSubtitlesController.Computer },
        { text: qsTr("From OpenSubtitles"), value: AddSubtitlesController.OpenSubtitles },
        { text: qsTr("From Link ..."), value: AddSubtitlesController.Link, ok: controller.target === AddSubtitlesController.File }
    ]

    // a 34 high dropdown button over a FigmaMenu of `options` ({ text, value, ok }) with `current` ticked
    component Dropdown: Rectangle {
        id: dd

        property var options: []
        property var current
        signal picked(var value)

        width: VLCStyle.dp(200, VLCStyle.scale)
        height: VLCStyle.dp(34, VLCStyle.scale)
        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: root._s.searchBg
        activeFocusOnTab: true
        border.width: activeFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: root._s.accent

        Accessible.role: Accessible.ComboBox
        Accessible.name: label.text
        Accessible.onPressAction: dd._open()

        function _open() {
            menu.rows = options.map(o => ({
                text: o.text,
                checked: o.value === current,
                enabled: o.ok ?? true,
                run: () => dd.picked(o.value)
            }))
            menu.popup(dd, 0, dd.height + VLCStyle.dp(4, VLCStyle.scale))
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                _open()
                event.accepted = true
            }
        }
        TapHandler { onTapped: dd._open() }

        Widgets.FigmaMenu {
            id: menu
            width: VLCStyle.dp(209, VLCStyle.scale)
        }

        Widgets.LabelExt {
            id: label
            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(12, VLCStyle.scale)
            anchors.right: chevron.left
            anchors.verticalCenter: parent.verticalCenter
            text: dd.options.find(o => o.value === dd.current)?.text ?? ""
            elide: Text.ElideRight
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root._s.title
        }

        Image {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(8, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(24, VLCStyle.scale)
            height: width
            sourceSize: Qt.size(width, height)
            source: Helpers.themedSvg(root.colorContext.palette, "qrc:///redesign/settings/chevron-down.svg")
        }
    }

    // OpenSubtitles language codes
    readonly property var _languages: [
        { text: qsTr("English"), value: "en" }, { text: qsTr("Spanish"), value: "es" },
        { text: qsTr("French"), value: "fr" }, { text: qsTr("German"), value: "de" },
        { text: qsTr("Italian"), value: "it" }, { text: qsTr("Portuguese (Portugal)"), value: "pt-PT" },
        { text: qsTr("Portuguese (Brazil)"), value: "pt-BR" }, { text: qsTr("Dutch"), value: "nl" },
        { text: qsTr("Polish"), value: "pl" }, { text: qsTr("Russian"), value: "ru" },
        { text: qsTr("Turkish"), value: "tr" }, { text: qsTr("Arabic"), value: "ar" },
        { text: qsTr("Chinese (simplified)"), value: "zh-CN" }, { text: qsTr("Japanese"), value: "ja" },
        { text: qsTr("Korean"), value: "ko" }, { text: qsTr("Swedish"), value: "sv" }
    ]
    readonly property bool _searchMode: controller.origin === AddSubtitlesController.OpenSubtitles

    component Glyph: Image {
        width: VLCStyle.dp(24, VLCStyle.scale)
        height: width
        sourceSize: Qt.size(width, height)
    }

    // the strip under the title bar: target, origin, and the location or the link
    Rectangle {
        id: top

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: VLCStyle.dp(46, VLCStyle.scale)
        color: root._s.topBar

        Dropdown {
            id: targetBox
            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(9, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            options: root._targets
            current: root.controller.target
            Accessible.name: qsTr("Add subtitles to")
            // the context carries what the target needs: loading it again reloads the media
            onPicked: (value) => {
                if (value !== root.controller.target)
                    root.openWith(Object.assign({}, root.context, { target: ["file", "folder", "playlist"][value] }))
            }
        }

        Dropdown {
            id: originBox
            anchors.left: targetBox.right
            anchors.leftMargin: VLCStyle.dp(10, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            options: root._origins
            current: root.controller.origin
            Accessible.name: qsTr("Subtitles from")
            onPicked: (value) => root.controller.origin = value
        }

        // From Computer: where the files come from; a click picks another folder
        Rectangle {
            visible: root.controller.origin === AddSubtitlesController.Computer
            anchors.left: originBox.right
            anchors.leftMargin: VLCStyle.dp(10, VLCStyle.scale)
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(9, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            height: VLCStyle.dp(34, VLCStyle.scale)
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root._s.searchBg
            activeFocusOnTab: true
            border.width: activeFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
            border.color: root._s.accent

            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Choose a folder")
            Accessible.onPressAction: _pick()

            function _pick() {
                const dir = DialogsProvider.pickFolder(qsTr("Choose a folder"), "")
                if (dir.toString() !== "")
                    root.controller.setFolder(dir)
            }
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    _pick()
                    event.accepted = true
                }
            }
            TapHandler { onTapped: parent._pick() }

            Widgets.IconLabel {
                id: folderGlyph
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(8, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                text: VLCIcons.folder
                font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
                color: root._s.title
            }

            Widgets.LabelExt {
                anchors.left: folderGlyph.right
                anchors.leftMargin: VLCStyle.dp(10, VLCStyle.scale)
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(8, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                text: root.controller.location || qsTr("Choose a folder")
                elide: Text.ElideMiddle
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._s.title
            }
        }

        // From OpenSubtitles: the search text and the language
        Dropdown {
            id: languageBox
            visible: root._searchMode
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(9, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            options: root._languages
            current: root.controller.osLanguage
            Accessible.name: qsTr("Subtitle language")
            onPicked: (value) => root.controller.osLanguage = value
        }

        Rectangle {
            visible: root._searchMode
            anchors.left: originBox.right
            anchors.leftMargin: VLCStyle.dp(10, VLCStyle.scale)
            anchors.right: languageBox.left
            anchors.rightMargin: VLCStyle.dp(10, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            height: VLCStyle.dp(34, VLCStyle.scale)
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root._s.searchBg
            border.width: searchField.activeFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
            border.color: root._s.accent
            onVisibleChanged: if (visible) searchField.forceActiveFocus()

            Widgets.IconLabel {
                id: searchGlyph
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(8, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                text: VLCIcons.search
                font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
                color: root._s.title
            }

            // a search runs when typing pauses, or on Enter
            Timer {
                id: searchDelay
                interval: 700
                onTriggered: root.controller.searchOpenSubtitles()
            }

            TextInput {
                id: searchField

                anchors.left: searchGlyph.right
                anchors.leftMargin: VLCStyle.dp(10, VLCStyle.scale)
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(12, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                selectByMouse: true
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._s.labelActive
                selectionColor: root._s.accentDim
                selectedTextColor: root._s.labelActive
                text: root.controller.osQuery
                onTextEdited: {
                    root.controller.osQuery = text
                    searchDelay.restart()
                }
                onAccepted: {
                    searchDelay.stop()
                    root.controller.searchOpenSubtitles()
                }
                Accessible.role: Accessible.EditableText
                Accessible.name: qsTr("Search OpenSubtitles")

                Widgets.LabelExt {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: !searchField.text && !searchField.preeditText
                    text: qsTr("Search for a title")
                    font: searchField.font
                    color: root._s.placeholder
                    Accessible.ignored: true
                }
            }
        }

        // From Link: replaces the location
        Rectangle {
            visible: root.controller.origin === AddSubtitlesController.Link
            anchors.left: originBox.right
            anchors.leftMargin: VLCStyle.dp(10, VLCStyle.scale)
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(9, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            height: VLCStyle.dp(34, VLCStyle.scale)
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root._s.searchBg
            border.width: linkField.activeFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
            border.color: root._s.accent
            onVisibleChanged: if (visible) linkField.forceActiveFocus()

            TextInput {
                id: linkField

                anchors.fill: parent
                anchors.leftMargin: VLCStyle.dp(12, VLCStyle.scale)
                anchors.rightMargin: VLCStyle.dp(12, VLCStyle.scale)
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                selectByMouse: true
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._s.labelActive
                selectionColor: root._s.accentDim
                selectedTextColor: root._s.labelActive
                text: root.controller.link
                onTextEdited: root.controller.link = text
                Accessible.role: Accessible.EditableText
                Accessible.name: qsTr("Subtitle link")

                Widgets.LabelExt {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: !linkField.text && !linkField.preeditText
                    text: qsTr("e.g., https://www.example.com/subtitles.srt")
                    font: linkField.font
                    color: root._s.placeholder
                    Accessible.ignored: true
                }
            }
        }
    }

    // File target: the subtitle files, ticking the ones to attach. Folder and Playlist: each media paired with one.
    ListView {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: top.bottom
        anchors.topMargin: VLCStyle.dp(12, VLCStyle.scale)
        anchors.bottom: parent.bottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: VLCStyle.dp(2, VLCStyle.scale)
        T.ScrollBar.vertical: Widgets.ScrollBarExt { colorContext.palette: VLCStyle.palette }

        // a link is attached to the one media, whose name the list shows
        model: root._pairs || root.controller.origin === AddSubtitlesController.Link ? root.controller.mediaItems
                                                                                       : root.controller.candidates

        Widgets.LabelExt {
            anchors.centerIn: parent
            visible: list.count === 0 && !root.controller.busy && !(root._searchMode && !root.controller.hasKey)
            text: root.controller.origin === AddSubtitlesController.Link ? ""
                : !root._searchMode ? qsTr("No subtitle files found")
                : root.controller.osError ? root.controller.osError
                : root.controller.osSearching ? qsTr("Searching...")
                : root.controller.osQuery.trim() ? qsTr("Press Enter to search OpenSubtitles")
                : qsTr("Type a title to search OpenSubtitles")
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root._s.placeholder
        }

        // no API key yet: say where to put it
        Column {
            visible: root._searchMode && !root.controller.hasKey
            anchors.centerIn: parent
            spacing: VLCStyle.dp(16, VLCStyle.scale)

            Widgets.LabelExt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Add an OpenSubtitles API key in Settings \u25B8 Network")
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._s.placeholder
            }

            Rectangle {
                id: settingsButton
                anchors.horizontalCenter: parent.horizontalCenter
                width: VLCStyle.dp(140, VLCStyle.scale)
                height: VLCStyle.dp(32, VLCStyle.scale)
                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: root._s.box
                activeFocusOnTab: true
                border.width: activeFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                border.color: root._s.value

                Accessible.role: Accessible.Button
                Accessible.name: openSettingsLabel.text
                Accessible.onPressAction: root.openNetworkSettings()
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.openNetworkSettings()
                        event.accepted = true
                    }
                }
                TapHandler { onTapped: root.openNetworkSettings() }

                Widgets.LabelExt {
                    id: openSettingsLabel
                    anchors.centerIn: parent
                    text: qsTr("Open Settings")
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    font.weight: Font.DemiBold
                    color: root._s.value
                }
            }
        }

        delegate: Item {
            id: line

            required property var modelData
            required property int index
            readonly property bool link: root.controller.origin === AddSubtitlesController.Link

            width: list.width
            height: root._rowHeight

            Loader {
                anchors.fill: parent
                sourceComponent: line.link ? linkRow : root._pairs ? pairRow : fileRow
            }

            Component {
                id: fileRow

                // subtitle one (1919:9121)
                Rectangle {
                    readonly property bool ticked: root.controller.ticked.indexOf(line.index) >= 0

                    anchors.fill: parent
                    anchors.leftMargin: root._margin
                    anchors.rightMargin: root._margin
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: ticked ? root._s.field : "transparent"
                    activeFocusOnTab: true
                    border.width: activeFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                    border.color: root._s.accent

                    Accessible.role: Accessible.CheckBox
                    Accessible.name: line.modelData
                    Accessible.checked: ticked
                    Accessible.onToggleAction: root.controller.toggle(line.index)

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            root.controller.toggle(line.index)
                            event.accepted = true
                        }
                    }
                    TapHandler { onTapped: root.controller.toggle(line.index) }

                    Glyph {
                        id: fileGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: VLCStyle.dp(8, VLCStyle.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        source: Helpers.themedSvg(root.colorContext.palette, "qrc:///redesign/dialogs/subtitle-file.svg")
                    }
                    Widgets.LabelExt {
                        anchors.left: fileGlyph.right
                        anchors.leftMargin: VLCStyle.dp(16, VLCStyle.scale)
                        anchors.right: tick.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: line.modelData
                        elide: Text.ElideMiddle
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        color: root._s.title
                    }
                    Widgets.IconLabel {
                        id: tick
                        visible: parent.ticked
                        anchors.right: parent.right
                        anchors.rightMargin: VLCStyle.dp(8, VLCStyle.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        text: VLCIcons.checkmark
                        font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
                        color: root._s.accent
                    }
                }
            }

            // the media a link goes to: its name, nothing to pick
            Component {
                id: linkRow

                Item {
                    Glyph {
                        id: linkGlyph
                        x: root._margin + VLCStyle.dp(8, VLCStyle.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        source: Helpers.themedSvg(root.colorContext.palette, "qrc:///redesign/dialogs/media-file.svg")
                    }
                    Widgets.LabelExt {
                        anchors.left: linkGlyph.right
                        anchors.leftMargin: VLCStyle.dp(16, VLCStyle.scale)
                        anchors.right: parent.right
                        anchors.rightMargin: root._margin
                        anchors.verticalCenter: parent.verticalCenter
                        text: line.modelData.name
                        elide: Text.ElideMiddle
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        color: root._s.title
                    }
                }
            }

            // the media, a dashed line, and its subtitle (subtitle multiple, 1915:8397)
            Component {
                id: pairRow

                Item {
                    id: pair

                    readonly property int paired: root.controller.pairs[line.index] ?? -1
                    readonly property real split: width * 0.5

                    Glyph {
                        id: mediaGlyph
                        x: root._margin + VLCStyle.dp(8, VLCStyle.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        source: Helpers.themedSvg(root.colorContext.palette, "qrc:///redesign/dialogs/media-file.svg")
                    }
                    Widgets.LabelExt {
                        id: mediaName
                        anchors.left: mediaGlyph.right
                        anchors.leftMargin: VLCStyle.dp(14, VLCStyle.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, pair.split - x - VLCStyle.dp(60, VLCStyle.scale))
                        text: line.modelData.name
                        elide: Text.ElideMiddle
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        color: root._s.title
                    }

                    Shape {
                        x: mediaName.x + mediaName.width + VLCStyle.dp(14, VLCStyle.scale)
                        width: pair.split - x
                        height: parent.height
                        ShapePath {
                            // Figma "Vector 77": 1 px Divider/Bright, dash 8 8
                            strokeColor: root.colorContext.palette.tokens.dividerBright
                            strokeWidth: VLCStyle.dp(1, VLCStyle.scale)
                            strokeStyle: ShapePath.DashLine
                            // in units of the stroke width
                            dashPattern: [8, 8]
                            fillColor: "transparent"
                            startX: 0; startY: height / 2
                            PathLine { x: width; y: height / 2 }
                        }
                    }

                    Rectangle {
                        id: cell

                        // Figma: the cell starts 20 after the split and ends 20 before the edge
                        x: pair.split + root._margin
                        width: pair.width - x - root._margin
                        height: parent.height
                        radius: VLCStyle.dp(6, VLCStyle.scale)
                        color: hover.hovered || activeFocus ? root._s.field : "transparent"
                        activeFocusOnTab: true
                        border.width: activeFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                        border.color: root._s.accent

                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("%1: %2").arg(line.modelData.name).arg(subName.text)
                        Accessible.onPressAction: cell._open()

                        function _open() {
                            const row = line.index
                            const rows = root.controller.candidates.map((c, i) => ({
                                text: c,
                                checked: i === pair.paired,
                                run: () => root.controller.setPair(row, i)
                            }))
                            rows.push({ text: qsTr("None"), checked: pair.paired < 0, run: () => root.controller.setPair(row, -1) })
                            menu.rows = rows
                            menu.popup(cell, 0, cell.height + VLCStyle.dp(4, VLCStyle.scale))
                        }
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                _open()
                                event.accepted = true
                            }
                        }
                        HoverHandler { id: hover }
                        TapHandler { onTapped: cell._open() }

                        Widgets.FigmaMenu {
                            id: menu
                            width: VLCStyle.dp(295, VLCStyle.scale)
                        }

                        Glyph {
                            id: subGlyph
                            anchors.left: parent.left
                            anchors.leftMargin: VLCStyle.dp(8, VLCStyle.scale)
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: pair.paired >= 0 ? 1 : 0.4
                            source: Helpers.themedSvg(root.colorContext.palette, "qrc:///redesign/dialogs/subtitle-file.svg")
                        }
                        Widgets.LabelExt {
                            id: subName
                            anchors.left: subGlyph.right
                            anchors.leftMargin: VLCStyle.dp(16, VLCStyle.scale)
                            anchors.right: swap.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: pair.paired >= 0 ? root.controller.candidates[pair.paired] : qsTr("None")
                            elide: Text.ElideMiddle
                            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                            color: pair.paired >= 0 ? root._s.title : root._s.placeholder
                        }
                        Glyph {
                            id: swap
                            anchors.right: parent.right
                            anchors.rightMargin: VLCStyle.dp(8, VLCStyle.scale)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: hover.hovered || cell.activeFocus
                            source: Helpers.themedSvg(root.colorContext.palette, "qrc:///redesign/dialogs/swap.svg")
                        }
                    }
                }
            }
        }
    }
}
