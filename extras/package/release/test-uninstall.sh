#!/bin/sh
# Self-check for uninstall.sh against a throwaway home.
set -u
U=$1; F=$(mktemp -d "$2/fakehome.XXXX")
export HOME=$F XDG_CONFIG_HOME=$F/.config XDG_DATA_HOME=$F/.local/share XDG_CACHE_HOME=$F/.cache
mkdir -p $F/.config/vlc $F/.config/other $F/.local/share/vlc/ml $F/.cache/vlc $F/.local/share/applications $F/Apps
touch $F/.local/share/applications/appimagekit_x-vlc-redesign.desktop $F/Apps/vlc-redesign.AppImage
echo n | sh $U $F/Apps/vlc-redesign.AppImage >/dev/null; [ $? = 1 ] && [ -d $F/.config/vlc ] || { echo FAIL cancel; exit 1; }
sh $U -y $F/Apps/vlc-redesign.AppImage
for p in .config/vlc .local/share/vlc .cache/vlc Apps/vlc-redesign.AppImage .local/share/applications/appimagekit_x-vlc-redesign.desktop; do
  [ -e $F/$p ] && { echo FAIL left $p; exit 1; }
done
[ -d $F/.config/other ] || { echo FAIL removed other; exit 1; }
sh $U -y | grep -q 'already uninstalled' || { echo FAIL rerun; exit 1; }
echo PASS
