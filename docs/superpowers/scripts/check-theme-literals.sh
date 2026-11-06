#!/bin/sh
# check-theme-literals.sh [PATH...]
# Lists every QML/JS line under modules/gui/qt (or the given paths) that writes a dark Figma token's
# hex (also as #AARRGGBB), a near-token dark literal or a Qt.rgba(0x..) colour, instead of reading theme.palette.tokens.
# A line ending in "// fixed colour: <reason>" is allowed. Exits 1 if anything is listed.
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
[ $# -gt 0 ] || set -- "$REPO/modules/gui/qt"
# the 20 dark token hexes (style/figmatokens.cpp), then the off-token dark literals
HEX='EAEAEA|C6C6C6|969696|8F8F8F|6B6B6B|404040|161616|222222|1F1F1F|1B1B1B|191919|151515|0E0E0E|090909|373737|D37918|FC9729|AB6314|371F06|1A1611'
HEX="$HEX|1E1E1E|171717|2A2A2A|3A3A3A|202020|2D2D2D"
grep -rniE --include='*.qml' --include='*.js' "#([0-9A-Fa-f]{2})?($HEX)\b|Qt\.rgba\(0x" "$@" | grep -v '// fixed colour:' && exit 1
exit 0
