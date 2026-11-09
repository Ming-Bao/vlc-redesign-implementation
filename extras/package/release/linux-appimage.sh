#!/bin/sh
# Build the Linux AppImage into $1 (default: dist/).
# Runs inside registry.videolan.org/vlc-debian-unstable (see release.yml).
set -e
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
export PATH="$ROOT/extras/package/release/bin:$PATH"  # retrying curl
OUT=$(mkdir -p "${1:-$ROOT/dist}" && cd "${1:-$ROOT/dist}" && pwd)
VERSION=${VERSION:-beta}
J=$(nproc)
B=$ROOT/build-linux
APPDIR=$B/AppDir

# The image lags sid: bring Qt up to date and add the runtime plugins the
# redesign needs.
if [ "$(id -u)" = 0 ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get full-upgrade -y -qq
    apt-get install -y -qq qt6-svg-plugins qt6-image-formats-plugins qt6-wayland
fi

# Meson >= 1.10 and friends from VLC's own tools.
(cd "$ROOT/extras/tools" && ./bootstrap && make -j$J)
export PATH="$ROOT/extras/tools/build/bin:$PATH"

# medialibrary 0.13 (sid's 0.14 has another API), as in VLC's contribs.
ML=medialibrary-0.13.2
if ! pkg-config --exact-version=0.13.2 medialibrary 2>/dev/null; then
    mkdir -p "$ROOT/build-ml" && cd "$ROOT/build-ml"
    [ -d $ML ] || curl -fsSL --retry 5 https://code.videolan.org/videolan/medialibrary/-/archive/0.13.2/$ML.tar.bz2 | tar xj
    meson setup $ML/build $ML --prefix=/usr --libdir=lib/x86_64-linux-gnu --buildtype=release \
        -Dlibvlc=disabled -Dtests=disabled
    ninja -C $ML/build install
    cd "$ROOT"
fi

[ -f "$B/build.ninja" ] || meson setup "$B" "$ROOT" --prefix=/usr --buildtype=release \
    -Dqt=enabled -Dmedialibrary=enabled -Dtests=disabled
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
cp "$B/vlc-redesign.desktop" "$APPDIR/"
cp "$ROOT/share/icons/256x256/vlc.png" "$APPDIR/vlc-redesign.png"

# Qt's plugins and QML modules, then every library anything needs, except the
# ones that must come from the host (the AppImage excludelist's core).
QT_PLUGINS=$(qtpaths6 --query QT_INSTALL_PLUGINS)
QT_QML=$(qtpaths6 --query QT_INSTALL_QML)
mkdir -p "$APPDIR/usr/qt/plugins" "$APPDIR/usr/lib/bundled"
for d in platforms platformthemes platforminputcontexts imageformats iconengines tls \
         xcbglintegrations wayland-decoration-client wayland-graphics-integration-client \
         wayland-shell-integration; do
    [ -d "$QT_PLUGINS/$d" ] && cp -a "$QT_PLUGINS/$d" "$APPDIR/usr/qt/plugins/"
done
cp -a "$QT_QML" "$APPDIR/usr/qt/qml"
EXCLUDE='/(ld-linux[^/]*|lib(c|m|dl|pthread|rt|resolv|util|anl|nsl|mvec)\.so[^/]*|libGL[^/]*|libEGL[^/]*|libGLX[^/]*|libGLdispatch[^/]*|libOpenGL[^/]*|libdrm\.so[^/]*|libgbm[^/]*|libvulkan[^/]*|libX11[^/]*|libxcb\.so[^/]*|libasound[^/]*|libjack[^/]*|libpipewire[^/]*|libfontconfig[^/]*|libfreetype[^/]*|libharfbuzz\.so[^/]*|libgcc_s[^/]*|libstdc\+\+[^/]*|libwayland-(client|server|egl|cursor)[^/]*|libudev[^/]*|libsystemd[^/]*|libdbus-1[^/]*)$'
LIBDIRS=$(find "$APPDIR/usr/lib" -name '*.so*' -printf '%h\n' | sort -u | tr '\n' ':')
find "$APPDIR" -type f | while read -r f; do
    [ "$(head -c4 "$f" | od -An -c | tr -d ' ')" = '177ELF' ] && LD_LIBRARY_PATH="$LIBDIRS" ldd "$f" 2>/dev/null
done | awk '/=> \//{print $3}' | sort -u | grep -v -E "$EXCLUDE" | grep -v "^$APPDIR" |
    while read -r l; do cp -nL "$l" "$APPDIR/usr/lib/bundled/"; done

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE=$(dirname "$(readlink -f "$0")")
export LD_LIBRARY_PATH="$HERE/usr/lib/x86_64-linux-gnu:$HERE/usr/lib/x86_64-linux-gnu/vlc:$HERE/usr/lib/bundled${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QT_PLUGIN_PATH="$HERE/usr/qt/plugins" QML_IMPORT_PATH="$HERE/usr/qt/qml" QML2_IMPORT_PATH="$HERE/usr/qt/qml"
exec "$HERE/usr/bin/vlc" "$@"
EOF
chmod +x "$APPDIR/AppRun"

cd "$B"
GH=https://github.com/AppImage
for f in appimagetool:appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
         runtime:type2-runtime/releases/download/continuous/runtime-x86_64; do
    [ -s "${f%%:*}" ] || curl -fsSL --retry 10 --retry-delay 15 --retry-all-errors -o "${f%%:*}" "$GH/${f#*:}"
done
chmod +x appimagetool
ARCH=x86_64 ./appimagetool --appimage-extract-and-run --runtime-file runtime \
    "$APPDIR" "$OUT/vlc-redesign-$VERSION-x86_64.AppImage"

cp "$ROOT/extras/package/release/uninstall.sh" "$OUT/uninstall.sh"
ls -l "$OUT"
