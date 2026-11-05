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
.pragma library

// The nine accent swatches, shared by Settings and the onboarding card. The first is the default orange, stored as `default`.
const colors = ["#D37918", "#E15032", "#C49E23", "#19A234", "#18AAD3", "#185DD3", "#8E42FF", "#F052B3", "#AFAFAF"]

function optionValue(hex) {
    return hex === colors[0] ? "default" : hex
}

function fromOption(v) {
    return (!v || v === "default") ? colors[0] : v.toUpperCase()
}
