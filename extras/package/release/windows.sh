#!/bin/sh
# Build the Windows installer and portable zip into $1 (default: dist/).
# Runs inside registry.videolan.org/vlc-debian-win64-posix (see release.yml).
set -e
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
export PATH="$ROOT/extras/package/release/bin:$PATH"  # retrying curl
OUT=$(mkdir -p "${1:-$ROOT/dist}" && cd "${1:-$ROOT/dist}" && pwd)
VERSION=${VERSION:-beta}

# The contrib (static) Qt is built without these (contrib/src/qtdeclarative/rules.mak): a QML file
# using one fails to load, and the main window never opens. Fail in seconds, not after the build.
if grep -rnE --include='*.qml' 'import QtQuick\.(Shapes|Particles)|\b(Canvas|Shape|ShapePath|PathView|PathLine|PathArc|PathAnimation|PathInterpolator|AnimatedImage|AnimatedSprite|SpriteSequence|Flipable)\s*\{' "$ROOT/modules/gui/qt"; then
    echo "error: QML above uses a type the static Qt does not have" >&2
    exit 1
fi

# Upstream's prebuilt contribs for this tree's contrib revision; only Qt is
# rebuilt, with the network module the redesign needs.
export VLC_PREBUILT_CONTRIBS_URL=https://artifacts.videolan.org/vlc/win64/vlc-contrib-x86_64-w64-mingw32-a5538c557d276378d5ba0f8f8010a8b87eaa6f78.tar.zst
export VLC_CONTRIB_REBUILD=qt

mkdir -p "$ROOT/build-win64" && cd "$ROOT/build-win64"
"$ROOT/extras/package/win32/build.sh" -a x86_64 -p -r -i r
cd win64  # build.sh builds in $PWD/win64

exe=$(ls vlc-*-win64.exe) zip=$(ls vlc-*-win64.zip)
top=${zip%-win64.zip}   # the zip holds this folder, e.g. vlc-4.0.0-dev/
cp "$ROOT/extras/package/release/uninstall.cmd" "$top/"
cp "$zip" "$OUT/vlc-redesign-$VERSION-win64-portable.zip"
zip -q "$OUT/vlc-redesign-$VERSION-win64-portable.zip" "$top/uninstall.cmd"
cp "$exe" "$OUT/vlc-redesign-$VERSION-win64.exe"
ls -l "$OUT"
