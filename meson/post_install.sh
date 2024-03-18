#!/usr/bin/env bash

# Ugly, but necesary to force getting correct build info
rm -f ${MESON_BUILD_ROOT}/src/mwp/_mwpvers.h

INSTDIR=${MESON_INSTALL_PREFIX}
if [ -n "$DESTDIR" ] ; then
  INSTDIR=${DESTDIR}/${MESON_INSTALL_PREFIX}
fi

ln -f ${INSTDIR}/bin/fc-get  ${INSTDIR}/bin/fc-set

#install -d $INSTDIR/share/vala/vapi/
#install -d $INSTDIR/include/
#install ${MESON_BUILD_ROOT}/src/common/mwpvlib.vapi  $INSTDIR/share/vala/vapi/
#install ${MESON_BUILD_ROOT}/src/common/mwpvlib.h  $INSTDIR/include/
