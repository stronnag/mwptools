#!/usr/bin/env bash
ln ${DESTDIR}/${MESON_INSTALL_PREFIX}/bin/fc-get  ${DESTDIR}/${MESON_INSTALL_PREFIX}/bin/fc-set

# Go programs, without whinging
for FN in /mwp-plot-elevations otxlog bbsummary ; do
  [ -e  $MESON_BUILD_ROOT/bin/$FN ] && cp $MESON_BUILD_ROOT/bin/$FN $MESON_INSTALL_PREFIX/bin
done

if [ -z $DESTDIR ]; then
  echo Compiling gsettings schemas...
  glib-compile-schemas $MESON_INSTALL_PREFIX/share/glib-2.0/schemas

  echo Updating desktop icon cache...
  gtk-update-icon-cache -qtf $MESON_INSTALL_PREFIX/share/icons/hicolor
fi
