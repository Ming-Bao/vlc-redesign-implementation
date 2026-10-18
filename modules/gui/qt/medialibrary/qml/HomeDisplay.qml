/******************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
 *
 * Author: Ash <ashutoshv191@gmail.com>
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
 ******************************************************************************/
import QtQuick

import VLC.MediaLibrary

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style

Widgets.PageLoader {
    id: root

    pageModel: [{
        name: "base",
        component: homeComponent,
        default: true
    }, {
        name: "continueWatching",
        component: continueWatchingComponent
    }, {
        name: "listenAgain",
        component: listenAgainComponent
    }, {
        name: "folders",
        component: foldersComponent
    }, {
        name: "favorites",
        component: favoritesComponent
    }]

    property int displayMarginBeginning: 0
    property int displayMarginEnd: 0

    property bool enableBeginningFade: true
    property bool enableEndFade: true

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Home View")
    AccessibleCompat.id: "homeDisplay"


    Component {
        id: homeComponent

        HomePage {
            focus: true

            onSeeAllButtonClicked: (name, reason) => {
                History.push([...root.pagePrefix, name], reason)
            }
        }
    }

    Component {
        id: continueWatchingComponent

        Widgets.PageExt {
            id: continueWatchingPage

            title: qsTr("Continue Watching")

            VideoAll {
                id: continueWatching

                anchors.fill: parent

                focus: true

                model: MLRecentVideoModel {
                    ml: MediaLib

                    sortCriteria: continueWatchingPage.sort.criteria
                    sortOrder: continueWatchingPage.sort.order
                    searchPattern: continueWatchingPage.search.pattern

                    readonly property bool needToNavigateBack: !loading && count === 0
                                                               && continueWatchingPage.search.pattern === ""

                    onNeedToNavigateBackChanged: {
                        if (needToNavigateBack)
                            History.previous(Qt.BacktabFocusReason)
                    }
                }

                sectionProperty: model.sortCriteria === "title" ? "title_first_symbol" : ""

                contextMenu: MLContextMenu {
                    model: continueWatching.model

                    showPlayAsAudioAction: true
                }

                displayMarginBeginning: root.displayMarginBeginning
                displayMarginEnd: root.displayMarginEnd

                enableBeginningFade: root.enableBeginningFade
                enableEndFade: root.enableEndFade
            }
        }
    }

    Component {
        id: listenAgainComponent

        Widgets.PageExt {
            id: listenAgainPage

            title: qsTr("Listen Again")

            MusicTrackListDisplay {
                anchors.fill: parent

                focus: true

                model: MLRecentAudioModel {
                    ml: MediaLib

                    sortCriteria: listenAgainPage.sort.criteria
                    sortOrder: listenAgainPage.sort.order
                    searchPattern: listenAgainPage.search.pattern

                    readonly property bool needToNavigateBack: !loading && count === 0
                                                               && listenAgainPage.search.pattern === ""

                    onNeedToNavigateBackChanged: {
                        if (needToNavigateBack)
                            History.previous(Qt.BacktabFocusReason)
                    }
                }

                section.property: model.sortCriteria === "title" ? "title_first_symbol" : ""

                Navigation.parentItem: listenAgainPage
                Navigation.upItem: listenAgainPage.header

                displayMarginBeginning: root.displayMarginBeginning
                displayMarginEnd: root.displayMarginEnd

                fadingEdge.enableBeginningFade: root.enableBeginningFade
                fadingEdge.enableEndFade: root.enableEndFade
            }
        }
    }

    Component {
        id: foldersComponent

        Widgets.PageExt {
            id: foldersPage

            title: qsTr("Frequently Visited Folders")

            isSearchable: true

            HomeFolderModel {
                id: folderModel

                onEmptyChanged: {
                    if (empty && foldersPage.search.pattern === "")
                        History.previous(Qt.BacktabFocusReason)
                }
            }

            function setCurrentItemFocus(reason) {
                const first = cards.itemAt(0)
                if (first)
                    first.forceActiveFocus(reason)
            }

            // the page takes the focus for itself (from the sidebar, or before the folders arrive),
            // and a reload destroys the focused card: hand it to a card
            function _restoreFocus(reason) {
                if (!foldersPage.activeFocus || (foldersPage.header?.activeFocus ?? false))
                    return
                for (let i = 0; i < cards.count; ++i) {
                    if (cards.itemAt(i).activeFocus)
                        return
                }
                setCurrentItemFocus(reason)
            }

            onActiveFocusChanged: if (activeFocus) Qt.callLater(_restoreFocus, focusReason)

            Flickable {
                id: foldersFlickable

                anchors.fill: parent

                focus: true

                contentWidth: width
                contentHeight: flow.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Flow {
                    id: flow

                    width: parent.width
                    spacing: VLCStyle.dp(20, VLCStyle.scale)
                    leftPadding: foldersPage.header?.leftPadding ?? 0
                    topPadding: VLCStyle.dp(20, VLCStyle.scale)

                    // cards on one line, for Up/Down
                    readonly property int perLine: Math.max(1, Math.floor((width - leftPadding + spacing) / (VLCStyle.dp(200, VLCStyle.scale) + spacing)))

                    Repeater {
                        id: cards

                        model: {
                            const pattern = foldersPage.search.pattern.toLowerCase()
                            return folderModel.entries.filter(e => e.name.toLowerCase().includes(pattern))
                        }

                        onItemAdded: Qt.callLater(foldersPage._restoreFocus, Qt.OtherFocusReason)

                        HomeSquareCard {
                            id: card

                            required property var modelData
                            required property int index

                            glyph: VLCIcons.folder
                            backing: "#1E1E1E"
                            title: modelData.name

                            Navigation.parentItem: foldersFlickable
                            Navigation.leftAction: () => {
                                if (index > 0)
                                    cards.itemAt(index - 1).forceActiveFocus(Qt.BacktabFocusReason)
                                else
                                    foldersFlickable.Navigation.defaultNavigationLeft()
                            }
                            Navigation.rightAction: () => {
                                if (index < cards.count - 1)
                                    cards.itemAt(index + 1).forceActiveFocus(Qt.TabFocusReason)
                                else
                                    foldersFlickable.Navigation.defaultNavigationRight()
                            }
                            Navigation.upAction: () => {
                                if (index >= flow.perLine)
                                    cards.itemAt(index - flow.perLine).forceActiveFocus(Qt.BacktabFocusReason)
                                else
                                    foldersFlickable.Navigation.defaultNavigationUp()
                            }
                            // the last line may be short: land on its last card
                            Navigation.downAction: () => {
                                if (index + flow.perLine < cards.count)
                                    cards.itemAt(index + flow.perLine).forceActiveFocus(Qt.TabFocusReason)
                                else if (Math.floor(index / flow.perLine) < Math.floor((cards.count - 1) / flow.perLine))
                                    cards.itemAt(cards.count - 1).forceActiveFocus(Qt.TabFocusReason)
                            }

                            onActiveFocusChanged: if (activeFocus) Helpers.positionFlickableToContainItem(foldersFlickable, card)

                            onActivated: (reason) => {
                                const tree = MainCtx.folderTree(modelData.mrl)
                                if (tree)
                                    History.push(["network", "browse"], { tree: tree }, reason)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: favoritesComponent

        Widgets.PageExt {
            id: favoritesPage

            title: qsTr("Favorites")

            MediaView {
                focus: true

                anchors.fill: parent

                model: MLMediaModel {
                    favoriteOnly: true

                    ml: MediaLib

                    sortCriteria: favoritesPage.sort.criteria || "insertion"
                    sortOrder: favoritesPage.sort.order
                    searchPattern: favoritesPage.search.pattern
                }

                displayMarginBeginning: root.displayMarginBeginning
                displayMarginEnd: root.displayMarginEnd

                enableBeginningFade: root.enableBeginningFade
                enableEndFade: root.enableEndFade
            }
        }
    }
}
