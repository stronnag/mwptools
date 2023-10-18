#!/usr/bin/env bash

[ -z "$1" ] && { echo "meson/uninstall.sh INSTALL_PREFIX" ; exit 42; }

MESON_INSTALL_PREFIX=$1
rm -f $MESON_INSTALL_PREFIX/bin/{fc-set,flashdl,ublox-geo,ublox-cli}
glib-compile-schemas $MESON_INSTALL_PREFIX/share/glib-2.0/schemas
gtk-update-icon-cache -qtf $MESON_INSTALL_PREFIX/share/icons/hicolor
update-mime-database $MESON_INSTALL_PREFIX/share/mime
update-desktop-database  $MESON_INSTALL_PREFIX/share/applications
