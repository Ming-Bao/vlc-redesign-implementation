
/*****************************************************************************
 * Copyright (C) 2022 VLC authors and VideoLAN
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
import QtQml

import VLC.MainInterface
import VLC.Menus

// @brief - a class that can be used to create native menus with support
// to asyncronously retreive data from MLBaseModel like model

QtObject {
    id: root

    /**
      actions - list of action to show

      each action is an Object and contains following keys
        "text" - (string) display text of the action

        "action" - (function(dataList, options, indexes)) a function that will be called when action is selected

        "visible" - (Boolean or function(dataList,options, indexes) -> Boolean) (optional) a boolean value or function which
                    controls whether the action is shown in the menu following 'popup' call

        "icon" - (string) (optional) a menu icon name, ":/redesign/menu/<icon>.svg"

        "separator" - (Boolean) (optional) true: a divider row, without "text" or "action"

        "checked", "enabled" - (Boolean) (optional) a check mark / a greyed out row

       e.g see MLContextMenu.qml
    **/

    property var actions: []

    property alias visible: menu.visible

    readonly property int currentRequest: _currentRequest

    signal requestData(var requestID, var indexes)


    property var _options: null

    property var _indexes: []

    property var _dataList: null

    property int _currentRequest: 0

    property var _effectiveActions: null

    property point _popupPoint

    // requests data for '_indexes' and shows popup menu
    // with 'NativeMenu::actions' based on '_options'
    // returns unique request id
    function popup(_indexes, point, _options) {
        root._options = _options
        root._indexes = _indexes
        _dataList = null
        _popupPoint = point

        const requestID = ++_currentRequest
        requestData(requestID, _indexes)
        return requestID
    }

    function setData(id, data) {
        if (_currentRequest !== id)
            return;

        _dataList = data

        // one row per effective action, so a row's index is its action's (see addMenuRows)
        const rows = []
        _effectiveActions = []
        for (let i in actions) {
            const action = actions[i]

            if (!action.hasOwnProperty("visible")
                    || (typeof action.visible === "boolean" && action.visible)
                    || (typeof action.visible === "function" && action.visible(_dataList, _options, _indexes))) {
                _effectiveActions.push(action)
                rows.push(_row(action))
            }
        }

        menu.popup(_popupPoint, rows)
    }

    // a plain string unless the action has a row key (the action itself holds functions)
    function _row(action) {
        const keys = ["icon", "separator", "checked", "enabled"].filter(k => action.hasOwnProperty(k))
        if (keys.length === 0)
            return action.text

        const row = { text: action.text ?? "" }
        for (const k of keys)
            row[k] = action[k]
        return row
    }

    function _executeAction(index) {
        const action = root._effectiveActions[index]
        action.action(_dataList, _options, _indexes)
    }


    readonly property StringListMenu _menu: StringListMenu {
        id: menu

        ctx: MainCtx

        onSelected: (index, _) => {
            root._executeAction(index)
        }
    }
}
