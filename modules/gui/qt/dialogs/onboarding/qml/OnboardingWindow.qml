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
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Dialogs
import "qrc:/qt/qml/VLC/Dialogs/AccentSwatches.js" as AccentSwatches
import "qrc:/qt/qml/VLC/Dialogs/OnboardingKeys.js" as OnboardingKeys

// The first-run onboarding card (Figma 1899:3055, 1902:3670, 1902:6770): Welcome, theme and colour, keyboard shortcuts.
// It stays dark whatever theme is picked; its accent-coloured parts follow the picked swatch. Nothing is written until
// Finish. Escape or closing the window skips onboarding. Opened by MainInterface.qml on DialogsProvider.showOnboarding.
DialogCard {
    id: root

    // the effective accent option ("default", "system", a hex), written back unchanged unless a swatch is clicked
    property string accentOption: Onboarding.currentAccent
    readonly property string accentHex: AccentSwatches.fromOption(accentOption)
    readonly property color accent: accentHex
    property int scheme: ColorSchemeModel.Night
    property int page: 0
    // Finish or skip ran: closing does nothing more
    property bool _done: false

    // the card is always dark; only the small player preview follows the picked theme tile
    readonly property var dk: VLCStyle.darkPalette.tokens
    readonly property var pv: previewPalette.tokens
    readonly property bool previewDark: previewPalette.isDark
    // the default swatch shows the theme's own accent tokens (Light: Accent/Main #E8851A, BG/Accent Bright #D8BA9A), as the
    // app will; the preview palette has them while the app's accent is still the default. A picked swatch isn't applied
    // yet, so the preview derives its tokens below.
    readonly property bool _previewDefault: accentHex === AccentSwatches.colors[0] && Onboarding.currentAccent === "default"
    readonly property color previewAccent: _previewDefault ? pv.accent : accent

    SystemPalette {
        id: previewPalette

        source: root.scheme
        ctx: MainCtx
    }

    readonly property bool _folderOk: !Onboarding.hasMediaLibrary || Onboarding.folderValid(folderField.text)

    title: qsTr("Welcome to VLC!")
    showHeader: false
    showFooter: false
    modal: true
    figmaWidth: 1090
    figmaHeight: 759
    cardColor: dk.bgB1

    onVisibleChanged: if (visible) content.forceActiveFocus()
    onPageChanged: content.forceActiveFocus()
    onCancelled: {
        _skip()
        close()
    }
    onClosing: _skip()

    function _next() {
        if (page === 0 && !_folderOk)
            return
        if (page < 2)
            page++
        else
            _finish()
    }

    function _finish() {
        if (_done)
            return
        _done = true
        Onboarding.finish(scheme, accentOption, folderField.text)
        close()
    }

    function _binding(key) {
        return key.startsWith("=") ? key.slice(1) : SettingsBridge.value(key)
    }

    // a shortcut row's keys as a flat list of caps and "/", each with the Figma gap before it: 4 inside a chord,
    // 10 around the "/". Every chord is drawn in full.
    function _keyParts(keys) {
        const parts = []
        keys.forEach((key, k) => {
            if (k > 0)
                parts.push({ text: "/", slash: true, gap: 10 })
            OnboardingKeys.caps(_binding(key)).forEach((text, i) =>
                parts.push({ text: text, slash: false, gap: parts.length === 0 ? 0 : (i === 0 ? 10 : 4) }))
        })
        return parts
    }

    function _skip() {
        if (_done)
            return
        _done = true
        Onboarding.skip()
    }

    // Figma buttons: 100 x 32, radius 6, SemiBold 16
    component Btn: T.Button {
        id: btn

        property color fill: dk.bgA3
        property color textColor: dk.fgA2

        width: VLCStyle.dp(100, VLCStyle.scale)
        height: VLCStyle.dp(32, VLCStyle.scale)
        opacity: enabled ? 1 : 0.5
        // a click leaves the focus where it was (Enter still means Next); Tab reaches it
        focusPolicy: Qt.TabFocus
        font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
        font.weight: Font.DemiBold
        Accessible.name: text
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()

        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: btn.fill

            FocusRing { visible: btn.visualFocus }
        }
        contentItem: Text {
            text: btn.text
            font: btn.font
            color: btn.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    component NextBtn: Btn {
        x: VLCStyle.dp(928, VLCStyle.scale)
        y: VLCStyle.dp(671, VLCStyle.scale)
        fill: root.accent
        textColor: dk.fgB1
        text: qsTr("Next")
        onClicked: root._next()
    }

    component BackBtn: Btn {
        x: VLCStyle.dp(820, VLCStyle.scale)
        y: VLCStyle.dp(671, VLCStyle.scale)
        text: qsTr("Back")
        onClicked: root.page--
    }

    // keyboard focus: an accent ring just outside the parent
    component FocusRing: Rectangle {
        anchors.fill: parent
        anchors.margins: -VLCStyle.dp(3, VLCStyle.scale)
        radius: parent.radius + VLCStyle.dp(3, VLCStyle.scale)
        color: "transparent"
        border.width: VLCStyle.focus_border
        border.color: root.accent
    }

    // Figma line height 1.75: the line is centred in 42
    component Heading: Text {
        anchors.horizontalCenter: parent.horizontalCenter
        height: VLCStyle.dp(42, VLCStyle.scale)
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
        color: dk.fgA1
    }

    // a preview icon: a VLCIcons glyph in a slot of the given width
    component PreviewIcon: Widgets.IconLabel {
        width: VLCStyle.dp(13.2, VLCStyle.scale)
        height: VLCStyle.dp(13.2, VLCStyle.scale)
        font.pixelSize: VLCStyle.dp(13.2, VLCStyle.scale)
        color: pv.fgA2
    }

    // the preview's volume meter: a wedge (Figma 48.4 x 15.4) cut at `right`
    component Wedge: ShapePath {
        readonly property real w: VLCStyle.dp(48.4, VLCStyle.scale)
        readonly property real h: VLCStyle.dp(15.4, VLCStyle.scale)
        property real right: w
        strokeColor: "transparent"
        startX: 0; startY: h * 0.33
        PathLine { x: right; y: h * (0.33 - 0.30 * right / w) }
        PathLine { x: right; y: h * (0.67 + 0.30 * right / w) }
        PathLine { x: 0; y: h * 0.67 }
        PathLine { x: 0; y: h * 0.33 }
    }

    component PreviewTime: Text {
        Layout.preferredWidth: VLCStyle.dp(41.8, VLCStyle.scale)
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: VLCStyle.dp(8.25, VLCStyle.scale)
        color: pv.fgA2
    }

    // a key cap; letters and words are padded 20, arrows and symbols 12
    component Cap: Item {
        id: cap

        property string text

        readonly property real _pad: VLCStyle.dp(/^[A-Za-z0-9]/.test(text) ? 20 : 12, VLCStyle.scale)

        implicitWidth: capLabel.implicitWidth + 2 * _pad + 2 * VLCStyle.dp(3, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(42, VLCStyle.scale)

        // Figma shadow 0 6 0 #5C5C5C40
        Rectangle {
            y: VLCStyle.dp(6, VLCStyle.scale)
            width: parent.width
            height: parent.height
            radius: VLCStyle.dp(12, VLCStyle.scale)
            color: "#405C5C5C"   // fixed colour: Figma key-cap shadow, not a token
        }
        Rectangle {
            anchors.fill: parent
            radius: VLCStyle.dp(12, VLCStyle.scale)
            color: dk.bgA3
            border.width: VLCStyle.dp(3, VLCStyle.scale)
            border.color: dk.dividerBright
        }
        Text {
            id: capLabel

            anchors.centerIn: parent
            text: cap.text
            font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
            font.weight: Font.Light
            color: dk.fg1
        }
    }

    // the Figma frame; scaled down to fit when the window is capped to the screen
    Item {
        id: content

        anchors.centerIn: parent
        width: VLCStyle.dp(1090, VLCStyle.scale)
        height: VLCStyle.dp(759, VLCStyle.scale)
        scale: Math.min(1, parent.width / width, parent.height / height)

        Keys.onReturnPressed: root._next()
        Keys.onEnterPressed: root._next()

        StackLayout {
            anchors.fill: parent
            currentIndex: root.page

            // Welcome
            Item {
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: VLCStyle.dp(116, VLCStyle.scale)
                    width: VLCStyle.dp(141, VLCStyle.scale)
                    height: VLCStyle.dp(141, VLCStyle.scale)
                    sourceSize: Qt.size(width, height)
                    source: SVGColorImage.colorize("qrc:///redesign/onboarding/cone.svg").accent(root.accent).uri()
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: VLCStyle.dp(286, VLCStyle.scale)
                    text: root.title
                    font.pixelSize: VLCStyle.dp(32, VLCStyle.scale)
                    font.weight: Font.Light
                    color: dk.fg1
                    Accessible.role: Accessible.Heading
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: VLCStyle.dp(362, VLCStyle.scale)
                    width: VLCStyle.dp(595, VLCStyle.scale)
                    text: qsTr("VLC is a free and open source cross-platform multimedia player and framework that plays most multimedia files as well as DVDs, Audio CDs, VCDs, and various streaming protocols.")
                    wrapMode: Text.WordWrap
                    lineHeightMode: Text.FixedHeight
                    lineHeight: VLCStyle.dp(28, VLCStyle.scale)
                    // Qt adds the extra line height below the text, Figma splits it: (28 - 19.4) / 2 above
                    topPadding: VLCStyle.dp(4, VLCStyle.scale)
                    font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                    font.weight: Font.Light
                    color: dk.fgA1
                }

                Column {
                    x: VLCStyle.dp(248, VLCStyle.scale)
                    y: VLCStyle.dp(500, VLCStyle.scale)
                    width: VLCStyle.dp(595, VLCStyle.scale)
                    spacing: VLCStyle.dp(16, VLCStyle.scale)
                    visible: Onboarding.hasMediaLibrary

                    Text {
                        text: qsTr("Choose a Media Folder to get started with")
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        color: dk.fgA2
                    }

                    Row {
                        spacing: VLCStyle.dp(10, VLCStyle.scale)

                        Rectangle {
                            width: VLCStyle.dp(595 - 10 - 114, VLCStyle.scale)
                            height: VLCStyle.dp(36, VLCStyle.scale)
                            radius: VLCStyle.dp(6, VLCStyle.scale)
                            color: dk.bgB2
                            border.width: VLCStyle.dp(2, VLCStyle.scale)
                            border.color: folderField.activeFocus ? root.accent : dk.bgA4

                            T.TextField {
                                id: folderField

                                anchors.fill: parent
                                anchors.margins: parent.border.width
                                leftPadding: VLCStyle.dp(12, VLCStyle.scale)
                                rightPadding: VLCStyle.dp(18, VLCStyle.scale)
                                topPadding: VLCStyle.dp(8, VLCStyle.scale)
                                bottomPadding: VLCStyle.dp(8, VLCStyle.scale)
                                verticalAlignment: TextInput.AlignVCenter
                                text: Onboarding.defaultFolder
                                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                                color: dk.fg2
                                selectionColor: root.accent
                                selectedTextColor: dk.fgB1
                                selectByMouse: true
                                activeFocusOnTab: true
                                Accessible.name: qsTr("Choose a Media Folder to get started with")
                                Component.onCompleted: cursorPosition = 0
                            }

                            // with no Videos folder the field starts empty
                            Text {
                                x: folderField.x + folderField.leftPadding
                                anchors.verticalCenter: parent.verticalCenter
                                visible: folderField.text.length === 0
                                text: qsTr("e.g., ~/Videos")
                                font: folderField.font
                                color: dk.fgA4
                            }
                        }

                        Btn {
                            width: VLCStyle.dp(114, VLCStyle.scale)
                            height: VLCStyle.dp(36, VLCStyle.scale)
                            font.weight: Font.Normal
                            text: qsTr("Browse")
                            onClicked: {
                                const path = Onboarding.pickFolder(folderField.text)
                                if (path)
                                    folderField.text = path
                            }
                        }
                    }
                }

                NextBtn {
                    enabled: root._folderOk
                }
            }

            // Theme and colour
            Item {
                // the player drawn small (the Figma Player at 0.55); it takes the picked theme
                Rectangle {
                    x: VLCStyle.dp(17, VLCStyle.scale)
                    y: VLCStyle.dp(19, VLCStyle.scale)
                    width: VLCStyle.dp(1056, VLCStyle.scale)
                    height: VLCStyle.dp(594, VLCStyle.scale)
                    color: pv.bgB2

                    Rectangle {
                        width: parent.width
                        height: VLCStyle.dp(22, VLCStyle.scale)
                        color: pv.bgA4

                        Image {
                            x: VLCStyle.dp(3.3 + 3.85, VLCStyle.scale)
                            anchors.verticalCenter: parent.verticalCenter
                            width: VLCStyle.dp(13.2, VLCStyle.scale)
                            height: VLCStyle.dp(13.2, VLCStyle.scale)
                            sourceSize: Qt.size(width, height)
                            source: SVGColorImage.colorize("qrc:///redesign/onboarding/cone.svg")
                                        .accent(root._previewDefault ? pv.logo : root.accent).uri()
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: VLCStyle.dp(3.3, VLCStyle.scale)
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: [VLCIcons.window_minimize, VLCIcons.window_maximize, VLCIcons.fullscreen, VLCIcons.window_close]

                                PreviewIcon {
                                    required property string modelData
                                    width: VLCStyle.dp(13.2 + 2 * 3.3, VLCStyle.scale)
                                    text: modelData
                                }
                            }
                        }
                    }

                    // the control bar
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: VLCStyle.dp(29.7, VLCStyle.scale)
                        color: pv.bgA3Transparent

                        Rectangle {
                            width: parent.width
                            height: VLCStyle.dp(0.55, VLCStyle.scale)
                            color: pv.dividerDim
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: VLCStyle.dp(11, VLCStyle.scale)
                            anchors.rightMargin: VLCStyle.dp(11, VLCStyle.scale)
                            spacing: VLCStyle.dp(11, VLCStyle.scale)

                            Row {
                                spacing: VLCStyle.dp(4.4, VLCStyle.scale)

                                PreviewIcon {
                                    width: VLCStyle.dp(16.5, VLCStyle.scale)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: VLCIcons.previous
                                }
                                Rectangle {
                                    width: VLCStyle.dp(29.7, VLCStyle.scale)
                                    height: VLCStyle.dp(15.4, VLCStyle.scale)
                                    radius: VLCStyle.dp(3.3, VLCStyle.scale)
                                    color: root.previewAccent

                                    PreviewIcon {
                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset: VLCStyle.dp(0.55, VLCStyle.scale)
                                        text: VLCIcons.play_filled
                                        color: pv.fgB1
                                    }
                                }
                                PreviewIcon {
                                    width: VLCStyle.dp(16.5, VLCStyle.scale)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: VLCIcons.next
                                }
                            }

                            PreviewTime {
                                text: "00:02:10"
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: VLCStyle.dp(15.4, VLCStyle.scale)
                                radius: VLCStyle.dp(3.3, VLCStyle.scale)
                                color: pv.bgB2

                                Rectangle {
                                    x: VLCStyle.dp(1.1, VLCStyle.scale)
                                    y: VLCStyle.dp(1.1, VLCStyle.scale)
                                    width: VLCStyle.dp(53.9, VLCStyle.scale)
                                    height: VLCStyle.dp(13.2, VLCStyle.scale)
                                    radius: VLCStyle.dp(2.2, VLCStyle.scale)
                                    // BG/Accent Bright for the picked swatch; light mirrors style/figmatokens.cpp (30 % accent over #D1D1D1)
                                    color: root._previewDefault ? pv.accentBgBright
                                         : root.previewDark
                                           ? Qt.rgba(root.accent.r * 0.26, root.accent.g * 0.26, root.accent.b * 0.26, 1)
                                           : Qt.tint("#D1D1D1", Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.30))   // fixed colour: light BG/Accent Bright formula
                                }
                                Rectangle {
                                    x: VLCStyle.dp(50.6, VLCStyle.scale)
                                    y: VLCStyle.dp(1.1, VLCStyle.scale)
                                    width: VLCStyle.dp(4.4, VLCStyle.scale)
                                    height: VLCStyle.dp(13.2, VLCStyle.scale)
                                    radius: VLCStyle.dp(2.2, VLCStyle.scale)
                                    color: root.previewAccent
                                }
                            }

                            PreviewTime {
                                text: "00:25:40"
                            }

                            Row {
                                spacing: VLCStyle.dp(4.4, VLCStyle.scale)

                                PreviewIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: VLCIcons.volume_low
                                }

                                // the volume meter: a wedge, its first 37 % lit with the meter's gradient (dimmed 20 %)
                                Shape {
                                    width: VLCStyle.dp(48.4, VLCStyle.scale)
                                    height: VLCStyle.dp(15.4, VLCStyle.scale)
                                    preferredRendererType: Shape.CurveRenderer

                                    Wedge { fillColor: pv.bgB2 }
                                    Wedge {
                                        right: w * 0.37
                                        fillGradient: LinearGradient {
                                            x1: 0; x2: VLCStyle.dp(48.4, VLCStyle.scale)
                                            GradientStop { position: 0.0; color: "#77A913" }   // fixed colour: Figma onboarding
                                            GradientStop { position: 0.58; color: "#8E8713" }   // fixed colour: Figma onboarding
                                        }
                                    }
                                }
                            }

                            Row {
                                spacing: VLCStyle.dp(6.6, VLCStyle.scale)

                                Repeater {
                                    model: [VLCIcons.audio_tracks, VLCIcons.audiosub, VLCIcons.settings]

                                    PreviewIcon {
                                        required property string modelData
                                        width: VLCStyle.dp(16.5, VLCStyle.scale)
                                        text: modelData
                                    }
                                }
                            }

                            PreviewIcon {
                                Layout.preferredWidth: VLCStyle.dp(16.5, VLCStyle.scale)
                                text: VLCIcons.playqueue
                            }
                        }
                    }
                }

                Heading {
                    y: VLCStyle.dp(173, VLCStyle.scale)
                    text: qsTr("Select your preferred theme and color.")
                    font.weight: Font.Light
                }

                Repeater {
                    model: [
                        { label: qsTr("Light"), scheme: ColorSchemeModel.Day, swatch: "#AFAFAF" },   // fixed colour: Figma onboarding
                        { label: qsTr("Dark"), scheme: ColorSchemeModel.Night, swatch: "#222222" },   // fixed colour: Figma onboarding
                        { label: qsTr("System"), scheme: ColorSchemeModel.System, swatch: "#222222" }   // fixed colour: Figma onboarding
                    ]

                    T.Button {
                        id: tile

                        required property int index
                        required property var modelData
                        readonly property bool selected: root.scheme === modelData.scheme

                        x: VLCStyle.dp(331 + 156 * index, VLCStyle.scale)
                        y: VLCStyle.dp(286, VLCStyle.scale)
                        width: VLCStyle.dp(116, VLCStyle.scale)
                        height: VLCStyle.dp(157, VLCStyle.scale)
                        text: modelData.label
                        onClicked: root.scheme = modelData.scheme
                        focusPolicy: Qt.TabFocus
                        Keys.onReturnPressed: root._next()
                        Keys.onEnterPressed: root._next()
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: text
                        Accessible.checked: selected

                        background: Item {
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: VLCStyle.dp(116 + 8, VLCStyle.scale)
                                height: width
                                y: -VLCStyle.dp(4, VLCStyle.scale)
                                radius: VLCStyle.dp(19 + 4, VLCStyle.scale)
                                color: "transparent"
                                border.width: VLCStyle.dp(4, VLCStyle.scale)
                                border.color: root.accent
                                visible: tile.selected

                                FocusRing { visible: tile.visualFocus }
                            }

                            Rectangle {
                                x: VLCStyle.dp(8, VLCStyle.scale)
                                y: VLCStyle.dp(8, VLCStyle.scale)
                                width: VLCStyle.dp(100, VLCStyle.scale)
                                height: width
                                radius: VLCStyle.dp(12, VLCStyle.scale)
                                color: tile.modelData.swatch

                                FocusRing { visible: tile.visualFocus && !tile.selected }

                                // System: the light part over the right of the swatch (the frame's gradient)
                                Shape {
                                    id: systemShape

                                    // the path is drawn on a 100 grid
                                    readonly property real k: width / 100
                                    readonly property real r: 12 * k

                                    anchors.fill: parent
                                    visible: tile.modelData.scheme === ColorSchemeModel.System
                                    preferredRendererType: Shape.CurveRenderer

                                    ShapePath {
                                        fillColor: "#AFAFAF"   // fixed colour: Figma onboarding
                                        strokeColor: "transparent"
                                        startX: 16 * systemShape.k; startY: 0
                                        PathLine { x: 100 * systemShape.k - systemShape.r; y: 0 }
                                        PathArc { x: 100 * systemShape.k; y: systemShape.r; radiusX: systemShape.r; radiusY: systemShape.r }
                                        PathLine { x: 100 * systemShape.k; y: 100 * systemShape.k - systemShape.r }
                                        PathArc { x: 100 * systemShape.k - systemShape.r; y: 100 * systemShape.k; radiusX: systemShape.r; radiusY: systemShape.r }
                                        PathLine { x: 75 * systemShape.k; y: 100 * systemShape.k }
                                        PathLine { x: 16 * systemShape.k; y: 0 }
                                    }
                                }
                            }
                        }

                        contentItem: Item {
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                text: tile.text
                                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                                font.weight: Font.Light
                                color: dk.fgA2
                            }
                        }
                    }
                }

                Repeater {
                    model: AccentSwatches.colors

                    T.Button {
                        id: swatch

                        required property int index
                        required property string modelData
                        readonly property bool selected: modelData === root.accentHex
                        readonly property color color: modelData

                        x: VLCStyle.dp(41 + 80 * index, VLCStyle.scale)
                        y: VLCStyle.dp(655, VLCStyle.scale)
                        width: VLCStyle.dp(64, VLCStyle.scale)
                        height: width
                        onClicked: root.accentOption = AccentSwatches.optionValue(modelData)
                        focusPolicy: Qt.TabFocus
                        Keys.onReturnPressed: root._next()
                        Keys.onEnterPressed: root._next()
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: modelData
                        Accessible.checked: selected

                        background: Rectangle {
                            radius: width / 2
                            color: "transparent"
                            border.width: swatch.selected ? VLCStyle.dp(4, VLCStyle.scale) : 0
                            border.color: Qt.rgba(swatch.color.r, swatch.color.g, swatch.color.b, 0.3)

                            FocusRing { visible: swatch.visualFocus }
                        }
                        contentItem: Item {
                            Rectangle {
                                anchors.centerIn: parent
                                width: VLCStyle.dp(40, VLCStyle.scale)
                                height: width
                                radius: width / 2
                                color: swatch.color
                                opacity: swatch.selected ? 1 : 0.5
                            }
                        }
                    }
                }

                BackBtn {}
                NextBtn {}
            }

            // Keyboard shortcuts
            Item {
                Heading {
                    y: VLCStyle.dp(60, VLCStyle.scale)
                    text: qsTr("Learn the basic keyboard shortcuts.")
                }

                // two columns of six; a row is a label and its bindings ("key-…" options or "=literal"), split into caps
                Repeater {
                    model: OnboardingKeys.rows

                    Item {
                        required property int index
                        required property var modelData

                        x: VLCStyle.dp(index < 6 ? 62 : 62 + 393 + 150, VLCStyle.scale)
                        y: VLCStyle.dp(154 + 82 * (index % 6), VLCStyle.scale)
                        height: VLCStyle.dp(42, VLCStyle.scale)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: VLCStyle.dp(220, VLCStyle.scale)
                            text: parent.modelData.label
                            elide: Text.ElideRight
                            font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                            font.weight: Font.Light
                            color: dk.fgA1
                        }

                        Row {
                            x: VLCStyle.dp(220 + 20, VLCStyle.scale)
                            // a long binding is shrunk to stay 20 clear of the right column's label (left column) or
                            // of the card's edge (right column): 605 - 20 - 302 and 1090 - 20 - 845
                            scale: Math.min(1, VLCStyle.dp(parent.index < 6 ? 283 : 225, VLCStyle.scale) / implicitWidth)
                            transformOrigin: Item.Left

                            Repeater {
                                model: root._keyParts(parent.parent.modelData.keys)

                                // a cap or a "/", after its gap
                                Item {
                                    id: part

                                    required property var modelData
                                    readonly property real _gap: VLCStyle.dp(modelData.gap, VLCStyle.scale)

                                    width: _gap + (modelData.slash ? slash.implicitWidth : partCap.implicitWidth)
                                    height: VLCStyle.dp(42, VLCStyle.scale)

                                    Text {
                                        id: slash

                                        x: part._gap
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: part.modelData.slash
                                        text: "/"
                                        font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                                        font.weight: Font.Light
                                        color: dk.fgA1
                                    }

                                    Cap {
                                        id: partCap

                                        x: part._gap
                                        visible: !part.modelData.slash
                                        text: part.modelData.slash ? "" : part.modelData.text
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    x: VLCStyle.dp(62, VLCStyle.scale)
                    y: VLCStyle.dp(671, VLCStyle.scale)
                    height: VLCStyle.dp(32, VLCStyle.scale)
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("Find the full list in the menu.")
                    font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                    color: dk.fgA3
                }

                BackBtn {}
                NextBtn {
                    text: qsTr("Finish")
                }
            }
        }
    }
}
