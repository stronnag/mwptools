#!/usr/bin/env bash

VERBOSE=
[ -z "$1" ] && { echo "meson/uninstall.sh INSTALL_PREFIX" ; exit 42; }
[ -n "$2" ] && VERBOSE=-v

MESON_INSTALL_PREFIX=$1
rm $VERBOSE -f $MESON_INSTALL_PREFIX/bin/{fc-set,flashdl,ublox-geo,ublox-cli,mwp-inav-radar-sim,mwp-mavlink-traffic-sim,mwp-gatt-bridge,mwp,mwp-area-planner,mwp-plot-elevations,mwp-log-replay,mwp-serial-cap}
rm $VERBOSE -rf $MESON_INSTALL_PREFIX/lib/mwp
rm $VERBOSE -f $MESON_INSTALL_PREFIX/lib/*mwp*
rm $VERBOSE -f $MESON_INSTALL_PREFIX/share/applications/{mwp.desktop,org.stronnag.mwp.desktop,mwp-area-planner.desktop}
rm $VERBOSE -rf $MESON_INSTALL_PREFIX/share/doc/mwp
rm $VERBOSE -f $MESON_INSTALL_PREFIX/share/glib-2.0/schemas/org.stronnag.mwp.gschema.xml
rm $VERBOSE -f $MESON_INSTALL_PREFIX/share/icons/hicolor/scalable/apps/{mwp_icon.svg,mwp_area_icon.svg
rm $VERBOSE -f $MESON_INSTALL_PREFIX/share/mime/packages/mwp-mimetypes.xml
rm $VERBOSE -f $MESON_INSTALL_PREFIX/share/nautilus/scripts/send-to-mwp
rm $VERBOSE -rf $MESON_INSTALL_PREFIX/share/mwp
rm $VERBOSE -f $MESON_INSTALL_PREFIX/share/vala/vapi/mwp*
rm $VERBOSE -f $MESON_INSTALL_PREFIX/include/mwp*.h

glib-compile-schemas $MESON_INSTALL_PREFIX/share/glib-2.0/schemas
gtk-update-icon-cache -qtf $MESON_INSTALL_PREFIX/share/icons/hicolor
update-mime-database $MESON_INSTALL_PREFIX/share/mime
update-desktop-database  $MESON_INSTALL_PREFIX/share/applications
