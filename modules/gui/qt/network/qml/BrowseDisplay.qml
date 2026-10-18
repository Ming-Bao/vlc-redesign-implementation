/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import QtQml.Models
import QtQml


import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style
import VLC.Network
import VLC.Dialogs

Widgets.PageLoader {
    id: root

    property int displayMarginBeginning: 0
    property int displayMarginEnd: 0

    property bool enableBeginningFade: true
    property bool enableEndFade: true

    // Settings

    pageModel: [{
        name: "home",
        default: true,
        component: browseHome
    }, {
        name: "podcasts",
        component: sourcePages
    }, {
        name: "radio",
        component: sourcePages
    }, {
        name: "browse",
        component: browseComponent,
        guard: function (prop) { return !!prop.tree }
    }]

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Browse view")

    //functions

    function _showBrowseNode(tree, reason) {
        History.push([...root.pagePrefix, "browse"], { tree: tree }, reason)
    }

    // Children
    Component {
        id: browseHome

        NetworkHomeDisplay { }
    }

    // Podcasts / Radio: the service discovery source's root, then the nodes below it
    Component {
        id: sourcePages

        Widgets.PageLoader {
            id: sourceLoader

            // "podcasts" | "radio": this loader's name, the last of its path
            readonly property bool podcasts: pagePrefix[pagePrefix.length - 1] === "podcasts"
            readonly property string sourceTitle: podcasts ? qsTr("Podcasts") : qsTr("Radio")

            readonly property var _crumbs: [
                { title: qsTr("Network"), path: root.pagePrefix },
                { title: sourceTitle, path: pagePrefix }
            ]

            function _showNode(tree, reason) {
                History.push([...pagePrefix, "browse"], { tree: tree }, reason)
            }

            pageModel: [{
                name: "base",
                default: true,
                component: sourceRoot
            }, {
                name: "browse",
                component: sourceBrowse,
                guard: function (prop) { return !!prop.tree }
            }]

            Component {
                id: sourceRoot

                BrowseTreeDisplay {
                    id: sourceRootPage

                    displayMarginBeginning: root.displayMarginBeginning
                    displayMarginEnd: root.displayMarginEnd

                    enableBeginningFade: root.enableBeginningFade
                    enableEndFade: root.enableEndFade

                    title: sourceLoader.sourceTitle
                    breadcrumbs: sourceLoader._crumbs

                    addText: sourceLoader.podcasts ? qsTr("Add podcast") : ""
                    onAddActivated: DialogsProvider.podcastConfigureDialog()

                    model: NetworkDeviceModel {
                        id: deviceModel

                        ctx: MainCtx
                        sd_source: NetworkDeviceModel.CAT_INTERNET
                        source_name: sourceLoader.podcasts ? "podcast" : "radio"

                        searchPattern: sourceRootPage.search.pattern
                        sortOrder: sourceRootPage.sort.order
                        sortCriteria: sourceRootPage.sort.criteria
                    }

                    contextMenu: NetworkDeviceContextMenu {
                        model: deviceModel
                        ctx: MainCtx
                    }

                    onBrowse: (tree, reason) => sourceLoader._showNode(tree, reason)

                    onCurrentIndexChanged: History.viewProp.initialIndex = currentIndex
                }
            }

            Component {
                id: sourceBrowse

                BrowseTreeDisplay {
                    id: sourceBrowsePage

                    property alias tree: mediaModel.tree

                    displayMarginBeginning: root.displayMarginBeginning
                    displayMarginEnd: root.displayMarginEnd

                    enableBeginningFade: root.enableBeginningFade
                    enableEndFade: root.enableEndFade

                    // Network ▸ source ▸ node…, each crumb pushes what onBrowse would push for its node
                    breadcrumbs: sourceLoader._crumbs.concat(headerPath.map((node) => ({
                        title: node.display,
                        path: [...sourceLoader.pagePrefix, "browse"],
                        props: { tree: node.tree }
                    })))

                    model: NetworkMediaModel {
                        id: mediaModel

                        ctx: MainCtx

                        searchPattern: sourceBrowsePage.search.pattern
                        sortOrder: sourceBrowsePage.sort.order
                        sortCriteria: sourceBrowsePage.sort.criteria
                    }

                    contextMenu: NetworkMediaContextMenu {
                        model: mediaModel
                        ctx: MainCtx
                    }

                    onBrowse: (tree, reason) => sourceLoader._showNode(tree, reason)

                    onCurrentIndexChanged: History.viewProp.initialIndex = currentIndex
                }
            }
        }
    }

    Component {
        id: browseComponent

        BrowseTreeDisplay {
            id: browseTreePage

            property alias tree: mediaModel.tree

            displayMarginBeginning: root.displayMarginBeginning
            displayMarginEnd: root.displayMarginEnd

            enableBeginningFade: root.enableBeginningFade
            enableEndFade: root.enableEndFade

            model: NetworkMediaModel {
                id: mediaModel

                ctx: MainCtx

                sortCriteria: browseTreePage.sort.criteria
                sortOrder: browseTreePage.sort.order
                searchPattern: browseTreePage.search.pattern
            }

            contextMenu: NetworkMediaContextMenu {
                model: mediaModel
                ctx: MainCtx
            }

            Navigation.cancelAction: function() {
                History.previous(Qt.BacktabFocusReason)
            }

            onBrowse: (tree, reason) => {
                root._showBrowseNode(tree, reason)
            }

            onCurrentIndexChanged: History.viewProp.initialIndex = currentIndex
        }
    }
}
