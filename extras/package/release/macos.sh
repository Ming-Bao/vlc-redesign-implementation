#!/bin/bash
# Build the macOS disk image into $1 (default: dist/), for ARCH aarch64
# (default) or x86_64 (Intel, cross-compiled). Runs on a GitHub macos-latest
# (Apple Silicon) runner (see release.yml).
set -e
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
export PATH="$ROOT/extras/package/release/bin:$PATH"  # retrying curl
OUT=$(mkdir -p "${1:-$ROOT/dist}" && cd "${1:-$ROOT/dist}" && pwd)
VERSION=${VERSION:-beta}
APP="VLC Redesign.app"
ID=io.github.ming-bao.vlc-redesign
ARCH=${ARCH:-aarch64}
case $ARCH in
    aarch64) DMG_ARCH=arm64 ;;
    x86_64) DMG_ARCH=x86_64 ;;
    *) echo "ARCH must be aarch64 or x86_64" >&2; exit 1 ;;
esac

# Upstream's prebuilt contribs; Qt (not built for macOS upstream) is built on
# top, and the Qt interface replaces the macosx one.
export VLC_FORCE_KERNELVERSION=19
export VLC_PREBUILT_CONTRIBS_URL=https://artifacts.videolan.org/vlc/macos-$DMG_ARCH/vlc-contrib-$ARCH-apple-darwin19-a302ba5409be61e07f8d4b34ed57d88258d7cc59.tar.zst
export VLC_CONTRIB_REBUILD="qt-tools qt qtsvg qtshadertools-tools qtdeclarative-tools qtdeclarative"
# ncurses: Homebrew's (pulled in by the build tools) points at an SDK the runner lacks.
export VLC_CONFIGURE_ARGS="--enable-qt --disable-ncurses"
export MINIMAL_OSX_VERSION=12.0   # Qt 6.8's minimum

mkdir -p "$ROOT/build-macos-$ARCH" && cd "$ROOT/build-macos-$ARCH"
# -d: release build (debug makes qmake link the _debug static Qt plugins)
"$ROOT/extras/package/macosx/build.sh" -d -a "$ARCH" -j "$(sysctl -n hw.ncpu)" || {
    # Which build files still ask for frameworks the SDK lacks.
    grep -rlw AGL contrib --include='*.prl' --include='*.pc' --include='*.cmake' \
        --include='*.conf' --include='*.la' --include='*.pri' 2>/dev/null | head -30
    exit 1
}

# The app must not depend on anything outside the bundle and the system.
if find VLC.app -type f \( -name '*.dylib' -o -perm -u+x \) -exec otool -L {} + 2>/dev/null |
        grep -E '/opt/homebrew|/usr/local/'; then
    echo "VLC.app links libraries from outside the bundle" >&2
    exit 1
fi

# Cross builds must really be for the target.
[ "$(lipo -archs VLC.app/Contents/MacOS/VLC)" = "$DMG_ARCH" ] || {
    echo "VLC.app is $(lipo -archs VLC.app/Contents/MacOS/VLC), not $DMG_ARCH" >&2
    exit 1
}

rm -rf dmg && mkdir dmg
cp -R VLC.app "dmg/$APP"
PL="dmg/$APP/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$ID" "$PL"
plutil -replace CFBundleName -string "VLC Redesign" "$PL"
plutil -replace CFBundleDisplayName -string "VLC Redesign" "$PL"
codesign --force --deep -s - "dmg/$APP"
cp "$ROOT/extras/package/release/uninstall.sh" "dmg/Uninstall VLC Redesign.command"
chmod +x "dmg/Uninstall VLC Redesign.command"
ln -s /Applications dmg/Applications
hdiutil create -volname "VLC Redesign" -srcfolder dmg -format UDZO -ov \
    "$OUT/vlc-redesign-$VERSION-macos-$DMG_ARCH.dmg"
ls -l "$OUT"
