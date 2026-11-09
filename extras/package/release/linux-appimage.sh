#!/bin/sh
# Build the Linux AppImage into $1 (default: dist/).
# Runs inside registry.videolan.org/vlc-debian-unstable (see release.yml).
set -e
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
OUT=$(mkdir -p "${1:-$ROOT/dist}" && cd "${1:-$ROOT/dist}" && pwd)
VERSION=${VERSION:-beta}
J=$(nproc)
B=$ROOT/build-linux
APPDIR=$B/AppDir

# Meson >= 1.10 and friends from VLC's own tools.
(cd "$ROOT/extras/tools" && ./bootstrap && make -j$J)
export PATH="$ROOT/extras/tools/build/bin:$PATH"

[ -f "$B/build.ninja" ] || meson setup "$B" "$ROOT" --prefix=/usr --buildtype=release \
    -Dqt=enabled -Dtests=disabled
ninja -C "$B"
rm -rf "$APPDIR"
DESTDIR="$APPDIR" meson install -C "$B" --quiet

cat > "$B/vlc-redesign.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=VLC Redesign
GenericName=Media player
Comment=VLC media player with a redesigned interface
Exec=vlc --started-from-file %U
Icon=vlc-redesign
Terminal=false
Categories=AudioVideo;Player;Recorder;
MimeType=$(grep -v '^#' "$ROOT/share/vlc.desktop.mimetypes" | tr '\n' ';')
StartupWMClass=vlc
EOF
cp "$ROOT/share/icons/256x256/vlc.png" "$B/vlc-redesign.png"

cd "$B"
for t in linuxdeploy linuxdeploy-plugin-qt; do
    [ -x $t-x86_64.AppImage ] || curl -fsSLo $t-x86_64.AppImage \
        https://github.com/linuxdeploy/$t/releases/download/continuous/$t-x86_64.AppImage
    chmod +x $t-x86_64.AppImage
done
export APPIMAGE_EXTRACT_AND_RUN=1 NO_STRIP=1
export QMAKE=$(command -v qmake6 || echo /usr/lib/qt6/bin/qmake)
export QML_SOURCES_PATHS="$ROOT/modules/gui/qt"
export EXTRA_PLATFORM_PLUGINS="libqwayland-generic.so;libqwayland-egl.so"
export LDAI_OUTPUT="$OUT/vlc-redesign-$VERSION-x86_64.AppImage"
plugins=$(find "$APPDIR/usr/lib" -path '*vlc/plugins*' -name '*.so' | sed 's/^/--deploy-deps-only=/')
# shellcheck disable=SC2086
./linuxdeploy-x86_64.AppImage --appdir "$APPDIR" \
    -e "$APPDIR/usr/bin/vlc" -d vlc-redesign.desktop -i vlc-redesign.png \
    $plugins --plugin qt --output appimage

cp "$ROOT/extras/package/release/uninstall.sh" "$OUT/uninstall.sh"
ls -l "$OUT"
