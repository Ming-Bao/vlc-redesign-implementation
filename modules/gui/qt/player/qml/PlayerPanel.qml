
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
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.Style
import VLC.Widgets as Widgets

// bottom-right popover card of the player (Figma "Controls" panels): tab header, one page per tab, footer button
T.Popup {
    id: root

    property var tabs: []
    property int currentTab: 0
    property string footerText: ""
    // the pages scroll when the card would be taller than this
    property real maximumHeight: Number.POSITIVE_INFINITY
    // the card takes maximumHeight and each page fills it (for pages that scroll themselves, like the queue)
    property bool fillHeight: false
    default property alias pages: pageHolder.data

    signal footerClicked()

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    readonly property bool _dark: theme.palette.isDark

    width: VLCStyle.dp(400, VLCStyle.scale)
    implicitHeight: fillHeight ? maximumHeight
                               : Math.min(contentHeight + topPadding + bottomPadding, maximumHeight)
    padding: 0
    focus: true
    // a press outside the card closes it and goes no further: it must not reach the video
    // (which would pause) or the control behind it
    closePolicy: T.Popup.CloseOnEscape
    modal: true
    // blocking clicks behind a modal popup needs its background; keep it invisible
    dim: true
    T.Overlay.modal: Item { }

    Connections {
        target: root.visible && root.modal ? root.T.Overlay.overlay : null
        // the modal popup blocks clicks on the background; close once the whole click is
        // absorbed so that neither press nor release reaches the video. The overlay also
        // reports clicks on the card itself: those are not dismissals
        function onReleased() {
            if (!cardHover.hovered && !root._otherPopupOpen())
                root.close()
        }
    }

    // another popup (e.g. a combo box list) is open over this card: a click there is not a dismissal.
    // Popups stacked below it (the docked queue card) do not count
    function _otherPopupOpen() {
        const own = contentItem.parent
        let above = false
        for (const c of T.Overlay.overlay.children) {
            if (c === own)
                above = true
            else if (above && c.visible && String(c).startsWith("QQuickPopupItem"))
                return true
        }
        return false
    }

    // start keyboard focus on the current page's selected track, else its first control; the
    // focus ring shows once the keyboard is used
    function focusPage() {
        const page = pageHolder.children[currentTab]
        for (const c of (page?.children ?? [])) {
            const row = c.focusRow?.()
            if (row) {
                row.forceActiveFocus(Qt.OtherFocusReason)
                return
            }
        }
        page?.nextItemInFocusChain(true)?.forceActiveFocus(Qt.OtherFocusReason)
    }

    onOpened: focusPage()

    background: Rectangle {
        radius: VLCStyle.dp(10, VLCStyle.scale)
        color: root._dark ? Qt.rgba(0x0E / 255, 0x0E / 255, 0x0E / 255, 0.95) : theme.bg.primary
    }

    contentItem: ColumnLayout {
        HoverHandler { id: cardHover }

        // the popup is not an Item, so the pages' ColorContexts find their palette here
        readonly property ColorContext colorContext: ColorContext {
            colorSet: ColorContext.Window
            palette: theme.palette
        }

        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: VLCStyle.dp(50, VLCStyle.scale)
            visible: root.tabs.length > 0
            topLeftRadius: VLCStyle.dp(10, VLCStyle.scale)
            topRightRadius: VLCStyle.dp(10, VLCStyle.scale)
            color: root._dark ? "#090909" : theme.bg.secondary

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    id: tabRepeater

                    model: root.tabs

                    delegate: T.TabButton {
                        id: tab

                        required property int index
                        required property var modelData

                        readonly property ColorContext colorContext: ColorContext {
                            id: tabTheme
                            colorSet: ColorContext.TabButton
                            focused: tab.visualFocus
                        }

                        readonly property color _fg: checked ? (root._dark ? "#8F8F8F" : theme.fg.primary)
                                                             : (root._dark ? "#6B6B6B" : theme.fg.secondary)

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        checked: root.currentTab === index
                        text: modelData.text
                        onClicked: root.currentTab = index
                        function _select(i) {
                            root.currentTab = Math.max(0, Math.min(root.tabs.length - 1, i))
                            tabRepeater.itemAt(root.currentTab).forceActiveFocus(Qt.TabFocusReason)
                        }

                        // only the current tab is in the focus chain: Up from the first row lands on it
                        focusPolicy: checked ? Qt.StrongFocus : Qt.ClickFocus
                        Keys.onDownPressed: root.focusPage()
                        Keys.onLeftPressed: _select(root.currentTab - 1)
                        Keys.onRightPressed: _select(root.currentTab + 1)

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

                                Widgets.LabelExt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.text
                                    font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
                                    color: tab._fg
                                }
                            }
                        }

                        background: Item {
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: VLCStyle.dp(4, VLCStyle.scale)
                                radius: VLCStyle.dp(4, VLCStyle.scale)
                                color: "transparent"
                                border.width: VLCStyle.focus_border
                                border.color: tabTheme.visualFocus
                                visible: tab.visualFocus
                            }

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

        Flickable {
            id: pageFlick

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: root.fillHeight ? -1 : pageHolder.implicitHeight
            Layout.minimumHeight: 0

            contentWidth: width
            contentHeight: pageHolder.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            // keep the keyboard-focused row in view
            Connections {
                target: pageFlick.Window.window
                function onActiveFocusItemChanged() {
                    const item = pageFlick.Window.activeFocusItem
                    let p = item
                    while (p && p !== pageHolder)
                        p = p.parent
                    if (!p)
                        return
                    const y = item.mapToItem(pageHolder, 0, 0).y
                    if (y < pageFlick.contentY)
                        pageFlick.contentY = y
                    else if (y + item.height > pageFlick.contentY + pageFlick.height)
                        pageFlick.contentY = y + item.height - pageFlick.height
                }
            }

            Item {
                id: pageHolder

                width: pageFlick.width
                implicitHeight: root.fillHeight ? pageFlick.height : (children[root.currentTab]?.implicitHeight ?? 0)
                height: implicitHeight

                function _sync() {
                    for (let i = 0; i < children.length; ++i) {
                        children[i].visible = (i === root.currentTab)
                        children[i].width = Qt.binding(() => pageHolder.width)
                        if (root.fillHeight) {
                            const page = children[i]
                            page.height = Qt.binding(() => pageHolder.height)
                        }
                    }
                }

                onChildrenChanged: _sync()

                Connections {
                    target: root
                    function onCurrentTabChanged() { pageHolder._sync() }
                }
            }
        }

        T.Button {
            id: footer

            readonly property ColorContext colorContext: ColorContext {
                id: footerTheme
                colorSet: ColorContext.ButtonStandard
                focused: footer.visualFocus
            }

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
                border.color: footerTheme.visualFocus
            }

            contentItem: Widgets.LabelExt {
                text: footer.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._dark ? "#8F8F8F" : theme.fg.primary
            }
        }
    }
}
