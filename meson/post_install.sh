#!/bin/sh

ln -f ${DESTDIR}/${MESON_INSTALL_PREFIX}/bin/fc-get  ${DESTDIR}/${MESON_INSTALL_PREFIX}/bin/fc-set

# Go programs, without whinging
for FN in mwp-plot-elevations bproxy ublox-geo ublox-cli flashdl ; do
  if [ -e  $MESON_BUILD_ROOT/$FN ] ; then
    rm -f $MESON_INSTALL_PREFIX/bin/$FN
    install -C $MESON_BUILD_ROOT/$FN $MESON_INSTALL_PREFIX/bin
  fi
done

if [ -z $DESTDIR ]; then
  echo Compiling gsettings schemas...
  glib-compile-schemas $MESON_INSTALL_PREFIX/share/glib-2.0/schemas

  echo Updating desktop icon cache...
  gtk-update-icon-cache -qtf $MESON_INSTALL_PREFIX/share/icons/hicolor
fi
