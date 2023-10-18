#!/usr/bin/env bash

# Ugly, but necesary to force getting correct build info
rm -f ${MESON_BUILD_ROOT}/src/mwp/_mwpvers.h

INSTDIR=${MESON_INSTALL_PREFIX}
if [ -n "$DESTDIR" ] ; then
  INSTDIR=${DESTDIR}/${MESON_INSTALL_PREFIX}
fi

ln -f ${INSTDIR}/bin/fc-get  ${INSTDIR}/bin/fc-set

# Additional programs, without whinging
for FN in ublox-geo ublox-cli flashdl ; do
  if [ -e  $MESON_BUILD_ROOT/$FN ] ; then
    rm -f $INSTDIR/bin/$FN
    install -C $MESON_BUILD_ROOT/$FN $INSTDIR/bin
  fi
done
