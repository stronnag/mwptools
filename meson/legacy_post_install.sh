#!/usr/bin/env bash

if [ -z $DESTDIR ]; then
  echo >&2 Compiling gsettings schemas ...
  glib-compile-schemas $MESON_INSTALL_PREFIX/share/glib-2.0/schemas

  echo >&2 Updating desktop icon cache ...
  gtk-update-icon-cache -qtf $MESON_INSTALL_PREFIX/share/icons/hicolor

  echo >&2 Updating mime database ...
  update-mime-database $MESON_INSTALL_PREFIX/share/mime

  echo >&2  Updating desktop database ...
  update-desktop-database  $MESON_INSTALL_PREFIX/share/applications
fi
