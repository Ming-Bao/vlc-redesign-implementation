/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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

pragma Singleton

import QtQuick

QtObject {

    function clamp(num : real, min : real, max : real) : real {
      return num <= min ? min : num >= max ? max : num;
    }

    // The index an arrow key (dx or dy is ±1) reaches in a grid of `count` items, `columns` per row,
    // or -1 when it leaves the grid: Left/Right stop at the row's ends, Up leaves from the first row,
    // Down leaves from the last row and lands on the last item when the row below is short.
    function gridStep(from : int, dx : int, dy : int, columns : int, count : int) : int {
        if (dx !== 0) {
            const to = from + dx
            return (to >= 0 && to < count && Math.floor(to / columns) === Math.floor(from / columns)) ? to : -1
        }
        if (dy < 0)
            return from - columns >= 0 ? from - columns : -1
        return Math.floor(from / columns) < Math.floor((count - 1) / columns) ? Math.min(from + columns, count - 1) : -1
    }

    // Tiles that count as items on a library root: everything but the Add tile
    function rootItemCount(tiles : var) : int {
        return tiles.filter(t => !t.add).length
    }

    // `fixed` tiles, then one tile per share (in order), each carrying its index as `share`
    function withShares(fixed : var, shares : var, glyph : string) : var {
        return [...fixed, ...shares.map((s, i) => ({ glyph: glyph, text: s.name, share: i }))]
    }

    // Distinct non-empty keys, most frequent first; ties keep the earliest (most recent) key.
    function rankByFrequency(keys: var) : var {
        const counts = {}
        const order = []
        for (const key of keys) {
            if (!key)
                continue
            if (!(key in counts)) {
                counts[key] = 0
                order.push(key)
            }
            ++counts[key]
        }
        // Array.sort is stable
        return order.sort((a, b) => counts[b] - counts[a])
    }

    // Folders of `file://` MRLs (most recent first), most played first
    function folderEntries(mrls: var) : var {
        const names = {}
        const folders = []
        for (const mrl of mrls) {
            const slash = mrl.lastIndexOf("/")
            // skip non-file MRLs and files at the root (slash is the one ending "file:///")
            if (!mrl.startsWith("file://") || slash <= "file://".length)
                continue
            const folder = mrl.substring(0, slash)
            const segment = folder.substring(folder.lastIndexOf("/") + 1)
            if (!segment)
                continue
            if (!(folder in names)) {
                try {
                    names[folder] = decodeURIComponent(segment)
                } catch (e) {
                    names[folder] = segment // malformed escape, e.g. a Latin-1 "%E9"
                }
            }
            folders.push(folder)
        }
        return rankByFrequency(folders).map(mrl => ({ mrl: mrl, name: names[mrl] }))
    }

    function isValidInstanceOf(object: var, type: var) : bool {
        return (!!object && (object instanceof type))
    }

    function transferFocus(item: Item, reason: int) {
        if (item.activeFocus && item.focusReason === reason)
            return

        if (item.setCurrentItemFocus)
            item.setCurrentItemFocus(reason)
        else
            item.forceActiveFocus(reason)
    }

    // NOTE: This allows us to force another 'reason' even when the item has activeFocus.
    function enforceFocus(item: Item, reason: int) {
        if (item.activeFocus && item.focusReason === reason)
            return

        item.focus = false;

        item.forceActiveFocus(reason);

        if (item.focusReason !== undefined)
            item.focusReason = reason // Control's focus reason sometimes is not adjusted with `forceActiveFocus()`, Qt bug?
    }

    function pointInRadius(x: real, y: real, radius: real) : bool {
         return (x * x + y * y < radius * radius)
    }

    // checks if point `pos` lies in rect `rect`
    function contains(rect : rect, pos : point) : bool {
        return (clamp(pos.x, rect.x, rect.x + rect.width) === pos.x)
                && (clamp(pos.y, rect.y, rect.y + rect.height) === pos.y)
    }

    function isInteger(data : var) : bool {
        return (typeof data === 'number' && (data % 1) === 0)
    }

    function compareFloat(a: real, b: real) : bool {
        return (Math.abs(a - b) < Number.EPSILON)
    }

    function alignUp(a : real, b : int) : int {
        return Math.ceil(a / b) * b
    }

    function alignDown(a : real, b : int) : int {
        return Math.floor(a / b) * b
    }

    // Currently only supports .25, .5, .75
    function denominatorForFloat(number : real) : int {
        const fraction = number % 1

        if (fraction === 0)
            return 1
        else if (compareFloat(fraction, 0.25))
            return 4
        else if (compareFloat(fraction, 0.50))
            return 2
        else if (compareFloat(fraction, 0.75))
            return 4
        else {
            console.error("Can not find denominator for number", number, "!")
            return 1
        }
    }

    function isSortedIntegerArrayConsecutive(array : var) : bool {
        for (let i = 1; i < array.length; ++i) {
            if ((array[i] - array[i - 1]) !== 1)
                return false
        }

        return true
    }

    function itemsMovable(sortedItemIndexes : var, targetIndex : int) : bool {
        return !isSortedIntegerArrayConsecutive(sortedItemIndexes) ||
                (targetIndex > (sortedItemIndexes[sortedItemIndexes.length - 1] + 1) ||
                 targetIndex < sortedItemIndexes[0])
    }

    /**
     * calculate content y for flickable such that item with given param will be fully visible
     * @param type:Flickable flickable
     * @param type:real y
     * @param type:real height
     * @param type:real topMargin
     * @param type:real bottomMargin
     * @return type:real appropriate contentY for flickable
     */
    function flickablePositionContaining(flickable : Flickable,
                                         y : real,
                                         height : real,
                                         topMargin : real,
                                         bottomMargin : real) : real {
        const itemTopY = flickable.originY + y
        const itemBottomY = itemTopY + height

        const viewTopY = flickable.contentY
        const viewBottomY = viewTopY + flickable.height

        let newContentY

        if (itemTopY < viewTopY)
             //item above view
            newContentY = itemTopY - topMargin
        else if (itemBottomY > viewBottomY)
             //item below view
            newContentY = itemBottomY + bottomMargin - flickable.height
        else
            newContentY = flickable.contentY

        return getFlickableBoundedContentY(flickable, newContentY)
    }

    function isArray(obj : var) : bool {
        return (obj?.length !== undefined) ?? false
    }

    // Similar to Item::contains(), but accepts area (rectangle):
    function itemIntersects(item: Item, area: rect) : bool {
        if (!item)
            return false
        if (area.width <= 0.0 || area.height <= 0.0)
            return false
        return !(((item.x < (area.x + area.width)) && ((item.x + item.width) > area.x)) &&
                 ((item.y < (area.y + area.height)) && ((item.y + item.height) > area.y)))
    }

    // Similar to `ItemView::positionViewAtIndex()` with `ItemView.Contain`,
    // but only the works in the y-axis for now.
    // The behavior is undefined if the item is not a visual child of the
    // content item. However, it is not required for the item to be a direct
    // child of the content item.
    function positionFlickableToContainItem(flickable: Flickable, item: Item) {
        console.assert(flickable)
        console.assert(item)
        console.assert(item.parent)
        const mappedRect = flickable.mapFromItem(item.parent, Qt.rect(item.x, item.y, item.width, item.height))
        // Flickable does not fully contain the item:
        if ((mappedRect.y < 0) || ((mappedRect.y + mappedRect.height) > flickable.height))
            flickable.contentY = getFlickableBoundedContentY(flickable,
                                                             flickable.contentItem.mapFromItem(item.parent, item.x, item.y).y -
                                                             Math.max(0, ((flickable.height - item.height) / 2)))
    }

    function getFlickableBoundedContentX(flickable: Flickable, contentX: real) : real {
        console.assert(flickable)
        return clamp(contentX,
                     estimateFlickableMinXExtent(flickable),
                     estimateFlickableMaxXExtent(flickable))
    }

    function getFlickableBoundedContentY(flickable: Flickable, contentY: real) : real {
        console.assert(flickable)
        return clamp(contentY,
                     estimateFlickableMinYExtent(flickable),
                     estimateFlickableMaxYExtent(flickable))
    }

    /// <flickable-extents>

    // FIXME: Get rid of this in favor of `QQuickFlickable::minXExtent()`:
    function estimateFlickableMinXExtent(flickable: Flickable) : real {
        console.assert(flickable)
        return (flickable.originX - flickable.leftMargin)
    }

    // FIXME: Get rid of this in favor of `QQuickFlickable::minYExtent()`:
    function estimateFlickableMinYExtent(flickable: Flickable) : real {
        console.assert(flickable)
        return (flickable.originY - flickable.topMargin)
    }

    // FIXME: Get rid of this in favor of `QQuickFlickable::maxXExtent()`:
    function estimateFlickableMaxXExtent(flickable: Flickable) : real {
        console.assert(flickable)
        return (flickable.originX + flickable.contentWidth - flickable.width + flickable.rightMargin)
    }

    // FIXME: Get rid of this in favor of `QQuickFlickable::maxYExtent()`:
    function estimateFlickableMaxYExtent(flickable: Flickable) : real {
        console.assert(flickable)
        return (flickable.originY + flickable.contentHeight - flickable.height + flickable.bottomMargin)
    }

    /// </flickable-extents>

    // 0: another section, 1: deeper in the entry's section, 2: at the section's root ("base" is PageLoader's default)
    function sidebarEntryState(viewPath : var, uri : var) : int {
        if (!uri || uri.length === 0 || viewPath.length < uri.length)
            return 0
        for (let i = 0; i < uri.length; i++)
            if (viewPath[i] !== uri[i])
                return 0
        const rest = viewPath.slice(uri.length)
        return (rest.length === 0 || (rest.length === 1 && rest[0] === "base")) ? 2 : 1
    }

    // Whether a model's mrl (percent-encoded) is the playing url (Player.url prints it decoded)
    function sameMedia(mrl : string, url : string) : bool {
        if (!mrl || !url)
            return false
        const dec = (s) => { try { return decodeURIComponent(s) } catch (e) { return s } }
        return dec(mrl) === dec(url)
    }

    // Label of one row of the redesign's sort menu (Figma "Sorting Options" 856:2215).
    // `text` is the page's own sortModel label, used for criteria the table does not know.
    function sortRowLabel(criteria : string, text : string, order : int) : string {
        const asc = (order === Qt.AscendingOrder)
        switch (criteria) {
        case "title":
        case "name":
            return asc ? qsTr("Title A-Z") : qsTr("Title Z-A")
        case "album_title":
            return asc ? qsTr("Album A-Z") : qsTr("Album Z-A")
        case "release_year":
            return asc ? qsTr("Oldest First") : qsTr("Newest First")
        case "duration":
            return asc ? qsTr("Shortest First") : qsTr("Longest First")
        case "last_played_date":
            return asc ? qsTr("Unwatched First") : qsTr("Watched First")
        case "main_artist":
            return asc ? qsTr("Artist A-Z") : qsTr("Artist Z-A")
        case "track_number":
            return asc ? qsTr("Track Number Ascending") : qsTr("Track Number Descending")
        case "disc_number":
            return asc ? qsTr("Disc Number Ascending") : qsTr("Disc Number Descending")
        case "mrl":
        case "url":
            return asc ? qsTr("URI Ascending") : qsTr("URI Descending")
        case "nb_tracks":
        case "nb_videos":
            return asc ? qsTr("Fewest Items First") : qsTr("Most Items First")
        default:
            return (asc ? qsTr("%1 Ascending") : qsTr("%1 Descending")).arg(text)
        }
    }

    // Page-header crumbs for the page at `prefix` titled `title`: one crumb per prefix level
    // that `labels` names (keyed by the joined path, e.g. "music/albums"), then the title
    // unless the last crumb already reads it. Each crumb is { title, path }.
    function breadcrumbs(prefix : var, title : string, labels : var) : var {
        const crumbs = []
        for (let i = 1; i <= prefix.length; ++i) {
            const path = prefix.slice(0, i)
            const label = labels[path.join("/")]
            if (label)
                crumbs.push({ title: label, path: path })
        }
        if (title && (crumbs.length === 0 || crumbs[crumbs.length - 1].title !== title))
            crumbs.push({ title: title, path: prefix.slice(0) })
        return crumbs
    }
}
