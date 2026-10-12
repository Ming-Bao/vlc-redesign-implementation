/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#ifndef NETWORKTREEITEM_HPP
#define NETWORKTREEITEM_HPP

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QObject>

#include "vlcmediasourcewrapper.hpp"
#include "util/shared_input_item.hpp"
#include "devicesourceprovider.hpp"

class NetworkTreeItem
{
    Q_GADGET
public:
    NetworkTreeItem() : source(nullptr), tree(nullptr), media(nullptr) {}

    NetworkTreeItem( SharedMediaSourceModel source, const SharedInputItem& item )
        : source(source)
        , tree(source->getTree())
        , media(item)
    {
    }

    NetworkTreeItem( MediaTreePtr tree, const SharedInputItem& item )
        : source(nullptr)
        , tree(tree)
        , media(item)
    {
    }

    //build a NetworkTreeItem with the same source/tree as parent
    NetworkTreeItem(NetworkTreeItem& parent, const SharedInputItem& item)
        : source(parent.source)
        , tree(parent.tree)
        , media(item)
    {
    }

    NetworkTreeItem( const NetworkTreeItem& ) = default;
    NetworkTreeItem& operator=( const NetworkTreeItem& ) = default;
    NetworkTreeItem( NetworkTreeItem&& ) = default;
    NetworkTreeItem& operator=( NetworkTreeItem&& ) = default;

    operator bool() const
    {
        return tree.get() != nullptr;
    }

    bool isValid() {
        MediaTreeLocker lock{ tree };
        input_item_node_t* node;
        return vlc_media_tree_Find( tree.get(), media.get(), &node, nullptr);
    }

    SharedMediaSourceModel source;
    MediaTreePtr tree;
    SharedInputItem media;
};

#endif // NETWORKTREEITEM_HPP
